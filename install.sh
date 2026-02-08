#!/bin/bash
# Bootstrap script for dotfiles installation
# Safe to curl | bash
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash -s -- --mode server

set -Eeuo pipefail

# Make common user-local install locations available in-process.
# This avoids requiring a shell restart after chezmoi applies tool installers.
export PATH="$HOME/.local/bin:$HOME/bin:$HOME/go/bin:$HOME/.opencode/bin:/usr/local/go/bin:$PATH"

# ============================================================================
# Configuration
# ============================================================================

REPO_URL="https://github.com/PoeAudits/dotfiles.git"

# Default values
MODE=""
VERBOSE="${VERBOSE:-false}"

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo "==> $*" >&2
}

log_error() {
    echo "ERROR: $*" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "DEBUG: $*" >&2
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

usage() {
    cat <<EOF
Bootstrap script for dotfiles installation

Usage:
    $0 [OPTIONS]

Options:
    --mode MODE     Installation mode (e.g., server, desktop)
    --verbose       Enable verbose output
    -h, --help      Show this help message

Examples:
    # Basic installation
    curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/install.sh | bash

    # With mode specified
    curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/install.sh | bash -s -- --mode server

EOF
    exit "${1:-0}"
}

detect_os() {
    local os=""
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os="$ID"
    elif [[ -f /etc/arch-release ]]; then
        os="arch"
    elif [[ -f /etc/debian_version ]]; then
        os="ubuntu"
    else
        os="unknown"
    fi
    
    echo "$os"
}

check_dependencies() {
    local -a missing_deps=()
    local -a required=("curl" "git")

    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_deps[*]}"
        log_info "Please install them and try again"
        return 1
    fi
}

install_chezmoi() {
    local os="$1"
    
    log_info "Checking for chezmoi..."
    
    # Check if chezmoi is already installed
    if command -v chezmoi &>/dev/null; then
        log_info "chezmoi is already installed: $(chezmoi --version)"
        return 0
    fi
    
    log_info "Installing chezmoi..."
    
    case "$os" in
        arch|manjaro)
            log_info "Detected Arch-based system"
            if command -v pacman &>/dev/null; then
                sudo pacman -S --noconfirm chezmoi || {
                    log_error "Failed to install chezmoi via pacman"
                    return 1
                }
            else
                log_error "pacman not found"
                return 1
            fi
            ;;
        ubuntu|debian)
            log_info "Detected Debian-based system"
            # Use official chezmoi install script for Ubuntu/Debian
            # as package repos may have outdated versions
            sh -c "$(curl -fsLS get.chezmoi.io)" || {
                log_error "Failed to install chezmoi via official installer"
                return 1
            }
            # Add ~/bin to PATH if chezmoi was installed there
            if [[ -x "$HOME/bin/chezmoi" ]]; then
                export PATH="$HOME/bin:$PATH"
            fi
            ;;
        *)
            log_info "Using official chezmoi installer for $os"
            sh -c "$(curl -fsLS get.chezmoi.io)" || {
                log_error "Failed to install chezmoi via official installer"
                return 1
            }
            # Add ~/bin to PATH if chezmoi was installed there
            if [[ -x "$HOME/bin/chezmoi" ]]; then
                export PATH="$HOME/bin:$PATH"
            fi
            ;;
    esac
    
    # Verify installation
    if ! command -v chezmoi &>/dev/null; then
        log_error "chezmoi installation failed - command not found"
        return 1
    fi
    
    log_info "chezmoi installed successfully: $(chezmoi --version)"
}

install_syncthing() {
    local os="$1"

    log_info "Checking for syncthing..."
    if command -v syncthing &>/dev/null; then
        log_info "syncthing already installed"
        return 0
    fi

    log_info "Installing syncthing..."
    case "$os" in
        arch|manjaro)
            if command -v pacman &>/dev/null; then
                sudo pacman -S --noconfirm syncthing || {
                    log_error "Failed to install syncthing via pacman"
                    return 1
                }
            else
                log_error "pacman not found"
                return 1
            fi
            ;;
        ubuntu|debian)
            if command -v apt-get &>/dev/null; then
                sudo apt-get update -y || true
                sudo apt-get install -y syncthing || {
                    log_error "Failed to install syncthing via apt"
                    return 1
                }
            else
                log_error "apt-get not found"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported OS for syncthing installation: $os"
            return 1
            ;;
    esac
}

configure_syncthing_service() {
    local mode="$1"

    log_info "Enabling syncthing user service..."
    # Ensure user services start at boot on headless servers.
    if [[ "$mode" == "server" ]] && command -v loginctl &>/dev/null; then
        loginctl enable-linger "${USER}" &>/dev/null || true
    fi
    systemctl --user enable syncthing.service || {
        log_error "Failed to enable syncthing user service"
        return 1
    }
    systemctl --user start syncthing.service || {
        log_error "Failed to start syncthing user service"
        return 1
    }

    if [[ "$mode" == "server" ]]; then
        log_info "Applying syncthing resource limits (server mode)"
        mkdir -p "$HOME/.config/systemd/user/syncthing.service.d"
        cat > "$HOME/.config/systemd/user/syncthing.service.d/override.conf" <<'EOF'
[Service]
Environment="GOMAXPROCS=2"
Environment="GOMEMLIMIT=512MiB"
EOF
        systemctl --user daemon-reload
        systemctl --user restart syncthing.service || {
            log_error "Failed to restart syncthing after applying limits"
            return 1
        }
    fi
}

install_pulse() {
    local mode="$1"
    local pulse_repo="$HOME/Overlord/projects/services/pulse"
    local pulse_bin="$HOME/.local/bin/pulse"
    local pulse_config_dir="$HOME/.config/pulse"
    local pulse_config="$pulse_config_dir/config.yaml"
    local pulse_service_dir="$HOME/.config/systemd/user"
    local pulse_service="$pulse_service_dir/pulse.service"

    if [[ "$mode" != "server" ]]; then
        return 0
    fi

    log_info "Configuring pulse scheduler (server mode)..."

    if ! command -v go &>/dev/null; then
        log_info "Skipping pulse setup: Go is not installed"
        return 0
    fi

    if [[ ! -f "$pulse_repo/Makefile" ]]; then
        log_info "Skipping pulse setup: source repo not found at $pulse_repo"
        log_info "After cloning pulse, run: make -C $pulse_repo build"
        return 0
    fi

    mkdir -p "$HOME/.local/bin"
    if make -C "$pulse_repo" build; then
        if [[ -f "$pulse_repo/bin/pulse" ]]; then
            install -m 0755 "$pulse_repo/bin/pulse" "$pulse_bin"
            log_info "Installed pulse binary to $pulse_bin"
        else
            log_error "Pulse build succeeded but binary was not found"
            return 0
        fi
    else
        log_error "Pulse build failed; skipping pulse service setup"
        return 0
    fi

    mkdir -p "$pulse_config_dir"
    if [[ ! -f "$pulse_config" && -f "$pulse_repo/config.yaml" ]]; then
        cp "$pulse_repo/config.yaml" "$pulse_config"
        chmod 600 "$pulse_config"
        log_info "Copied default pulse config to $pulse_config"
    fi

    mkdir -p "$pulse_service_dir"
    cat > "$pulse_service" <<EOF
[Unit]
Description=Pulse Scheduler Service
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=simple
EnvironmentFile=-$HOME/.config/opencode/server.env
ExecStart=$pulse_bin --config $pulse_config --state $pulse_config_dir/state.json
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    if systemctl --user enable --now pulse.service; then
        log_info "Pulse user service enabled and started"
    else
        log_error "Pulse service was installed but failed to start"
        log_info "Check logs: journalctl --user -u pulse -f"
    fi
}

run_chezmoi_init() {
    local repo_url="$1"
    local mode="$2"
    
    log_info "Initializing dotfiles from $repo_url"
    
    # Build chezmoi command
    local -a cmd=("chezmoi" "init" "--apply")
    
    # Add mode if specified via promptString
    if [[ -n "$mode" ]]; then
        log_info "Using mode: $mode"
        cmd+=("--promptString" "mode=$mode")
    fi
    
    # Add repository URL last
    cmd+=("$repo_url")
    
    # Run chezmoi init
    log_debug "Running: ${cmd[*]}"
    OPENCODE_INSTALL_SH=1 "${cmd[@]}" || {
        log_error "chezmoi init failed"
        return 1
    }
    
    log_info "Dotfiles initialized successfully"
}

show_post_install() {
    cat <<EOF

================================================================================
Installation Complete!
================================================================================

Your dotfiles have been installed successfully.

Next steps:
  1. Review the installed configuration files
  2. Restart your shell or run: exec \$SHELL
  3. Check chezmoi status: chezmoi status
  4. Update dotfiles: chezmoi update
  5. Verify Overlord sync health: overlord doctor

Useful commands:
  chezmoi diff       - Show changes between local and repo
  chezmoi apply      - Apply changes from repo
  chezmoi edit FILE  - Edit a file managed by chezmoi
  chezmoi cd         - Open chezmoi source directory

For more information, visit: https://chezmoi.io

================================================================================

EOF
}

bootstrap_overlord() {
    log_info "Bootstrapping Overlord sync config..."

    if ! command -v overlord &>/dev/null; then
        log_error "overlord command not found"
        log_info "This usually means it's installed but not on PATH yet. Try:"
        log_info "  export PATH=\"$HOME/.local/bin:$HOME/go/bin:/usr/local/go/bin:\$PATH\""
        log_info "Then re-run: overlord setup --init"
        # Non-fatal: the rest of the machine setup is still useful.
        return 0
    fi

    local -a cmd=(overlord setup)
    local help_out
    help_out=$(overlord setup --help 2>&1 || true)
    if printf '%s' "$help_out" | grep -q -- "--init"; then
        cmd=(overlord setup --init)
    fi

    log_info "Running: ${cmd[*]}"
    log_info "This prompts for machine name, role, and optional peer device ID"
    if ! "${cmd[@]}"; then
        log_error "Overlord bootstrap failed"
        log_info "Fix the issue and rerun: ${cmd[*]}"
        return 1
    fi

    log_info "Overlord bootstrap complete"
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                MODE="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage 1
                ;;
        esac
    done
    
    log_info "Starting dotfiles bootstrap"
    
    # Check dependencies
    log_info "Checking dependencies..."
    check_dependencies || exit 1
    
    # Detect OS
    local os
    os=$(detect_os)
    log_info "Detected OS: $os"
    
    # Install chezmoi if needed
    install_chezmoi "$os" || exit 1
    
    # Run chezmoi init
    run_chezmoi_init "$REPO_URL" "$MODE" || exit 1

    # Install and configure syncthing
    install_syncthing "$os" || exit 1
    configure_syncthing_service "$MODE" || exit 1

    # Install pulse scheduler if source exists (server mode)
    install_pulse "$MODE"

    # Bootstrap Overlord machine config + Syncthing config folder
    bootstrap_overlord || true
    
    # Show post-install instructions
    show_post_install

    log_info "Bootstrap complete!"

    # Re-print the machine key + next-steps summary at the very end.
    # (The same info is printed during `chezmoi init --apply`, but later installs
    # can scroll it out of view.)
    if [[ -x "$HOME/.local/bin/machine-setup-summary" ]]; then
        "$HOME/.local/bin/machine-setup-summary"
    else
        log_warn "Missing: $HOME/.local/bin/machine-setup-summary"
        log_warn "Re-run: chezmoi apply (or check ~/.ssh and gpg keys manually)"
    fi
}

# Run main function with all arguments
main "$@"

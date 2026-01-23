#!/bin/bash
# Bootstrap script for dotfiles installation
# Safe to curl | bash
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash -s -- --mode server

set -Eeuo pipefail

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
            ;;
        *)
            log_info "Using official chezmoi installer for $os"
            sh -c "$(curl -fsLS get.chezmoi.io)" || {
                log_error "Failed to install chezmoi via official installer"
                return 1
            }
            ;;
    esac
    
    # Verify installation
    if ! command -v chezmoi &>/dev/null; then
        log_error "chezmoi installation failed - command not found"
        return 1
    fi
    
    log_info "chezmoi installed successfully: $(chezmoi --version)"
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
    "${cmd[@]}" || {
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

Useful commands:
  chezmoi diff       - Show changes between local and repo
  chezmoi apply      - Apply changes from repo
  chezmoi edit FILE  - Edit a file managed by chezmoi
  chezmoi cd         - Open chezmoi source directory

For more information, visit: https://chezmoi.io

================================================================================

EOF
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
    
    # Show post-install instructions
    show_post_install
    
    log_info "Bootstrap complete!"
}

# Run main function with all arguments
main "$@"

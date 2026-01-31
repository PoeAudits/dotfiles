# Dotfiles

Personal dotfiles managed by [Chezmoi](https://www.chezmoi.io/) with secrets handled by [pass](https://www.passwordstore.org/).

## Overview

This repository contains everything needed to reproduce a consistent development environment across multiple machines. It supports two installation modes:

- **Desktop** - Full workstation setup (Omarchy/Arch Linux)
- **Server** - Headless VPS setup (Ubuntu)

Chezmoi handles dotfile templating and deployment, while pass (with per-machine GPG keys) manages secrets separately.

## Quick Start

### New Machine

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/install.sh | bash
```

Or with explicit mode:

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/install.sh | bash -s -- --mode server
```

The installer will:
1. Detect your OS (Arch or Ubuntu)
2. Install Chezmoi
3. Prompt for machine configuration (mode, git identity)
4. Apply all dotfiles
5. Run setup scripts (GPG, pass, tools)

### Existing Machine

```bash
chezmoi update
```

## What's Included

| Component | Description | Notes |
|-----------|-------------|-------|
| **Neovim** | LazyVim-based configuration | `~/.config/nvim/` |
| **tmux** | Terminal multiplexer config | `~/.config/tmux/` |
| **Git** | Global git configuration | Templated for user identity |
| **Starship** | Cross-shell prompt | `~/.config/starship.toml` |
| **SSH** | Host configurations | Keys are NOT stored here |
| **Shell** | zsh/bash configs | Shared aliases and functions |
| **OpenCode** | AI coding assistant config | `~/.config/opencode/` |
| **Overlord** | Project management | `~/.config/overlord/` |

## Installation Modes

Chezmoi prompts for a mode during setup. This affects which files are installed and how templates render.

### Desktop Mode

- Full Omarchy integration
- Desktop-specific aliases and tools
- GUI application configs (if any)

### Server Mode

- Headless-optimized configuration
- Minimal prompt settings
- No GUI-related configs
- **Tailscale** mesh VPN (enabled and started)
- **UFW** firewall (deny all incoming except Tailscale)
- **OpenCode web server** as a systemd service (port 4096)
- `opencode-env` helper script for managing API keys

The mode is stored in `~/.config/chezmoi/chezmoi.toml` and used by templates:

```bash
# In templates
{{ if eq .mode "desktop" }}
# Desktop-specific config
{{ end }}
```

### Server-Only Setup Scripts

On server mode, chezmoi automatically runs these additional setup scripts:

| Script | Purpose |
|--------|---------|
| `run_once_setup-tailscale.sh` | Enables `tailscaled`, checks auth status |
| `run_once_setup-ufw.sh` | Configures UFW: deny all, allow Tailscale interface |
| `run_once_setup-opencode-server.sh` | Creates `opencode-web` systemd service + `opencode-env` helper |

### OpenCode Server (Server Mode)

The server runs `opencode web --port 4096 --hostname 0.0.0.0` as a systemd service. All traffic is restricted to the Tailscale mesh by UFW.

```
Phone (Tailscale) ──────────────┐
                                │
Desktop (opencode attach) ──────┼──▶  opencode web (:4096)  ──▶  LLM APIs
                                │      (systemd service)
Laptop (opencode attach) ───────┘      WorkingDirectory=~
                                       Binds 0.0.0.0:4096
                                       (UFW restricts to Tailscale)
```

**Access:**
- TUI: `opencode attach http://<tailscale-ip>:4096`
- Web UI: `http://<tailscale-ip>:4096` (from phone browser)
- Health: `curl http://localhost:4096/global/health`

**Managing API keys:**

The service loads API keys from `~/.config/opencode/server.env` (an `EnvironmentFile`). Use the `opencode-env` helper to generate it from `pass`:

```bash
# Generate env file from pass (env/api-keys and env/shell entries)
opencode-env generate

# Check current env file status (shows keys, not values)
opencode-env check

# Restart service to pick up new keys
systemctl restart opencode-web
```

The env file is NOT generated automatically during install because `pass` may not be configured yet on a fresh machine. After setting up pass, run `opencode-env generate` and then start the service.

## Secrets Management

Secrets are stored in a **separate private repository** using pass (GPG-encrypted password store). They are never committed to this dotfiles repo.

### How It Works

1. Each machine has its own GPG key (never copied between machines)
2. All machine keys are listed in the pass repo's `.gpg-id`
3. Secrets are encrypted to all keys, so any machine can decrypt
4. Shell startup loads secrets as environment variables

### Adding a New Secret

```bash
# Add to pass
pass insert dev/new-api-key

# If needed, update shell config to export it
chezmoi edit ~/.zshrc
# Add to the secrets loading section

chezmoi apply
```

### How API Keys Reach Applications

The shell config (`~/.zshrc`) loads secrets at startup:

```bash
# Secrets are loaded via the passenv function
if [[ -f "$PASSWORD_STORE_DIR/env/api-keys.gpg" ]]; then
    passenv "env/api-keys"
fi
```

Store your API keys in pass at `env/api-keys` as `KEY=VALUE` pairs:

```bash
pass edit env/api-keys
# Add lines like:
# OPENAI_API_KEY=sk-...
# ANTHROPIC_API_KEY=sk-ant-...
```

### pass Repository Structure

```
~/.password-store/
├── .gpg-id              # All machine GPG key IDs
├── env/
│   ├── shell.gpg        # Shell environment variables
│   └── api-keys.gpg     # API keys (OPENAI, ANTHROPIC, etc.)
├── dev/
│   └── github-token.gpg
└── infra/
    └── hetzner-api-token.gpg
```

## Adding a New Machine

See [ONBOARDING.md](ONBOARDING.md) for the complete guide.

**Quick summary:**

1. Run the bootstrap script on the new machine
2. GPG key is generated automatically
3. Export the public key and transfer to an existing machine
4. On existing machine: import key, add to `.gpg-id`, re-encrypt, push
5. On new machine: clone pass repo, verify access

## Adding New Tools

Tools are defined in `tools.yaml`. The install script reads this file and installs any missing tools.

### Adding a Tool

Edit `tools.yaml`:

```yaml
tools:
  # ... existing tools ...

  ripgrep:
    check: "rg --version"
    install:
      arch: "sudo pacman -S --noconfirm ripgrep"
      ubuntu: "sudo apt install -y ripgrep"
```

Format:
- `check`: Command to verify if tool is installed (exit 0 = installed)
- `install.arch`: Install command for Arch Linux
- `install.ubuntu`: Install command for Ubuntu/Debian
- `install.all`: Universal install command (used if arch/ubuntu not specified)

After editing, apply changes:

```bash
chezmoi apply
```

The install script runs automatically when `tools.yaml` changes.

## Making Changes

### Edit a Managed File

```bash
# Edit via chezmoi (opens source file)
chezmoi edit ~/.config/nvim/init.lua

# Apply changes to home directory
chezmoi apply
```

### Edit Source Directly

```bash
# Go to chezmoi source directory
chezmoi cd

# Edit files directly
nvim dot_config/nvim/init.lua

# Apply changes
chezmoi apply
```

### Commit and Push

```bash
chezmoi cd
git add -A
git commit -m "update: nvim config"
git push
```

### Pull Changes on Another Machine

```bash
chezmoi update
```

## Customization

### Machine-Specific Configuration

Chezmoi uses Go templates for machine differences. Variables are set in `.chezmoi.toml.tmpl`:

```toml
[data]
mode = "desktop"  # or "server"

[data.git]
name = "Your Name"
email = "your@email.com"
```

### Using Templates

Files ending in `.tmpl` are processed as templates:

```bash
# In dot_config/git/config.tmpl
[user]
    name = {{ .git.name }}
    email = {{ .git.email }}
```

### Conditional Content

```bash
# In dot_zshrc.tmpl
{{ if eq .mode "desktop" }}
# Desktop-only configuration
alias open="xdg-open"
{{ else }}
# Server-only configuration
alias open="echo 'No GUI on server'"
{{ end }}
```

### Ignoring Files by Mode

The `.chezmoiignore` file controls which files are skipped:

```
{{ if eq .mode "server" }}
# Don't install desktop-specific configs on servers
dot_config/hyper-whisper/
{{ end }}
```

### Local Overrides

For machine-specific config that shouldn't be in the repo, create:

- `~/.zshrc.local` - Sourced at end of `.zshrc`
- `~/.bashrc.local` - Sourced at end of `.bashrc`

## Repository Structure

```
dotfiles/
├── .chezmoi.toml.tmpl          # Machine config template
├── .chezmoiignore              # Files to skip by mode
├── .chezmoiscripts/
│   ├── run_once_clone-repos.sh.tmpl    # Clone .opencode and .agents repos
│   ├── run_once_setup-gpg.sh.tmpl      # Per-machine GPG + SSH keys
│   ├── run_once_setup-pass.sh.tmpl     # Verify pass setup
│   ├── run_once_setup-tailscale.sh.tmpl      # Enable tailscaled + auth
│   ├── run_once_setup-ufw.sh.tmpl            # Firewall (server only)
│   ├── run_once_setup-opencode-server.sh.tmpl # OpenCode systemd (server only)
│   └── run_onchange_install-tools.sh.tmpl    # Install tools from tools.yaml
├── dot_config/
│   ├── nvim/                   # Neovim (LazyVim)
│   ├── tmux/                   # tmux config
│   ├── opencode/               # OpenCode AI config
│   ├── overlord/               # Project management
│   ├── git/config.tmpl         # Git config (templated)
│   ├── starship.toml           # Shell prompt
│   └── shell/
│       ├── aliases.sh          # Shared aliases
│       └── functions.sh        # Shared functions
├── dot_zshrc.tmpl              # Zsh config (templated)
├── dot_bashrc.tmpl             # Bash config (templated)
├── private_dot_ssh/config      # SSH host configs (not keys)
├── tools.yaml                  # Tool definitions
├── install.sh                  # Bootstrap script
├── ONBOARDING.md               # New machine guide
└── README.md                   # This file
```

## Useful Commands

Run `make help` in the chezmoi source directory to see all available Makefile targets.

### Chezmoi

| Command | Description |
|---------|-------------|
| `chezmoi update` | Pull and apply latest changes |
| `chezmoi apply` | Apply source to home directory |
| `chezmoi diff` | Show pending changes |
| `chezmoi edit FILE` | Edit a managed file |
| `chezmoi cd` | Open source directory |
| `chezmoi status` | Show managed file status |
| `chezmoi data` | Show template data |

### Server (OpenCode)

| Command | Description |
|---------|-------------|
| `opencode-env generate` | Generate env file from pass |
| `opencode-env check` | Show env file status |
| `systemctl status opencode-web` | Check service status |
| `systemctl restart opencode-web` | Restart service |
| `journalctl -u opencode-web -f` | Follow service logs |
| `opencode attach http://<ip>:4096` | Connect TUI to server |

## Security Notes

- **SSH keys** are generated per-machine, never stored in dotfiles
- **GPG keys** are per-machine, never copied between machines
- **Secrets** live in a separate private pass repository
- **API keys** are loaded at shell startup from pass, not hardcoded

## License

Personal configuration files. Use at your own risk.

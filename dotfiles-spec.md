# Dotfiles Specification

## Overview

The dotfiles repository contains all configuration needed to reproduce the development environment on any machine. It supports two installation modes: `server` (headless VPS/Ubuntu) and `desktop` (Omarchy workstation).

**Key Tools:**
- **Chezmoi** - Dotfiles management with templating
- **pass (GPG)** - Secrets management with per-machine keys

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Dotfiles Manager | **Chezmoi** | Best multi-machine support, templates, AI-friendly CLI |
| Secrets Manager | **pass (GPG)** | Git-synced, CLI-native, no external service |
| GPG Strategy | **Per-machine keys** | More secure, individually revocable |
| Secrets Location | **Separate repo** | Clean separation from dotfiles |
| Tool Installation | **Config-driven** | YAML/TOML config, easy to extend |

## Repository Structure

```
dotfiles/                           # Chezmoi source directory
├── .chezmoi.toml.tmpl              # Machine config template (mode, git identity)
├── .chezmoiignore                  # Ignore desktop files on server
├── .chezmoiscripts/
│   ├── run_once_setup-gpg.sh.tmpl  # GPG key generation
│   ├── run_once_setup-pass.sh.tmpl # pass installation and setup
│   └── run_onchange_install-tools.sh.tmpl  # Tool installation
│
├── dot_config/
│   ├── nvim/                       # Neovim configuration
│   │   ├── init.lua
│   │   └── lua/
│   ├── tmux/
│   │   └── tmux.conf
│   ├── opencode/
│   │   └── opencode.jsonc
│   ├── overlord/
│   │   └── registry.json
│   ├── git/
│   │   └── config.tmpl             # Templated for user identity
│   ├── starship.toml
│   └── shell/
│       ├── aliases.sh
│       └── functions.sh
│
├── dot_zshrc.tmpl                  # Main zsh config (templated)
├── dot_bashrc.tmpl                 # Bash fallback (templated)
│
├── private_dot_ssh/
│   └── config                      # SSH host configs (not keys!)
│
├── tools.yaml                      # Extensible tool definitions
├── install.sh                      # Bootstrap script (curl | bash)
└── README.md
```

### Separate pass Repository

```
password-store/                     # Separate git repo
├── .gpg-id                         # List of GPG key IDs (all machines)
├── dev/
│   ├── openai-api-key.gpg
│   ├── anthropic-api-key.gpg
│   └── github-token.gpg
└── infra/
    └── hetzner-api-token.gpg
```

## What's Included

### Common (Both Server and Desktop)

| Component | Chezmoi Path | Target | Notes |
|-----------|--------------|--------|-------|
| Neovim config | `dot_config/nvim/` | `~/.config/nvim/` | Editor configuration |
| tmux config | `dot_config/tmux/` | `~/.config/tmux/` | Terminal multiplexer |
| OpenCode config | `dot_config/opencode/` | `~/.config/opencode/` | AI agent config |
| Overlord | `dot_config/overlord/` | `~/.config/overlord/` | Project management |
| Git config | `dot_config/git/config.tmpl` | `~/.config/git/config` | Templated for identity |
| Starship | `dot_config/starship.toml` | `~/.config/starship.toml` | Shell prompt |
| Shell config | `dot_zshrc.tmpl`, `dot_bashrc.tmpl` | `~/.zshrc`, `~/.bashrc` | Templated |
| SSH config | `private_dot_ssh/config` | `~/.ssh/config` | Host definitions only |

### Desktop Only (Omarchy)

| Component | Notes |
|-----------|-------|
| Hyper Whisper | Voice-to-text (hardware dependent) |
| Desktop-specific shell | Additional aliases/functions |

### Server Only

| Component | Notes |
|-----------|-------|
| No GUI tools | Server is headless |
| Minimal prompt | Faster starship config |

## Chezmoi Templating

### Machine Configuration (`.chezmoi.toml.tmpl`)

```toml
{{- $mode := promptStringOnce . "mode" "Installation mode (server/desktop)" "desktop" -}}
{{- $gitName := promptStringOnce . "git.name" "Git user name" -}}
{{- $gitEmail := promptStringOnce . "git.email" "Git email" -}}

[data]
mode = {{ $mode | quote }}

[data.git]
name = {{ $gitName | quote }}
email = {{ $gitEmail | quote }}
```

### Conditional Configuration

```bash
# In dot_zshrc.tmpl
{{ if eq .mode "desktop" }}
# Desktop-specific configuration
alias open="xdg-open"
{{ else }}
# Server-specific configuration
alias open="echo 'No GUI on server'"
{{ end }}
```

### Ignoring Files by Mode

```
# .chezmoiignore
{{ if eq .mode "server" }}
dot_config/hyper-whisper/
{{ end }}
```

## pass (GPG) Integration

### Per-Machine GPG Keys

Each machine has its own GPG key. Benefits:
- Revoke single machine without affecting others
- Clear audit trail per machine
- No key copying between machines

### Setup Flow

**First Machine:**
```bash
# 1. Generate GPG key
gpg --quick-gen-key "Thomas (desktop) <email>" ed25519

# 2. Initialize pass
pass init <gpg-key-id>

# 3. Add secrets
pass insert dev/openai-api-key
pass insert dev/anthropic-api-key

# 4. Push to git
pass git init
pass git remote add origin <private-repo>
pass git push -u origin main
```

**Adding New Machine:**
```bash
# On new machine:
# 1. Generate GPG key
gpg --quick-gen-key "Thomas (vps) <email>" ed25519
# 2. Export public key
gpg --armor --export <key-id> > vps.pub.asc

# On existing machine:
# 3. Import new machine's public key
gpg --import vps.pub.asc
# 4. Add to pass
cd ~/.password-store
echo "<new-key-id>" >> .gpg-id
pass init $(cat .gpg-id)  # Re-encrypts to all keys
pass git push

# On new machine:
# 5. Clone pass repo
git clone <repo> ~/.password-store
pass ls  # Verify access
```

### Shell Integration

```bash
# In .zshrc/.bashrc
export PASSWORD_STORE_DIR="$HOME/.password-store"

# Load secrets at shell start
if command -v pass &>/dev/null && [[ -d "$PASSWORD_STORE_DIR" ]]; then
    export OPENAI_API_KEY=$(pass show dev/openai-api-key 2>/dev/null)
    export ANTHROPIC_API_KEY=$(pass show dev/anthropic-api-key 2>/dev/null)
    export GITHUB_TOKEN=$(pass show dev/github-token 2>/dev/null)
fi
```

## Extensible Tool Installation

### Tool Configuration (`tools.yaml`)

```yaml
tools:
  go:
    version: "1.22"
    check: "go version"
    install:
      arch: |
        sudo pacman -S --noconfirm go
      ubuntu: |
        GO_VERSION="1.22.0"
        wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
        rm "go${GO_VERSION}.linux-amd64.tar.gz"

  bun:
    check: "bun --version"
    install:
      all: "curl -fsSL https://bun.sh/install | bash"

  uv:
    check: "uv --version"
    install:
      all: "curl -LsSf https://astral.sh/uv/install.sh | sh"

  foundry:
    check: "forge --version"
    install:
      all: |
        curl -L https://foundry.paradigm.xyz | bash
        ~/.foundry/bin/foundryup

  tailscale:
    check: "tailscale --version"
    install:
      all: "curl -fsSL https://tailscale.com/install.sh | sh"

  tmux:
    check: "tmux -V"
    install:
      arch: "sudo pacman -S --noconfirm tmux"
      ubuntu: "sudo apt install -y tmux"

  neovim:
    check: "nvim --version"
    install:
      arch: "sudo pacman -S --noconfirm neovim"
      ubuntu: |
        sudo apt install -y software-properties-common
        sudo add-apt-repository -y ppa:neovim-ppa/unstable
        sudo apt update && sudo apt install -y neovim

  starship:
    check: "starship --version"
    install:
      all: "curl -sS https://starship.rs/install.sh | sh -s -- -y"

  pass:
    check: "pass --version"
    install:
      arch: "sudo pacman -S --noconfirm pass"
      ubuntu: "sudo apt install -y pass"
```

### Adding New Tools

To add a new tool, just edit `tools.yaml`:

```yaml
  ripgrep:
    check: "rg --version"
    install:
      arch: "sudo pacman -S --noconfirm ripgrep"
      ubuntu: "sudo apt install -y ripgrep"
```

The install script automatically picks up new entries.

## Bootstrap Process

### One-Liner for New Machine

```bash
curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/install.sh | bash
```

Or with explicit mode:
```bash
curl -fsSL ... | bash -s -- --mode server
```

### What the Bootstrap Does

1. Detect OS (Arch vs Ubuntu)
2. Install Chezmoi
3. Run `chezmoi init --apply <repo>`
4. Chezmoi runs:
   - Prompts for machine config (mode, git identity)
   - Applies all dotfiles
   - Runs setup scripts (GPG, pass, tools)
5. Display post-install instructions

## Secrets Handling

**Never commit secrets to dotfiles!**

### Strategy

| Secret Type | Storage | Access |
|-------------|---------|--------|
| API keys (OpenAI, Anthropic, etc.) | pass | Shell env vars at startup |
| SSH private keys | Generated per-machine | Never in dotfiles |
| Git credentials | SSH keys via pass or agent | Never in dotfiles |
| High-sensitivity (crypto) | Desktop only, hardware wallet | Never on VPS |

### pass Structure

```
~/.password-store/
├── .gpg-id                    # All machine key IDs
├── dev/
│   ├── openai-api-key.gpg
│   ├── anthropic-api-key.gpg
│   ├── github-token.gpg
│   └── hetzner-api-token.gpg
└── personal/
    └── ...
```

## Sync Workflow

### Making Changes

```bash
# Edit a config
chezmoi edit ~/.config/nvim/init.lua

# Or edit directly in source
cd $(chezmoi source-path)
nvim dot_config/nvim/init.lua

# Apply changes
chezmoi apply

# Commit
chezmoi cd
git add -A && git commit -m "update: nvim config"
git push
```

### Pulling Changes to Another Machine

```bash
chezmoi update
```

### Adding New Secrets

```bash
# Add to pass
pass insert dev/new-api-key

# Update shell config to load it (if needed)
chezmoi edit ~/.zshrc
# Add: export NEW_API_KEY=$(pass show dev/new-api-key 2>/dev/null)

chezmoi apply
```

## Initial Setup Checklist

### New Server (VPS)

1. [ ] Run bootstrap: `curl -fsSL <url> | bash -s -- --mode server`
2. [ ] Complete Chezmoi prompts (mode=server, git identity)
3. [ ] GPG key generated automatically
4. [ ] Export GPG public key: `gpg --armor --export <id> > server.pub.asc`
5. [ ] **On existing machine:** Add server key to pass, re-encrypt, push
6. [ ] Clone pass repo: `git clone <repo> ~/.password-store`
7. [ ] Verify: `pass ls`
8. [ ] Configure Tailscale: `sudo tailscale up`

### New Desktop (Omarchy)

1. [ ] Run bootstrap: `curl -fsSL <url> | bash` (or `--mode desktop`)
2. [ ] Complete Chezmoi prompts
3. [ ] GPG key generated automatically
4. [ ] If first machine: Initialize pass store
5. [ ] If additional machine: Follow "adding new machine" flow
6. [ ] Verify secrets load: `echo $ANTHROPIC_API_KEY`
7. [ ] Configure any desktop-specific tools (Hyper Whisper, etc.)

## Comparison: Why Chezmoi + pass

### Chezmoi vs GNU Stow

| Aspect | Chezmoi | GNU Stow |
|--------|---------|----------|
| Templating | Yes, Go templates | No |
| Multi-machine | Built-in variables | Manual |
| Encryption | Built-in (age) | No |
| One-liner install | Yes | No |
| Learning curve | Medium | Low |

**Chose Chezmoi** for templates and multi-machine support.

### pass vs 1Password

| Aspect | pass | 1Password |
|--------|------|-----------|
| Cost | Free | $36/year |
| Self-hosted | Yes (git) | No |
| CLI quality | Good | Excellent |
| Service accounts | N/A (GPG keys) | Requires paid plan |
| Dependencies | GPG, git | External service |

**Chose pass** for self-hosted, git-synced, no external dependency.

## Implementation

See [dotfile-implementation.md](./dotfile-implementation.md) for the orchestration plan.

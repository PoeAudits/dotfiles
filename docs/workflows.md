# Workflows

Common day-to-day workflows for maintaining and using this setup.

## Update this machine from repo

```bash
chezmoi update
```

## Edit a managed file

```bash
chezmoi edit ~/.config/nvim/init.lua
chezmoi apply
```

Or from source directory:

```bash
chezmoi cd
nvim dot_config/nvim/init.lua
chezmoi apply
```

## Check pending changes

```bash
chezmoi diff
chezmoi status
```

## Add or update tools

Edit `tools.yaml` and apply:

```bash
chezmoi apply
```

This triggers `.chezmoiscripts/run_onchange_install-tools.sh.tmpl`.

Tool format in `tools.yaml`:

```yaml
tools:
  tool-name:
    check: "command --version"
    install:
      arch: "sudo pacman -S --noconfirm tool-name"
      ubuntu: "sudo apt install -y tool-name"
```

## Rotate or add a secret

```bash
pass edit ai/openai-api-key
```

If the value is consumed by OpenCode server env files:

```bash
opencode-env generate
systemctl restart opencode-web
```

## Useful checks

```bash
make help
make ufw-lockdown
make ufw-status
make lint
make test
```

# Repository Guide

This is a chezmoi source repository.

## Top-level layout

- `.chezmoi.toml.tmpl` - template data prompts and defaults.
- `.chezmoiignore` - excludes repository-only files from being deployed into `$HOME`.
- `.chezmoiscripts/` - one-time and on-change automation scripts.
- `dot_*` and `private_*` files - managed files mapped into home directory paths.
- `tools.yaml` - declarative tool installation matrix.
- `install.sh` - bootstrap entrypoint for new machines.

## Important chezmoi scripts

- `.chezmoiscripts/run_once_setup-gpg.sh.tmpl`
  - Generates per-machine GPG key.
  - Ensures encryption subkey exists.
  - Generates SSH key.
  - Exports GPG public key for transfer.
- `.chezmoiscripts/run_once_setup-pass.sh.tmpl`
  - Verifies `pass` installation and decrypt access.
  - Prints guidance when machine is not authorized yet.
- `.chezmoiscripts/run_once_clone-repos.sh.tmpl`
  - Clones `.opencode` and `.agents` companion repositories.
- `.chezmoiscripts/run_onchange_install-tools.sh.tmpl`
  - Parses `tools.yaml` and installs missing tools.
- `.chezmoiscripts/run_once_setup-tailscale.sh.tmpl`
  - Enables/starts `tailscaled` and checks login state.
- `.chezmoiscripts/run_once_setup-ufw.sh.tmpl` (server mode)
  - Locks firewall to Tailscale access (skips until Tailscale is connected).
- `.chezmoiscripts/run_once_setup-opencode-server.sh.tmpl` (server mode)
  - Installs `opencode-web` systemd service and `opencode-env` helper.
- `dot_local/bin/ufw-tailscale-lockdown`
  - Convenience wrapper to apply the server UFW rules after Tailscale auth.
- `.chezmoiscripts/run_once_zz-post-setup.sh.tmpl`
  - Prints consolidated post-install summary and next steps.

## Modes

`mode` is prompted during bootstrap and used in templates.

- `desktop` - workstation setup.
- `server` - headless setup with networking and OpenCode service automation.

Template usage example:

```text
{{ if eq .mode "server" }}
...server-only content...
{{ end }}
```

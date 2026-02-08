# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/), with secrets managed separately using [pass](https://www.passwordstore.org/) and per-machine GPG keys.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash
```

Server mode:

```bash
curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash -s -- --mode server
```

## Documentation

All detailed docs now live in `docs/`.

- `docs/README.md` - Documentation index
- `docs/new-machine-install.md` - End-to-end install flow for a new machine
- `docs/gpg-pass-setup.md` - GPG/pass setup, key rotation, troubleshooting
- `docs/server-mode.md` - Tailscale, UFW, OpenCode service, Syncthing, Pulse
- `docs/workflows.md` - Daily usage and maintenance workflows
- `docs/repository-guide.md` - Repository layout, templates, and chezmoi scripts
- `docs/vps-rebuild.md` - Disaster recovery runbook for VPS rebuilds

## Common Commands

Run `make help` for all available targets.

- `make install` - install dependencies
- `make build` - build project artifacts
- `make test` - run tests
- `make lint` - run lint checks
- `make fmt` - run formatters
- `make clean` - clean generated artifacts

## Security Model

- Each machine gets its own SSH and GPG keys.
- Private keys are never copied between machines.
- Secrets are stored in a separate private pass repository.
- Dotfiles repo contains configuration only (no secret values).

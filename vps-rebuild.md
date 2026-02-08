# VPS Rebuild Runbook

This runbook restores a destroyed/replaced VPS with minimal manual steps. Target is full rebuild in under one hour.

## Scope

- Host: Hetzner CPX11 (Ubuntu 24.04)
- Access model: Tailscale-only
- Source of truth:
  - Dotfiles: chezmoi repo
  - Secrets: pass repo (GPG encrypted)
  - Project files: Syncthing + Overlord activation

## Prerequisites

- Hetzner VPS created and reachable by SSH
- Existing machine available with pass/GPG access (desktop or laptop)
- Tailscale tailnet access

## 1) Base bootstrap

On the new VPS:

```bash
sudo apt-get update -y
sudo apt-get install -y curl git
curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash -s -- --mode server
```

What this configures:

- chezmoi + dotfiles
- Syncthing install + user service enable/start
- Syncthing server resource limits (`GOMAXPROCS=2`, `GOMEMLIMIT=512MiB`)
- Tailscale/UFW/OpenCode setup scripts (server mode)
- Pulse install attempt (if source exists at `~/Overlord/projects/services/pulse`)

## 2) Join Tailscale

```bash
tailscale up --ssh
tailscale status
tailscale ip -4
```

Record the new Tailscale IP for follow-up checks.

## 3) Restore pass access

Generate a fresh machine key on the VPS, then add it to `.gpg-id` from an existing trusted machine.

On VPS:

```bash
gpg --quick-gen-key "Thomas (vps) <your-email@example.com>" rsa4096
gpg --list-keys
gpg --armor --export <new-key-id> > ~/vps.pub.asc
```

Move `~/vps.pub.asc` to a trusted existing machine and run:

```bash
gpg --import ~/vps.pub.asc
cd ~/.password-store
echo "<new-key-id>" >> .gpg-id
pass init $(cat .gpg-id)
pass git add .gpg-id
pass git commit -m "Add key for rebuilt vps"
pass git push
```

Back on VPS:

```bash
git clone git@github.com:<you>/password-store.git ~/.password-store
pass ls
```

## 4) Regenerate OpenCode environment

```bash
opencode-env generate
opencode-env check
systemctl restart opencode-web
systemctl status opencode-web --no-pager
curl -fsS http://localhost:4096/global/health
```

## 5) Verify Syncthing

```bash
systemctl --user status syncthing --no-pager
curl -fsS "http://$(tailscale ip -4):8384/rest/system/status"
```

If Syncthing is configured to bind its GUI/API to Tailscale IP only, `localhost:8384` will fail by design.

If pairing is required, exchange Syncthing device IDs with desktop and re-share folders using Overlord activation.

## 6) Restore project working set

From your control machine:

```bash
overlord activate <project-name>
```

Repeat for required projects. Then on VPS per project:

```bash
overlord setup <project-name>
```

## 7) Pulse health scheduler

If `pulse` was auto-installed by bootstrap:

```bash
systemctl --user status pulse --no-pager
journalctl --user -u pulse -n 50 --no-pager
```

If not installed automatically (source missing during bootstrap):

```bash
make -C ~/Overlord/projects/services/pulse build
install -m 0755 ~/Overlord/projects/services/pulse/bin/pulse ~/.local/bin/pulse
mkdir -p ~/.config/pulse
cp ~/Overlord/projects/services/pulse/config.yaml ~/.config/pulse/config.yaml
systemctl --user daemon-reload
systemctl --user enable --now pulse
```

## 8) Final validation checklist

- `tailscale status` shows connected
- `systemctl status opencode-web` is active
- `curl http://localhost:4096/global/health` returns healthy
- `systemctl --user status syncthing` is active
- `systemctl --user status pulse` is active
- Overlord-synced projects are present and up to date

## Recovery timing target

- Fresh VPS to fully operational state: under 1 hour.

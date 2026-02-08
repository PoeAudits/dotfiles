# VPS Rebuild Runbook

This runbook restores a destroyed or replaced VPS with minimal manual work.

## Scope

- Host profile: Hetzner CPX11, Ubuntu 24.04
- Access model: Tailscale-only
- Source of truth:
  - Dotfiles: this chezmoi repository
  - Secrets: private pass repository
  - Projects: Syncthing + Overlord activation

## Prerequisites

- Fresh VPS reachable over SSH
- Existing trusted machine with pass access
- Tailscale tailnet access

## 1) Bootstrap base system

```bash
sudo apt-get update -y
sudo apt-get install -y curl git
curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash -s -- --mode server
```

## 2) Join Tailscale

```bash
tailscale up --ssh
tailscale status
tailscale ip -4
```

## 2b) Lock firewall to Tailscale

```bash
source ~/.bashrc
ufw-tailscale-lockdown
sudo ufw status verbose
```

## 3) Restore pass access

On VPS:

```bash
gpg --list-keys
gpg --armor --export <new-key-id> > ~/vps.pub.asc
```

On trusted machine (copy key from VPS):

First edit ~/.ssh/config to set the tailscale address for the new machine:
```bash

scp <vps-host>:~/vps.pub.asc ~/vps.pub.asc
```

On existing trusted machine:

```bash
gpg --import ~/vps.pub.asc

# Set trust level to ultimate for the new key
gpg --edit-key <new-key-id> <<EOF
trust
5
save
EOF

cd ~/.password-store
echo "<new-key-id>" >> .gpg-id
pass init $(cat .gpg-id)
pass git add .gpg-id
pass git commit -m "Add key for rebuilt vps"
pass git push
```

Back on VPS:

Make sure to first add the ssh key to github:

```bash
git clone git@github.com:PoeAudits/.password-store.git ~/.password-store
pass ls
```

## 4) Restore OpenCode service environment

```bash
opencode-env generate
systemctl restart opencode-web
systemctl status opencode-web --no-pager
sleep 2
curl -fsS http://localhost:4096/global/health
```

## 5) Pair Syncthing devices

On VPS, get the Syncthing device ID:

```bash
syncthing --device-id
```

On your local machine, add the VPS device to Syncthing:

```bash
# Add device to local Syncthing
overlord syncthing device add <vps-device-id> --name vps
```

Or manually via Syncthing GUI at http://localhost:8384:
1. Actions → Show ID (copy your local device ID)
2. Add Remote Device → paste VPS device ID
3. On VPS, accept the connection request

## 6) Verify Syncthing and project sync

```bash
systemctl --user status syncthing --no-pager
```

Then from a control machine:

```bash
overlord activate <project-name> --peer vps
```

On VPS per project:

```bash
overlord setup <project-name>
```

## 7) Verify Pulse (if used)

```bash
systemctl --user status pulse --no-pager
journalctl --user -u pulse -n 50 --no-pager
```

## Final checklist

- `tailscale status` connected
- `sudo ufw status verbose` shows Tailscale-only inbound
- `systemctl status opencode-web` active
- `curl http://localhost:4096/global/health` healthy
- Syncthing devices paired (check http://localhost:8384 for connected devices)
- `systemctl --user status syncthing` active
- `systemctl --user status pulse` active (if enabled)

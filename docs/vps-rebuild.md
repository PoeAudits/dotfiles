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

Syncthing is what keeps `~/Overlord` (and projects) in sync between your main machine and the VPS.

### 5a) Verify Syncthing is running (both machines)

On VPS:

```bash
systemctl --user status syncthing --no-pager
syncthing --device-id
```

On main machine:

```bash
systemctl --user status syncthing --no-pager
syncthing --device-id
```

### 5b) (Optional but recommended) Restore the VPS Syncthing identity

If you restore the VPS Syncthing identity (`cert.pem` + `key.pem`) the device ID stays the same across rebuilds.
That means the main machine usually does not need Syncthing edits after a rebuild.

- Syncthing identity (device ID source): `~/.config/syncthing/cert.pem` and `~/.config/syncthing/key.pem`
- Syncthing config (devices/folders/gui/apikey): `~/.config/syncthing/config.xml`

Backup the identity somewhere safe before you lose the old VPS. If you use `pass`, storing these files there works well because they are plain text.

On a machine with `pass` access (example paths; choose your own):

```bash
# Pull the files from the old VPS (adjust user/host)
scp <old-vps-host>:~/.config/syncthing/cert.pem /tmp/vps-syncthing-cert.pem
scp <old-vps-host>:~/.config/syncthing/key.pem /tmp/vps-syncthing-key.pem
scp <old-vps-host>:~/.config/syncthing/config.xml /tmp/vps-syncthing-config.xml

# Store in pass
pass insert -m infra/syncthing/vps/cert.pem < /tmp/vps-syncthing-cert.pem
pass insert -m infra/syncthing/vps/key.pem < /tmp/vps-syncthing-key.pem
pass insert -m infra/syncthing/vps/config.xml < /tmp/vps-syncthing-config.xml

pass git add -A
pass git commit -m "Backup vps syncthing identity"
pass git push
```

To restore (on VPS):

```bash
systemctl --user stop syncthing
mkdir -p ~/.config/syncthing
chmod 700 ~/.config/syncthing

# Restore from pass (adjust entry names if you chose different paths)
pass show infra/syncthing/vps/cert.pem > ~/.config/syncthing/cert.pem
pass show infra/syncthing/vps/key.pem > ~/.config/syncthing/key.pem

# Optional: restore full config (includes device list, folder shares, GUI settings, API key).
# This also restores the GUI auth settings; skip this if you don't know what those are.
pass show infra/syncthing/vps/config.xml > ~/.config/syncthing/config.xml

chmod 600 ~/.config/syncthing/cert.pem ~/.config/syncthing/key.pem || true
systemctl --user start syncthing
syncthing --device-id
```

If you do not have the old identity files, the rebuilt VPS will have a new device ID and you must re-pair it.

### 5c) Pair devices (required if the VPS device ID changed)

You must add each device on the other side (Syncthing trust is mutual):

- If the old VPS no longer exists and you did not restore its Syncthing identity, the VPS will have a new device ID.
  In that case, remove/forget the old VPS device on the main machine and add the new one.

1) Add VPS on the main machine

- Open Syncthing on the main machine.
- Add Remote Device using the VPS device ID.
- In the device settings, set Addresses to a stable Tailscale address (recommended):
  - `tcp://<vps-tailscale-ip>:22000`
  - or `tcp://<vps-hostname>.ts.net:22000`

2) Add main machine on the VPS

The Syncthing GUI on the VPS usually listens on `127.0.0.1:8384`. Use an SSH tunnel from your main machine:

```bash
ssh -L 8384:127.0.0.1:8384 <vps-host>
```

Then open `http://127.0.0.1:8384` in your local browser and:

- Add Remote Device using the main machine device ID.
- Set Addresses to a stable Tailscale address:
  - `tcp://<main-tailscale-ip>:22000`
  - or `tcp://<main-hostname>.ts.net:22000`

Notes:

- If either side shows an “untrusted device” prompt, you still need to explicitly Add/Confirm it on that side.
- If you prefer editing files instead of using the GUI, these address changes are in `~/.config/syncthing/config.xml` under the relevant `<device>` entry. Restart Syncthing after editing:

```bash
systemctl --user restart syncthing
```

3) Confirm connectivity

On VPS (and optionally on main):

```bash
systemctl --user status syncthing --no-pager
```

From a browser (via the tunnel on VPS), confirm the remote device shows `Connected`.

### 5d) Troubleshooting (if devices do not connect)

1) Verify Tailscale connectivity (both machines)

```bash
tailscale status
tailscale ip -4

# Try to reach the peer over Tailscale
tailscale ping <peer-hostname-or-ip>
```

2) Confirm you set Tailscale Addresses (not LAN/DNS)

- In each device's settings, set Addresses to `tcp://<tailscale-ip>:22000` (or `tcp://<host>.ts.net:22000`).
- If you edit `~/.config/syncthing/config.xml`, restart Syncthing after changes:

```bash
systemctl --user restart syncthing
```

3) Check Syncthing logs for the reason

On the machine that can't connect:

```bash
journalctl --user -u syncthing -n 200 --no-pager
```

4) Firewall sanity (VPS)

With this runbook's UFW setup, traffic over `tailscale0` should be allowed. Verify:

```bash
sudo ufw status verbose
```

If you changed the firewall manually, ensure the VPS allows Syncthing over Tailscale (at minimum `22000/tcp` on `tailscale0`).

If `install.sh` ran `overlord setup` before Syncthing was paired (or you skipped the peer device ID prompt), rerun it now on the VPS so Overlord knows who the main peer is:

```bash
# If this errors, run: overlord setup
overlord setup --init
```



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
- Syncthing devices paired (VPS GUI via: `ssh -L 8384:127.0.0.1:8384 <vps-host>` then `http://127.0.0.1:8384`)
- `systemctl --user status syncthing` active
- `systemctl --user status pulse` active (if enabled)

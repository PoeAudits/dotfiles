# Server Mode Guide

Server mode is intended for headless Ubuntu/Debian hosts.

## What server mode enables

- Tailscale daemon setup and status checks.
- UFW firewall locked to Tailscale traffic.
- `opencode-web` systemd service on port `4096`.
- `opencode-env` helper for generating OpenCode environment variables from pass.
- Syncthing resource limits (`GOMAXPROCS=2`, `GOMEMLIMIT=512MiB`).
- Optional Pulse setup when source exists at `~/Overlord/projects/services/pulse`.

## Tailscale

Authenticate:

```bash
tailscale up --ssh
```

Verify:

```bash
tailscale status
tailscale ip -4
```

## UFW rules

Server setup configures (after Tailscale is connected):

- default deny incoming
- default allow outgoing
- allow in on `tailscale0`
- allow `41641/udp` for Tailscale WireGuard

Check:

```bash
sudo ufw status verbose
```

Apply (recommended helper):

```bash
ufw-tailscale-lockdown
```

Or from the repo:

```bash
make ufw-lockdown
```

Notes:

- The automated UFW setup skips lock-down until `tailscale status` reports `BackendState=Running`.
- After `tailscale up --ssh`, re-run `chezmoi apply` or run `ufw-tailscale-lockdown`.

## OpenCode web service

Service: `opencode-web`

- Runs `opencode web --port 4096 --hostname 0.0.0.0`
- Uses environment file `~/.config/opencode/server.env`
- Managed with systemd at `/etc/systemd/system/opencode-web.service`

Generate environment file from pass:

```bash
opencode-env generate
opencode-env check
```

Start and check:

```bash
systemctl start opencode-web
systemctl status opencode-web
curl http://localhost:4096/global/health
```

Connect from another Tailscale device:

```bash
opencode attach http://<tailscale-ip>:4096
```

## Syncthing

Check service:

```bash
systemctl --user status syncthing
```

Server mode installs an override at:

- `~/.config/systemd/user/syncthing.service.d/override.conf`

## Pulse (optional)

If source is available, bootstrap attempts install and enables a user service.

Check:

```bash
systemctl --user status pulse
journalctl --user -u pulse -n 50 --no-pager
```

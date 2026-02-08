# New Machine Installation Guide

This guide covers a full setup for a brand new machine using this dotfiles repository.

## What the bootstrap does

Running `install.sh` will:

1. Detect OS (Arch-based or Ubuntu/Debian-based).
2. Install `chezmoi` if missing.
3. Initialize this repo via `chezmoi init --apply`.
4. Install and start Syncthing.
5. Run setup scripts (GPG/SSH key setup, pass checks, repo cloning, tool install).
6. Run `overlord setup --init`.

In server mode it also sets up Tailscale, UFW, and OpenCode server automation.

## Prerequisites

- `curl` and `git` available.
- A GitHub account (for SSH key registration).
- One existing trusted machine with current pass access (required for adding a new machine key).

## 1) Run bootstrap on the new machine

Desktop/default:

```bash
curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash
```

Server:

```bash
curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash -s -- --mode server
```

## 2) Add this machine's SSH key to GitHub

Show key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Then add it at `https://github.com/settings/keys` and verify:

```bash
ssh -T git@github.com
```

## 3) Authorize this machine's GPG key in pass (from an existing trusted machine)

On the trusted machine:

```bash
# Import key from new machine (adjust host or path as needed)
ssh user@new-machine "cat ~/.gnupg/public-keys/$(ssh user@new-machine hostname).asc" | gpg --import

# Find key ID and add it to recipients
gpg --list-keys --keyid-format LONG
cd ~/.password-store
echo "<new-machine-key-id>" >> .gpg-id
pass init $(cat .gpg-id)
pass git add .gpg-id
pass git commit -m "Add key for new machine"
pass git push
```

## 4) Clone password store on the new machine

```bash
git clone git@github.com:PoeAudits/.password-store.git ~/.password-store
pass ls
```

If `pass ls` fails, see troubleshooting in `docs/gpg-pass-setup.md`.

## 5) Server-only post install

If this is a server, finish these steps:

```bash
tailscale up --ssh
tailscale status
ufw-tailscale-lockdown
opencode-env generate
systemctl start opencode-web
systemctl status opencode-web
```

More detail: `docs/server-mode.md`.

## Verification checklist

- `chezmoi status` runs cleanly.
- `pass ls` works.
- `tailscale status` is connected (server mode).
- `systemctl status opencode-web` is active (server mode).
- `systemctl --user status syncthing` is active.

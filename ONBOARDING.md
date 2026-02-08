# GPG and pass Setup Guide

Quick reference for managing per-machine GPG keys and the pass password store across multiple machines.

## Overview

This setup uses **per-machine GPG keys** for security and revocability. Each machine has its own GPG key, and all keys are listed in `.gpg-id` in the pass repository. When you add or remove a machine, you re-encrypt the entire password store to the current set of keys.

**Key Principle:** Never copy private keys between machines. Generate fresh keys on each machine.

---

## SSH Key Setup (GitHub Authentication)

SSH keys are required to push/pull the password-store repository from GitHub. Set this up on each new machine before git operations.

### 1. Generate SSH Key

```bash
# Generate ed25519 key (recommended)
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Press Enter to accept the default location (`~/.ssh/id_ed25519`). Optionally set a passphrase for extra security.

### 2. Start SSH Agent and Add Key

```bash
# Start the SSH agent
eval "$(ssh-agent -s)"

# Add your key to the agent
ssh-add ~/.ssh/id_ed25519
```

**Optional:** To auto-start the agent, add to `~/.bashrc` or `~/.zshrc`:

```bash
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
```

### 3. Add Public Key to GitHub

```bash
# Display your public key
cat ~/.ssh/id_ed25519.pub
```

Then:
1. Go to https://github.com/settings/keys
2. Click **"New SSH key"**
3. Title: Use machine hostname (e.g., `vps`, `laptop`, `desktop`)
4. Key type: **Authentication Key**
5. Paste the public key
6. Click **"Add SSH key"**

### 4. Test Connection

```bash
ssh -T git@github.com
```

Expected output:
```
Hi your-username! You've successfully authenticated, but GitHub does not provide shell access.
```

**Troubleshooting:** If you see "Permission denied", verify:
- The public key is added to GitHub
- The SSH agent is running (`ssh-add -l` should list your key)
- You're using the correct GitHub username

---

## First Machine Setup

Use this flow when setting up pass for the first time.

### 1. Generate GPG Key

```bash
# Generate key with hostname identifier
# Format: "Name (machine-identifier) <email>"
gpg --quick-gen-key "Thomas ($(hostname)) <your-email@example.com>" rsa4096
```

**Naming convention:** Use a short machine identifier in parentheses:
- `Thomas (laptop) <email>` - for your laptop
- `Thomas (desktop) <email>` - for your desktop  
- `Thomas (vps) <email>` - for a VPS/server

#### Verify Key Creation

```bash
# List your keys
gpg --list-keys
```

Example output:
```
pub   rsa4096 2026-01-25 [SC]
      ABC123DEF456789012345678901234567890ABCD
uid           [ultimate] Thomas (laptop) <your-email@example.com>
```

- **Key ID:** The 40-character hex string (e.g., `ABC123DEF456789012345678901234567890ABCD`)
- **`[ultimate]`:** Normal - means this is YOUR key (you have the private key)

#### If You Need to Regenerate

If you made a mistake (wrong name, etc.), delete and recreate:

```bash
# Get your key ID first
gpg --list-keys

# Delete secret (private) key first
gpg --delete-secret-keys <key-id>

# Then delete public key
gpg --delete-keys <key-id>

# Now regenerate with correct info
gpg --quick-gen-key "Thomas (correct-name) <your-email@example.com>" rsa4096
```

### 2. Initialize pass Store

```bash
# Initialize pass with your GPG key ID
pass init <your-gpg-key-id>
```

This creates `~/.password-store/` with a `.gpg-id` file containing your key ID.

### 3. Add Initial Secrets

```bash
# Add your secrets
pass insert ai/openai-api-key
pass insert ai/anthropic-api-key
pass insert dev/github-token
pass insert infra/hetzner-api-token

# Verify
pass ls
```

### 4. Push to Private Git Repo

```bash
# Initialize git repo
cd ~/.password-store
git init
git add .
git commit -m "Initial pass store"

# Add remote and push
git remote add origin git@github.com:your-username/password-store.git
git push -u origin main
```

**Done!** Your first machine is set up.

---

## Adding a New Machine

Use this flow when setting up pass on a second, third, etc. machine.

### Prerequisites on New Machine

1. **SSH key set up** - See [SSH Key Setup](#ssh-key-setup-github-authentication) above
2. **GPG installed** - Usually pre-installed, verify with `gpg --version`

### On the New Machine

#### 1. Generate GPG Key

```bash
# Generate key with machine identifier
# Use a short, descriptive name for this machine
gpg --quick-gen-key "Thomas (vps) <your-email@example.com>" rsa4096
```

**Naming examples:**
- `Thomas (vps)` - for a VPS/server
- `Thomas (work-laptop)` - for work machine
- `Thomas (home-desktop)` - for home machine

#### 2. Verify Key Creation

```bash
gpg --list-keys
```

Example output:
```
pub   rsa4096 2026-01-25 [SC]
      ABC123DEF456789012345678901234567890ABCD
uid           [ultimate] Thomas (vps) <your-email@example.com>
```

**Note:** `[ultimate]` trust is normal - it means this is your own key.

#### 3. If You Need to Regenerate

Made a mistake? Delete and recreate:

```bash
# Delete secret key first, then public key
gpg --delete-secret-keys <key-id>
gpg --delete-keys <key-id>

# Regenerate
gpg --quick-gen-key "Thomas (correct-name) <your-email@example.com>" rsa4096
```

#### 4. Export Public Key

```bash
# Get your key ID
gpg --list-keys

# Export public key to file
gpg --armor --export <new-machine-key-id> > ~/new-machine.pub.asc
```

#### 5. Transfer Public Key to Existing Machine

```bash
# Option 1: SCP (if you have SSH access)
scp ~/new-machine.pub.asc user@existing-machine:~/

# Option 2: Display and copy-paste via SSH
cat ~/new-machine.pub.asc
# Then SSH to existing machine and paste into a file
```

### On an Existing Machine

#### 6. Import New Machine's Public Key

```bash
# Import the public key
gpg --import ~/new-machine.pub.asc

# Verify import
gpg --list-keys
# Should show the new machine's key
```

#### 7. Trust the Key (Recommended)

```bash
gpg --edit-key <new-machine-key-id>
```

In the GPG prompt:
```
gpg> trust
Your decision? 5  (ultimate trust)
Do you really want to set this key to ultimate trust? y
gpg> quit
```

#### 8. Add Key to pass and Re-encrypt

```bash
# Navigate to pass store
cd ~/.password-store

# Add new key ID to .gpg-id
echo "<new-machine-key-id>" >> .gpg-id

# Re-encrypt all secrets to all keys in .gpg-id
pass init $(cat .gpg-id)

# Commit and push
pass git add .gpg-id
pass git commit -m "Add key for new-machine"
pass git push
```

**What just happened:** `pass init` re-encrypted every secret to all GPG keys listed in `.gpg-id`. Now both machines can decrypt the secrets.

### Back on the New Machine

#### 9. Clone pass Repository

```bash
# Clone the password store
git clone git@github.com:your-username/password-store.git ~/.password-store
```

#### 10. Verify Access

```bash
# List all secrets
pass ls

# Try decrypting a secret
pass show ai/openai-api-key
```

If you see `gpg: decryption failed: No secret key`, the re-encryption on the existing machine didn't include your key. Go back to step 8 and verify your key ID is in `.gpg-id`.

**Done!** The new machine can now access all secrets.

---

## Tailscale Setup

Tailscale is installed automatically via `tools.yaml`. The `run_once_setup-tailscale.sh` script enables and starts `tailscaled`, but authentication requires manual action.

### Step 1: Authenticate

```bash
# For desktops/laptops
tailscale up

# For headless servers (enables Tailscale SSH)
tailscale up --ssh
```

This prints an auth URL. Open it in your browser and approve the device in your Tailscale admin console.

### Step 2: Verify connection

```bash
tailscale status
tailscale ip -4    # Show your Tailscale IP
```

### Step 3: Firewall (servers only)

On server mode, UFW is configured automatically by `run_once_setup-ufw.sh`:
- Deny all incoming traffic
- Allow all traffic on `tailscale0` interface
- Allow Tailscale WireGuard port (41641/udp)

Verify with:

```bash
ufw status verbose
```

After UFW is enabled, SSH is only accessible via Tailscale. Do NOT disconnect your current session until you've verified Tailscale connectivity from another device.

---

## OpenCode Server Setup (Server Mode Only)

On server mode, chezmoi creates a systemd service for `opencode web` and a helper script for managing API keys. The service listens on port 4096 and is accessible from all Tailscale devices.

### Architecture

```
Phone (Tailscale) ──────────────┐
                                │
Desktop (opencode attach) ──────┼──▶  opencode web (:4096)
                                │      (systemd service)
Laptop (opencode attach) ───────┘      WorkingDirectory=~
                                       Binds 0.0.0.0:4096
```

### Step 1: Generate the environment file

The service needs API keys (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GITHUB_TOKEN`, etc.). These are loaded from `~/.config/opencode/server.env`, generated from `pass`.

This step requires pass to be fully set up first (GPG key generated, password store cloned, decryption verified).

```bash
# Generate env file from pass entries
opencode-env generate

# Verify the file was created
opencode-env check
```

### Step 2: Start the service

```bash
systemctl start opencode-web
```

The service is already enabled (starts on boot). Check status:

```bash
systemctl status opencode-web
curl http://localhost:4096/global/health
```

### Step 3: Connect from other devices

From desktop/laptop (over Tailscale):

```bash
opencode attach http://<tailscale-ip>:4096

# Attach to a specific project
opencode attach --dir=/root/Overlord/projects/web/my-project http://<tailscale-ip>:4096
```

From phone: open `http://<tailscale-ip>:4096` in your browser.

### Managing the service

```bash
# View logs
journalctl -u opencode-web -f

# Restart after updating keys or opencode binary
systemctl restart opencode-web

# Regenerate env file (e.g., after key rotation)
opencode-env generate && systemctl restart opencode-web
```

---

## Removing a Machine

Use this flow when decommissioning a machine or revoking access.

### 1. Remove Key from `.gpg-id`

On any existing machine with access:

```bash
cd ~/.password-store

# Edit .gpg-id and remove the line with the old machine's key ID
nvim .gpg-id

# Or use sed
sed -i '/<old-machine-key-id>/d' .gpg-id
```

### 2. Re-encrypt to Remaining Keys

```bash
# Re-encrypt all secrets to only the remaining keys
pass init $(cat .gpg-id)

# Commit and push
pass git add .gpg-id
pass git commit -m "Remove key for old-machine"
pass git push
```

### 3. Revoke GPG Key (Optional)

If the machine was compromised or you want to formally revoke the key:

```bash
# On any machine with the key
gpg --edit-key <old-machine-key-id>
# In GPG prompt: type "revkey", confirm, then "save"

# Export revocation certificate
gpg --armor --export <old-machine-key-id> > revoked-key.asc

# Publish to keyserver (optional)
gpg --send-keys <old-machine-key-id>
```

**Done!** The old machine can no longer decrypt any secrets.

---

## Common Issues

### GPG Agent Not Running

**Symptom:** `gpg: decryption failed: No secret key`

**Fix:**
```bash
# Start GPG agent
gpg-agent --daemon

# Or restart it
gpgconf --kill gpg-agent
gpg-agent --daemon
```

Add to your shell config to auto-start:
```bash
# In ~/.zshrc or ~/.bashrc
export GPG_TTY=$(tty)
gpg-connect-agent /bye
```

### Passphrase Caching

**Symptom:** GPG asks for passphrase every time

**Fix:** Configure GPG agent cache timeout:

```bash
# Edit ~/.gnupg/gpg-agent.conf
echo "default-cache-ttl 3600" >> ~/.gnupg/gpg-agent.conf
echo "max-cache-ttl 86400" >> ~/.gnupg/gpg-agent.conf

# Reload agent
gpgconf --reload gpg-agent
```

- `default-cache-ttl`: Cache passphrase for 1 hour (3600 seconds)
- `max-cache-ttl`: Maximum cache time of 24 hours (86400 seconds)

### Key Trust Levels

**Symptom:** `gpg: WARNING: This key is not certified with a trusted signature!`

**Fix:** Trust your own keys:

```bash
gpg --edit-key <key-id>
# In GPG prompt:
trust
5  # (ultimate trust)
quit
```

### pass Git Push Fails

**Symptom:** `pass git push` fails with authentication error

**Fix:** Ensure SSH key is set up correctly. See [SSH Key Setup](#ssh-key-setup-github-authentication) section above.

Quick verification:
```bash
# Check if SSH agent has your key loaded
ssh-add -l

# Test GitHub connection
ssh -T git@github.com
```

### Secrets Not Loading in Shell

**Symptom:** `echo $OPENAI_API_KEY` is empty

**Fix:** Check shell integration in `~/.zshrc` or `~/.bashrc`:

```bash
# Should be present:
export PASSWORD_STORE_DIR="$HOME/.password-store"

if command -v pass &>/dev/null && [[ -d "$PASSWORD_STORE_DIR" ]]; then
    export OPENAI_API_KEY=$(pass show ai/openai-api-key 2>/dev/null)
    export ANTHROPIC_API_KEY=$(pass show ai/anthropic-api-key 2>/dev/null)
    export GITHUB_TOKEN=$(pass show dev/github-token 2>/dev/null)
fi
```

Reload shell: `source ~/.zshrc`

### Wrong GPG Key Selected

**Symptom:** `gpg: decryption failed: No secret key` even though key exists

**Fix:** Verify which keys pass is trying to use:

```bash
# Check .gpg-id
cat ~/.password-store/.gpg-id

# List your secret keys
gpg --list-secret-keys

# If your key ID is not in .gpg-id, re-run pass init
pass init <your-key-id>
```

---

## Quick Reference

### Useful Commands

```bash
# List all secrets
pass ls

# Show a secret
pass show ai/openai-api-key

# Add/edit a secret
pass insert dev/new-secret
pass edit dev/existing-secret

# Generate random password
pass generate dev/random-password 32

# Remove a secret
pass rm dev/old-secret

# Git operations
pass git status
pass git log
pass git push

# List GPG keys
gpg --list-keys          # Public keys
gpg --list-secret-keys   # Private keys

# Export public key
gpg --armor --export <key-id>

# Import public key
gpg --import keyfile.asc

# Delete GPG key (for regeneration)
gpg --delete-secret-keys <key-id>
gpg --delete-keys <key-id>

# SSH key management
ssh-keygen -t ed25519 -C "email"   # Generate key
ssh-add -l                          # List loaded keys
ssh -T git@github.com               # Test GitHub connection
```

### File Locations

- **pass store:** `~/.password-store/`
- **GPG keys:** `~/.gnupg/`
- **GPG config:** `~/.gnupg/gpg.conf`, `~/.gnupg/gpg-agent.conf`
- **SSH keys:** `~/.ssh/id_ed25519` (private), `~/.ssh/id_ed25519.pub` (public)
- **Chezmoi source:** `~/.local/share/chezmoi/`

---

## Security Notes

1. **Never commit `.gpg-id` with only one key** - If you lose that machine, you lose access to all secrets
2. **Keep at least 2 machines in `.gpg-id`** - Redundancy is critical
3. **Back up your GPG private key** - Store securely offline (USB drive, paper backup)
4. **Use strong passphrases** - Your GPG key passphrase is the master password
5. **Revoke compromised keys immediately** - Don't wait

---

## Workflow Summary

| Action | Steps |
|--------|-------|
| **SSH setup** | `ssh-keygen` → add to GitHub → `ssh -T git@github.com` |
| **GPG key setup** | `gpg --quick-gen-key "Name (machine) <email>" rsa4096` → verify with `gpg --list-keys` |
| **First machine** | SSH setup → GPG setup → `pass init <key-id>` → add secrets → `pass git push` |
| **Add new machine** | SSH setup → GPG setup → export pub key → import on existing → add to `.gpg-id` → `pass init` → push → clone on new machine |
| **Remove machine** | Remove from `.gpg-id` → `pass init` → push |
| **Add secret** | `pass insert path/to/secret` |
| **Sync changes** | `pass git pull` or `pass git push` |
| **Verify access** | `pass ls` and `pass show path/to/secret` |
| **Regenerate GPG key** | `gpg --delete-secret-keys <id>` → `gpg --delete-keys <id>` → regenerate |

---

For more details, see [dotfiles-spec.md](thoughts/plans/dotfiles-spec.md).


Recommended: Simple interactive test
docker run -it --rm ubuntu:24.04 bash
Then inside:
apt update && apt install -y curl git sudo
export PATH="$HOME/bin:$PATH"
curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash -s -- --mode server

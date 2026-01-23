# GPG and pass Setup Guide

Quick reference for managing per-machine GPG keys and the pass password store across multiple machines.

## Overview

This setup uses **per-machine GPG keys** for security and revocability. Each machine has its own GPG key, and all keys are listed in `.gpg-id` in the pass repository. When you add or remove a machine, you re-encrypt the entire password store to the current set of keys.

**Key Principle:** Never copy private keys between machines. Generate fresh keys on each machine.

---

## First Machine Setup

Use this flow when setting up pass for the first time.

### 1. Generate GPG Key

```bash
# Generate key with hostname identifier (with signing capability for pass)
gpg --quick-gen-key "Thomas ($(hostname)) <your-email@example.com>" rsa4096
```

**Note the key ID** from the output (8-character hex string).

### 2. Initialize pass Store

```bash
# Initialize pass with your GPG key ID
pass init <your-gpg-key-id>
```

This creates `~/.password-store/` with a `.gpg-id` file containing your key ID.

### 3. Add Initial Secrets

```bash
# Add your secrets
pass insert dev/openai-api-key
pass insert dev/anthropic-api-key
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

### On the New Machine

#### 1. Run Chezmoi Init

```bash
# Bootstrap dotfiles (includes GPG setup)
curl -fsSL https://raw.githubusercontent.com/your-username/dotfiles/main/install.sh | bash
```

This generates a GPG key automatically. If you need to generate manually:

```bash
gpg --quick-gen-key "Thomas ($(hostname)) <your-email@example.com>" rsa4096
```

#### 2. Export Public Key

```bash
# Get your new key ID
gpg --list-keys

# Export public key
gpg --armor --export <new-machine-key-id> > ~/new-machine.pub.asc
```

#### 3. Transfer Public Key to Existing Machine

```bash
# Copy to existing machine (use scp, rsync, or paste via SSH)
scp ~/new-machine.pub.asc existing-machine:~/
```

### On an Existing Machine

#### 4. Import New Machine's Public Key

```bash
# Import the public key
gpg --import ~/new-machine.pub.asc

# Trust the key (optional but recommended)
gpg --edit-key <new-machine-key-id>
# In GPG prompt: type "trust", select "5" (ultimate), then "quit"
```

#### 5. Add Key to pass and Re-encrypt

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

#### 6. Clone pass Repository

```bash
# Clone the password store
git clone git@github.com:your-username/password-store.git ~/.password-store

# Verify you can access secrets
pass ls
pass show dev/openai-api-key
```

**Done!** The new machine can now access all secrets.

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

**Fix:** Ensure SSH key is added to GitHub:

```bash
# Generate SSH key if needed
ssh-keygen -t ed25519 -C "your-email@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key and add to GitHub
cat ~/.ssh/id_ed25519.pub
```

### Secrets Not Loading in Shell

**Symptom:** `echo $OPENAI_API_KEY` is empty

**Fix:** Check shell integration in `~/.zshrc` or `~/.bashrc`:

```bash
# Should be present:
export PASSWORD_STORE_DIR="$HOME/.password-store"

if command -v pass &>/dev/null && [[ -d "$PASSWORD_STORE_DIR" ]]; then
    export OPENAI_API_KEY=$(pass show dev/openai-api-key 2>/dev/null)
    export ANTHROPIC_API_KEY=$(pass show dev/anthropic-api-key 2>/dev/null)
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
pass show dev/openai-api-key

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
```

### File Locations

- **pass store:** `~/.password-store/`
- **GPG keys:** `~/.gnupg/`
- **GPG config:** `~/.gnupg/gpg.conf`, `~/.gnupg/gpg-agent.conf`
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

| Action | Command |
|--------|---------|
| First machine setup | `pass init <key-id>` → add secrets → `pass git push` |
| Add new machine | Generate key → export pub key → import on existing → add to `.gpg-id` → `pass init` → push |
| Remove machine | Remove from `.gpg-id` → `pass init` → push |
| Add secret | `pass insert path/to/secret` |
| Sync changes | `pass git pull` or `pass git push` |
| Verify access | `pass ls` and `pass show path/to/secret` |

---

For more details, see [dotfiles-spec.md](thoughts/plans/dotfiles-spec.md).

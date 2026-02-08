# GPG and Pass Setup Guide

Complete guide for setting up GPG keys and the `pass` password store across multiple machines.

## Key Concepts

- **Each machine gets its own GPG key** - never copy private keys between machines
- **GPG keys have subkeys** - a primary key (signing) and subkeys (encryption)
- **Encryption requires an encryption subkey** - keys with only `[SC]` (Sign/Certify) cannot receive encrypted data
- **pass encrypts to all keys in `.gpg-id`** - all listed keys can decrypt the secrets

---

## Part 1: First Machine Setup

Run all commands on your **first/primary machine**.

### Step 1: Generate GPG Key

```bash
# Generate RSA key
# Format: "Name (machine-identifier) <email>"
gpg --quick-gen-key "Thomas (laptop) <your-email@example.com>" rsa4096
```

**Note:** This creates a signing key only. You MUST add an encryption subkey (next step).

### Step 2: Add Encryption Subkey

The primary key cannot encrypt - you need to add an encryption subkey:

```bash
gpg --edit-key <your-key-id>
```

In the GPG prompt:
```
gpg> addkey
Please select what kind of key you want:
   (6) RSA (encrypt only)
Your selection? 6

What keysize do you want? 4096

Key is valid for? 3y

Really create? (y/N) y

gpg> save
```

### Step 3: Verify Key Has Encryption Capability

```bash
gpg --list-keys --keyid-format long
```

Expected output:
```
pub   rsa4096/1234567890ABCDEF 2026-01-25 [SC] [expires: 2029-01-24]
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
uid                 [ultimate] Thomas (laptop) <your-email@example.com>
sub   rsa4096/FEDCBA0987654321 2026-01-25 [E] [expires: 2029-01-24]
```

**Critical:** You MUST see a `sub` line with `[E]` (Encryption). If missing, repeat Step 2.

### Step 4: Note Your Key ID

The key ID is the 40-character hex string:
```
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Or use the short form (last 16 characters).

### Step 5: Generate SSH Key (for GitHub)

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Press Enter for default location, optionally set passphrase.

### Step 6: Add SSH Key to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```

1. Go to https://github.com/settings/keys
2. Click "New SSH key"
3. Title: `laptop` (or your machine name)
4. Paste the public key
5. Click "Add SSH key"

Test:
```bash
ssh -T git@github.com
```

### Step 7: Initialize pass

```bash
pass init <your-gpg-key-id>
```

### Step 8: Add Secrets

```bash
pass insert ai/anthropic-api-key
pass insert ai/openai-api-key
# etc.

# Verify
pass ls
pass show ai/anthropic-api-key
```

### Step 9: Push to Git

```bash
cd ~/.password-store
git init
git add .
git commit -m "Initial password store"
git remote add origin git@github.com:YOUR-USERNAME/password-store.git
git push -u origin main
```

**First machine setup complete.**

---

## Part 2: Adding a New Machine

This requires running commands on **both machines**. Pay attention to which machine each step specifies.

### Automated Setup (Recommended)

If you run the dotfiles install script, Steps 1-6 are handled automatically:

```bash
curl -fsSL https://raw.githubusercontent.com/PoeAudits/dotfiles/main/install.sh | bash -s -- --mode server
```

The script will:
- Generate GPG key with encryption subkey
- Generate SSH key
- Export GPG public key to `~/<hostname>.pub.asc`
- Display next steps with exact commands

After running the install script, skip to **Step 5** (add SSH key to GitHub).

### Manual Setup

If you need to set up keys manually, follow all steps below.

### ON NEW MACHINE: Step 1 - Generate GPG Key

```bash
# Use a unique identifier for this machine
gpg --quick-gen-key "Thomas (vps) <your-email@example.com>" rsa4096
```

Note your key ID from the output (40-character hex string).

### ON NEW MACHINE: Step 2 - Add Encryption Subkey

The primary key cannot encrypt - you must add an encryption subkey:

```bash
gpg --edit-key <your-key-id>
```

In the GPG prompt:
```
gpg> addkey
Please select what kind of key you want:
   (6) RSA (encrypt only)
Your selection? 6

What keysize do you want? 4096

Key is valid for? 3y

Really create? (y/N) y

gpg> save
```

### ON NEW MACHINE: Step 3 - Verify Encryption Capability

```bash
gpg --list-keys --keyid-format long
```

You MUST see:
```
pub   rsa4096/... [SC]
      <YOUR-KEY-ID>
uid   [ultimate] Thomas (vps) <your-email@example.com>
sub   rsa4096/... [E]    <-- REQUIRED!
```

If there's no `sub` line with `[E]`, repeat Step 2.

### ON NEW MACHINE: Step 4 - Generate SSH Key

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

### ON NEW MACHINE: Step 5 - Add SSH Key to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```

Add to https://github.com/settings/keys with title matching your machine name.

Test:
```bash
ssh -T git@github.com
```

### ON NEW MACHINE: Step 6 - Export Public Key

```bash
# Get your key ID
gpg --list-keys

# Export to file
gpg --armor --export <new-machine-key-id> > ~/new-machine.pub.asc

# Display for copy-paste (alternative to scp)
cat ~/new-machine.pub.asc
```

### ON NEW MACHINE: Step 7 - Export Public Key to File

Ensure the public key is exported and ready:
```bash
gpg --armor --export <new-machine-key-id> > ~/new-machine.pub.asc
```

---

### ON EXISTING MACHINE: Step 8 - Transfer and Import Public Key

**Note:** Typically the existing machine (laptop) can SSH into the new machine (VPS), but not vice versa. Run these commands from your existing machine.

**Option A - SCP from existing machine:**
```bash
# Pull the public key FROM the new machine
scp user@new-machine:~/new-machine.pub.asc ~/

# Import it
gpg --import ~/new-machine.pub.asc
```

**Option B - SSH and copy-paste:**
```bash
# SSH into new machine and display the key
ssh user@new-machine "cat ~/new-machine.pub.asc"

# Copy the output, then import locally:
gpg --import <<'EOF'
-----BEGIN PGP PUBLIC KEY BLOCK-----
<paste key content here>
-----END PGP PUBLIC KEY BLOCK-----
EOF
```

**Option C - Single command:**
```bash
# Import directly via SSH
ssh user@new-machine "cat ~/new-machine.pub.asc" | gpg --import
```

### ON EXISTING MACHINE: Step 9 - Verify Import

```bash
gpg --list-keys <new-machine-key-id>
```

**Verify you see the encryption subkey:**
```
pub   rsa4096/... [SC]
uid   [ unknown] Thomas (vps) <your-email@example.com>
sub   rsa4096/... [E]    <-- MUST BE PRESENT!
```

### ON EXISTING MACHINE: Step 10 - Trust the Key

```bash
gpg --edit-key <new-machine-key-id>
```

In GPG prompt:
```
gpg> trust
Your decision? 5
Do you really want to set this key to ultimate trust? y
gpg> quit
```

### ON EXISTING MACHINE: Step 11 - Add Key to .gpg-id

```bash
cd ~/.password-store
echo "<new-machine-key-id>" >> .gpg-id
```

### ON EXISTING MACHINE: Step 12 - Re-encrypt All Secrets

```bash
pass init $(cat .gpg-id)
```

**Expected output:**
```
Password store initialized for KEY1, KEY2
reencrypting ai/anthropic-api-key
reencrypting ai/openai-api-key
...
```

**If it doesn't show "reencrypting" lines, something is wrong.** See [Troubleshooting](#troubleshooting).

### ON EXISTING MACHINE: Step 13 - Verify and Push

```bash
# Verify files changed
git status

# Commit and push
pass git add .
pass git commit -m "Add key for vps"
pass git push
```

---

### ON NEW MACHINE: Step 14 - Clone Password Store

```bash
git clone git@github.com:YOUR-USERNAME/password-store.git ~/.password-store
```

### ON NEW MACHINE: Step 15 - Verify Access

```bash
pass ls
pass show ai/anthropic-api-key
```

**New machine setup complete.**

---

## Adding Encryption Subkey (If Missing)

If your key only shows `[SC]` with no `[E]` subkey, add one:

### ON THE MACHINE WITH THE KEY:

```bash
gpg --edit-key <your-key-id>
```

In GPG prompt:
```
gpg> addkey
Please select what kind of key you want:
   (6) RSA (encrypt only)
Your selection? 6

RSA keys may be between 1024 and 4096 bits long.
What keysize do you want? 4096

Key is valid for? 3y

Really create? y

gpg> save
```

After adding the subkey, **re-export your public key** and re-import it on all other machines:

```bash
# Export updated public key
gpg --armor --export <your-key-id> > ~/updated-key.pub.asc
```

Then import on other machines and run `pass init` again.

---

## Troubleshooting

### "pass init" doesn't re-encrypt files

**Symptom:** `pass init` says initialized but `git status` shows no changes.

**Cause:** The encryption subkey is missing from one or more keys in `.gpg-id`.

**Fix:**
1. Check each key has an encryption subkey:
   ```bash
   gpg --list-keys <key-id>
   ```
2. Look for `sub ... [E]` line
3. If missing, add encryption subkey (see above)
4. Re-import the updated public key
5. Run `pass init $(cat .gpg-id)` again

### "gpg: public key decryption failed: No secret key"

**Symptom:** Can't decrypt secrets on new machine.

**Causes:**
1. Your key isn't in `.gpg-id`
2. Secrets weren't re-encrypted after adding your key
3. Your key has no encryption subkey

**Diagnose:**
```bash
# Check what keys the secret is encrypted to
gpg --list-packets ~/.password-store/ai/anthropic-api-key.gpg 2>&1 | grep keyid

# Check what keys are in .gpg-id
cat ~/.password-store/.gpg-id

# Check your key has encryption capability
gpg --list-keys --keyid-format long
```

### Check which keys a file is encrypted to

```bash
gpg --list-packets ~/.password-store/SECRET-NAME.gpg 2>&1 | grep -i "keyid\|encrypted"
```

### "[unknown]" trust level

**Symptom:** Key shows `[ unknown]` instead of `[ultimate]`.

**Fix:** Trust the key:
```bash
gpg --edit-key <key-id>
gpg> trust
Your decision? 5
gpg> quit
```

---

## Quick Reference

### Commands Summary

| Task | Command |
|------|---------|
| Generate key | `gpg --quick-gen-key "Name (machine) <email>" rsa4096` |
| Add encryption subkey (required!) | `gpg --edit-key <key-id>` then `addkey`, `(6) RSA encrypt`, `save` |
| List keys | `gpg --list-keys` |
| List secret keys | `gpg --list-secret-keys` |
| Export public key | `gpg --armor --export <key-id> > key.pub.asc` |
| Import public key | `gpg --import key.pub.asc` |
| Trust a key | `gpg --edit-key <key-id>` then `trust`, `5`, `quit` |
| Delete key | `gpg --delete-secret-keys <id>` then `gpg --delete-keys <id>` |
| Init/re-encrypt pass | `pass init $(cat .gpg-id)` |
| Check file encryption | `gpg --list-packets FILE.gpg 2>&1 \| grep keyid` |

### Key Capability Flags

| Flag | Meaning |
|------|---------|
| `[S]` | Sign |
| `[C]` | Certify |
| `[E]` | Encrypt |
| `[A]` | Authenticate |

A working key for `pass` MUST have `[E]` capability (usually on a subkey).

### File Locations

| What | Path |
|------|------|
| Password store | `~/.password-store/` |
| GPG keys | `~/.gnupg/` |
| SSH keys | `~/.ssh/` |
| Key recipients | `~/.password-store/.gpg-id` |

---

## Workflow Checklist

### First Machine
- [ ] Generate GPG key: `gpg --quick-gen-key "Name (machine) <email>" rsa4096`
- [ ] Add encryption subkey: `gpg --edit-key <id>` → `addkey` → `(6) RSA encrypt` → `save`
- [ ] Verify `[E]` subkey exists: `gpg --list-keys`
- [ ] Generate SSH key
- [ ] Add SSH key to GitHub
- [ ] Initialize pass
- [ ] Add secrets
- [ ] Push to git

### Adding New Machine
- [ ] **NEW:** Generate GPG key: `gpg --quick-gen-key "Name (machine) <email>" rsa4096`
- [ ] **NEW:** Add encryption subkey: `gpg --edit-key <id>` → `addkey` → `(6) RSA encrypt` → `save`
- [ ] **NEW:** Verify `[E]` subkey exists: `gpg --list-keys`
- [ ] **NEW:** Generate SSH key
- [ ] **NEW:** Add SSH key to GitHub
- [ ] **NEW:** Export public key
- [ ] **EXISTING:** Import public key
- [ ] **EXISTING:** Verify `[E]` subkey in imported key
- [ ] **EXISTING:** Trust the key
- [ ] **EXISTING:** Add key ID to `.gpg-id`
- [ ] **EXISTING:** Run `pass init` - verify "reencrypting" output
- [ ] **EXISTING:** Push changes
- [ ] **NEW:** Clone password store
- [ ] **NEW:** Verify can decrypt secrets

# GPG and pass Guide

This setup uses a per-machine key model:

- Every machine has its own GPG keypair.
- Private keys are never copied to another machine.
- `~/.password-store/.gpg-id` lists all key recipients.
- `pass init $(cat .gpg-id)` re-encrypts every secret to the current recipient set.

## Key requirements

Your key must include encryption capability (`[E]`), usually as a subkey.

Check:

```bash
gpg --list-keys --keyid-format long
```

Expected shape:

```text
pub   rsa4096/PRIMARY_KEY_ID ... [SC]
uid   ...
sub   rsa4096/SUBKEY_ID ... [E]
```

## First machine setup

1. Generate key:

```bash
gpg --quick-gen-key "Name (machine) <email@example.com>" rsa4096 sign 0
```

2. Add encryption subkey:

```bash
gpg --quick-add-key <primary-key-id> rsa4096 encr 0
```

3. Verify `[E]` subkey exists.
4. Initialize pass:

```bash
pass init <primary-key-id>
```

5. Add secrets and push `~/.password-store` to your private repo.

## Add a new machine

On new machine:

1. Bootstrap this dotfiles repo (see `docs/new-machine-install.md`).
2. Export public key:

```bash
gpg --armor --export <new-machine-key-id> > ~/new-machine.pub.asc
```

On existing trusted machine:

3. Import and trust key:

```bash
gpg --import ~/new-machine.pub.asc
gpg --edit-key <new-machine-key-id>
# trust -> 5 -> y -> quit
```

4. Add recipient and re-encrypt:

```bash
cd ~/.password-store
echo "<new-machine-key-id>" >> .gpg-id
pass init $(cat .gpg-id)
pass git add .gpg-id
pass git commit -m "Add key for new machine"
pass git push
```

Back on new machine:

5. Clone store and verify decrypt:

```bash
git clone git@github.com:PoeAudits/.password-store.git ~/.password-store
pass ls
pass show ai/openai-api-key
```

## Remove a machine

On a trusted machine:

```bash
cd ~/.password-store
# remove old key id from .gpg-id
pass init $(cat .gpg-id)
pass git add .gpg-id
pass git commit -m "Remove key for old machine"
pass git push
```

Optional hard revocation:

```bash
gpg --edit-key <old-key-id>
# revkey
```

## Troubleshooting

- `gpg: decryption failed: No secret key`
  - Ensure your key ID is in `.gpg-id`.
  - Ensure secrets were re-encrypted after key changes.
  - Ensure your key has an `[E]` subkey.
- `pass ls` fails on new machine
  - Re-run recipient update and `pass init` on an authorized machine.
- Key trust warnings
  - `gpg --edit-key <id>` then `trust` -> `5`.

## Useful commands

```bash
pass ls
pass show <entry>
pass insert <entry>
pass edit <entry>
pass git status
pass git pull
pass git push
gpg --list-keys
gpg --list-secret-keys
```

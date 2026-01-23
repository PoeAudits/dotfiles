# Orchestration Plan: Dotfiles Repository with Chezmoi + pass

## Source Plan
Converted from Planning Brief after Q&A exploration session. Key decisions: Chezmoi for dotfiles management, pass (GPG) for secrets with per-machine keys, separate repos for dotfiles and secrets, extensible tool installation.

## Overview

**Objective:** Create a portable dotfiles system using Chezmoi and pass (GPG) that can bootstrap any machine (Omarchy desktop, Ubuntu VPS, or Arch server) to a fully configured development environment in under 1 hour.

**Phases:** 6 phases, 19 total tasks

**Estimated Complexity:** Moderate-Complex

**Key Skills Required:**
- `bash-defensive-patterns` - all shell scripts, install scripts
- `readme-documentation` - README creation

---

## Phase 1: Repository Foundation ⏳

**Status:** ⏳ Pending
**Goal:** Initialize Chezmoi repository with base structure and configuration

**Dependencies:** None

**Parallel Execution:** Tasks 1.1 and 1.2 can run in parallel

### Task 1.1: Initialize Chezmoi Repository ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Initialize a new Chezmoi-managed dotfiles repository with the proper structure:
- Initialize with `chezmoi init`
- Create `.chezmoi.toml.tmpl` for machine-specific variables (hostname, OS, mode)
- Create `.chezmoiignore` to exclude desktop-only files on servers
- Set up the source directory structure

**Context:**
Chezmoi stores source files in `~/.local/share/chezmoi/` by default. Files are prefixed (`dot_`, `private_`, etc.) and templates use `.tmpl` suffix. The `.chezmoi.toml.tmpl` file prompts for machine config on first run.

Machine variables needed:
- `mode`: "server" or "desktop"
- `hostname`: machine name for conditionals
- Auto-detected: `.chezmoi.os`, `.chezmoi.arch`

**References:**
- Chezmoi docs: https://chezmoi.io/user-guide/setup/
- Template syntax: https://chezmoi.io/user-guide/templating/

**Success Criteria:**
- [ ] Chezmoi repository initialized
- [ ] `.chezmoi.toml.tmpl` prompts for mode (server/desktop)
- [ ] `.chezmoiignore` excludes desktop files when mode=server
- [ ] Basic directory structure created

**Required Skills:**
- `bash-defensive-patterns`

**Constraints:**
- Must work for fresh `chezmoi init --apply` on new machine
- Template prompts should have sensible defaults

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 1.2: Create .gitignore and Repository Metadata ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Create repository-level files:
1. `.gitignore` excluding:
   - Any `.env*` files
   - Private keys (`id_*`, `*.pem`, `*.key`)
   - Editor/OS artifacts (`.DS_Store`, `*.swp`, `*~`)
   - GPG files that shouldn't be committed
   - Any credential files
   
2. Basic `README.md` placeholder (full docs in Phase 6)

**Context:**
Security-critical - secrets are managed by pass, never in dotfiles repo.

**Success Criteria:**
- [ ] .gitignore covers all sensitive file patterns
- [ ] Common editor/OS artifacts excluded
- [ ] Comments explain each section
- [ ] Placeholder README exists

**Required Skills:**
- None specific

**Constraints:**
- Must be comprehensive to prevent accidental secret commits

**Completion Notes:** _(filled by orchestrator after completion)_

---

## Phase 2: Core Configuration Files ⏳

**Status:** ⏳ Pending
**Goal:** Add essential configuration files managed by Chezmoi

**Dependencies:** Phase 1

**Parallel Execution:** All tasks (2.1-2.5) can run in parallel

### Task 2.1: Create Neovim Configuration ⏳

**Status:** ⏳ Pending
**Subagent:** executor

**Task Description:**
Create Neovim configuration in Chezmoi format (`dot_config/nvim/`):
1. `init.lua` - main entry point with:
   - Basic editor settings (line numbers, tabs/spaces, etc.)
   - Key mappings for common operations
   - Plugin manager setup (lazy.nvim recommended)
   - Conditional loading based on machine type if needed
   
2. `lua/` directory structure for organized config:
   - `lua/core/options.lua` - editor options
   - `lua/core/keymaps.lua` - key mappings
   - `lua/plugins/` - plugin configurations

**Context:**
Neovim is the primary editor. Config should be functional out of the box but extensible. Use Chezmoi templating if any machine-specific differences needed.

**Success Criteria:**
- [ ] Neovim starts without errors
- [ ] Basic editing experience is comfortable
- [ ] Plugin manager bootstraps on first run
- [ ] LSP support configured for common languages
- [ ] File structure is organized and maintainable

**Required Skills:**
- None specific (Lua/Neovim knowledge helpful)

**Constraints:**
- Should work on both desktop and server
- Avoid heavy GUI-dependent plugins for server compatibility

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 2.2: Create tmux Configuration ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Create tmux configuration (`dot_config/tmux/tmux.conf` or `dot_tmux.conf`):
- Ergonomic prefix key (Ctrl-a or Ctrl-Space)
- Vi mode for copy
- Mouse support enabled
- Useful keybindings for splits and navigation
- Sensible pane/window navigation (vim-style hjkl)
- Status bar configuration showing useful info
- 256/true color support
- Reasonable history limit

**Context:**
Terminal multiplexer used heavily for remote development on VPS. Config should be comfortable for extended sessions.

**Success Criteria:**
- [ ] Prefix key is ergonomic
- [ ] Vi-style navigation works
- [ ] Mouse support enabled
- [ ] Status bar shows session/window info
- [ ] Copy mode works intuitively

**Required Skills:**
- None specific

**Constraints:**
- Avoid plugins for initial setup (keep portable)
- Should work on both Arch and Ubuntu

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 2.3: Create Git Configuration ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Create Git configuration as Chezmoi template (`dot_config/git/config.tmpl`):
- Default branch name (main)
- Useful aliases (st, co, br, lg for pretty log, etc.)
- Color settings enabled
- Push default (current)
- Pull rebase settings
- User name/email from Chezmoi data (`.chezmoi.toml.tmpl`)
- Delta or diff-so-fancy for better diffs (optional, detect if available)

**Context:**
Global git configuration. User identity comes from Chezmoi template variables set during init.

**References:**
- Template should use `{{ .git.name }}` and `{{ .git.email }}` from chezmoi data

**Success Criteria:**
- [ ] Common git aliases configured
- [ ] Sensible defaults for push/pull
- [ ] User identity templated from chezmoi config
- [ ] Works without optional tools (delta)

**Required Skills:**
- None specific

**Constraints:**
- User identity must come from template, not hardcoded

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 2.4: Create Starship Configuration ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Create Starship prompt configuration (`dot_config/starship.toml`):
- Git branch and status (clean, dirty, ahead/behind)
- Directory (truncated to reasonable depth)
- Language version indicators (Go, Python, Node) - only when relevant
- Command duration for slow commands (>2s)
- Exit code indicator for failures
- Hostname display (useful when SSH'd to VPS)
- Keep prompt fast and clean

**Context:**
Shell prompt configuration shared across all machines. Should be informative but not cluttered.

**Success Criteria:**
- [ ] Prompt shows essential info without clutter
- [ ] Git integration works correctly
- [ ] Language versions shown only in relevant directories
- [ ] Hostname visible (helps distinguish local vs VPS)
- [ ] Prompt renders quickly

**Required Skills:**
- None specific

**Constraints:**
- Keep reasonably minimal - avoid slow modules
- Should work in both zsh and bash

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 2.5: Create SSH Configuration ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Create SSH configuration (`private_dot_ssh/config`):
- Common defaults:
  - `AddKeysToAgent yes`
  - `IdentitiesOnly yes`
  - `ServerAliveInterval 60`
- Example host entries (commented) showing pattern
- Placeholder for VPS host configuration
- Use `private_` prefix for Chezmoi to set correct permissions

**Context:**
SSH host configurations only - private keys are NOT stored here. Each machine generates its own keys. The `private_` prefix ensures Chezmoi sets 600 permissions.

**Success Criteria:**
- [ ] Sensible SSH defaults configured
- [ ] Example host patterns included as comments
- [ ] No sensitive data (keys, real hostnames) included
- [ ] File permissions will be correct (600)

**Required Skills:**
- None specific

**Constraints:**
- Never include private keys
- Use placeholder hostnames in examples

**Completion Notes:** _(filled by orchestrator after completion)_

---

## Phase 3: Shell Configuration ⏳

**Status:** ⏳ Pending
**Goal:** Set up shell configurations with pass integration and Chezmoi templating

**Dependencies:** Phase 1

**Parallel Execution:** Tasks 3.1 and 3.2 can run in parallel; 3.3 depends on 3.1

### Task 3.1: Create Shell Configuration Files ⏳

**Status:** ⏳ Pending
**Subagent:** executor

**Task Description:**
Create shell configurations as Chezmoi templates:

1. `dot_zshrc.tmpl` - main zsh config:
   - PATH setup (`~/.local/bin`, Go, Bun, etc.)
   - Source aliases and functions files
   - Initialize starship prompt
   - Initialize pass (PASSWORD_STORE_DIR)
   - Source secrets from pass (via helper function, not plaintext)
   - Conditional sections for desktop vs server

2. `dot_bashrc.tmpl` - bash fallback with similar structure

3. `dot_config/shell/aliases.sh` - shared aliases:
   - Git shortcuts (g, gst, gco, etc.)
   - Navigation (.. , ..., etc.)
   - Common tool aliases (ls colors, etc.)
   - Chezmoi shortcuts (cz, cza, czd)

4. `dot_config/shell/functions.sh` - shared functions:
   - `mkcd` - mkdir and cd
   - `passget` - helper to get secrets from pass
   - `passenv` - load secrets as env vars from pass

**Context:**
Shell configs must work on zsh (desktop) and bash (server). Pass integration loads secrets at shell start without exposing them in dotfiles.

**References:**
- pass integration: `export VAR=$(pass show path/to/secret)`
- Chezmoi templates can use `{{ if eq .mode "desktop" }}`

**Success Criteria:**
- [ ] PATH includes all required directories
- [ ] Starship prompt initializes
- [ ] Aliases and functions load correctly
- [ ] pass integration works (secrets loaded as env vars)
- [ ] Desktop/server differences handled via templates
- [ ] Works in both zsh and bash

**Required Skills:**
- `bash-defensive-patterns`

**Constraints:**
- No hardcoded secrets
- Must be portable between zsh and bash where possible
- Secrets loaded from pass, not files

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 3.2: Create OpenCode Configuration ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Create OpenCode configuration (`dot_config/opencode/`):
1. `opencode.jsonc` - main config referencing environment variables for API keys
2. Any additional OpenCode config files needed

**Context:**
OpenCode reads API keys from environment variables. The shell config (Task 3.1) loads these from pass. OpenCode config should reference `${ANTHROPIC_API_KEY}` etc., not contain actual keys.

**Success Criteria:**
- [ ] OpenCode config references env vars for secrets
- [ ] Config structure matches OpenCode expectations
- [ ] No hardcoded API keys

**Required Skills:**
- None specific

**Constraints:**
- Never include actual API keys
- Use environment variable references

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 3.3: Create Overlord Configuration Placeholder ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Create Overlord configuration placeholder (`dot_config/overlord/`):
1. `registry.json` - empty or minimal project registry
2. Any other Overlord config files needed
3. README explaining the structure

**Context:**
Overlord manages project registry. Initial config should be minimal - projects added as they're created.

**Success Criteria:**
- [ ] Valid JSON structure for registry
- [ ] Overlord can start without errors
- [ ] Structure documented

**Required Skills:**
- None specific

**Constraints:**
- Keep minimal - just enough to not error

**Completion Notes:** _(filled by orchestrator after completion)_

---

## Phase 4: pass (GPG) Setup Infrastructure ⏳

**Status:** ⏳ Pending
**Goal:** Create scripts and documentation for pass setup with per-machine GPG keys

**Dependencies:** Phase 1

**Parallel Execution:** Tasks 4.1 and 4.2 can run in parallel; 4.3 depends on both

### Task 4.1: Create GPG Key Setup Script ⏳

**Status:** ⏳ Pending
**Subagent:** executor

**Task Description:**
Create Chezmoi run script (`.chezmoiscripts/run_once_setup-gpg.sh.tmpl`):

1. Check if GPG key already exists for this machine
2. If not, generate new ed25519 GPG key:
   - Use machine hostname in key identifier
   - Prompt for passphrase (or generate strong one)
   - Export public key to known location
3. Display instructions for adding key to pass store on another machine
4. Handle both Arch (gpg) and Ubuntu (gpg) - should be same

Script should be idempotent and informative.

**Context:**
Per-machine GPG keys strategy. Each machine has its own key. When a new machine is added, its public key must be added to the pass repo's `.gpg-id` file and `pass init` re-run to re-encrypt all secrets.

**References:**
- GPG key generation: `gpg --quick-gen-key "name <email>" ed25519`
- Export: `gpg --armor --export keyid > machine.pub.asc`

**Success Criteria:**
- [ ] Script generates GPG key if not present
- [ ] Key uses machine hostname for identification
- [ ] Public key exported for sharing
- [ ] Clear instructions displayed
- [ ] Idempotent - safe to run multiple times

**Required Skills:**
- `bash-defensive-patterns`

**Constraints:**
- Must work on both Arch and Ubuntu
- Should not overwrite existing keys
- Passphrase handling must be secure

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 4.2: Create pass Setup Script ⏳

**Status:** ⏳ Pending
**Subagent:** executor

**Task Description:**
Create Chezmoi run script (`.chezmoiscripts/run_once_setup-pass.sh.tmpl`):

1. Install pass if not present (pacman or apt)
2. Check if PASSWORD_STORE_DIR exists
3. If not, provide options:
   - Clone existing pass repo (prompt for git URL)
   - Initialize new pass store (for first machine)
4. Verify GPG key can decrypt (test with `pass ls`)
5. Set PASSWORD_STORE_DIR in shell config

Script should handle the "chicken and egg" problem of setting up pass on a new machine.

**Context:**
pass stores secrets in `~/.password-store/` by default (or PASSWORD_STORE_DIR). The store is a git repo. New machines need to:
1. Have their GPG key added to `.gpg-id` on another machine
2. Have the store re-encrypted with `pass init $(cat .gpg-id)`
3. Clone the repo

**References:**
- pass init: `pass init gpg-id1 gpg-id2 ...`
- pass git: `pass git clone <url>`

**Success Criteria:**
- [ ] pass installed if missing
- [ ] Handles both new store and existing store scenarios
- [ ] Verifies GPG decryption works
- [ ] Clear error messages if GPG key not in store
- [ ] Idempotent

**Required Skills:**
- `bash-defensive-patterns`

**Constraints:**
- Must work on both Arch and Ubuntu
- Handle missing GPG key gracefully (can't decrypt yet)

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 4.3: Create New Machine Onboarding Documentation ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Create documentation file (`.chezmoitemplates/ONBOARDING.md` or similar) covering:

1. **First Machine Setup:**
   - Generate GPG key
   - Initialize pass store
   - Add initial secrets
   - Push to private git repo

2. **Adding a New Machine:**
   - On new machine: run chezmoi init, generate GPG key
   - Copy public key to existing machine
   - On existing machine: add key to `.gpg-id`, run `pass init`, push
   - On new machine: clone pass repo, verify access

3. **Removing a Machine:**
   - Remove key from `.gpg-id`
   - Re-run `pass init` to re-encrypt
   - Revoke GPG key

4. **Common Issues:**
   - GPG agent issues
   - Key trust levels
   - Passphrase caching

**Context:**
Per-machine GPG keys require coordination when adding new machines. This doc is the reference for that process.

**Success Criteria:**
- [ ] First machine flow is clear
- [ ] New machine addition flow is step-by-step
- [ ] Machine removal documented
- [ ] Common troubleshooting covered

**Required Skills:**
- `readme-documentation`

**Constraints:**
- Should be understandable by future self under time pressure

**Completion Notes:** _(filled by orchestrator after completion)_

---

## Phase 5: Extensible Tool Installation ⏳

**Status:** ⏳ Pending
**Goal:** Create extensible system for installing development tools

**Dependencies:** Phase 1

**Parallel Execution:** Tasks 5.1 first, then 5.2

### Task 5.1: Create Tool Installation Framework ⏳

**Status:** ⏳ Pending
**Subagent:** executor

**Task Description:**
Create extensible tool installation system:

1. `tools.yaml` (or `tools.toml`) - tool definitions:
   ```yaml
   tools:
     go:
       check: "go version"
       install_arch: |
         # install commands for arch
       install_ubuntu: |
         # install commands for ubuntu
       version: "1.22"
     
     bun:
       check: "bun --version"
       install: "curl -fsSL https://bun.sh/install | bash"
     
     # ... more tools
   ```

2. `.chezmoiscripts/run_onchange_install-tools.sh.tmpl`:
   - Read tool definitions
   - For each tool: check if installed, install if not
   - Handle Arch vs Ubuntu differences
   - Report what was installed

3. Initial tools to include:
   - Go (1.22+)
   - Bun
   - uv (Python)
   - Foundry (forge, cast, anvil)
   - Tailscale
   - tmux (if not present)
   - neovim (if not present)
   - starship
   - pass
   - gpg

**Context:**
Tools need to be easily addable. Adding a new tool should only require editing the config file, not the install script. The `run_onchange_` prefix means it re-runs when the tools file changes.

**Success Criteria:**
- [ ] Tool config file is easy to read and edit
- [ ] Adding new tool requires only config change
- [ ] Install script handles Arch and Ubuntu
- [ ] Idempotent (skips installed tools)
- [ ] Clear output showing what was installed

**Required Skills:**
- `bash-defensive-patterns`

**Constraints:**
- Keep config format simple (YAML or TOML)
- Use official install methods where possible

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 5.2: Create Bootstrap Script ⏳

**Status:** ⏳ Pending
**Subagent:** worker

**Task Description:**
Create standalone bootstrap script that can be curled and run:

`install.sh` (at repo root):
1. Detect OS (Arch vs Ubuntu)
2. Install chezmoi if not present
3. Run `chezmoi init --apply <repo-url>`
4. Display post-install instructions

Should support:
```bash
# One-liner for new machine:
curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/install.sh | bash
# Or with explicit mode:
curl -fsSL ... | bash -s -- --mode server
```

**Context:**
Entry point for bootstrapping new machines. Should be minimal - just get chezmoi running, let chezmoi handle the rest.

**References:**
- Chezmoi one-liner: `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <user>`

**Success Criteria:**
- [ ] Works on Arch and Ubuntu
- [ ] Installs chezmoi correctly
- [ ] Passes mode to chezmoi init if specified
- [ ] Clear output and error messages
- [ ] Can be curled and piped to bash

**Required Skills:**
- `bash-defensive-patterns`

**Constraints:**
- Must be safe to run as curl | bash
- Minimal dependencies (just curl and bash)

**Completion Notes:** _(filled by orchestrator after completion)_

---

## Phase 6: Documentation & Validation ⏳

**Status:** ⏳ Pending
**Goal:** Complete documentation and validate the full installation flow

**Dependencies:** Phases 1-5

**Parallel Execution:** Tasks 6.1 and 6.2 can run in parallel; 6.3 after both

### Task 6.1: Create Complete README ⏳

**Status:** ⏳ Pending
**Subagent:** executor

**Task Description:**
Create comprehensive `README.md` covering:

1. **Overview** - what this dotfiles system does (Chezmoi + pass)
2. **Quick Start**:
   - New machine (one-liner)
   - Existing machine (update)
3. **What's Included** - table of managed configs
4. **Installation Modes** - server vs desktop differences
5. **Secrets Management**:
   - How pass works
   - How to add new secrets
   - How API keys get to applications
6. **Adding a New Machine** - link to onboarding doc
7. **Adding New Tools** - how to edit tools.yaml
8. **Making Changes**:
   - Edit source with `chezmoi edit`
   - Apply with `chezmoi apply`
   - Commit and push
9. **Customization** - how templates work for machine differences

**Context:**
Primary documentation. Should enable future self to bootstrap a new machine without remembering details.

**Success Criteria:**
- [ ] Quick start is copy-pasteable
- [ ] All major sections covered
- [ ] Secrets workflow is clear
- [ ] Tool addition process documented
- [ ] No sensitive information

**Required Skills:**
- `readme-documentation`

**Constraints:**
- Should work for someone who hasn't seen the spec

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 6.2: Validate Chezmoi Structure ⏳

**Status:** ⏳ Pending
**Subagent:** executor

**Task Description:**
Validate the Chezmoi setup:

1. Run `chezmoi verify` to check for issues
2. Run `chezmoi diff` to see what would change
3. Test template rendering with `chezmoi execute-template`
4. Verify all scripts pass shellcheck
5. Test `chezmoi apply --dry-run` 
6. Verify file permissions are correct (especially SSH, GPG)
7. Document any issues found and fix them

**Context:**
Ensure the dotfiles will work before first real deployment.

**Success Criteria:**
- [ ] `chezmoi verify` passes
- [ ] All scripts pass shellcheck
- [ ] Dry-run succeeds
- [ ] Templates render correctly for both modes
- [ ] File permissions are appropriate

**Required Skills:**
- `bash-defensive-patterns`

**Constraints:**
- Do not actually apply (just validate)

**Completion Notes:** _(filled by orchestrator after completion)_

---

### Task 6.3: End-to-End Test ⏳

**Status:** ⏳ Pending
**Subagent:** executor

**Task Description:**
Perform end-to-end test of the installation flow:

1. On current machine, run full `chezmoi apply`
2. Verify all configs are in place
3. Verify shell starts correctly with new config
4. Verify pass integration works (can retrieve secrets)
5. Verify starship prompt works
6. Verify neovim starts correctly
7. Verify tmux works
8. Document any issues and fixes

**Context:**
Real test on actual machine before deploying to VPS or other machines.

**Success Criteria:**
- [ ] All configs applied correctly
- [ ] Shell functions properly
- [ ] pass secrets accessible
- [ ] All managed applications work
- [ ] No errors in any config

**Required Skills:**
- `bash-defensive-patterns`

**Constraints:**
- Backup existing configs before applying
- Be prepared to rollback if issues

**Completion Notes:** _(filled by orchestrator after completion)_

---

## Execution Notes

### Parallelization Opportunities
- Phase 1: Tasks 1.1 and 1.2 can run in parallel
- Phase 2: All tasks (2.1-2.5) can run in parallel
- Phase 3: Tasks 3.1 and 3.2 in parallel; 3.3 after 3.1
- Phase 4: Tasks 4.1 and 4.2 in parallel; 4.3 after both
- Phase 5: Task 5.1 first, then 5.2
- Phase 6: Tasks 6.1 and 6.2 in parallel; 6.3 after both

### Critical Path
1.1 → 3.1 → 5.1 → 6.3

### Risk Points
- **GPG key management**: Per-machine keys add complexity - documentation critical
- **pass bootstrap**: Chicken-egg problem on new machines - script must handle gracefully
- **Cross-platform**: Scripts must work on both Arch and Ubuntu
- **Shell compatibility**: Configs must work in both zsh and bash

### Review Checkpoints
- After Phase 2: Review configs for completeness
- After Phase 4: Review GPG/pass scripts for security
- After Phase 5: Review tool installation for robustness
- After Phase 6: Full review before deployment

### Documentation Checkpoints
- After Phase 4: Onboarding docs should be complete
- After Phase 6: README should be complete

---

## Task Summary Table

| Phase | Task | Subagent | Dependencies | Parallel? | Status |
|-------|------|----------|--------------|-----------|--------|
| 1 | 1.1 Initialize Chezmoi repo | worker | none | yes (w/ 1.2) | ⏳ |
| 1 | 1.2 Create .gitignore | worker | none | yes (w/ 1.1) | ⏳ |
| 2 | 2.1 Neovim config | executor | Phase 1 | yes (all P2) | ⏳ |
| 2 | 2.2 tmux config | worker | Phase 1 | yes (all P2) | ⏳ |
| 2 | 2.3 Git config | worker | Phase 1 | yes (all P2) | ⏳ |
| 2 | 2.4 Starship config | worker | Phase 1 | yes (all P2) | ⏳ |
| 2 | 2.5 SSH config | worker | Phase 1 | yes (all P2) | ⏳ |
| 3 | 3.1 Shell configs | executor | Phase 1 | yes (w/ 3.2) | ⏳ |
| 3 | 3.2 OpenCode config | worker | Phase 1 | yes (w/ 3.1) | ⏳ |
| 3 | 3.3 Overlord config | worker | 3.1 | no | ⏳ |
| 4 | 4.1 GPG setup script | executor | Phase 1 | yes (w/ 4.2) | ⏳ |
| 4 | 4.2 pass setup script | executor | Phase 1 | yes (w/ 4.1) | ⏳ |
| 4 | 4.3 Onboarding docs | worker | 4.1, 4.2 | no | ⏳ |
| 5 | 5.1 Tool install framework | executor | Phase 1 | no | ⏳ |
| 5 | 5.2 Bootstrap script | worker | 5.1 | no | ⏳ |
| 6 | 6.1 Complete README | executor | Phases 1-5 | yes (w/ 6.2) | ⏳ |
| 6 | 6.2 Validate structure | executor | Phases 1-5 | yes (w/ 6.1) | ⏳ |
| 6 | 6.3 End-to-end test | executor | 6.1, 6.2 | no | ⏳ |

---

## Execution Status

_This section is updated by the orchestrator during execution._

**Last Updated:** [not started]
**Current Phase:** -
**Current Task:** -

### Progress
- Phases complete: 0 of 6
- Tasks complete: 0 of 19

### Divergences from Plan
_(none yet)_

### Handoff History
_(none)_

---

## Key Decisions Reference

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Dotfiles Manager | Chezmoi | Best multi-machine support, AI-friendly CLI, templates |
| Secrets Manager | pass (GPG) | CLI-native, git-synced, no external service dependency |
| GPG Key Strategy | Per-machine keys | More secure, individually revocable |
| Pass Store Location | Separate git repo | Clean separation from dotfiles |
| Tool Installation | Config-driven (YAML) | Easy to add new tools without script changes |
| Secret Loading | Shell startup via pass | Secrets never in dotfiles, loaded dynamically |

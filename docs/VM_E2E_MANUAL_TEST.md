# Manual VM E2E Test Guide

**Branch**: `feat/vm-e2e-orchestrator`
**Tags**: `vm-iac/foundation-v1`, `vm-iac/e2e-orchestrator-v1`, `vm-iac/config-fixes-v1`
**Last updated**: 2026-03-03

This guide walks through a full end-to-end bootstrap test inside a fresh macOS VM, specifically testing the config fixes and Brewfile changes on the feature branch before merging to main.

---

## Prerequisites

| Requirement | How to verify |
|-------------|---------------|
| `tart` installed | `tart --version` |
| VM checkpoint exists | `tart list \| grep dotfiles-macos-checkpoint` |
| SSH key in agent | `ssh-add -l` (must show `id_ed25519`) |
| Guest has Remote Login | Previously configured during one-time setup |
| Guest user `baelson` | Matches `ssh_user` in matrix config |
| On feature branch | `git branch --show-current` → `feat/vm-e2e-orchestrator` |

---

## What This Tests

The feature branch has **4 config files** that differ from `main`. This guide verifies each fix:

| Fix | File | What to look for |
|-----|------|-----------------|
| `encryption = "age"` top-level key | `.chezmoi.toml.tmpl` | `chezmoi doctor` shows no encryption warnings |
| `.chezmoiignore` narrowed sublime pattern | `.chezmoiignore` | `.sublime-settings` files deploy (not blocked) |
| `brew bundle --no-lock` removed | `install-packages.sh.tmpl` | `brew bundle` runs without `--no-lock` error |
| MAS skip when no iCloud login | `install-packages.sh.tmpl` | MAS apps skipped (not hung) during `brew bundle` |
| Brewfile reconciliation | `Brewfile.tmpl` | tart, tmuxwatch, codex-cask, docker-desktop install correctly |

---

## Step-by-Step Procedure

### Step 1: Clone fresh VM from checkpoint

```bash
# Delete any leftover test VM
tart delete dotfiles-macos-current 2>/dev/null || true

# Clone from checkpoint (APFS copy-on-write — instant)
tart clone dotfiles-macos-checkpoint dotfiles-macos-current
```

### Step 2: Start VM and get IP

```bash
tart run --no-graphics dotfiles-macos-current &
sleep 25
VM_IP=$(tart ip dotfiles-macos-current)
echo "Guest IP: $VM_IP"
```

### Step 3: Verify guest prerequisites

```bash
ssh -o StrictHostKeyChecking=no baelson@$VM_IP '
  echo "=== Git ===" && git --version
  echo "=== Sudo ===" && sudo -n true && echo "passwordless sudo OK"
  echo "=== SSH Key ===" && head -1 ~/.ssh/authorized_keys
  echo "=== Homebrew ===" && brew --version
'
```

All four checks should pass. If Homebrew is not installed, install it first:
```bash
ssh baelson@$VM_IP '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
```

### Step 4: Bootstrap from main (SCP workaround)

The VM clones from GitHub via SSH agent forwarding. This pulls from `main` since the private repo requires SSH auth and chezmoi's go-git doesn't support it (ISSUE-019).

```bash
# Run from ~/Git/Projects/Active/dotfiles/ on HOST
scp -o StrictHostKeyChecking=no setup.sh baelson@$VM_IP:~/setup.sh
ssh -A baelson@$VM_IP 'DOTFILES_REPO_URL="git@github.com:Baelson/dotfiles.git" zsh ~/setup.sh'
```

**Expected**: Bootstrap clones the repo, runs `chezmoi init --apply`, then aborts when it hits encrypted files (no age key in VM). This is normal — partial deploy.

### Step 5: Complete initial chezmoi apply (skip encrypted)

```bash
ssh baelson@$VM_IP '~/bin/chezmoi apply --exclude=encrypted,scripts --verbose'
```

**Expected**: All non-encrypted files deploy. Exit code 0.

### Step 6: Overlay feature branch config files

This is the critical step — SCP the 4 changed config files from the feature branch into the guest's chezmoi source directory, then re-apply.

```bash
# Run from ~/Git/Projects/Active/dotfiles/ on HOST

# 1. chezmoi.toml template (encryption = "age" fix)
scp home/.chezmoi.toml.tmpl \
    baelson@$VM_IP:~/.local/share/chezmoi/home/.chezmoi.toml.tmpl

# 2. chezmoiignore (narrowed sublime pattern)
scp home/.chezmoiignore \
    baelson@$VM_IP:~/.local/share/chezmoi/home/.chezmoiignore

# 3. install-packages lifecycle script (MAS skip + no --no-lock)
scp "home/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl" \
    "baelson@$VM_IP:~/.local/share/chezmoi/home/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"

# 4. Brewfile template (tart, tmuxwatch, codex cask, docker-desktop, tap ordering)
scp home/Brewfile.tmpl \
    baelson@$VM_IP:~/.local/share/chezmoi/home/Brewfile.tmpl
```

Re-apply chezmoi to regenerate target files from the updated templates:
```bash
ssh baelson@$VM_IP '~/bin/chezmoi apply --exclude=encrypted --verbose'
```

**Expected**: chezmoi regenerates `~/.chezmoi.toml`, `~/Brewfile`, and the lifecycle script from the updated templates.

### Step 7: Verify config fix #1 — encryption key in chezmoi.toml

```bash
ssh baelson@$VM_IP 'grep "^encryption" ~/.config/chezmoi/chezmoi.toml'
```

**Expected**: `encryption = "age"` — the top-level key is present.

```bash
ssh baelson@$VM_IP '~/bin/chezmoi doctor 2>&1 | grep -i -E "age|encrypt"'
```

**Expected**: No errors about missing encryption configuration.

### Step 8: Verify config fix #2 — sublime-settings not ignored

```bash
ssh baelson@$VM_IP 'cat ~/.local/share/chezmoi/home/.chezmoiignore | grep sublime'
```

**Expected**: Only `*.sublime-workspace` and `*.sublime-project` patterns — NOT `*.sublime-*`.

```bash
ssh baelson@$VM_IP '~/bin/chezmoi managed | grep -i sublime'
```

**Expected**: `.sublime-settings` files appear in the managed list (if any exist in the source).

### Step 9: Verify config fix #3 + #4 — brew bundle with MAS skip

```bash
# First, manually tap rcmdnk/file (workaround for tap ordering bug)
ssh baelson@$VM_IP 'brew tap rcmdnk/file'

# Run brew bundle
ssh baelson@$VM_IP 'cd ~ && brew bundle --verbose 2>&1 | tee /tmp/brew-bundle.log'
```

**Watch for**:
- **MAS skip**: Lines like `Skipping mas '...'` for all 27 MAS apps (no hang)
- **No `--no-lock` error**: `brew bundle` starts without flag errors
- **tart installs**: `Installing tart` appears in output
- **docker-desktop**: `Installing docker-desktop` (not `docker`)
- **codex as cask**: `Installing codex` as a cask (not formula)

If zoom PKG hangs (known issue), wait ~5 minutes then Ctrl+C. zoom.app will already be installed.

After brew bundle completes (or is killed after zoom):
```bash
ssh baelson@$VM_IP '
  echo "=== MAS Skip Verification ==="
  grep -c "Skipping" /tmp/brew-bundle.log && echo "MAS apps were skipped"

  echo "=== Brewfile New Packages ==="
  brew list --formula | grep -E "tart|tmuxwatch" && echo "New formulae installed"
  brew list --cask | grep -E "docker-desktop|codex|claude-code" && echo "New casks installed"
'
```

### Step 10: Full verification suite

```bash
ssh baelson@$VM_IP '
  echo "══════════════════════════════════"
  echo "  CORE DOTFILES"
  echo "══════════════════════════════════"
  for f in .zshrc .zshenv .zprofile .gitconfig .vimrc .npmrc .p10k.zsh Brewfile; do
    test -f ~/"$f" && echo "PASS: $f" || echo "FAIL: $f"
  done

  echo ""
  echo "══════════════════════════════════"
  echo "  CONFIG DIRECTORIES"
  echo "══════════════════════════════════"
  for d in .config/git .config/chezmoi .local/share/chezmoi .claude; do
    test -d ~/"$d" && echo "PASS: $d" || echo "FAIL: $d"
  done

  echo ""
  echo "══════════════════════════════════"
  echo "  CHEZMOI EXTERNALS"
  echo "══════════════════════════════════"
  test -d ~/.local/share/antigen && echo "PASS: antigen" || echo "FAIL: antigen"
  test -d ~/.local/share/oh-my-zsh && echo "PASS: oh-my-zsh" || echo "FAIL: oh-my-zsh"

  echo ""
  echo "══════════════════════════════════"
  echo "  APP SETTINGS DIRECTORIES"
  echo "══════════════════════════════════"
  test -d ~/Library/Application\ Support/Code/User && echo "PASS: VS Code" || echo "FAIL: VS Code"
  test -d ~/Library/Application\ Support/Cursor/User && echo "PASS: Cursor" || echo "FAIL: Cursor"
  test -d ~/Library/Application\ Support/Sublime\ Text/Packages/User && echo "PASS: Sublime Text" || echo "FAIL: Sublime Text"
  test -d ~/Library/Application\ Support/Sublime\ Merge/Packages/User && echo "PASS: Sublime Merge" || echo "FAIL: Sublime Merge"

  echo ""
  echo "══════════════════════════════════"
  echo "  CLI TOOLS"
  echo "══════════════════════════════════"
  for cmd in brew chezmoi git gh node uv fzf tmux nvim ffmpeg direnv mas tart; do
    command -v "$cmd" >/dev/null 2>&1 && echo "PASS: $cmd" || echo "FAIL: $cmd"
  done

  echo ""
  echo "══════════════════════════════════"
  echo "  ENCRYPTION CONFIG (fix #1)"
  echo "══════════════════════════════════"
  grep -q "^encryption" ~/.config/chezmoi/chezmoi.toml 2>/dev/null \
    && echo "PASS: encryption key present in chezmoi.toml" \
    || echo "FAIL: encryption key missing"

  echo ""
  echo "══════════════════════════════════"
  echo "  ENCRYPTED FILES (expected skip)"
  echo "══════════════════════════════════"
  test -f ~/.ssh/id_ed25519 && echo "INFO: SSH key exists (unexpected without age key)" \
    || echo "PASS: SSH key correctly not deployed (no age key)"

  echo ""
  echo "══════════════════════════════════"
  echo "  PACKAGE COUNTS"
  echo "══════════════════════════════════"
  echo "Formulae: $(brew list --formula | wc -l | tr -d " ")"
  echo "Casks: $(brew list --cask | wc -l | tr -d " ")"
  echo "Apps in /Applications: $(ls /Applications | wc -l | tr -d " ")"
'
```

### Step 11: Reset VM to pre-test state

```bash
tart stop dotfiles-macos-current 2>/dev/null || true
tart delete dotfiles-macos-current
echo "VM deleted. Checkpoint remains intact."

# Verify both VMs in expected state
tart list
```

---

## Known Issues (Expected Failures)

| Issue | Severity | What you'll see |
|-------|----------|-----------------|
| ISSUE-019: private repo bootstrap | P1 | `setup.sh` needs SCP workaround (Step 4) |
| Encrypted file abort | P1 | `chezmoi init --apply` stops at `.ssh` — use `--exclude=encrypted` |
| `brew bundle` tap ordering | P2 | `brew-file` not found — manual `brew tap rcmdnk/file` first |
| zoom PKG hang | P2 | `installer` hangs in headless VM — Ctrl+C after ~5 min |
| Sublime Text path | P2 | May deploy to legacy "Sublime Text 3" path |
| codex cask | P3 | May fail to install (unclear Homebrew status) |
| Sublime Merge empty | P3 | `Packages/User` empty until first app config change |
| iTerm2 prefs | P3 | Not managed by chezmoi (enhancement needed) |

---

## Pass/Fail Criteria

**Minimum for merge to main**:
- [ ] All 8 core dotfiles present
- [ ] All 4 config directories present
- [ ] Both chezmoi externals (antigen, oh-my-zsh) present
- [ ] `encryption = "age"` in chezmoi.toml (config fix #1)
- [ ] `.sublime-settings` not blocked by ignore pattern (config fix #2)
- [ ] `brew bundle` runs without `--no-lock` error (config fix #3)
- [ ] MAS apps skipped without hang when no iCloud login (config fix #4)
- [ ] All 12+ CLI tools available (`tart` now included)
- [ ] 48/48 unit tests pass on host: `bats tests/unit/test_vm_iac_scripts.bats`

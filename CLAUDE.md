# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**dotfiles** is a personal macOS dotfiles repository providing one-command bootstrap on a fresh machine via [chezmoi](https://www.chezmoi.io/). A thin `setup.sh` wrapper installs chezmoi, provisions the age decryption identity, then hands off to `chezmoi init` + `chezmoi apply --force`. Everything else — Xcode CLT, Homebrew, packages, app config, encrypted-file decryption — runs inside chezmoi lifecycle scripts. This is a personal reference repo, not a turnkey adoption template; read `README.md` "Forking and adapting" before reuse.

## Build & Development Commands

This is a chezmoi source dir, not a typical software project — there is no build step, no Makefile, no `package.json`, no `pyproject.toml`.

```bash
# Preview pending changes
chezmoi diff
chezmoi apply --dry-run --verbose

# Apply changes to $HOME
chezmoi apply
chezmoi apply --force

# Pull latest + apply (steady-state update)
chezmoi update

# Health check
chezmoi doctor

# Run the BATS test suite
bats tests/unit/ tests/integration/

# Bootstrap from a fresh Mac
curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/setup.sh | bash
```

## Architecture

```
dotfiles/
├── setup.sh                       # bootstrap entry point (thin wrapper)
├── README.md                      # quick start + forking guide
├── REQUIREMENTS.md                # what the repo provides + adaptation path
├── TESTING.md                     # test layers + how to run them
├── .chezmoiroot                   # points chezmoi at `home/`
├── .pre-commit-config.yaml        # shellcheck, BATS, markdownlint hooks
├── bootstrap/
│   └── key.txt.age                # passphrase-encrypted age identity (safe to publish)
├── .github/workflows/             # ci-testing, claude, claude-code-review
├── scripts/
│   ├── setup/                     # bootstrap helpers
│   ├── test/                      # test runners (run-critical-tests.sh, ...)
│   └── tools/                     # dev tooling
├── tests/                         # BATS: unit/ integration/ infrastructure/ lib/
└── home/                          # chezmoi source root (.chezmoiroot points here)
    ├── .chezmoi.toml.tmpl         # environment detection + data variables
    ├── .chezmoiexternal.toml.tmpl # oh-my-zsh / antigen / dircolors externals
    ├── .chezmoiignore
    ├── .chezmoiscripts/darwin/    # lifecycle scripts (run_once_*, run_onchange_*)
    ├── Brewfile.tmpl              # package manifest (templated)
    ├── dot_*                      # ~/.* dotfiles (zshrc, gitconfig, p10k, ...)
    ├── private_*                  # mode-0700 deploys (SSH keys, license files)
    └── empty_*                    # zero-byte file stubs (.npmrc, .netrc, ...)
```

## Code Conventions

### chezmoi source-tree naming

| Prefix/suffix | Effect | Example |
|---|---|---|
| `dot_` | Adds `.` prefix to target | `dot_zshrc` → `.zshrc` |
| `private_` | mode 0600 (files) / 0700 (dirs) | `private_dot_ssh/` → `.ssh/` |
| `encrypted_` | age-decrypted at apply time | `encrypted_private_key` |
| `executable_` | sets `+x` bit | `executable_script.sh` → `script.sh` |
| `empty_` | creates zero-byte file | `empty_dot_npmrc` |
| `.tmpl` | Go-template rendered | `Brewfile.tmpl` → `Brewfile` |
| `run_once_before_` | runs once, before main apply | `run_once_before_install-homebrew.sh` |
| `run_onchange_after_` | re-runs when content hash changes | `run_onchange_after_install-packages.sh.tmpl` |

### Shell scripts

- `#!/bin/bash` (portable, runs on macOS default `/bin/bash` 3.2.57).
- `set -euo pipefail` at the top of every script.
- `command rm`/`command cp`/`command mv` to bypass zsh's `-i` aliases.
- Variables wrapped in braces: `"${VAR}"` not `"$VAR"`.
- `$HOME` not `~` in paths.

### Commit messages

Conventional commits — `feat(scope):`, `fix(scope):`, `docs(scope):`, `chore(scope):`.

## Detected Patterns

- **Native dry-run delegation** — verification leans on `chezmoi apply --dry-run --verbose` rather than a custom diff harness.
- **Dual-path age provisioning** — Keychain fast path (`dotfiles-age:$USER`, no prompt) with a passphrase-fallback decrypt of `bootstrap/key.txt.age` (safe to publish; security is in the passphrase). Both absent → encrypted files stay as non-fatal stubs.
- **run-onchange content-hash trigger** — `run_onchange_after_*` lifecycle scripts re-run only when their rendered content hash changes (package installs, macOS defaults, shell env).
- **ShellCheck for chezmoi templates** — `.pre-commit-config.yaml` runs `shellcheck` on scripts plus a templates-aware variant on `.tmpl` script sources.
- **iTerm2 shell integration** — installed automatically by a lifecycle script; iTerm2 prefs managed via `LoadPrefsFromCustomFolder`.

## Best Practices

- Read `README.md`, `REQUIREMENTS.md`, and `TESTING.md` before significant work — they capture the adaptation path and test layers.
- Verify with evidence — `chezmoi status`, `chezmoi apply --dry-run`, BATS output — not assertions.
- Never delete git branches without explicit request. Trunk-based with short-lived `feat/*`, `fix/*`, `docs/*`, `chore/*` branches; `--no-ff` merges to `main`.
- The pre-commit `run-critical-tests` hook runs the full BATS suite (`tests/unit/` + `tests/integration/`); suite is currently clean. If a documented pre-existing failure trips it, bypass the *named* hook only (`SKIP=run-critical-tests git commit ...`) — never a blanket `--no-verify`.
- New `.bats` files with shebangs require `chmod +x` AND `git add --chmod=+x` — a plain `chmod` alone won't update git's index mode on an untracked file, and the `check-shebang-scripts-are-executable` pre-commit hook will reject the commit.
- This is a personal repo. Don't generalize package picks or encrypted files for reuse; the architecture is the shareable part (see `README.md` "Forking and adapting").

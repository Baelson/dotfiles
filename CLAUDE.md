# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**dotfiles** is a personal macOS dotfiles repository providing one-command bootstrap on a fresh machine via [chezmoi](https://www.chezmoi.io/). A thin `setup.sh` wrapper installs chezmoi, provisions the age decryption identity, then hands off to `chezmoi init` + `chezmoi apply --force`. Everything else — Xcode CLT, Homebrew, packages, app config, encrypted-file decryption — runs inside chezmoi lifecycle scripts. This is a personal reference repo, not a turnkey adoption template; read `README.md` "Forking and adapting" before reuse.

> **Published derivative.** This repository is generated from a private working tree by a scrub pipeline. It lags the author's live config and ships a **published sample** age identity (`bootstrap/sample-key.txt.age`, passphrase `change-me-on-first-run`) plus **sample** encrypted files, so a fork can `chezmoi apply` to a coherent state without any real secret. Rotate the sample identity before storing anything real (`README.md` → "Forking and adapting").

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
├── .chezmoiroot                   # points chezmoi at `home/`
├── bootstrap/
│   └── sample-key.txt.age         # published throwaway sample age identity
├── .github/workflows/
│   └── leak-check.yml             # post-publish secret/artifact scan (gitleaks + absent-artifact)
├── tests/                         # BATS: unit/ integration/
└── home/                          # chezmoi source root (.chezmoiroot points here)
    ├── .chezmoi.toml.tmpl         # environment detection + data variables
    ├── .chezmoiexternal.toml.tmpl # oh-my-zsh / antigen / dircolors externals
    ├── .chezmoiignore
    ├── .chezmoiscripts/darwin/    # lifecycle scripts (run_once_*, run_onchange_*)
    │   ├── run_once_before_provision-age-key.sh   # age key: sample-identity fallback (prompts passphrase)
    │   └── run_once_before_warn-existing-ssh.sh   # create_ ~/.ssh heads-up (won't overwrite existing files)
    ├── Brewfile.tmpl              # package manifest (templated)
    ├── dot_*                      # ~/.* dotfiles (zshrc, gitconfig, p10k, ...)
    ├── private_dot_ssh/           # ~/.ssh (create_-managed; SAMPLE encrypted blobs)
    └── empty_*                    # zero-byte file stubs (.npmrc, .netrc, ...)
```

## Code Conventions

### chezmoi source-tree naming

| Prefix/suffix | Effect | Example |
|---|---|---|
| `dot_` | Adds `.` prefix to target | `dot_zshrc` → `.zshrc` |
| `private_` | mode 0600 (files) / 0700 (dirs) | `private_dot_ssh/` → `.ssh/` |
| `encrypted_` | age-decrypted at apply time | `encrypted_private_key` |
| `create_` | create-if-absent; never overwrites an existing target | `create_encrypted_private_id_ed25519.age` |
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

- **Sample-identity age provisioning** — a Keychain fast path (`dotfiles-age:$USER`, no prompt) with a passphrase-fallback decrypt of `bootstrap/sample-key.txt.age` (a **published throwaway** identity, passphrase `change-me-on-first-run`; both passphrase and key are public). Both absent → encrypted files stay as non-fatal stubs. Rotate the sample identity before any real use.
- **`create_ ~/.ssh` (create-if-absent)** — every `~/.ssh` file is managed with chezmoi's `create_` attribute, so `chezmoi apply` never overwrites an existing `~/.ssh` file (real keys are safe; a sample `authorized_keys` can't lock you out). `run_once_before_warn-existing-ssh.sh` announces any skip.
- **Two-pass apply** — when the Keychain fast-path is absent, `setup.sh` runs `chezmoi init → apply` (first pass, triggers lifecycle scripts including the age-key provision), then if `key.txt` was provisioned, re-runs `chezmoi init` (picks up the `[age]` config) + `apply --force` (second pass, decrypts encrypted files).
- **run-onchange content-hash trigger** — `run_onchange_after_*` lifecycle scripts re-run only when their rendered content hash changes (package installs, macOS defaults, shell env).
- **iTerm2 shell integration** — installed automatically by a lifecycle script.

## Best Practices

- Read `README.md` before significant work — it captures the forking/adaptation path.
- Verify with evidence — `chezmoi status`, `chezmoi apply --dry-run`, BATS output — not assertions.
- Never delete git branches without explicit request. Trunk-based with short-lived `feat/*`, `fix/*`, `docs/*`, `chore/*` branches; `--no-ff` merges to `main`.
- This is a personal repo. Don't generalize package picks or encrypted files for reuse; the architecture is the shareable part (see `README.md` "Forking and adapting").

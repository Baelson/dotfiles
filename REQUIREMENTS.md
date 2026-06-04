# Requirements

What this dotfiles repo provides, what it doesn't, and what shape the
"adapt for my machine" path looks like.

## What this repo gives you

A single `setup.sh` at the repo root that, when run on a fresh macOS
machine, brings up a fully-configured development environment in one
shot:

- **Packages** — 70+ Homebrew formulae and casks (CLI tools, terminal
  apps, GUI apps, fonts) declared in `home/Brewfile.tmpl`. The template
  drops or adds entries based on environment flags (`headless`,
  `personal`/`work`, `mas` opt-in for Mac App Store apps).
- **Shell** — zsh + oh-my-zsh + antigen + Powerlevel10k, with prompt
  config, aliases, and custom functions. iTerm2 shell integration
  installed automatically. fzf key bindings.
- **Terminal apps** — iTerm2 (full plist managed via
  `LoadPrefsFromCustomFolder`) + Terminal.app (profile imported from a
  generated `.terminal` file). tmux config with extended keys and
  Nord-themed status line.
- **Editors / IDE** — Neovim, Sublime Text + Sublime Merge, VS Code +
  Cursor, with VS Code extensions installed via the Brewfile when
  `is_primary` matches.
- **macOS defaults** — Dock, Finder, Mission Control, Accessibility,
  Safari, Mail, etc. set by `run_onchange_after_configure-macos-defaults.sh.tmpl`.
- **LaunchAgents** — generic plist-reload mechanism (auto-discovers any
  managed plists at runtime).
- **Encrypted secrets** — SSH keys, app license files, etc. age-encrypted
  in the source tree, decrypted at apply time using the user's age
  identity.

The bootstrap is **idempotent**: re-running it picks up changes and
reconciles drift instead of starting over.

## How it works (one-paragraph version)

`setup.sh` curl-installs `chezmoi` to `~/.local/bin`, stages the user's
age identity from the macOS Keychain (`dotfiles-age:$USER`) to
`~/.config/chezmoi/key.txt`, then runs `chezmoi init --apply` against
this repo. chezmoi's lifecycle scripts handle everything else:
non-interactive Homebrew install (which silently installs Xcode CLT
via `softwareupdate`), package install via `brew bundle`, macOS defaults,
shell environment setup, app configuration. Steady-state updates run via
`chezmoi update`.

## What you bring (one-time, per machine)

- macOS 12+ with admin privileges and an internet connection.
- An age identity (`age-keygen -o ~/.config/chezmoi/key.txt`) staged
  into the macOS Keychain. iCloud Keychain sync makes this a one-time
  setup across all your Macs. Without it, encrypted files (your SSH
  keys, license files) won't decrypt — bootstrap warns and continues;
  you stage the key later and re-apply.

The full prereq command + verification steps used to live in a separate
`PROJECT_INIT.md`; for a fork user the only meaningful one is:

```bash
security add-generic-password -s dotfiles-age -a "$USER" \
    -w "$(awk '/^AGE-SECRET-KEY/{print; exit}' ~/.config/chezmoi/key.txt)" -U
```

(See README's "Forking and adapting" section for the rest.)

## What this repo doesn't give you

- A turnkey adoption path. This is a **personal** dotfiles repo with
  one user's preferences hardcoded. Forking and adapting (changing the
  hostname detected as primary, swapping Brewfile entries, replacing
  encrypted-file recipients, removing personal LaunchAgents) is
  expected.
- A multi-user / team configuration management system. For that, look
  at chezmoi templates with a shared source repo + per-user data file
  pattern, not this layout.
- Cross-platform (Linux, Windows). macOS only. The lifecycle scripts
  live under `home/.chezmoiscripts/darwin/` and assume Homebrew, BSD
  userland, AppKit-based defaults, etc.

## Environment shape

chezmoi data variables (see `home/.chezmoi.toml.tmpl`):

| Variable | Default | Meaning |
|---|---|---|
| `personal` | `true` | Personal vs work machine |
| `work` | `false` | Auto-detected by hostname (`work-laptop`, `*corp*`) |
| `headless` | prompted | CLI-only environment (drops GUI casks, fonts, app config) |
| `ephemeral` | prompted | Disposable container/CI/VM (drops persistent packages) |
| `mas` | `false` | Mac App Store apps opt-in (env: `CHEZMOI_MAS=true`) |
| `is_primary` | hostname == `your-primary-host` | Primary-Mac gate for additional apps and configs (fork users change the hostname literal in `home/.chezmoi.toml.tmpl`) |
| `skip_flaky_casks` | `false` | Omit casks with unreliable installers in headless VMs (env: `CHEZMOI_SKIP_FLAKY_CASKS=true`) |

## Where to look next

- `setup.sh` — the bootstrap entry point.
- `home/Brewfile.tmpl` — the package manifest, gated by environment vars.
- `home/.chezmoi.toml.tmpl` — environment detection logic.
- `home/.chezmoiscripts/darwin/` — lifecycle scripts (install order:
  homebrew → packages → macOS defaults → shell env → app setup → plist
  reload).
- `TESTING.md` — what's tested and how to run it.
- `README.md` — quick-start.

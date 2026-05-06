# dotfiles

Personal macOS dotfiles. One-command bootstrap on a fresh machine via
[chezmoi](https://www.chezmoi.io/). Brewfile, shell, terminal apps, macOS
defaults, encrypted secrets — all reproducible.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/setup.sh | bash
```

`setup.sh` is a thin wrapper: installs `chezmoi` to `~/.local/bin`, stages
the age decryption identity from the macOS Keychain (if present, see
[Forking and adapting](#forking-and-adapting) below), then hands off to
`chezmoi init` + `chezmoi apply --force`. Everything else (Xcode CLT,
Homebrew, packages, app config, encrypted-file decryption) runs inside
chezmoi lifecycle scripts.

Requirements: macOS 12+, admin privileges, internet. Absent age key is
non-fatal — encrypted files stay as stubs and you can stage the key
later.

## Forking and adapting

This is a personal dotfiles repo, not a turnkey adoption template. Most
fork users will want to:

1. **Generate your own age identity** and stage it into the macOS
   Keychain so chezmoi can decrypt the encrypted files (or replace the
   encrypted files with your own):
   ```bash
   age-keygen -o ~/.config/chezmoi/key.txt
   chmod 600 ~/.config/chezmoi/key.txt

   # Stage the single-line AGE-SECRET-KEY-1... value (multi-line round-trips as hex)
   security add-generic-password -s dotfiles-age -a "$USER" \
       -w "$(awk '/^AGE-SECRET-KEY/{print; exit}' ~/.config/chezmoi/key.txt)" -U
   ```
   iCloud Keychain syncs the entry across signed-in Macs, so subsequent
   machines need no manual step.

2. **Replace the personal encrypted files** under
   `home/private_dot_ssh/`, `home/private_Library/private_Application Support/{Many Tricks,Beyond Compare}/` —
   those are encrypted to the original repo owner's age recipient; they
   won't decrypt with your key. You'll want to either remove them or
   re-encrypt your own equivalents with `chezmoi add --encrypt`.

3. **Change the primary-Mac hostname literal** in
   `home/.chezmoi.toml.tmpl` (`{{- if eq $hostname "Kurama" -}}`) to
   match your own primary Mac's hostname, or remove the gating entirely
   if you don't need it.

4. **Audit the `home/Brewfile.tmpl`** — it has a lot of opinionated
   personal-preference apps (font choice, GUI tools, MAS opt-ins).

## Layout

```
setup.sh                  Bootstrap entry point
home/                     Chezmoi source dir (deploys to ~/)
  Brewfile.tmpl           Package manifest (templated)
  .chezmoi.toml.tmpl      Environment detection + data variables
  .chezmoiscripts/darwin/ Lifecycle scripts (Homebrew, packages, defaults, ...)
  .chezmoiexternal.toml.tmpl   oh-my-zsh / antigen / dircolors externals
  dot_*                   ~/.* dotfiles (zshrc, gitconfig, tmux, ...)
  private_*               Mode-0700 deploys (SSH keys, license files)
  encrypted_*             Age-encrypted files
scripts/                  Test runners + dev tooling
tests/                    BATS test suites + verify-manifest
```

## Documentation

- **[REQUIREMENTS.md](REQUIREMENTS.md)** — what the repo provides + how to
  adapt it.
- **[TESTING.md](TESTING.md)** — test layers + how to run them.

## Stack

chezmoi · Homebrew · zsh + oh-my-zsh + antigen + Powerlevel10k · iTerm2 ·
tmux · age (encryption) · BATS (tests).

## License

Personal. Architecture and patterns are shared as a reference; specific
package picks, encrypted files, and personal preferences are not
intended for direct reuse.

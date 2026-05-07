# dotfiles

Personal macOS dotfiles. One-command bootstrap on a fresh machine via
[chezmoi](https://www.chezmoi.io/). Brewfile, shell, terminal apps, macOS
defaults, encrypted secrets — all reproducible.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/setup.sh | bash
```

`setup.sh` is a thin wrapper: installs `chezmoi` to `~/.local/bin`,
provisions the age decryption identity, then hands off to `chezmoi
init` + `chezmoi apply --force`. Everything else (Xcode CLT, Homebrew,
packages, app config, encrypted-file decryption) runs inside chezmoi
lifecycle scripts.

**Age key provisioning** has two paths, in priority order:

1. **Keychain fast path** (no prompt). If a `dotfiles-age:$USER` entry
   exists in the macOS login Keychain, it's staged to
   `~/.config/chezmoi/key.txt` before `chezmoi init`. Useful on a
   primary machine where you've already run the one-time
   `security add-generic-password` step. Note: the login Keychain is
   **not** iCloud-synced, so this isn't automatic across new Macs.
2. **Passphrase fallback** (one prompt). If no Keychain entry, the
   bootstrap decrypts `bootstrap/key.txt.age` (an age-passphrase-encrypted
   copy of the key, safe to publish — security comes from the
   passphrase) using a passphrase read from `/dev/tty`. Setup re-runs
   `chezmoi init` + `chezmoi apply --force` after the fallback decrypt
   so the `[age]` block lands in the regenerated config.

Both absent → encrypted files stay as stubs (non-fatal); stage either
later and re-run `chezmoi apply --force`.

Requirements: macOS 12+, admin privileges, internet.

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

# dotfiles

Personal macOS dotfiles. One-command bootstrap on a fresh machine via
[chezmoi](https://www.chezmoi.io/). Brewfile, shell, terminal apps, macOS
defaults, encrypted secrets — all reproducible.

> **This repo is a published derivative.** It is generated from a private
> working tree by a scrub pipeline, so it lags the author's live config and ships
> a **sample** age identity in place of real secrets (see below). The
> architecture and patterns are the shareable part; the specific package picks
> and encrypted files are not meant for direct reuse.

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
2. **Sample-identity fallback** (one prompt). If no Keychain entry, the
   bootstrap decrypts `bootstrap/sample-key.txt.age` — a **published throwaway
   SAMPLE identity** whose passphrase (`change-me-on-first-run`) and private key
   are both public. You type the sample passphrase at the prompt; it decrypts the
   **sample** encrypted files so `chezmoi apply` converges. Setup re-runs
   `chezmoi init` + `chezmoi apply --force` after the fallback decrypt so the
   `[age]` block lands in the regenerated config.

Both absent → encrypted files stay as stubs (non-fatal); stage either
later and re-run `chezmoi apply --force`.

> ⚠️ **The sample identity is PUBLIC — rotate before any real use.** The sample
> age key and the `~/.ssh/*` keys it deploys are throwaways anyone can decrypt.
> Generate your own identity + keys and re-encrypt before storing a real secret
> (see "Forking and adapting").

Requirements: macOS 12+, admin privileges, internet.

## `create_ ~/.ssh` — chezmoi never overwrites your existing SSH files

All `~/.ssh` material is managed with chezmoi's `create_` attribute
(create-if-absent): chezmoi writes the managed/SAMPLE version of a file **only if
the target is absent**, and **never overwrites an existing one**. So on a machine
that already has real `~/.ssh` keys, `chezmoi apply` leaves them untouched (and a
`run_once_before` script prints which files it's skipping). A fresh machine gets
the sample keys created. To adopt the repo's version of a file that already
exists, delete the local one yourself and re-run `chezmoi apply`.

## Forking and adapting

This is a personal dotfiles repo, not a turnkey adoption template. Most
fork users will want to:

1. **Generate your own age identity** (replacing the published sample) and stage
   it into the macOS Keychain so chezmoi can decrypt the encrypted files (or
   replace the encrypted files with your own):
   ```bash
   age-keygen -o ~/.config/chezmoi/key.txt
   chmod 600 ~/.config/chezmoi/key.txt

   # Stage the single-line secret-key value (it starts with AGE-SECRET-KEY;
   # a multi-line value round-trips through the Keychain as hex, so take one line)
   security add-generic-password -s dotfiles-age -a "$USER" \
       -w "$(awk '/^AGE-SECRET-KEY/{print; exit}' ~/.config/chezmoi/key.txt)" -U
   ```
   iCloud Keychain syncs the entry across signed-in Macs, so subsequent
   machines need no manual step.

2. **Replace the sample encrypted files** under `home/private_dot_ssh/`. As
   shipped they are **sample** SSH keys encrypted to the published sample
   recipient — fine for a demo run, never for real use. Thanks to `create_`
   (above), they won't clobber your real `~/.ssh`. Generate your own and
   re-encrypt them to your recipient with `chezmoi add --encrypt`, or remove them.

3. **Primary-Mac gating is stripped from this published derivative**
   (`is_primary` defaults to `false`, so you get the standard app set). If you
   want host-specific gating, add an `$is_primary` hostname-detection block to
   `home/.chezmoi.toml.tmpl` matching your own primary Mac's hostname.

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
  private_*               Mode-0700 deploys (SSH keys, ...)
  *encrypted_*.age        Age-encrypted files (SAMPLE blobs in this derivative)
bootstrap/
  sample-key.txt.age      Published throwaway sample age identity
scripts/                  Test runners + dev tooling
tests/                    BATS test suites + verify-manifest
```

## Stack

chezmoi · Homebrew · zsh + oh-my-zsh + antigen + Powerlevel10k · iTerm2 ·
tmux · age (encryption) · BATS (tests).

## License

Personal. Architecture and patterns are shared as a reference; specific
package picks, encrypted files, and personal preferences are not
intended for direct reuse.

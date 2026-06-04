#!/bin/bash
#
# setup.sh — Thin-wrapper bootstrap for a fresh macOS machine.
#
# Installs chezmoi to PATH, provisions the age decryption identity (Keychain
# fast path or passphrase-encrypted-in-repo fallback), then hands off to
# `chezmoi init` + `chezmoi apply --force`. Everything else (Homebrew, Xcode
# CLT, age binary, packages, app config, encrypted-file decryption) runs
# inside chezmoi lifecycle scripts and templates.
#
# Repo is public — no PAT needed; clone is unauthenticated HTTPS.
#
# Usage (from a fresh macOS shell, local or SSH):
#   curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/setup.sh | bash
#
# Age key provisioning — TWO paths, in priority order:
#
#   1. Keychain fast path (no prompt). If `dotfiles-age:$USER` exists in the
#      macOS login Keychain, setup.sh stages it to ~/.config/chezmoi/key.txt
#      BEFORE `chezmoi init`. The .chezmoi.toml.tmpl stat-guard renders the
#      [age] block on the first init, so a single apply decrypts everything.
#      NOTE: the login Keychain is NOT iCloud-synced; this fast path requires
#      a one-time `security add-generic-password` per machine.
#
#   2. Passphrase fallback (one prompt). If no Keychain entry was used, the
#      `run_once_before_provision-age-key.sh` lifecycle script (running after
#      Homebrew + age install) decrypts `bootstrap/key.txt.age` from the
#      cloned source dir using a passphrase read from /dev/tty. setup.sh
#      then re-runs `chezmoi init` + `chezmoi apply --force` to pick up
#      the [age] block and decrypt files.
#
# Absent both → encrypted files stay as stubs after apply (non-fatal).
# Operator can stage either later and re-run `chezmoi apply --force`.
#
# Optional env override:
#   DOTFILES_BRANCH=<branch>   # clone a non-default branch (VM E2E for in-flight changes)

set -euo pipefail

readonly REPO_OWNER="Baelson"
readonly REPO_NAME="dotfiles"
readonly REPO_HTTPS_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
readonly REPO_SSH_URL="git@github.com:${REPO_OWNER}/${REPO_NAME}.git"
readonly AGE_KEYCHAIN_SERVICE="dotfiles-age"

DOTFILES_BRANCH="${DOTFILES_BRANCH:-}"

log_step() { echo "==> $*"; }
log_warn() { echo "WARNING: $*" >&2; }
log_err()  { echo "ERROR: $*"   >&2; }

# -----------------------------------------------------------------------------
# Guard rails
# -----------------------------------------------------------------------------

if [[ "${OSTYPE}" != darwin* ]]; then
    log_err "This bootstrap is macOS-only (OSTYPE=${OSTYPE})."
    exit 1
fi

readonly ACCOUNT="${USER:-$(id -un)}"
: "${ACCOUNT:?Unable to resolve current username}"

# -----------------------------------------------------------------------------
# Step 1: Install chezmoi to ~/.local/bin if missing.
#
# `</dev/null` is load-bearing: under `curl ... | bash`, bash's stdin IS the
# pipe from curl. Any subprocess that reads FD 0 eats the rest of the script.
# Every external tool below redirects stdin from /dev/null.
# -----------------------------------------------------------------------------

if command -v chezmoi >/dev/null 2>&1; then
    log_step "chezmoi already installed ($(command -v chezmoi))"
else
    log_step "Installing chezmoi to ${HOME}/.local/bin via get.chezmoi.io"
    mkdir -p "${HOME}/.local/bin"
    sh -c "$(curl -fsSL https://get.chezmoi.io)" -- -b "${HOME}/.local/bin" </dev/null
    export PATH="${HOME}/.local/bin:${PATH}"
fi

# -----------------------------------------------------------------------------
# Step 2: Stage age identity from Keychain (fast path).
# -----------------------------------------------------------------------------

readonly AGE_KEY_DIR="${HOME}/.config/chezmoi"
readonly AGE_KEY_FILE="${AGE_KEY_DIR}/key.txt"
KEY_PRESTAGED=0

if [[ -f "${AGE_KEY_FILE}" ]]; then
    log_step "Age key already present at ${AGE_KEY_FILE}"
    KEY_PRESTAGED=1
elif security find-generic-password -s "${AGE_KEYCHAIN_SERVICE}" -a "${ACCOUNT}" >/dev/null 2>&1; then
    log_step "Staging age identity from Keychain (service=${AGE_KEYCHAIN_SERVICE}, account=${ACCOUNT})"
    mkdir -p "${AGE_KEY_DIR}"
    umask 077
    security find-generic-password -s "${AGE_KEYCHAIN_SERVICE}" -a "${ACCOUNT}" -w > "${AGE_KEY_FILE}"
    chmod 600 "${AGE_KEY_FILE}"

    # macOS `security ... -w` outputs HEX (one long line of 0-9a-f) when the
    # stored value isn't valid single-line UTF-8 — embedded newlines trigger
    # this. If the operator staged with the full multi-line key.txt
    # (`-w "$(cat key.txt)"`), retrieval gives back unparseable hex. Detect
    # the breakage with an actionable error rather than letting `chezmoi
    # apply` fail with cryptic "unknown identity type" at decrypt time.
    if ! grep -q '^AGE-SECRET-KEY-' "${AGE_KEY_FILE}"; then
        log_err "Staged ~/.config/chezmoi/key.txt does not contain an AGE-SECRET-KEY-1... line."
        log_err "The Keychain entry probably stored a multi-line value that round-trips as hex."
        log_err "Re-stage with just the secret key (single line):"
        log_err "  KEY=\$(awk '/^AGE-SECRET-KEY/{print; exit}' ~/.config/chezmoi/key.txt)"
        log_err "  security add-generic-password -s ${AGE_KEYCHAIN_SERVICE} -a \"\$USER\" -w \"\$KEY\" -U"
        exit 1
    fi
    KEY_PRESTAGED=1
else
    log_step "No Keychain entry ${AGE_KEYCHAIN_SERVICE}:${ACCOUNT} — will fall back to passphrase prompt during apply (if bootstrap/key.txt.age is present)"
fi

# -----------------------------------------------------------------------------
# Step 3: chezmoi init — unauthenticated HTTPS clone (repo is public).
#
# `--use-builtin-git=on` sidesteps the xcode-select git stub on bare macOS
# (/usr/bin/git hangs over SSH trying to pop the CLT-install GUI dialog).
# chezmoi's embedded go-git ignores ~/.netrc and credential helpers — fine
# for a public repo.
# -----------------------------------------------------------------------------

if [[ -n "${DOTFILES_BRANCH}" ]]; then
    log_step "chezmoi init --use-builtin-git=on --branch ${DOTFILES_BRANCH} ${REPO_HTTPS_URL}"
    chezmoi init --use-builtin-git=on --branch "${DOTFILES_BRANCH}" "${REPO_HTTPS_URL}" </dev/null
else
    log_step "chezmoi init --use-builtin-git=on ${REPO_HTTPS_URL}"
    chezmoi init --use-builtin-git=on "${REPO_HTTPS_URL}" </dev/null
fi

# -----------------------------------------------------------------------------
# Step 4: chezmoi apply --force (first pass).
#
# Installs Homebrew + age via run_once_before_install-homebrew.sh, then
# (if KEY_PRESTAGED=0) the run_once_before_provision-age-key.sh lifecycle
# script prompts for the passphrase and decrypts bootstrap/key.txt.age.
#
# Encrypted files in this same apply pass stay as stubs because chezmoi
# loaded its config (with no [age] block) at init time. Step 5 re-applies
# if a fallback decryption happened.
#
# Lifecycle failures (e.g. flaky cask downloads) are noted but do NOT
# short-circuit Step 5 / Step 6. The apply exit code is propagated at end.
# -----------------------------------------------------------------------------

log_step "chezmoi apply --force (first pass)"
APPLY_EXIT=0
chezmoi apply --force </dev/null || APPLY_EXIT=$?
if [[ "${APPLY_EXIT}" -ne 0 ]]; then
    log_warn "chezmoi apply exited ${APPLY_EXIT}. Continuing; will surface at end."
fi

# -----------------------------------------------------------------------------
# Step 5: If passphrase fallback decrypted the key during the first apply,
# re-init + re-apply so the regenerated config emits the [age] block and
# the encrypted files actually decrypt.
# -----------------------------------------------------------------------------

if [[ "${KEY_PRESTAGED}" -eq 0 ]] && [[ -f "${AGE_KEY_FILE}" ]]; then
    log_step "Passphrase fallback provisioned key — re-running chezmoi init + apply"
    chezmoi init </dev/null
    # Second pass is authoritative: the first pass was expected to fail on
    # `.age:` files because chezmoi loaded its config (no [age] block) at
    # init time. Reset APPLY_EXIT so the final-check below reflects the
    # actual end state, not the stale first-pass exit code.
    APPLY_EXIT=0
    chezmoi apply --force </dev/null || APPLY_EXIT=$?
    if [[ "${APPLY_EXIT}" -ne 0 ]]; then
        log_warn "chezmoi apply (second pass) exited ${APPLY_EXIT}. Continuing; will surface at end."
    fi
fi

# -----------------------------------------------------------------------------
# Step 6: Flip source-dir remote to SSH.
#
# Ergonomic only (no credentials in the clone URL): steady-state
# `chezmoi update` uses ssh-agent rather than re-prompting for HTTPS creds.
# -----------------------------------------------------------------------------

SRC="$(chezmoi source-path)"
# chezmoi source-path returns the source dir; the git checkout is one level
# up when .chezmoiroot is present. Check both.
GIT_DIR=""
if [[ -d "${SRC}/.git" ]]; then
    GIT_DIR="${SRC}"
elif [[ -d "${SRC}/../.git" ]]; then
    GIT_DIR="$(cd "${SRC}/.." && pwd)"
fi
if [[ -n "${GIT_DIR}" ]]; then
    CURRENT_ORIGIN="$(git -C "${GIT_DIR}" remote get-url origin 2>/dev/null || true)"
    case "${CURRENT_ORIGIN}" in
        "https://github.com/${REPO_OWNER}/${REPO_NAME}.git" \
        | "git@github.com:${REPO_OWNER}/${REPO_NAME}.git" \
        | "https://github.com/${REPO_OWNER}/${REPO_NAME}" )
            log_step "Flipping source-dir remote to SSH (${REPO_SSH_URL})"
            git -C "${GIT_DIR}" remote set-url origin "${REPO_SSH_URL}"
            ;;
        *)
            log_warn "Source-dir origin is '${CURRENT_ORIGIN:-<unset>}', not the public ${REPO_OWNER}/${REPO_NAME} repo — SKIPPING remote-flip (refusing to repoint a non-public remote; wrong-remote privacy guard)."
            ;;
    esac
else
    log_warn "chezmoi source-path (${SRC}) is not inside a git checkout — skipping remote flip"
fi

# Surface apply failure now that the remote flip is done.
if [[ "${APPLY_EXIT}" -ne 0 ]]; then
    log_err "chezmoi apply failed (exit ${APPLY_EXIT}). Bootstrap partially succeeded."
    log_err "Fix the cause and re-run: chezmoi apply --force"
    exit "${APPLY_EXIT}"
fi

cat <<'EOF'

Bootstrap complete.

Next steps:
  - Open a new shell (or `exec zsh -l`) so PATH updates take effect.
  - Run `chezmoi diff` to review drift; `chezmoi apply` to reconcile.
  - Run `chezmoi update` for steady-state sync (uses SSH + ssh-agent).
EOF

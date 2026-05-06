#!/bin/bash
#
# setup.sh — Thin-wrapper bootstrap for a fresh macOS machine.
#
# Installs chezmoi to PATH, stages the age identity from the macOS Keychain,
# then hands off to `chezmoi init` + `chezmoi apply --force`. Everything else
# (Homebrew, Xcode CLT, age binary, packages, encrypted-file decryption, app
# config) runs inside chezmoi lifecycle scripts and templates.
#
# Repo is public — no PAT needed; clone is unauthenticated HTTPS.
#
# Usage (from a fresh macOS shell, local or SSH):
#   curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/setup.sh | bash
#
# Precondition (one-time per machine; fork users replace with their own key):
#   security add-generic-password -s dotfiles-age -a "$USER" \
#       -w "$(awk '/^AGE-SECRET-KEY/{print; exit}' ~/.config/chezmoi/key.txt)" -U
#
# Absent age key is non-fatal: encrypted files stay as stubs after apply,
# operator can stage later and re-run `chezmoi apply --force`.
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
# Step 2: Stage the age identity from the macOS Keychain.
#
# Staged BEFORE `chezmoi init` so .chezmoi.toml.tmpl's stat-gated [age] block
# renders on the first (and only) init. Absence is non-fatal — encrypted files
# stay as stubs, operator can stage later and re-run `chezmoi apply --force`.
# -----------------------------------------------------------------------------

AGE_KEY_DIR="${HOME}/.config/chezmoi"
AGE_KEY_FILE="${AGE_KEY_DIR}/key.txt"

if [[ -f "${AGE_KEY_FILE}" ]]; then
    log_step "Age key already present at ${AGE_KEY_FILE}"
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
else
    log_warn "No Keychain entry ${AGE_KEYCHAIN_SERVICE}:${ACCOUNT} — encrypted files will not decrypt."
    log_warn "Stage with: KEY=\$(awk '/^AGE-SECRET-KEY/{print; exit}' ~/.config/chezmoi/key.txt) && \\"
    log_warn "  security add-generic-password -s ${AGE_KEYCHAIN_SERVICE} -a ${ACCOUNT} -w \"\$KEY\" -U"
fi

# -----------------------------------------------------------------------------
# Step 3: chezmoi init — unauthenticated HTTPS clone (repo is public).
#
# `--use-builtin-git=on` sidesteps the xcode-select git stub on bare macOS
# (/usr/bin/git hangs over SSH trying to pop the CLT-install GUI dialog).
# chezmoi's embedded go-git ignores ~/.netrc and credential helpers — fine
# for our case since the public repo needs no auth at all.
# -----------------------------------------------------------------------------

if [[ -n "${DOTFILES_BRANCH}" ]]; then
    log_step "chezmoi init --use-builtin-git=on --branch ${DOTFILES_BRANCH} ${REPO_HTTPS_URL}"
    chezmoi init --use-builtin-git=on --branch "${DOTFILES_BRANCH}" "${REPO_HTTPS_URL}" </dev/null
else
    log_step "chezmoi init --use-builtin-git=on ${REPO_HTTPS_URL}"
    chezmoi init --use-builtin-git=on "${REPO_HTTPS_URL}" </dev/null
fi

# -----------------------------------------------------------------------------
# Step 4: chezmoi apply --force.
#
# Lifecycle failures (e.g. flaky cask downloads) are noted but do NOT
# short-circuit Step 5's remote-flip. The apply exit code is propagated at
# the very end.
# -----------------------------------------------------------------------------

log_step "chezmoi apply --force"
APPLY_EXIT=0
chezmoi apply --force </dev/null || APPLY_EXIT=$?
if [[ "${APPLY_EXIT}" -ne 0 ]]; then
    log_warn "chezmoi apply exited ${APPLY_EXIT}. Continuing to remote-flip; investigate after bootstrap."
fi

# -----------------------------------------------------------------------------
# Step 5: Flip source-dir remote to SSH.
#
# Ergonomic-only now that the clone URL contains no credentials: steady-state
# `chezmoi update` uses ssh-agent rather than re-prompting for HTTPS credentials.
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
    log_step "Flipping source-dir remote to SSH (${REPO_SSH_URL})"
    git -C "${GIT_DIR}" remote set-url origin "${REPO_SSH_URL}"
else
    log_warn "chezmoi source-path (${SRC}) is not inside a git checkout — skipping remote flip"
fi

# Surface the apply failure now that the remote flip is done.
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

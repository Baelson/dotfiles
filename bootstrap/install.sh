#!/bin/bash
#
# bootstrap/install.sh — Canonical one-shot bootstrap for a fresh macOS machine.
#
# Resolves ISSUE-019: on a truly bare macOS install (no Xcode CLT), /usr/bin/git
# is a stub that triggers the xcode-select GUI dialog, hanging over SSH. We
# sidestep that entirely by letting Homebrew's NONINTERACTIVE=1 installer handle
# CLT via softwareupdate, then using real git for a chezmoi HTTPS clone
# authenticated by a short-lived ~/.netrc sourced from the Keychain PAT.
#
# Usage (from a fresh macOS shell, local or SSH):
#   curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/bootstrap/install.sh | bash
#
# Precondition (one-time, human):
#   security add-generic-password -s github-pat -a "$USER" -w '<PAT>' -U
#   (PAT scope: `repo` classic, or fine-grained read/write on Baelson/dotfiles.)
#
# Optional env vars (passed through to chezmoi templates):
#   EPHEMERAL=1   — minimal install for temporary/borrowed machines
#   HEADLESS=1    — no desktop apps (servers, SSH-only systems)
#
# After success:
#   - ~/.netrc is scrubbed (trap-guaranteed even on failure)
#   - Chezmoi source-dir remote is flipped HTTPS → SSH, so steady-state
#     `chezmoi update` uses SSH + ssh-agent (no netrc required)
#
# See docs/plans/2026-04-20-issue-019-bootstrap-reconciliation.md for the design.

set -euo pipefail

readonly REPO_OWNER="Baelson"
readonly REPO_NAME="dotfiles"
readonly REPO_HTTPS_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
readonly REPO_SSH_URL="git@github.com:${REPO_OWNER}/${REPO_NAME}.git"
readonly KEYCHAIN_SERVICE="github-pat"

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
# Step 1: Pre-flight — confirm the PAT Keychain entry exists before we burn
# minutes on Homebrew install. Checks presence only (no -w), so this does NOT
# trigger a macOS "Allow access" dialog on first use.
# -----------------------------------------------------------------------------

log_step "Checking for Keychain entry (service=${KEYCHAIN_SERVICE}, account=${ACCOUNT})"
if ! security find-generic-password -s "${KEYCHAIN_SERVICE}" -a "${ACCOUNT}" >/dev/null 2>&1; then
    log_err "Missing Keychain entry for service=${KEYCHAIN_SERVICE}, account=${ACCOUNT}."
    echo "Create a GitHub PAT with 'repo' scope at https://github.com/settings/tokens, then:" >&2
    echo "  security add-generic-password -s ${KEYCHAIN_SERVICE} -a ${ACCOUNT} -w '<token>' -U" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 2: Homebrew — also handles CLT via softwareupdate under NONINTERACTIVE=1
# -----------------------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
    log_step "Homebrew already installed ($(command -v brew))"
else
    log_step "Installing Homebrew (non-interactive; will also install Xcode CLT if missing)"
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Load brew shellenv. command -v works if brew is on PATH already (test envs,
# already-bootstrapped machines). Fall back to known install paths for the
# "just-installed" case where PATH hasn't been refreshed in this shell.
if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
else
    log_err "brew not found on PATH or at /opt/homebrew/bin, /usr/local/bin after install"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 3: Install chezmoi + age
# -----------------------------------------------------------------------------

log_step "Installing chezmoi and age"
brew install chezmoi age

# -----------------------------------------------------------------------------
# Step 4: Fetch PAT from Keychain and write ~/.netrc (0600)
#
# Install the cleanup trap BEFORE writing netrc so any failure — including
# right after the file is created — still scrubs the plaintext token. The
# existence check in Step 1 already failed fast on a missing entry; at this
# point an empty value means the Keychain was tampered with mid-run.
# -----------------------------------------------------------------------------

log_step "Retrieving PAT value from Keychain"
TOKEN="$(security find-generic-password -s "${KEYCHAIN_SERVICE}" -a "${ACCOUNT}" -w 2>/dev/null || true)"
if [[ -z "${TOKEN}" ]]; then
    log_err "Keychain entry ${KEYCHAIN_SERVICE}:${ACCOUNT} exists but returned an empty value."
    exit 1
fi

# Scrub the PAT value by truncating ~/.netrc rather than deleting it. The
# dotfiles source tree contains `home/empty_dot_netrc` (chezmoi-managed empty
# placeholder), so deleting the file would leave chezmoi reporting drift on
# every subsequent apply. Truncating removes the plaintext token while
# preserving chezmoi's "managed empty file" invariant.
cleanup_netrc() {
    if [[ -f "${HOME}/.netrc" ]]; then
        : > "${HOME}/.netrc" 2>/dev/null || true
        chmod 600 "${HOME}/.netrc" 2>/dev/null || true
    fi
}
trap cleanup_netrc EXIT INT TERM

log_step "Writing short-lived ~/.netrc (mode 0600)"
umask 077
printf 'machine github.com\nlogin %s\npassword %s\n' "${ACCOUNT}" "${TOKEN}" > "${HOME}/.netrc"
chmod 600 "${HOME}/.netrc"
unset TOKEN

# -----------------------------------------------------------------------------
# Step 4: chezmoi init — HTTPS clone via go-git or real git (both read netrc)
#
# --exclude=encrypted,scripts:
#   - encrypted: age key isn't provisioned yet; it'll be decrypted from
#     bootstrap/key.txt.age by run_once_before_provision-age-key.sh during
#     the next apply.
#   - scripts:   deferred to the dedicated apply call below so CLT / Homebrew
#     aren't re-triggered mid-init.
# -----------------------------------------------------------------------------

log_step "chezmoi init --apply --exclude=encrypted,scripts ${REPO_HTTPS_URL}"
chezmoi init --apply --exclude=encrypted,scripts "${REPO_HTTPS_URL}"

# -----------------------------------------------------------------------------
# Step 5: chezmoi apply --force — full pass deploys scripts AND encrypted files.
#
# chezmoi's per-pass order is run_once_before_* → files → run_onchange_after_*,
# so run_once_before_provision-age-key.sh provisions ~/.config/chezmoi/key.txt
# (from the encrypted bootstrap/key.txt.age) BEFORE the files phase tries to
# decrypt private_dot_ssh/, license files, etc. That makes a single apply
# sufficient even on a bare machine — no third pass needed.
#
# (Earlier versions used --include=scripts here, which limited the pass to
# scripts only; encrypted files never decrypted. The bug surfaced in the
# first encryption-enabled VM E2E and was fixed by dropping the --include.)
#
# A lifecycle script may still fail (e.g., a flaky cask download timing out).
# That failure is noted but does NOT short-circuit the remote-flip + netrc
# scrub — those are independent of whether every package installed cleanly.
# install.sh exits non-zero at the very end if apply failed.
# -----------------------------------------------------------------------------

log_step "chezmoi apply --force"
APPLY_EXIT=0
chezmoi apply --force || APPLY_EXIT=$?
if [[ "${APPLY_EXIT}" -ne 0 ]]; then
    log_warn "chezmoi apply exited ${APPLY_EXIT}. Continuing to remote-flip; investigate after bootstrap."
fi

# -----------------------------------------------------------------------------
# Step 6: Flip source-dir remote to SSH and scrub ~/.netrc
# -----------------------------------------------------------------------------

SRC="$(chezmoi source-path)"
# chezmoi source-path returns the dir containing the source files. The git
# checkout is one level up (the repo root), so check both locations.
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

log_step "Scrubbing ~/.netrc"
cleanup_netrc
trap - EXIT INT TERM

# Surface the apply failure now that cleanup + flip are done.
if [[ "${APPLY_EXIT}" -ne 0 ]]; then
    log_err "chezmoi apply failed (exit ${APPLY_EXIT}). Bootstrap partially succeeded."
    log_err "Fix the cause and re-run: chezmoi apply --force"
    exit "${APPLY_EXIT}"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

cat <<'EOF'

Bootstrap complete.

Next steps:
  - Open a new shell (or `exec zsh -l`) so PATH updates take effect.
  - Run `chezmoi diff` to review drift; `chezmoi apply` to reconcile.
  - Run `chezmoi update` for steady-state sync (uses SSH + ssh-agent).

See docs/plans/2026-04-20-issue-019-bootstrap-reconciliation.md for the design.
EOF

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
# Resolves ISSUE-022: chezmoi loads its config once per invocation and
# .chezmoi.toml.tmpl stat-gates the [age] block on ~/.config/chezmoi/key.txt.
# We clone first (config without [age]), decrypt the age key from
# bootstrap/key.txt.age here in install.sh (interactive passphrase prompt),
# then re-run `chezmoi init` so the config regenerates with [age] populated,
# then `chezmoi apply --force` deploys everything in a single pass.
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
# See docs/plans/2026-04-20-issue-019-bootstrap-reconciliation.md (ISSUE-019)
# and docs/plans/2026-04-22-issue-022-install-sh-age-key-ordering.md (ISSUE-022).

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
# dotfiles source tree contains `home/empty_private_dot_netrc` (chezmoi-managed
# empty placeholder with mode 0600 via the `private_` prefix), so deleting the
# file would leave chezmoi reporting drift on every subsequent apply.
# Truncating removes the plaintext token while preserving chezmoi's "managed
# empty file" invariant; the `private_` prefix ensures apply keeps ~/.netrc at
# 0600 rather than relaxing it to the umask default 0644.
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
# Age-key provisioning helper (ISSUE-022)
#
# Decrypts the passphrase-protected bootstrap/key.txt.age into
# ~/.config/chezmoi/key.txt so the subsequent `chezmoi init` renders a
# config with the `[age]` block (stat-gated in .chezmoi.toml.tmpl).
#
# Must be called BETWEEN the two `chezmoi init` calls — the first init
# clones the source dir so we can find bootstrap/key.txt.age, the second
# init regenerates the config now that the key exists.
#
# Degrades gracefully when provisioning isn't possible:
#   - key already present        → idempotent no-op
#   - age binary missing         → warn + skip (shouldn't happen post-Step 3)
#   - bootstrap/key.txt.age gone → warn + skip
#   - no controlling terminal    → warn + skip (automated SSH-only regression)
#   - age -d fails (bad passphrase) → rm partial, warn + continue
# In all skip branches, encrypted files simply stay as stubs after apply;
# the operator sees a clear warning and the rest of bootstrap still succeeds.
#
# TTY detection uses /dev/tty, NOT `[[ -t 0 ]]` on stdin. The canonical
# bootstrap invocation is `curl ... | bash`, which makes bash's stdin the
# pipe from curl — so `-t 0` falsely reports non-interactive even when the
# user is sitting at a Terminal.app window. /dev/tty, by contrast, refers
# to the *controlling terminal* and is accessible whenever install.sh was
# launched from an interactive shell, piped or not. (age itself also reads
# the passphrase from /dev/tty internally, bypassing stdin.) Non-interactive
# contexts — SSH without `-t`, cron, launchd — have no /dev/tty at all, so
# the open fails and we skip cleanly.
# -----------------------------------------------------------------------------

provision_age_key() {
    local age_key_dir="${HOME}/.config/chezmoi"
    local age_key_file="${age_key_dir}/key.txt"
    local source_path
    source_path="$(chezmoi source-path 2>/dev/null || true)"
    local encrypted_key="${source_path}/../bootstrap/key.txt.age"

    if [[ -f "${age_key_file}" ]]; then
        log_step "Age key already present at ${age_key_file} — skipping provisioning"
        return 0
    fi
    if ! command -v age >/dev/null 2>&1; then
        log_warn "age not installed — skipping age key provisioning (encrypted files will not deploy)"
        return 0
    fi
    if [[ ! -f "${encrypted_key}" ]]; then
        log_warn "No encrypted age key at ${encrypted_key} — skipping (encrypted files will not deploy)"
        return 0
    fi
    # /dev/tty, not `-t 0`: the runbook invokes install.sh via
    # `curl ... | bash`, which makes stdin the pipe from curl — `-t 0` then
    # falsely reports non-interactive even when a real terminal is attached.
    # /dev/tty is the controlling terminal and exists whenever the user
    # launched install.sh from a shell window, pipe or no pipe.
    if ! { : </dev/tty; } 2>/dev/null; then
        log_warn "No controlling terminal (/dev/tty unavailable) — skipping age key provisioning (encrypted files will not deploy)"
        log_warn "Run install.sh from an interactive terminal to provision the key."
        return 0
    fi

    log_step "Provisioning age decryption key (passphrase-protected; one prompt below)"
    mkdir -p "${age_key_dir}"
    # Redirect stdin from /dev/tty so the passphrase prompt works even when
    # install.sh was invoked via `curl ... | bash` (bash's stdin is the
    # pipe, but /dev/tty still points to the interactive terminal). age's
    # internal passphrase reader also opens /dev/tty directly, but being
    # explicit here avoids any ambiguity on platforms where it doesn't.
    if age -d -o "${age_key_file}" "${encrypted_key}" </dev/tty; then
        chmod 600 "${age_key_file}"
        log_step "Age key provisioned at ${age_key_file}"
    else
        log_warn "Failed to decrypt age key (wrong passphrase?) — continuing without encryption"
        rm -f "${age_key_file}"
    fi
}

# -----------------------------------------------------------------------------
# Step 4: chezmoi init — clone only (no --apply).
#
# At this point the age key doesn't exist yet, so .chezmoi.toml.tmpl's
# stat-gated [age] block renders empty. We clone the source dir now so
# bootstrap/key.txt.age is available on disk for Step 5, then re-run
# `chezmoi init` in Step 6 to regenerate chezmoi.toml with [age] populated.
#
# Splitting init (clone) from apply (deploy) sidesteps chezmoi's
# load-config-once-per-invocation semantics — the follow-up init picks up
# the newly-provisioned key.
# -----------------------------------------------------------------------------

log_step "chezmoi init ${REPO_HTTPS_URL}"
chezmoi init "${REPO_HTTPS_URL}"

# -----------------------------------------------------------------------------
# Step 5: Provision the age key (primary entry point per ISSUE-022 fix).
#
# The lifecycle script home/.chezmoiscripts/darwin/run_once_before_provision-age-key.sh
# remains in-tree as a fallback for users who clone manually (`chezmoi init`
# directly, not via install.sh), but it is NO LONGER on the critical path —
# it relied on chezmoi's subprocess stdin which is detached in practice.
# -----------------------------------------------------------------------------

provision_age_key

# -----------------------------------------------------------------------------
# Step 6: chezmoi init — regenerate chezmoi.toml now that the key exists.
#
# The stat guard in .chezmoi.toml.tmpl will now emit `encryption = "age"` +
# the [age] block, so Step 7's apply can decrypt encrypted files successfully
# in a single pass. If Step 5 skipped (non-TTY, missing age, etc.), the
# regen is a no-op and encrypted files will stay as stubs — that's the
# expected degrade-gracefully behavior.
# -----------------------------------------------------------------------------

log_step "chezmoi init (regenerate config; emits [age] block if key provisioned)"
chezmoi init

# -----------------------------------------------------------------------------
# Step 7: chezmoi apply --force — full pass deploys files AND encrypted files.
#
# A lifecycle script may still fail (e.g. a flaky cask download timing out).
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
# Step 8: Flip source-dir remote to SSH and scrub ~/.netrc
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

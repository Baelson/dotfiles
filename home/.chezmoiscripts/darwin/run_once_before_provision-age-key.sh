#!/bin/zsh
#
# chezmoi Lifecycle Script: Age Key Provisioning (passphrase fallback)
# =====================================================================
#
# Provisions ~/.config/chezmoi/key.txt by decrypting the
# passphrase-protected bootstrap/key.txt.age stored in the repo. Runs
# AFTER run_once_before_install-homebrew.sh (lexicographic ordering:
# `install-` < `provision-`) so that the `age` binary is on PATH.
#
# This is the FALLBACK path — setup.sh's primary path stages the age
# identity from the macOS Keychain (`dotfiles-age:$USER`) before
# `chezmoi init`, which lets the .chezmoi.toml.tmpl stat-guard render
# the [age] block on the first init. This script only fires when the
# Keychain entry was absent and bootstrap/key.txt.age is in the repo.
#
# After this script provisions key.txt, setup.sh re-runs `chezmoi init`
# + `chezmoi apply --force` to regenerate the config with [age] populated
# and decrypt encrypted files. (chezmoi loads its config once per
# invocation; the first apply pass leaves encrypted files as stubs.)
#
# TTY discipline:
#   - Use /dev/tty rather than `[[ -t 0 ]]`. Under `curl ... | bash` -> chezmoi
#     subprocesses, stdin is the pipe even in a real Terminal.app session, so
#     `-t 0` falsely reports non-interactive and the script silently skips.
#     /dev/tty refers to the controlling terminal and is accessible whenever
#     install was launched from an interactive shell.
#   - age -d reads the passphrase from /dev/tty internally, but we redirect
#     stdin from /dev/tty explicitly to be safe across age versions.
#
# Skip cleanly (no error) on:
#   - key.txt already provisioned (idempotent)
#   - age binary missing (shouldn't happen — install-homebrew installed it)
#   - bootstrap/key.txt.age missing (fork user removed it)
#   - no /dev/tty (cron, launchd, SSH-no-tty, headless VM)
#
# References:
#   - age scrypt-passphrase encryption: https://github.com/FiloSottile/age
#   - chezmoi encryption: https://www.chezmoi.io/user-guide/encryption/

set -euo pipefail

readonly AGE_KEY_DIR="${HOME}/.config/chezmoi"
readonly AGE_KEY_FILE="${AGE_KEY_DIR}/key.txt"

CHEZMOI_SOURCE="$(chezmoi source-path 2>/dev/null || echo "${HOME}/.local/share/chezmoi/home")"
ENCRYPTED_KEY="${CHEZMOI_SOURCE}/../bootstrap/key.txt.age"
# Forker fallback: the PUBLISHED throwaway sample identity (Phase 3 pull-forward). Its passphrase and
# private key are PUBLIC — used only so a forker's `chezmoi apply` decrypts the SAMPLE dotfiles content.
SAMPLE_KEY="${CHEZMOI_SOURCE}/../bootstrap/sample-key.txt.age"
readonly SAMPLE_PASSPHRASE="change-me-on-first-run"

# Idempotent — skip if already provisioned.
if [[ -f "${AGE_KEY_FILE}" ]]; then
    exit 0
fi

# Make brew + age discoverable. chezmoi runs each lifecycle script in its
# own subprocess; the brew shellenv eval inside run_once_before_install-homebrew.sh
# only affects THAT subprocess, not its siblings. On a fresh machine where
# chezmoi was launched before brew existed, /opt/homebrew/bin is not yet on
# the inherited PATH — so `command -v age` returns false even though the
# previous lifecycle script just installed it. Load shellenv explicitly here.
if ! command -v age >/dev/null 2>&1; then
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Skip if age is still missing after shellenv (install-homebrew lifecycle
# either failed or was skipped).
if ! command -v age >/dev/null 2>&1; then
    echo "⚠️  age not installed — skipping age key provisioning"
    echo "💡 Install via: brew install age && chezmoi apply --force"
    exit 0
fi

# Real key absent (fork user) — fall back to the PUBLISHED SAMPLE identity if present.
# SECURITY POSTURE (deliberate): a HUMAN at a terminal must TYPE the passphrase — that friction is the
# real mitigation (it forces awareness that this is a throwaway, publicly-decryptable identity). Only a
# HEADLESS context (CI / VM E2E — no /dev/tty) auto-provisions, so a forker-scenario test gets a green
# decrypt without silently installing a public identity on a real person's machine.
if [[ ! -f "${ENCRYPTED_KEY}" ]]; then
    if [[ -f "${SAMPLE_KEY}" ]]; then
        echo ""
        echo "############################################################################"
        echo "#  ⚠️  PUBLISHED SAMPLE age identity (throwaway demo key).                  #"
        echo "#  Its passphrase ('change-me-on-first-run') AND private key are PUBLIC —   #"
        echo "#  anyone can decrypt anything encrypted to it. Encrypted dotfiles decrypt  #"
        echo "#  to SAMPLE content. DO NOT store real secrets against it: generate your   #"
        echo "#  own age key and re-encrypt before real use (see README).                 #"
        echo "############################################################################"
        echo ""
        mkdir -p "${AGE_KEY_DIR}"
        if { : </dev/tty; } 2>/dev/null; then
            # Human at a terminal — require them to type the sample passphrase (friction = awareness).
            echo "🔐 To provision the SAMPLE identity, enter its passphrase (it is: ${SAMPLE_PASSPHRASE}):"
            if age -d -o "${AGE_KEY_FILE}" "${SAMPLE_KEY}" </dev/tty \
               && age-keygen -y "${AGE_KEY_FILE}" >/dev/null 2>&1; then
                chmod 600 "${AGE_KEY_FILE}"
                echo "✅ SAMPLE age key provisioned — ROTATE before storing any real secret."
            else
                echo "❌ Not provisioned — encrypted files stay as stubs. Re-run \`chezmoi apply --force\` to retry."
                rm -f "${AGE_KEY_FILE}"
            fi
        else
            # Headless (CI / VM E2E only): age has no non-interactive passphrase input, so drive `age -d`
            # through a pty via /usr/bin/script (always on macOS). Validate with `age-keygen -y` (prints the
            # recipient iff valid) — avoids the literal age-secret-key prefix the privacy gate denies.
            echo "ℹ️  Headless context — auto-provisioning the sample identity for this non-interactive run."
            if printf '%s\n' "${SAMPLE_PASSPHRASE}" | script -q /dev/null age -d -o "${AGE_KEY_FILE}" "${SAMPLE_KEY}" >/dev/null 2>&1 \
               && age-keygen -y "${AGE_KEY_FILE}" >/dev/null 2>&1; then
                chmod 600 "${AGE_KEY_FILE}"
                echo "✅ SAMPLE age key auto-provisioned (headless) — rotate before real use."
            else
                echo "❌ Failed to provision the sample age key — encrypted files stay as stubs."
                rm -f "${AGE_KEY_FILE}"
            fi
        fi
        exit 0
    fi
    echo "⚠️  No encrypted age key at ${ENCRYPTED_KEY} — encrypted files will stay as stubs"
    exit 0
fi

# /dev/tty probe, NOT `[[ -t 0 ]]`. The latter is false under
# `curl ... | bash` even in interactive Terminal.app sessions; the former
# tracks the controlling terminal and only fails in truly headless contexts.
if ! { : </dev/tty; } 2>/dev/null; then
    echo "⚠️  No controlling terminal (/dev/tty unavailable) — skipping age key provisioning"
    echo "💡 Run \`chezmoi apply --force\` from an interactive shell to provision"
    exit 0
fi

echo "🔐 Provisioning age decryption key — enter the passphrase for the dotfiles age key:"
mkdir -p "${AGE_KEY_DIR}"
if age -d -o "${AGE_KEY_FILE}" "${ENCRYPTED_KEY}" </dev/tty; then
    chmod 600 "${AGE_KEY_FILE}"
    echo "✅ Age key provisioned at ${AGE_KEY_FILE}"
else
    echo "❌ Failed to decrypt age key (wrong passphrase?). Encrypted files will stay as stubs."
    echo "💡 Re-run \`chezmoi apply --force\` to retry."
    rm -f "${AGE_KEY_FILE}"
    exit 0
fi

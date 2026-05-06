#!/bin/zsh
#
# chezmoi Lifecycle Script: Xcode CLT + Homebrew + age install
# ============================================================
#
# Runs once per machine, before `chezmoi apply` reaches the files phase.
# Three steps, in order:
#
# 1. Xcode Command Line Tools — installed via the "cookbook" flag-file
#    + softwareupdate pattern (the same one GitHub Actions and most CI
#    macOS setups use). Two prior approaches both failed in bare VMs:
#    - Phase 5C: `NONINTERACTIVE=1` Homebrew → softwareupdate -l catalog
#      filter returned empty → infinite hang on Homebrew's wait loop.
#    - Phase 5G: `xcode-select --install` → "no developer tools were
#      found, and no install could be requested (perhaps no UI is
#      present)" — fails immediately on `tart run --no-graphics`.
#    The cookbook pattern (Phase 5H): touch the
#    `/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress`
#    flag file, then `softwareupdate -l` populates the catalog with the
#    on-demand CLT package, then `softwareupdate -i "<full label>"`
#    installs it silently. Bounded 15-min poll catches any future
#    regression cleanly.
#
# 2. Homebrew — `NONINTERACTIVE=1` suppresses installer prompts. With
#    CLT already in place from Step 1, the Homebrew installer's
#    CLT-detect path short-circuits.
#
# 3. age binary — useful for manual decrypt/audit; chezmoi itself uses
#    its `--use-builtin-age=auto` for runtime decrypts.
#
# Ordering is load-bearing: this script is the authoritative installer
# for CLT + Homebrew + age (install.sh is a thin wrapper that only
# curl-installs chezmoi). It must run BEFORE any lifecycle step that
# depends on brew, age, or real git — which is why it lives as
# run_once_before_* rather than run_onchange_after_*.
#
# `</dev/null` on every subprocess that might read FD 0. Under
# `curl ... | bash` (the canonical install.sh invocation), bash's stdin
# IS the pipe. Subprocesses that read stdin consume bytes meant for
# bash's later execution, truncating the script silently. install.sh
# already curl-installs chezmoi safely; this script runs later inside
# chezmoi's subprocess, so FD 0 hygiene is still important.
#
# References:
# - chezmoi run_once scripts: https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/
# - Homebrew NONINTERACTIVE: https://docs.brew.sh/Installation#unattended-installation
# - Cookbook CLT install (the pattern used here):
#   https://apple.stackexchange.com/questions/107307/
#   https://github.com/Homebrew/install/blob/HEAD/install.sh (the same flag-file approach)

set -euo pipefail

echo "🍺 CLT + Homebrew + age lifecycle step"

# -----------------------------------------------------------------------------
# Step 1: Xcode Command Line Tools — cookbook flag-file + softwareupdate
#
# The flag file `/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress`
# tells softwareupdate to populate its catalog with the on-demand CLT
# package. Without this, `softwareupdate -l` shows an empty list on bare
# VMs (Phase 5C) and `xcode-select --install` errors with "no UI is
# present" (Phase 5G). With it, the CLT package shows up in the list
# and we can install it explicitly via `softwareupdate -i "<label>"`.
#
# Bounded 15-min poll on `xcode-select -p` catches any regression cleanly
# rather than hanging silently.
# -----------------------------------------------------------------------------

if xcode-select -p >/dev/null 2>&1; then
    echo "✅ Xcode CLT already installed at $(xcode-select -p)"
else
    echo "📱 Installing Xcode CLT via cookbook flag-file + softwareupdate"
    flag_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "${flag_file}"

    # `softwareupdate -l` populates the catalog respecting the flag file.
    # Capture the latest matching CLT label (parses the leading "* Label:")
    # form from `-l`'s output. Apple ships multiple labels (e.g. one per
    # CLT-supported macOS); `tail -1` picks the newest.
    label="$(softwareupdate -l 2>&1 \
        | awk -F'\t' '/^\* Label: .*Command Line Tools/ {sub(/^\* Label: /, ""); print}' \
        | tail -1)"

    if [[ -z "${label}" ]]; then
        # Fallback parse: older softwareupdate output format ("* <label>").
        label="$(softwareupdate -l 2>&1 \
            | awk -F'*' '/Command Line Tools/ {print $2}' \
            | sed 's/^ *//' \
            | tail -1)"
    fi

    if [[ -n "${label}" ]]; then
        echo "📦 Installing CLT label: ${label}"
        softwareupdate -i "${label}" --verbose </dev/null
    else
        echo "❌ Could not find a Command Line Tools label in softwareupdate -l output." >&2
        echo "   Catalog may be empty or this macOS version uses an unexpected label format." >&2
        rm -f "${flag_file}"
        exit 1
    fi

    rm -f "${flag_file}"

    # Bounded post-install poll: even with `softwareupdate -i` returning
    # success, the CLT receipt may take a few seconds to register.
    deadline=$(( $(date +%s) + 900 ))   # 15 min budget
    while ! xcode-select -p >/dev/null 2>&1; do
        if [[ "$(date +%s)" -ge "${deadline}" ]]; then
            echo "❌ Xcode CLT did not register within 15 min after softwareupdate -i succeeded." >&2
            echo "   Recovery: log in to the VM GUI, run 'xcode-select --install' interactively, then re-run 'chezmoi apply --force'." >&2
            exit 1
        fi
        echo "⏳ Waiting for Xcode CLT to register…"
        sleep 10
    done
    echo "✅ Xcode CLT installed at $(xcode-select -p)"
fi

# -----------------------------------------------------------------------------
# Step 2: Homebrew
# -----------------------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
    echo "✅ Homebrew already installed at $(command -v brew)"
else
    echo "📦 Installing Homebrew (NONINTERACTIVE=1)"
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        </dev/null
fi

# Add Homebrew to PATH for the remainder of this apply pass.
if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
else
    echo "❌ brew not found on PATH or at /opt/homebrew/bin, /usr/local/bin after install" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 3: age — needed so the user can decrypt the keyed age identity manually
# if they ever want to re-roll or audit. chezmoi itself uses built-in age
# (`--use-builtin-age=auto`) for its own decrypts, but a user-facing `age`
# binary is handy.
# -----------------------------------------------------------------------------

if command -v age >/dev/null 2>&1; then
    echo "✅ age already installed at $(command -v age)"
else
    echo "🔐 Installing age"
    brew install age </dev/null
fi

echo "✅ CLT + Homebrew + age lifecycle step complete"

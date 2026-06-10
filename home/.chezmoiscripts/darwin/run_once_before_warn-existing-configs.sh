#!/bin/zsh
#
# run_once_before_warn-existing-configs.sh — create_ freeze heads-up for the
# 5 shell configs (.zshrc .zprofile .zshenv .gitconfig .p10k.zsh).
#
# In the PUBLIC derivative these ship with chezmoi's `create_` attribute
# (create_dot_*): chezmoi writes the managed version ONLY if the target does
# not already exist, and NEVER overwrites an existing one. The corollary is a
# silent FREEZE — if your file already exists, `chezmoi diff` shows nothing
# and future upstream changes to these 5 files never reach you. This runs
# once, BEFORE the file phase, to LOUDLY say which files are frozen — the
# parity warning to run_once_before_warn-existing-ssh.sh.
#
# The private source manages the same 5 files as plain dot_* (owner-overwrite
# semantics), where no freeze exists — so warn per-file only when THIS source
# carries the create_dot_ form. CHEZMOI_SOURCE_DIR is set by chezmoi for
# lifecycle scripts (verified on chezmoi 2.70.2); absent it (manual run), stay
# silent rather than guess.
#
# To adopt the managed version of a frozen file: move yours aside (or delete
# it), then re-run `chezmoi apply`.
#
# Non-fatal: always exits 0. zsh (matches the sibling lifecycle scripts) — zsh
# handles empty-array expansion under `set -u` cleanly.

set -euo pipefail

SRC="${CHEZMOI_SOURCE_DIR:-}"
# Target basenames managed via create_dot_* in the public derivative.
MANAGED=(.zshrc .zprofile .zshenv .gitconfig .p10k.zsh)

frozen=()
if [[ -n "${SRC}" ]]; then
    for t in "${MANAGED[@]}"; do
        if [[ -e "${SRC}/create_dot_${t#.}" && -e "${HOME}/${t}" ]]; then
            frozen+=("${t}")
        fi
    done
fi

if [[ ${#frozen[@]} -gt 0 ]]; then
    echo ""
    echo "############################################################################"
    echo "#  ⚠️  EXISTING SHELL/GIT CONFIGS DETECTED — chezmoi will NOT overwrite them."
    echo "############################################################################"
    echo "#  These already exist and are managed with chezmoi's create_ attribute"
    echo "#  (create-if-absent), so the managed versions are NOT applied over them —"
    echo "#  and they will NOT receive future upstream updates (silent skip, empty"
    echo "#  chezmoi diff):"
    for t in "${frozen[@]}"; do
        echo "#    - ~/${t}"
    done
    echo "#"
    echo "#  This is deliberate: it prevents this repo's configs from clobbering your"
    echo "#  customized files. To adopt the managed version of a specific file, move"
    echo "#  yours aside (or delete it) and re-run: chezmoi apply"
    echo "############################################################################"
    echo ""
fi

exit 0

#!/bin/zsh
#
# run_once_before_warn-existing-ssh.sh — forker-safety heads-up for ~/.ssh.
#
# All ~/.ssh material is managed with chezmoi's `create_` attribute
# (home/private_dot_ssh/create_encrypted_*.age): chezmoi writes the managed /
# SAMPLE version of a file ONLY if the target does not already exist, and NEVER
# overwrites an existing one. This runs once, BEFORE the file phase, to LOUDLY
# tell the operator which existing ~/.ssh files chezmoi will leave untouched —
# so a forker is never silently locked out by a sample authorized_keys, and
# real private keys are never clobbered by samples.
#
# To intentionally adopt the managed/sample version of a file: delete the
# existing one yourself, then re-run `chezmoi apply`.
#
# Non-fatal: always exits 0. zsh (matches the sibling lifecycle scripts) — zsh
# handles empty-array expansion under `set -u` cleanly.

set -euo pipefail

SSH_DIR="${HOME}/.ssh"
# Targets managed via create_encrypted_* in home/private_dot_ssh/.
MANAGED=(authorized_keys id_ed25519 id_ed25519.pub id_rsa id_rsa.pub config known_hosts known_hosts.old)

existing=()
for f in "${MANAGED[@]}"; do
    if [[ -e "${SSH_DIR}/${f}" ]]; then
        existing+=("${f}")
    fi
done

if [[ ${#existing[@]} -gt 0 ]]; then
    echo ""
    echo "############################################################################"
    echo "#  ⚠️  EXISTING ~/.ssh FILES DETECTED — chezmoi will NOT overwrite them.     #"
    echo "############################################################################"
    echo "#  These already exist and are managed with chezmoi's create_ attribute"
    echo "#  (create-if-absent), so the managed/SAMPLE versions are NOT applied over"
    echo "#  them:"
    for f in "${existing[@]}"; do
        echo "#    - ~/.ssh/${f}"
    done
    echo "#"
    echo "#  This is deliberate: it prevents a sample authorized_keys from locking you"
    echo "#  out, and prevents sample private keys from clobbering real ones. To adopt"
    echo "#  the managed/sample version of a specific file, delete the existing one"
    echo "#  yourself and re-run: chezmoi apply"
    echo "############################################################################"
    echo ""
fi

exit 0

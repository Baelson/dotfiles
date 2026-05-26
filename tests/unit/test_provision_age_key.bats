#!/usr/bin/env bats
#
# test_provision_age_key.bats — Unit coverage for the age key provisioning
# lifecycle script.
#
# Target: home/.chezmoiscripts/darwin/run_once_before_provision-age-key.sh
#
# The script is the FALLBACK path when setup.sh's Keychain fast-path was
# absent. It decrypts bootstrap/key.txt.age using a passphrase read from
# /dev/tty and writes ~/.config/chezmoi/key.txt. After this script runs,
# setup.sh re-runs `chezmoi init` + `chezmoi apply --force` to pick up
# the [age] block and decrypt encrypted files.
#
# Skip cases exercised here:
#   - key.txt already present (idempotent exit 0)
#   - age binary missing (warn + exit 0, encrypted files stay as stubs)
#   - bootstrap/key.txt.age absent (warn + exit 0)
#   - no /dev/tty available (headless runner — warn + exit 0)
#
# TTY discipline tests (ISSUE-022 hotfix):
#   - Source-level: script uses `/dev/tty` probe, NOT `[[ -t 0 ]]`
#   - Runtime (skip if no /dev/tty): piped stdin does NOT false-skip provisioning
#
# Notes on hermeticity:
#   - HOME is redirected to BATS_TEST_TMPDIR.
#   - PATH is stripped to "${FAKE_BIN}:/usr/bin:/bin".
#   - The lifecycle script is #!/bin/zsh; invoked via `run zsh`.

LIFECYCLE_SCRIPT="${BATS_TEST_DIRNAME%/tests/*}/home/.chezmoiscripts/darwin/run_once_before_provision-age-key.sh"

setup() {
    export FAKE_BIN="${BATS_TEST_TMPDIR}/fake-bin"
    mkdir -p "${FAKE_BIN}"
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "${HOME}"
    export USER="testuser"
    export PATH="${FAKE_BIN}:/usr/bin:/bin"
}

# Write a fake executable into $FAKE_BIN.
fake() {
    local name="$1"; shift
    local body="$*"
    {
        echo '#!/bin/bash'
        echo "${body}"
    } > "${FAKE_BIN}/${name}"
    chmod +x "${FAKE_BIN}/${name}"
}

# Set up a fake chezmoi source-path pointing to a dir that HAS a
# bootstrap/key.txt.age file (the normal provisioning scenario).
setup_chezmoi_with_encrypted_key() {
    local fake_src="${BATS_TEST_TMPDIR}/fake-source"
    mkdir -p "${fake_src}" "${fake_src}/../bootstrap"
    touch "${fake_src}/../bootstrap/key.txt.age"
    fake chezmoi "echo '${fake_src}'"
}

# -----------------------------------------------------------------------------
# Source-level invariant — TTY discipline
# -----------------------------------------------------------------------------

@test "provision-age-key: source uses /dev/tty probe, not -t 0, for TTY detection" {
    # Regression guard for the ISSUE-022 hotfix. The old `[[ -t 0 ]]` gate
    # falsely reported non-interactive when run via `curl ... | bash` because
    # bash's stdin IS the pipe even in a real Terminal.app session. The fix
    # uses `: </dev/tty` which probes the controlling terminal, not FD 0.
    local src="${LIFECYCLE_SCRIPT}"

    # Positive: the /dev/tty probe MUST be present.
    grep -q '{ : </dev/tty; }' "${src}" \
      || (echo "Missing /dev/tty probe in ${src}" >&2; false)

    # Negative: the fd-0 check MUST NOT appear in functional (non-comment) code.
    # The script's own docstring mentions `[[ -t 0 ]]` to explain the anti-pattern,
    # so we strip comment lines before checking.
    if grep -vE '^\s*#' "${src}" | grep -qE '\-t 0'; then
        echo "Found deprecated -t 0 check in non-comment code of ${src}" >&2
        false
    fi
}

# -----------------------------------------------------------------------------
# Idempotency
# -----------------------------------------------------------------------------

@test "provision-age-key: exits 0 silently when key.txt already exists" {
    # The first guard in the script: if key.txt is present, skip immediately.
    # This is the steady-state condition for machines that have already run.
    setup_chezmoi_with_encrypted_key
    mkdir -p "${HOME}/.config/chezmoi"
    echo 'AGE-SECRET-KEY-1EXISTINGKEY' > "${HOME}/.config/chezmoi/key.txt"
    chmod 600 "${HOME}/.config/chezmoi/key.txt"

    run zsh "${LIFECYCLE_SCRIPT}"

    [ "${status}" -eq 0 ]
    # Silent: no output expected (the script just exits 0 when key exists).
    [ -z "${output}" ]
}

# -----------------------------------------------------------------------------
# Skip branches — graceful degradation
# -----------------------------------------------------------------------------

@test "provision-age-key: missing age binary warns and exits 0" {
    # If `age` is not in PATH (shouldn't happen post-Homebrew install, but
    # guard against a broken brew run), the script must warn and continue.
    # Encrypted files will stay as stubs — that's the documented degrade behavior.
    setup_chezmoi_with_encrypted_key
    # No `age` in FAKE_BIN — command -v age returns non-zero.

    run zsh "${LIFECYCLE_SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "age not installed" ]]
    # Must NOT have attempted to decrypt (key.txt absent = did not proceed).
    [ ! -f "${HOME}/.config/chezmoi/key.txt" ]
}

@test "provision-age-key: missing bootstrap/key.txt.age warns and exits 0" {
    # Fork user or someone who removed the encrypted key file: the script
    # must skip cleanly with a message about stubs.
    local fake_src="${BATS_TEST_TMPDIR}/fake-source-no-key"
    mkdir -p "${fake_src}"
    # Intentionally do NOT create bootstrap/key.txt.age
    fake chezmoi "echo '${fake_src}'"
    fake age 'exit 0'  # age present but irrelevant — key.txt.age absent

    run zsh "${LIFECYCLE_SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "stubs" ]]
    [ ! -f "${HOME}/.config/chezmoi/key.txt" ]
}

@test "provision-age-key: no /dev/tty warns and exits 0" {
    # Headless runner (CI, launchd, SSH-no-tty): /dev/tty not available.
    # Skip this test if /dev/tty IS accessible (the interactive-runner case
    # is covered by the stdin-as-pipe test below).
    if { : </dev/tty; } 2>/dev/null; then
        skip "/dev/tty is available in this runner — covered by stdin-as-pipe test"
    fi

    setup_chezmoi_with_encrypted_key
    fake age 'exit 0'

    run zsh "${LIFECYCLE_SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "No controlling terminal" ]]
    [ ! -f "${HOME}/.config/chezmoi/key.txt" ]
}

# -----------------------------------------------------------------------------
# ISSUE-022 hotfix — stdin-as-pipe does NOT false-skip provisioning
# (re-homed from test_bootstrap_install.bats)
# -----------------------------------------------------------------------------

@test "provision-age-key: stdin-as-pipe does NOT false-skip age provisioning" {
    # Reproduction of the ISSUE-022 hotfix: canonical invocation is
    # `curl ... | bash`, which makes bash's stdin a pipe. The old `[[ -t 0 ]]`
    # gate then falsely reported non-interactive and skipped provisioning.
    # The /dev/tty-based fix is immune because /dev/tty tracks the controlling
    # terminal, not FD 0.
    #
    # Skip if /dev/tty isn't accessible in this runner (CI, headless VM).
    # The source-level regression guard above still enforces the invariant.
    if ! { : </dev/tty; } 2>/dev/null; then
        skip "no /dev/tty in this BATS runner — source-level guard covers the invariant"
    fi

    local age_log="${BATS_TEST_TMPDIR}/age.log"
    setup_chezmoi_with_encrypted_key

    # age fake: succeed (exit 0), write the key file, and log the invocation.
    fake age "
        echo \"\$@\" >> '${age_log}'
        if [[ \"\${1:-}\" == '-d' && \"\${2:-}\" == '-o' ]]; then
            echo 'AGE-SECRET-KEY-1FAKEPROVISIONED' > \"\${3}\"
            exit 0
        fi
        exit 1
    "

    # Simulate `curl ... | bash`: pipe the script into zsh so stdin is a pipe,
    # not a terminal. This is exactly the condition the old gate got wrong.
    run bash -c "cat '${LIFECYCLE_SCRIPT}' | zsh 2>&1"

    [ "${status}" -eq 0 ]
    # age -d WAS called even though stdin is a pipe (the /dev/tty fix works).
    [ -f "${age_log}" ] \
      || (echo "age was never invoked — /dev/tty fix may have broken" >&2; false)
    grep -q -- "^-d -o " "${age_log}" \
      || (echo "age log does not show a decrypt call: $(cat "${age_log}")" >&2; false)
    # The false-skip warning must NOT appear — /dev/tty was accessible.
    [[ "${output}" != *"No controlling terminal"* ]]
}

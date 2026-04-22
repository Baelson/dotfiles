#!/usr/bin/env bats
#
# test_bootstrap_install.bats — Unit coverage for bootstrap/install.sh.
#
# Focuses on the behaviors the ISSUE-019 design doc explicitly calls out:
#   - Missing Keychain entry → fail-fast with a useful recovery hint.
#   - ~/.netrc is mode 0600 during the chezmoi init window.
#   - Trap cleans ~/.netrc on failure (no plaintext PAT left on disk).
#   - Source-dir remote is flipped to SSH after a successful run.
#
# VM E2E (scripts/vm/vmctl.sh) is the authoritative integration test — this
# file is about isolated behavioral guarantees, using PATH-injected mocks for
# security, brew, chezmoi, and git.
#
# Notes on hermeticity:
#   - HOME is redirected to BATS_TEST_TMPDIR so real user netrc is untouched.
#   - PATH is stripped to "${FAKE_BIN}:/usr/bin:/bin" to starve the script of
#     real brew/chezmoi/git; fakes cover every external command the script
#     reaches under these scenarios.

BOOTSTRAP_SCRIPT="${BATS_TEST_DIRNAME%/tests/*}/bootstrap/install.sh"

setup() {
    export FAKE_BIN="${BATS_TEST_TMPDIR}/fake-bin"
    mkdir -p "${FAKE_BIN}"
    export HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "${HOME}"
    export USER="testuser"
    export PATH="${FAKE_BIN}:/usr/bin:/bin"
    export NETRC_SNAPSHOT="${BATS_TEST_TMPDIR}/netrc-snapshot"
    export GIT_LOG="${BATS_TEST_TMPDIR}/git.log"
}

# Write a fake executable into $FAKE_BIN.
# Usage: fake <name> <bash-body>
fake() {
    local name="$1"; shift
    local body="$*"
    {
        echo '#!/bin/bash'
        echo "${body}"
    } > "${FAKE_BIN}/${name}"
    chmod +x "${FAKE_BIN}/${name}"
}

# Convenience: the standard "healthy" fakes used by happy-path tests.
# brew + security(present, returns token) + chezmoi(init/apply/source-path)
# + git(record invocations).
setup_healthy_fakes() {
    # security: presence check (no -w) exits 0; -w prints a fake token.
    fake security '
        for arg in "$@"; do
            if [[ "${arg}" == "-w" ]]; then
                echo "ghp_faketoken1234567890abcdef"
                exit 0
            fi
        done
        exit 0
    '

    # brew: shellenv emits nothing (harmless to eval); everything else no-ops.
    fake brew '
        if [[ "${1:-}" == "shellenv" ]]; then
            echo ""
            exit 0
        fi
        exit 0
    '

    # chezmoi: init/apply no-op; source-path returns a writable tmp repo.
    fake chezmoi "
        case \"\${1:-}\" in
            source-path)
                mkdir -p \"\${BATS_TEST_TMPDIR}/fake-source/.git\"
                echo \"\${BATS_TEST_TMPDIR}/fake-source\"
                ;;
            init|apply)
                if [[ -f \"\${HOME}/.netrc\" ]]; then
                    stat -f '%Lp' \"\${HOME}/.netrc\" > \"${NETRC_SNAPSHOT}\" 2>/dev/null || true
                fi
                ;;
        esac
        exit 0
    "

    # git: record every invocation for remote-flip assertions.
    fake git "echo \"\$@\" >> \"${GIT_LOG}\"; exit 0"
}

# -----------------------------------------------------------------------------
# Source-tree invariants — not execution-dependent
# -----------------------------------------------------------------------------

@test "source tree: netrc placeholder uses private_ prefix (mode 0600 after apply)" {
    # Regression guard for ISSUE-022 sub-defect (b). Without the `private_`
    # prefix, chezmoi apply relaxes ~/.netrc from install.sh's 0600 back to
    # the default umask 0644, leaving loose perms on a credential file.
    local repo_root="${BATS_TEST_DIRNAME%/tests/*}"
    [ -f "${repo_root}/home/empty_private_dot_netrc" ]
    [ ! -f "${repo_root}/home/empty_dot_netrc" ]
}

# -----------------------------------------------------------------------------
# Static checks — no execution required
# -----------------------------------------------------------------------------

@test "bootstrap/install.sh: bash -n passes" {
    run bash -n "${BOOTSTRAP_SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "bootstrap/install.sh: shellcheck --severity=warning passes" {
    # Restore system PATH for this static check; fakes aren't relevant here.
    local real_shellcheck
    real_shellcheck="$(PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin command -v shellcheck || true)"
    if [[ -z "${real_shellcheck}" ]]; then
        skip "shellcheck not installed"
    fi
    run "${real_shellcheck}" --severity=warning "${BOOTSTRAP_SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "bootstrap/install.sh: has executable bit set" {
    [ -x "${BOOTSTRAP_SCRIPT}" ]
}

# -----------------------------------------------------------------------------
# Fail-fast: missing Keychain entry
# -----------------------------------------------------------------------------

@test "bootstrap: missing Keychain entry exits non-zero with recovery hint" {
    # Real `security` exits 44 when the item is absent — mirror that.
    fake security 'echo "security: SecKeychainSearchCopyNext: not found" >&2; exit 44'

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" =~ "Missing Keychain entry" ]]
    [[ "${output}" =~ "github-pat" ]]
    [[ "${output}" =~ "security add-generic-password" ]]
    [[ "${output}" =~ "testuser" ]]
    # Fail-fast must happen BEFORE brew install — i.e., the Homebrew install
    # banner text should not appear. We spell "Installing Homebrew" the way
    # install.sh does, to catch accidental reordering later.
    [[ ! "${output}" =~ "Installing Homebrew" ]]
}

@test "bootstrap: Keychain entry present but empty value exits non-zero" {
    # Presence (no -w) → exit 0; value (-w) → empty
    fake security '
        for arg in "$@"; do
            if [[ "${arg}" == "-w" ]]; then
                # Nothing on stdout.
                exit 0
            fi
        done
        exit 0
    '
    # Make brew install and chezmoi no-op so the script reaches the PAT fetch.
    fake brew '
        if [[ "${1:-}" == "shellenv" ]]; then echo ""; fi
        exit 0
    '

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -ne 0 ]
    [[ "${output}" =~ "empty value" ]]
}

# -----------------------------------------------------------------------------
# ~/.netrc lifecycle
# -----------------------------------------------------------------------------

@test "bootstrap: netrc is mode 0600 at the moment chezmoi init is called" {
    setup_healthy_fakes

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -f "${NETRC_SNAPSHOT}" ]
    local mode
    mode="$(cat "${NETRC_SNAPSHOT}")"
    # stat -f '%Lp' on BSD/macOS returns just the permission bits, e.g. "600".
    [ "${mode}" = "600" ]
}

@test "bootstrap: ~/.netrc is empty (scrubbed but not deleted) after a successful run" {
    # home/empty_private_dot_netrc makes chezmoi own ~/.netrc as a 0600-mode
    # empty file (the `private_` prefix ensures apply keeps the tight perms).
    # Bootstrap must truncate, not delete, to avoid chezmoi drift on subsequent
    # apply calls. We verify both: the file still exists AND has zero length.
    setup_healthy_fakes

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -f "${HOME}/.netrc" ]
    [ ! -s "${HOME}/.netrc" ]
    # Must also still be 0600 so a subsequent real PAT write inherits tight perms.
    local mode
    mode="$(stat -f '%Lp' "${HOME}/.netrc")"
    [ "${mode}" = "600" ]
}

@test "bootstrap: trap scrubs ~/.netrc contents when chezmoi init fails mid-run" {
    fake security '
        for arg in "$@"; do
            if [[ "${arg}" == "-w" ]]; then echo "ghp_faketoken"; exit 0; fi
        done
        exit 0
    '
    fake brew '
        if [[ "${1:-}" == "shellenv" ]]; then echo ""; fi
        exit 0
    '
    # chezmoi init fails; trap must fire.
    fake chezmoi '
        if [[ "${1:-}" == "init" ]]; then
            echo "simulated init failure" >&2
            exit 1
        fi
        exit 0
    '
    fake git 'exit 0'

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -ne 0 ]
    # Trap must have truncated the file. Either absent (never written, e.g.
    # init failed before Step 4) OR present-and-empty is acceptable; the
    # invariant is "no plaintext token value survives".
    if [[ -f "${HOME}/.netrc" ]]; then
        [ ! -s "${HOME}/.netrc" ]
    fi
}

# -----------------------------------------------------------------------------
# Remote URL flip
# -----------------------------------------------------------------------------

@test "bootstrap: source-dir remote is set to SSH URL after successful run" {
    setup_healthy_fakes

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -f "${GIT_LOG}" ]
    grep -q -- "-C .* remote set-url origin git@github.com:Baelson/dotfiles.git" "${GIT_LOG}"
}

@test "bootstrap: apply-with-scripts failure still flips remote to SSH and scrubs netrc" {
    # Scenario: chezmoi apply --include=scripts exits non-zero (e.g., a flaky
    # cask download). Install.sh must still do the remote-flip + netrc scrub,
    # then surface the apply exit code at the end. This is the critical
    # regression from the first E2E run on the bare VM.
    fake security '
        for arg in "$@"; do
            if [[ "${arg}" == "-w" ]]; then echo "ghp_faketoken"; exit 0; fi
        done
        exit 0
    '
    fake brew '
        if [[ "${1:-}" == "shellenv" ]]; then echo ""; fi
        exit 0
    '
    fake chezmoi "
        case \"\${1:-}\" in
            source-path)
                mkdir -p \"\${BATS_TEST_TMPDIR}/fake-source/.git\"
                echo \"\${BATS_TEST_TMPDIR}/fake-source\"
                ;;
            apply)
                # This is the --include=scripts --force call. Fail it.
                # (init is also 'chezmoi init', not 'apply', so we only fail 'apply'.)
                echo 'simulated cask download timeout' >&2
                exit 1
                ;;
            init)
                # init --apply succeeds quietly
                ;;
        esac
        exit 0
    "
    fake git "echo \"\$@\" >> \"${GIT_LOG}\"; exit 0"

    run bash "${BOOTSTRAP_SCRIPT}"

    # Exit code should match the apply failure (propagated at the end)
    [ "${status}" -ne 0 ]
    # Output should note the partial-success state
    [[ "${output}" =~ "partially succeeded" || "${output}" =~ "Continuing to remote-flip" ]]
    # Remote-flip MUST have happened even though apply failed
    [ -f "${GIT_LOG}" ]
    grep -q -- "remote set-url origin git@github.com:Baelson/dotfiles.git" "${GIT_LOG}"
    # netrc must be truncated (or absent) — no plaintext PAT left on disk
    if [[ -f "${HOME}/.netrc" ]]; then
        [ ! -s "${HOME}/.netrc" ]
    fi
}

@test "bootstrap: remote-flip works when source-path is a child of the git checkout" {
    # chezmoi with .chezmoiroot puts the source at <checkout>/home, so .git
    # lives one level up from source-path. Install.sh must find it either way.
    fake security '
        for arg in "$@"; do
            if [[ "${arg}" == "-w" ]]; then echo "ghp_faketoken"; exit 0; fi
        done
        exit 0
    '
    fake brew '
        if [[ "${1:-}" == "shellenv" ]]; then echo ""; fi
        exit 0
    '
    fake chezmoi "
        case \"\${1:-}\" in
            source-path)
                mkdir -p \"\${BATS_TEST_TMPDIR}/fake-checkout/.git\"
                mkdir -p \"\${BATS_TEST_TMPDIR}/fake-checkout/home\"
                # source lives at checkout/home (matches .chezmoiroot layout)
                echo \"\${BATS_TEST_TMPDIR}/fake-checkout/home\"
                ;;
        esac
        exit 0
    "
    fake git "echo \"\$@\" >> \"${GIT_LOG}\"; exit 0"

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -f "${GIT_LOG}" ]
    grep -q -- "remote set-url origin git@github.com:Baelson/dotfiles.git" "${GIT_LOG}"
    # The -C path should be the checkout dir (parent of source-path), not the source-path itself
    grep -qE -- "-C [^ ]*fake-checkout remote set-url" "${GIT_LOG}"
}

@test "bootstrap: init invocation uses --exclude=encrypted,scripts" {
    # Capture chezmoi args separately for this assertion.
    local chezmoi_log="${BATS_TEST_TMPDIR}/chezmoi.log"
    fake security '
        for arg in "$@"; do
            if [[ "${arg}" == "-w" ]]; then echo "ghp_faketoken"; exit 0; fi
        done
        exit 0
    '
    fake brew '
        if [[ "${1:-}" == "shellenv" ]]; then echo ""; fi
        exit 0
    '
    fake chezmoi "
        echo \"\$@\" >> \"${chezmoi_log}\"
        if [[ \"\${1:-}\" == \"source-path\" ]]; then
            mkdir -p \"\${BATS_TEST_TMPDIR}/fake-source/.git\"
            echo \"\${BATS_TEST_TMPDIR}/fake-source\"
        fi
        exit 0
    "
    fake git 'exit 0'

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    # init line must carry both the apply flag and the exclude set.
    grep -q -- "init --apply --exclude=encrypted,scripts https://github.com/Baelson/dotfiles.git" "${chezmoi_log}"
    # Secondary apply must be a full pass (no --include=scripts gating) so
    # encrypted files decrypt + deploy in the same run that provisions the
    # age key via run_once_before_provision-age-key.sh.
    grep -q -- "apply --force" "${chezmoi_log}"
    # Regression guard: the old --include=scripts form limited the pass to
    # scripts only and left encrypted files on disk as stubs.
    ! grep -q -- "apply --include=scripts" "${chezmoi_log}"
}

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

@test "bootstrap: ~/.netrc is absent after a successful run" {
    setup_healthy_fakes

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ ! -f "${HOME}/.netrc" ]
}

@test "bootstrap: trap scrubs ~/.netrc when chezmoi init fails mid-run" {
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
    [ ! -f "${HOME}/.netrc" ]
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
    # Secondary apply must target scripts explicitly.
    grep -q -- "apply --include=scripts --force" "${chezmoi_log}"
}

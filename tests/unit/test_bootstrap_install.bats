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

# -----------------------------------------------------------------------------
# ISSUE-022 fix — age-key ordering invariant
#
# The bootstrap must call, in order:
#   1. chezmoi init <URL>     (clone only; config rendered without [age] block)
#   2. provision_age_key      (decrypt bootstrap/key.txt.age into ~/.config/chezmoi/key.txt
#                              if TTY + age present; else skip with a warning)
#   3. chezmoi init           (regen chezmoi.toml — [age] block now emitted if
#                              the key was provisioned)
#   4. chezmoi apply --force  (single-pass deploy of files, encrypted files,
#                              and lifecycle scripts)
# The older, pre-ISSUE-022 form (`chezmoi init --apply --exclude=encrypted,scripts`)
# MUST NOT appear — it rendered the config without [age] and forced manual
# recovery on the 2026-04-21 VM walk.
# -----------------------------------------------------------------------------

@test "ISSUE-022 regression guard: install.sh source encodes the age-key ordering invariant" {
    # Static assertion against the script text: the order of operations
    # (init clone → provision age key → init regen → apply) is enforced by
    # the SOURCE order of these calls. If someone reverts the ordering
    # (e.g. back to a single `chezmoi init --apply --exclude=encrypted,scripts`),
    # this test fails regardless of runtime behavior.
    local src="${BOOTSTRAP_SCRIPT}"

    # Line numbers of the four anchor points.
    local ln_init_clone ln_provision ln_init_regen ln_apply
    ln_init_clone=$(grep -n 'chezmoi init "${REPO_HTTPS_URL}"' "${src}" | head -1 | cut -d: -f1)
    ln_provision=$(grep -n '^provision_age_key$' "${src}" | head -1 | cut -d: -f1)
    # Second `chezmoi init` has no URL — look for the bare invocation (not the function definition).
    ln_init_regen=$(grep -n '^chezmoi init$' "${src}" | head -1 | cut -d: -f1)
    # Anchor on start-of-line so the docstring references (`# chezmoi apply --force`)
    # don't beat the real invocation to the top of grep's output.
    ln_apply=$(grep -n '^chezmoi apply --force' "${src}" | head -1 | cut -d: -f1)

    [ -n "${ln_init_clone}" ]  || (echo "missing: chezmoi init clone line" >&2; false)
    [ -n "${ln_provision}" ]   || (echo "missing: provision_age_key call line" >&2; false)
    [ -n "${ln_init_regen}" ]  || (echo "missing: chezmoi init regen line" >&2; false)
    [ -n "${ln_apply}" ]       || (echo "missing: chezmoi apply --force line" >&2; false)

    # Strict ordering: each anchor appears strictly after the previous one.
    [ "${ln_init_clone}" -lt "${ln_provision}" ]
    [ "${ln_provision}" -lt "${ln_init_regen}" ]
    [ "${ln_init_regen}" -lt "${ln_apply}" ]

    # Hard regression guards against the two known-bad forms:
    #   - pre-ISSUE-022: "init --apply --exclude=encrypted,scripts" rendered
    #     config without [age]
    #   - pre-ISSUE-019 encrypted-apply fix: "apply --include=scripts" limited
    #     the pass to scripts only, never deploying encrypted files
    ! grep -q -- "init --apply --exclude=encrypted,scripts" "${src}"
    ! grep -q -- "apply --include=scripts" "${src}"
}

@test "ISSUE-022: runtime sequence is init-clone → provision → init-regen → apply --force" {
    # Runtime assertion: fake chezmoi logs every invocation; verify the
    # sequence of calls matches the ISSUE-022 ordering. BATS runs without
    # a TTY on stdin by default, so provision_age_key skips gracefully with
    # a warning — the init/apply sequence itself is independent of that skip.
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
    # age fake is present but should never be called under non-TTY;
    # presence guards against command-not-found masking the TTY-skip path.
    fake age 'echo "age should not be invoked under non-TTY" >&2; exit 2'
    fake chezmoi "
        echo \"\$@\" >> \"${chezmoi_log}\"
        case \"\${1:-}\" in
            source-path)
                mkdir -p \"\${BATS_TEST_TMPDIR}/fake-source/.git\"
                echo \"\${BATS_TEST_TMPDIR}/fake-source\"
                ;;
        esac
        exit 0
    "
    fake git 'exit 0'

    # Capture stderr (log_warn writes there) alongside stdout so we can assert
    # the non-TTY skip warning appeared. BATS `run` only captures stdout by
    # default; wrapping in `bash -c` + `2>&1` merges the streams.
    run bash -c "bash '${BOOTSTRAP_SCRIPT}' 2>&1"

    [ "${status}" -eq 0 ]

    # Explicit ordering via line numbers in the captured log. The chezmoi
    # fake records every invocation as one line; we assert:
    #   - line with `init https://...` appears first (clone)
    #   - bare `init` appears second (regen)
    #   - `apply --force` appears last
    local first_init_line second_init_line apply_line
    first_init_line=$(grep -n '^init https' "${chezmoi_log}" | head -1 | cut -d: -f1)
    second_init_line=$(grep -n '^init$' "${chezmoi_log}" | head -1 | cut -d: -f1)
    apply_line=$(grep -n '^apply --force' "${chezmoi_log}" | head -1 | cut -d: -f1)
    [ -n "${first_init_line}" ]  || (cat "${chezmoi_log}" >&2; false)
    [ -n "${second_init_line}" ] || (cat "${chezmoi_log}" >&2; false)
    [ -n "${apply_line}" ]       || (cat "${chezmoi_log}" >&2; false)
    [ "${first_init_line}" -lt "${second_init_line}" ]
    [ "${second_init_line}" -lt "${apply_line}" ]

    # provision_age_key must produce one of its documented diagnostics — any
    # of its four early-exit branches is acceptable here. The common
    # substring "encrypted files will not deploy" covers three skip branches
    # (missing-age, missing-encrypted-key, non-TTY); the fourth branch
    # (wrong passphrase) uses "continuing without encryption".
    [[ "${output}" == *"encrypted files will not deploy"* ]] || \
      [[ "${output}" == *"continuing without encryption"* ]]
}

@test "ISSUE-022: missing age binary warns and continues without aborting" {
    # Negative path: if the 'age' tool is somehow absent (shouldn't happen
    # post-Step 3, but guard against a broken Homebrew install), the
    # provisioner must warn and let the rest of the bootstrap proceed.
    setup_healthy_fakes
    # Explicitly leave 'age' out of FAKE_BIN — it's not in the base system
    # PATH either (/usr/bin:/bin), so `command -v age` will return non-zero.

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    # The age-missing warning is a specific branch distinct from the
    # non-TTY branch (the latter is what the other ISSUE-022 test exercises).
    # If `age` isn't in FAKE_BIN AND stdin isn't a TTY, both conditions hold;
    # the `age`-missing check in provision_age_key runs first, so that
    # warning is the one we should see.
    [[ "${output}" == *"age not installed"* ]] || \
      [[ "${output}" == *"Non-interactive session"* ]]   # acceptable fallback
    # Final apply still ran despite age being missing (encrypted files stay
    # as stubs, but that's the documented degrade-gracefully behavior).
    [ -f "${GIT_LOG}" ]
    grep -q -- "remote set-url origin git@github.com:Baelson/dotfiles.git" "${GIT_LOG}"
}

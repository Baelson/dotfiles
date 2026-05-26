#!/usr/bin/env bats
#
# test_bootstrap_install.bats — Unit coverage for setup.sh.
#
# Focuses on the behaviors that the Phase-5L thin-wrapper architecture
# explicitly calls out:
#   - Subprocess stdin redirected to /dev/null (curl|bash pipe-consumption guard).
#   - Age Keychain fast-path: present → staged; absent → non-fatal log + continue.
#   - Source-dir remote is flipped to SSH after a successful run (transport only,
#     guarded by the 2026-05-19 P0 fix — only when origin is the public dotfiles repo).
#   - Step 6 remote-flip guard: skips when origin is not the canonical public repo.
#   - ISSUE-022 ordering invariant: init-clone → apply → regen-init → apply.
#
# VM E2E (run from a fresh machine or VM) is the authoritative end-to-end test;
# this file covers isolated behavioral guarantees via PATH-injected mocks.
#
# Notes on hermeticity:
#   - HOME is redirected to BATS_TEST_TMPDIR so real user files are untouched.
#   - PATH is stripped to "${FAKE_BIN}:/usr/bin:/bin" to starve the script of
#     real security/chezmoi/git; fakes cover every external command reached.

BOOTSTRAP_SCRIPT="${BATS_TEST_DIRNAME%/tests/*}/setup.sh"

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

    # git: record every invocation for remote-flip assertions, AND answer
    # `git -C <dir> remote get-url origin` with the canonical public-dotfiles
    # HTTPS URL so the Step 6 transport-flip guard (post-2026-05-19 P0 fix) is
    # satisfied and the SSH flip proceeds. Per-test fakes that need a
    # different origin override this with `fake_git_with_origin <url>` below.
    fake git "
        if [[ \"\${3:-}\" == 'remote' ]] && [[ \"\${4:-}\" == 'get-url' ]]; then
            echo 'https://github.com/Baelson/dotfiles.git'
            exit 0
        fi
        echo \"\$@\" >> \"${GIT_LOG}\"
        exit 0
    "
}

# Helper for the WS3 transport-flip guard tests (2026-05-19 P0 fix):
# install a git fake that returns a specific URL for `remote get-url origin`,
# logs everything else to ${GIT_LOG}. Pass an empty string to make get-url
# fail (mimicking real git's behavior when origin is unset).
fake_git_with_origin() {
    local origin_url="$1"
    fake git "
        if [[ \"\${3:-}\" == 'remote' ]] && [[ \"\${4:-}\" == 'get-url' ]]; then
            if [[ -n '${origin_url}' ]]; then
                echo '${origin_url}'
                exit 0
            else
                exit 1
            fi
        fi
        echo \"\$@\" >> \"${GIT_LOG}\"
        exit 0
    "
}

# Helper for the WS3 transport-flip guard tests:
# pre-stage a fake AGE_KEY_FILE so setup.sh Step 2 takes the "already present"
# branch (line 89) and doesn't fail the AGE-SECRET-KEY format check that's
# tripped by `setup_healthy_fakes`'s `security -w` returning a github token
# for every -w query. This unblocks Step 6 (the guard under test) from
# executing. NOT a behavioral assertion — purely harness setup.
prestage_fake_age_key() {
    mkdir -p "${HOME}/.config/chezmoi"
    echo 'AGE-SECRET-KEY-1FAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE' \
        > "${HOME}/.config/chezmoi/key.txt"
    chmod 600 "${HOME}/.config/chezmoi/key.txt"
}

# -----------------------------------------------------------------------------
# curl|bash stdin safety
# -----------------------------------------------------------------------------

@test "ISSUE-022 curl|bash-safety: every subprocess call redirects stdin to /dev/null" {
    # Regression guard for the pipe-consumption bug. When setup.sh is run via
    # `curl ... | bash`, bash's stdin IS the pipe containing the remaining
    # script bytes. Any subprocess that reads FD 0 consumes those bytes,
    # truncating the rest of the script and causing bash to exit 0 mid-bootstrap.
    # chezmoi's embedded go-git, `chezmoi apply` lifecycle scripts, and the
    # get.chezmoi.io installer can all read stdin. Every such call MUST redirect
    # stdin from /dev/null.
    #
    # This test enumerates the canonical call sites in the Phase-5L thin-wrapper
    # and asserts each has </dev/null.
    local src="${BOOTSTRAP_SCRIPT}"

    # 1. chezmoi installer via get.chezmoi.io (single-line call).
    grep -qE 'get\.chezmoi\.io.*</dev/null' "${src}" \
      || (echo "get.chezmoi.io installer is missing </dev/null" >&2; false)

    # 2. chezmoi init <URL>  (Step 3, clone with --use-builtin-git=on).
    grep -qE 'chezmoi init --use-builtin-git=on.*</dev/null' "${src}" \
      || (echo "chezmoi init --use-builtin-git=on <URL> is missing </dev/null" >&2; false)

    # 3. chezmoi apply --force (Steps 4 and 5 — same pattern, multiple occurrences).
    grep -qE 'chezmoi apply --force </dev/null' "${src}" \
      || (echo "chezmoi apply --force is missing </dev/null" >&2; false)

    # 4. chezmoi init (Step 5, regen — bare init with no URL).
    grep -qE 'chezmoi init </dev/null' "${src}" \
      || (echo "chezmoi init regen (Step 5) is missing </dev/null" >&2; false)
}

# -----------------------------------------------------------------------------
# Static checks — no execution required
# -----------------------------------------------------------------------------

@test "setup.sh: bash -n passes" {
    run bash -n "${BOOTSTRAP_SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "setup.sh: shellcheck --severity=warning passes" {
    # Restore system PATH for this static check; fakes aren't relevant here.
    local real_shellcheck
    real_shellcheck="$(PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin command -v shellcheck || true)"
    if [[ -z "${real_shellcheck}" ]]; then
        skip "shellcheck not installed"
    fi
    run "${real_shellcheck}" --severity=warning "${BOOTSTRAP_SCRIPT}"
    [ "${status}" -eq 0 ]
}

@test "setup.sh: has executable bit set" {
    [ -x "${BOOTSTRAP_SCRIPT}" ]
}

# -----------------------------------------------------------------------------
# Keychain behavior (Phase-5L: missing entry is non-fatal)
# -----------------------------------------------------------------------------

@test "bootstrap: missing Keychain entry is non-fatal — logs fallback message and continues" {
    # Phase-5L change: the dotfiles-age Keychain entry is optional, not required.
    # setup.sh logs a fallback message and continues with KEY_PRESTAGED=0.
    # Age provisioning falls back to the lifecycle script (passphrase prompt).
    setup_healthy_fakes
    # Override: presence check (no -w) exits 44 → entry absent.
    fake security 'exit 44'

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "will fall back to passphrase" ]]
}

# -----------------------------------------------------------------------------
# Remote URL flip
# -----------------------------------------------------------------------------

@test "bootstrap: apply-with-scripts failure still flips remote to SSH" {
    # Scenario: chezmoi apply exits non-zero (e.g., a flaky cask download).
    # setup.sh must still do the remote-flip, then surface the apply exit code.
    prestage_fake_age_key   # bypass AGE-key validation; KEY_PRESTAGED=1

    fake brew 'if [[ "${1:-}" == "shellenv" ]]; then echo ""; fi; exit 0'
    fake chezmoi "
        case \"\${1:-}\" in
            source-path)
                mkdir -p \"\${BATS_TEST_TMPDIR}/fake-source/.git\"
                echo \"\${BATS_TEST_TMPDIR}/fake-source\"
                ;;
            apply)
                echo 'simulated cask download timeout' >&2
                exit 1
                ;;
            init)
                ;;
        esac
        exit 0
    "
    fake_git_with_origin 'https://github.com/Baelson/dotfiles.git'

    run bash -c "bash '${BOOTSTRAP_SCRIPT}' 2>&1"

    # Exit code propagates the apply failure
    [ "${status}" -ne 0 ]
    # Remote-flip MUST have happened even though apply failed
    [ -f "${GIT_LOG}" ]
    grep -q -- "remote set-url origin git@github.com:Baelson/dotfiles.git" "${GIT_LOG}"
    # Partial-success warning and apply-failure message are surfaced
    [[ "${output}" =~ "partially succeeded" || "${output}" =~ "Continuing; will surface at end" ]]
}

@test "bootstrap: remote-flip works when source-path is a child of the git checkout" {
    # chezmoi with .chezmoiroot puts the source at <checkout>/home, so .git
    # lives one level up from source-path. setup.sh must find it either way.
    prestage_fake_age_key

    fake brew 'if [[ "${1:-}" == "shellenv" ]]; then echo ""; fi; exit 0'
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
    fake_git_with_origin 'https://github.com/Baelson/dotfiles.git'

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -f "${GIT_LOG}" ]
    grep -q -- "remote set-url origin git@github.com:Baelson/dotfiles.git" "${GIT_LOG}"
    # The -C path should be the checkout dir (parent of source-path), not source-path itself
    grep -qE -- "-C [^ ]*fake-checkout remote set-url" "${GIT_LOG}"
}

# -----------------------------------------------------------------------------
# 2026-05-19 P0 security fix — transport-flip guard on Step 6.
#
# setup.sh Step 6 used to unconditionally repoint `origin` of the chezmoi
# source-dir to git@github.com:Baelson/dotfiles.git. Post-Phase-5M.1 the
# sourceDir resolves to a sibling PRIVATE dotfiles-private checkout, so the
# flip silently cross-repointed the private repo's origin to the public one.
# A subsequent `git push origin main` on 2026-05-19 nearly leaked 399 private
# commits; only GitHub's non-fast-forward rejection prevented the leak.
#
# The fix wraps the `remote set-url` in a transport-only guard: flip ONLY when
# origin already resolves to one of the canonical public-Baelson/dotfiles URL
# shapes. The four tests below assert the guarded behavior. They double as the
# corrected rows 11/12/13 of the BATS public-bootstrap refactor handoff plus a
# fifth shape (#11 from the [ESCALATE-A] Opus review) covering the most
# security-critical non-match — an embedded-credential HTTPS URL.
# -----------------------------------------------------------------------------

@test "bootstrap (P0 guard): remote-flip is SKIPPED when origin is dotfiles-private" {
    # The exact hazard this fix exists to prevent: source-path origin is the
    # PRIVATE repo (post-5M.1 normal state); Step 6 must NOT repoint it.
    setup_healthy_fakes
    prestage_fake_age_key
    fake_git_with_origin 'git@github.com:Baelson/dotfiles-private.git'

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    # Behavioral: no `remote set-url` was ever called.
    # GIT_LOG may not exist in the SKIP path — the fake's `remote get-url`
    # branch returns before logging, and no other git call follows. The grep
    # against a missing file exits nonzero, which `!` converts to a pass.
    ! grep -q -- 'remote set-url' "${GIT_LOG}" 2>/dev/null
    # The skip path executed (warning surfaced — proves it wasn't silently noop):
    [[ "${output}" =~ "SKIPPING remote-flip" ]]
    [[ "${output}" =~ "dotfiles-private" || "${output}" =~ "non-public" ]]
}

@test "bootstrap (P0 guard): remote-flip ALLOWED when origin is public dotfiles HTTPS" {
    # Fork-user happy path: cloned via HTTPS, Step 6 upgrades transport to SSH.
    setup_healthy_fakes
    prestage_fake_age_key
    fake_git_with_origin 'https://github.com/Baelson/dotfiles.git'

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    [ -f "${GIT_LOG}" ]
    grep -q -- "remote set-url origin git@github.com:Baelson/dotfiles.git" "${GIT_LOG}"
}

@test "bootstrap (P0 guard): remote-flip is SKIPPED when origin is a foreign repo" {
    # Defense-in-depth: any third-party origin (e.g. a fork that re-pointed)
    # must not be repointed by our installer.
    setup_healthy_fakes
    prestage_fake_age_key
    fake_git_with_origin 'git@github.com:SomeOtherUser/somerepo.git'

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    # GIT_LOG may not exist in the SKIP path — the fake's `remote get-url`
    # branch returns before logging, and no other git call follows. The grep
    # against a missing file exits nonzero, which `!` converts to a pass.
    ! grep -q -- 'remote set-url' "${GIT_LOG}" 2>/dev/null
    [[ "${output}" =~ "SKIPPING remote-flip" ]]
}

@test "bootstrap (P0 guard): remote-flip is SKIPPED when origin is unset" {
    # Real git exits non-zero when origin is unset; the fake_git_with_origin
    # helper mimics that by exiting 1 when passed an empty URL.
    setup_healthy_fakes
    prestage_fake_age_key
    fake_git_with_origin ''

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    # GIT_LOG may not exist in the SKIP path — the fake's `remote get-url`
    # branch returns before logging, and no other git call follows. The grep
    # against a missing file exits nonzero, which `!` converts to a pass.
    ! grep -q -- 'remote set-url' "${GIT_LOG}" 2>/dev/null
    [[ "${output}" =~ "SKIPPING remote-flip" ]]
    [[ "${output}" =~ "<unset>" ]]
}

@test "bootstrap (P0 guard): remote-flip is SKIPPED when origin embeds basic-auth creds" {
    # [ESCALATE-A] Opus-review shape #11: an HTTPS URL with embedded
    # user:token@ MUST not be repointed — flipping would clobber a remote the
    # user may have intentionally configured with credentials. The current
    # case arms intentionally do not match this shape; this test pins that.
    setup_healthy_fakes
    prestage_fake_age_key
    fake_git_with_origin 'https://user:token@github.com/Baelson/dotfiles.git'

    run bash "${BOOTSTRAP_SCRIPT}"

    [ "${status}" -eq 0 ]
    # GIT_LOG may not exist in the SKIP path — the fake's `remote get-url`
    # branch returns before logging, and no other git call follows. The grep
    # against a missing file exits nonzero, which `!` converts to a pass.
    ! grep -q -- 'remote set-url' "${GIT_LOG}" 2>/dev/null
    [[ "${output}" =~ "SKIPPING remote-flip" ]]
}

# -----------------------------------------------------------------------------
# ISSUE-022 fix — ordering and runtime sequence invariants
#
# Phase-5L architecture: age key provisioning moved from a function inside
# setup.sh into the chezmoi lifecycle script
# `home/.chezmoiscripts/darwin/run_once_before_provision-age-key.sh`.
# setup.sh's job is now: init-clone → apply (first pass, runs lifecycle
# scripts) → [if key provisioned: regen-init + apply second pass] → SSH flip.
# See test_provision_age_key.bats for lifecycle-script behavioral tests.
# -----------------------------------------------------------------------------

@test "ISSUE-022 regression guard: setup.sh source encodes init-clone→apply→regen-init order" {
    # Static assertion against the script text: the ordering of the three
    # anchor call sites must be init-clone < apply-first < regen-init.
    # If someone reverts the ordering (e.g. back to a single
    # `chezmoi init --apply --exclude=encrypted,scripts`), this test fails
    # regardless of runtime behavior.
    local src="${BOOTSTRAP_SCRIPT}"

    local ln_init_clone ln_apply_first ln_init_regen
    # Step 3: init with URL and --use-builtin-git=on
    ln_init_clone=$(grep -nE 'chezmoi init --use-builtin-git=on.*REPO_HTTPS_URL' "${src}" | head -1 | cut -d: -f1)
    # Step 4: first apply — anchor to column 0 to skip header-comment references
    # (setup.sh header mentions `chezmoi apply --force` in its docstring; `^chezmoi`
    # matches only real invocations at the start of the line, not comment lines).
    ln_apply_first=$(grep -nE '^chezmoi apply --force' "${src}" | head -1 | cut -d: -f1)
    # Step 5: regen init — bare `chezmoi init </dev/null` (no URL, inside the if block)
    ln_init_regen=$(grep -nE '^\s+chezmoi init </dev/null' "${src}" | head -1 | cut -d: -f1)

    [ -n "${ln_init_clone}" ]  || (echo "missing: chezmoi init --use-builtin-git=on clone" >&2; false)
    [ -n "${ln_apply_first}" ] || (echo "missing: chezmoi apply --force first pass" >&2; false)
    [ -n "${ln_init_regen}" ]  || (echo "missing: chezmoi init regen (Step 5)" >&2; false)

    # Strict ordering: each anchor appears strictly after the previous one.
    [ "${ln_init_clone}" -lt "${ln_apply_first}" ]
    [ "${ln_apply_first}" -lt "${ln_init_regen}" ]

    # Hard regression guards against the three known-bad forms:
    #   - pre-ISSUE-022: "init --apply --exclude=encrypted,scripts" rendered
    #     config without [age]
    #   - pre-ISSUE-019 encrypted-apply fix: "apply --include=scripts" limited
    #     the pass to scripts only, never deploying encrypted files
    ! grep -q -- "init --apply --exclude=encrypted,scripts" "${src}"
    ! grep -q -- "apply --include=scripts" "${src}"
}

@test "ISSUE-022: runtime sequence is init-clone → apply → regen-init → apply (two-pass path)" {
    # Runtime assertion: fake chezmoi logs every invocation; verify the
    # sequence matches the ISSUE-022 two-pass ordering. The regen path fires
    # when KEY_PRESTAGED=0 AND the lifecycle script provisions key.txt during
    # the first apply. We simulate that by having the chezmoi apply fake
    # create key.txt — the regen condition then evaluates to true.
    local chezmoi_log="${BATS_TEST_TMPDIR}/chezmoi.log"

    # KEY_PRESTAGED=0: no Keychain entry (security returns not-found, exit 44).
    fake security 'exit 44'
    fake brew 'if [[ "${1:-}" == "shellenv" ]]; then echo ""; fi; exit 0'
    fake age 'exit 0'
    fake chezmoi "
        echo \"\$@\" >> \"${chezmoi_log}\"
        case \"\${1:-}\" in
            source-path)
                mkdir -p \"\${BATS_TEST_TMPDIR}/fake-source/.git\"
                echo \"\${BATS_TEST_TMPDIR}/fake-source\"
                ;;
            apply)
                # Simulate lifecycle script provisioning the age key on first apply.
                # Triggers the Step 5 regen condition (KEY_PRESTAGED=0 && key.txt exists).
                mkdir -p \"\${HOME}/.config/chezmoi\"
                echo 'AGE-SECRET-KEY-1FAKEFAKEFAKEFAKE' > \"\${HOME}/.config/chezmoi/key.txt\"
                ;;
        esac
        exit 0
    "
    fake_git_with_origin 'https://github.com/Baelson/dotfiles.git'

    run bash -c "bash '${BOOTSTRAP_SCRIPT}' 2>&1"

    [ "${status}" -eq 0 ]
    [ -f "${chezmoi_log}" ] || (echo "chezmoi was never called" >&2; false)

    # Verify init-clone → apply-first → regen-init → apply-second ordering
    # via line numbers in the captured invocation log.
    local ln_init_clone ln_apply_first ln_init_regen ln_apply_second
    ln_init_clone=$(grep -n '^init --use-builtin-git=on https' "${chezmoi_log}" | head -1 | cut -d: -f1)
    ln_apply_first=$(grep -n '^apply --force' "${chezmoi_log}" | head -1 | cut -d: -f1)
    ln_init_regen=$(grep -n '^init$' "${chezmoi_log}" | head -1 | cut -d: -f1)
    ln_apply_second=$(grep -n '^apply --force' "${chezmoi_log}" | tail -1 | cut -d: -f1)

    [ -n "${ln_init_clone}" ]   || (cat "${chezmoi_log}" >&2; false)
    [ -n "${ln_apply_first}" ]  || (cat "${chezmoi_log}" >&2; false)
    [ -n "${ln_init_regen}" ]   || (cat "${chezmoi_log}" >&2; false)
    [ -n "${ln_apply_second}" ] || (cat "${chezmoi_log}" >&2; false)

    [ "${ln_init_clone}" -lt "${ln_apply_first}" ]
    [ "${ln_apply_first}" -lt "${ln_init_regen}" ]
    [ "${ln_init_regen}" -lt "${ln_apply_second}" ]
}

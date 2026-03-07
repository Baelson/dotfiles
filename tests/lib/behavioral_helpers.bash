#!/usr/bin/env bash
#
# Behavioral assertion helpers used by FR-7 debug mode tests.
#

assert_success() {
    # shellcheck disable=SC2154 # status is provided by bats.
    if [[ "$status" -ne 0 ]]; then
        echo "Expected command success, got exit code: $status" >&2
        echo "Output:" >&2
        echo "$output" >&2
        return 1
    fi
}

assert_failure() {
    # shellcheck disable=SC2154 # status is provided by bats.
    if [[ "$status" -eq 0 ]]; then
        echo "Expected command failure, but it succeeded." >&2
        echo "Output:" >&2
        echo "$output" >&2
        return 1
    fi
}

assert_argument_processed() {
    local expected_flag="$1"
    if [[ "$output" =~ $expected_flag ]]; then
        return 0
    fi
    # Check for flag-specific behavioral evidence (not generic keywords)
    case "$expected_flag" in
        *dry-run*)  if [[ "$output" =~ "DRY RUN" ]]; then return 0; fi ;;
        *verbose*)  if [[ "$output" =~ "DEBUG" ]]; then return 0; fi ;;
        *trace*)    if [[ "$output" =~ "TRACE" ]]; then return 0; fi ;;
    esac
    echo "Expected output evidence for flag: $expected_flag" >&2
    echo "Output:" >&2
    echo "$output" >&2
    return 1
}

assert_no_errors_in_output() {
    local output_lower
    output_lower="$(printf "%s" "$output" | tr '[:upper:]' '[:lower:]')"
    if [[ "$output_lower" =~ "command not found" ]] || [[ "$output_lower" =~ "syntax error" ]] || [[ "$output_lower" =~ "setup interrupted" ]]; then
        echo "Unexpected error output found." >&2
        echo "$output" >&2
        return 1
    fi
}

assert_no_system_modifications() {
    local snapshot_before="$1"
    local snapshot_after="$2"
    local before_filtered="$BATS_TEST_TMPDIR/before_filtered.txt"
    local after_filtered="$BATS_TEST_TMPDIR/after_filtered.txt"

    grep -v -E "snapshot_(before|after)\\.txt$" "$snapshot_before" | sort > "$before_filtered" || true
    grep -v -E "snapshot_(before|after)\\.txt$" "$snapshot_after" | sort > "$after_filtered" || true

    if ! diff -u "$before_filtered" "$after_filtered" >/dev/null 2>&1; then
        echo "Detected filesystem modifications in dry-run mode." >&2
        diff -u "$before_filtered" "$after_filtered" >&2 || true
        return 1
    fi
}

assert_success_indicators_present() {
    if [[ ! "$output" =~ "completed successfully" ]] && [[ ! "$output" =~ "Setup completed successfully" ]] && [[ ! "$output" =~ "DRY RUN completed successfully" ]]; then
        echo "Missing success indicator in output." >&2
        echo "$output" >&2
        return 1
    fi
}

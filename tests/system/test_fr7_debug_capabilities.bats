#!/usr/bin/env bats
#
# FR-7: Debugging and Troubleshooting Capabilities Testing
#
# This test suite validates all command-line argument combinations and variations
# for the bootstrap script debug capabilities as specified in FR-7.
#
# Reference: docs/PRD.md#fr-7-debugging-and-troubleshooting
#

load '../lib/test_helper'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# Test Matrix: Basic argument functionality
@test "FR-7.1: --help displays usage information" {
    run_bootstrap "setup.core.sh" "--help"
    assert_bootstrap_success
    validate_help_output "$output"
    validate_fr7_debug_capabilities "--help" "$output"
}

@test "FR-7.2: --dry-run shows preview without execution" {
    run_bootstrap "setup.core.sh" "--dry-run"
    assert_bootstrap_success
    validate_dry_run_output "$output"
    validate_fr7_debug_capabilities "--dry-run" "$output"
}

@test "FR-7.3: --debug-trace shows control flow" {
    run_bootstrap "setup.core.sh" "--debug-trace"
    assert_bootstrap_success
    validate_debug_trace_output "$output"
    validate_fr7_debug_capabilities "--debug-trace" "$output"
}

@test "FR-7.4: --debug-verbose shows detailed execution" {
    run_bootstrap "setup.core.sh" "--debug-verbose"
    assert_bootstrap_success
    validate_debug_verbose_output "$output"
    validate_fr7_debug_capabilities "--debug-verbose" "$output"
}

# Test Matrix: Combination arguments (positive cases)
@test "FR-7.5: --dry-run --debug-trace combination" {
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-trace"
    assert_bootstrap_success
    validate_dry_run_output "$output"
    validate_debug_trace_output "$output"
    validate_fr7_debug_capabilities "--dry-run --debug-trace" "$output"
}

@test "FR-7.6: --dry-run --debug-verbose combination" {
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-verbose"
    assert_bootstrap_success
    validate_dry_run_output "$output"
    validate_debug_verbose_output "$output"
    validate_fr7_debug_capabilities "--dry-run --debug-verbose" "$output"
}

@test "FR-7.7: --debug-trace --debug-verbose combination" {
    run_bootstrap "setup.core.sh" "--debug-trace" "--debug-verbose"
    assert_bootstrap_success
    validate_debug_trace_output "$output"
    validate_debug_verbose_output "$output"
    validate_fr7_debug_capabilities "--debug-trace --debug-verbose" "$output"
}

@test "FR-7.8: --dry-run --debug-trace --debug-verbose all flags" {
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-trace" "--debug-verbose"
    assert_bootstrap_success
    validate_dry_run_output "$output"
    validate_debug_verbose_output "$output"
    validate_fr7_debug_capabilities "--dry-run --debug-trace --debug-verbose" "$output"
}

# Test Matrix: Argument order variations (positive cases)
@test "FR-7.9: --debug-verbose --dry-run (reversed order)" {
    run_bootstrap "setup.core.sh" "--debug-verbose" "--dry-run"
    assert_bootstrap_success
    validate_dry_run_output "$output"
    validate_debug_verbose_output "$output"
    validate_fr7_debug_capabilities "--debug-verbose --dry-run" "$output"
}

@test "FR-7.10: --debug-verbose --debug-trace (explicit both)" {
    run_bootstrap "setup.core.sh" "--debug-verbose" "--debug-trace"
    assert_bootstrap_success
    validate_debug_verbose_output "$output"
    validate_debug_trace_output "$output"
    validate_fr7_debug_capabilities "--debug-verbose --debug-trace" "$output"
}

@test "FR-7.11: --debug-trace --dry-run (reversed order)" {
    run_bootstrap "setup.core.sh" "--debug-trace" "--dry-run"
    assert_bootstrap_success
    validate_dry_run_output "$output"
    validate_debug_trace_output "$output"
    validate_fr7_debug_capabilities "--debug-trace --dry-run" "$output"
}

# Test Matrix: Negative cases (invalid combinations and edge cases)
@test "FR-7.12: Invalid argument --invalid-flag" {
    run_bootstrap "setup.core.sh" "--invalid-flag"
    assert_bootstrap_error
    [[ "$output" =~ "Unknown option" || "$output" =~ "Invalid" || "$output" =~ "Error" ]]
}

@test "FR-7.13: Empty argument handling" {
    run_bootstrap "setup.core.sh" ""
    # This should succeed as empty args are valid (default execution)
    assert_bootstrap_success
}

@test "FR-7.14: Multiple help flags --help --help" {
    run_bootstrap "setup.core.sh" "--help" "--help"
    assert_bootstrap_success
    validate_help_output "$output"
}

@test "FR-7.15: Mixed valid and invalid arguments" {
    run_bootstrap "setup.core.sh" "--dry-run" "--invalid-flag"
    assert_bootstrap_error
    [[ "$output" =~ "Unknown option" || "$output" =~ "Invalid" || "$output" =~ "Error" ]]
}

# Test Matrix: System state validation for dry-run
@test "FR-7.16: Dry-run makes no system modifications" {
    timestamp_before=$(date +%s)
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-verbose"
    timestamp_after=$(date +%s)
    
    assert_bootstrap_success
    validate_no_system_changes "$timestamp_before" "$timestamp_after"
    validate_dry_run_output "$output"
}

# Test Matrix: Error message quality
@test "FR-7.17: Error messages are clear and actionable" {
    run_bootstrap "setup.core.sh" "--invalid-option"
    assert_bootstrap_error
    
    # Error message should be helpful
    [[ "$output" =~ "Usage:" || "$output" =~ "Try --help" || "$output" =~ "Available options" ]]
}

# Test Matrix: Help accessibility
@test "FR-7.18: Help is accessible with -h short flag" {
    run_bootstrap "setup.core.sh" "-h"
    # Should either work or provide clear guidance
    if [[ "$status" -eq 0 ]]; then
        validate_help_output "$output"
    else
        [[ "$output" =~ "--help" || "$output" =~ "Use --help" ]]
    fi
}
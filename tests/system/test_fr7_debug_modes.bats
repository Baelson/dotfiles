#!/usr/bin/env bats
#
# FR-7: Debug and Troubleshooting Comprehensive Validation
#
# This test suite proves that debug modes actually work differently from each other
# and that each flag produces the documented behavior.
#
# Reference: docs/PRD.md#fr-7-debugging-and-troubleshooting
#
# CRITICAL IMPROVEMENT: This test suite addresses SYSTEM_IMPROVEMENTS.md findings
# that previous tests were passing when features were not implemented.
#
# Key Principle: Each test must PROVE it can fail when implementation is broken.
#
# Test Philosophy:
# - Behavioral Testing: Test what code DOES, not what it SAYS
# - Negative Cases: Prove error handling works
# - Deep Validation: Check actual behavior, not just output patterns
#

load '../lib/test_helper'
load '../lib/behavioral_helpers'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# ========================================
# FR-7.1: Dry-Run Mode Validation
# ========================================
# Requirement: --dry-run previews operations without making system modifications
# Critical: Must prove NO system changes occur

@test "FR-7.1: --dry-run makes NO system modifications" {
    # Create system snapshot before execution
    local snapshot_before="$BATS_TEST_TMPDIR/snapshot_before.txt"
    find "$BATS_TEST_TMPDIR" -type f > "$snapshot_before" 2>/dev/null || true

    # Run with dry-run flag
    run_modern_setup --dry-run
    assert_success

    # Create system snapshot after execution
    local snapshot_after="$BATS_TEST_TMPDIR/snapshot_after.txt"
    find "$BATS_TEST_TMPDIR" -type f > "$snapshot_after" 2>/dev/null || true

    # Verify no modifications (except snapshot files themselves)
    assert_no_system_modifications "$snapshot_before" "$snapshot_after"

    # Verify dry-run indicators present in output
    assert_argument_processed "--dry-run"

    # Verify no error messages
    assert_no_errors_in_output
}

# ========================================
# FR-7.2: Debug-Verbose Mode Validation
# ========================================
# Requirement: --debug-verbose shows MORE output than normal mode
# Critical: Must prove output is actually different and more detailed

@test "FR-7.2: --debug-verbose shows MORE output than normal mode" {
    # Run in normal mode (with dry-run for safety)
    run_modern_setup --dry-run
    assert_success
    local normal_output="$output"
    local normal_line_count=$(echo "$normal_output" | wc -l)

    # Run in debug-verbose mode
    run_modern_setup --dry-run --debug-verbose
    assert_success
    local debug_output="$output"
    local debug_line_count=$(echo "$debug_output" | wc -l)

    # Debug output should be longer
    [[ $debug_line_count -gt $normal_line_count ]] || {
        echo "ERROR: --debug-verbose produced same amount of output" >&2
        echo "Normal: $normal_line_count lines, Debug: $debug_line_count lines" >&2
        return 1
    }

    # Debug output should contain [DEBUG] markers
    assert_argument_processed "--debug-verbose"

    # Verify outputs are actually different
    [[ "$debug_output" != "$normal_output" ]] || {
        echo "ERROR: --debug-verbose output identical to normal output" >&2
        return 1
    }
}

# ========================================
# FR-7.3: Debug-Trace Mode Validation
# ========================================
# Requirement: --debug-trace shows function-level execution tracing
# Critical: Must prove trace markers present and show function flow

@test "FR-7.3: --debug-trace shows function-level tracing" {
    run_modern_setup --dry-run --debug-trace
    assert_success

    # Must contain [TRACE] markers
    assert_argument_processed "--debug-trace"

    # Should show function entry/exit with function names
    local function_trace_found=false
    if [[ "$output" =~ "main:" || "$output" =~ "check_prerequisites:" || "$output" =~ "parse_arguments:" ]]; then
        function_trace_found=true
    fi

    [[ "$function_trace_found" == "true" ]] || {
        echo "ERROR: No function-level tracing found" >&2
        echo "Expected: Output containing function names like 'main:', 'check_prerequisites:', etc." >&2
        echo "Actual: No function trace markers found" >&2
        return 1
    }

    # Verify no errors
    assert_no_errors_in_output
}

# ========================================
# FR-7.4: Help Mode Validation
# ========================================
# Requirement: --help exits 0 and shows comprehensive information
# Critical: Must verify ALL documented sections present

@test "FR-7.4: --help exits 0 and shows comprehensive information" {
    run_modern_setup --help
    assert_success

    # Verify ALL required sections present
    local required_sections=(
        "USAGE:"
        "OPTIONS:"
        "--dry-run"
        "--debug-verbose"
        "--debug-trace"
        "--help"
        "ENVIRONMENT VARIABLES:"
        "EPHEMERAL"
        "HEADLESS"
        "EXAMPLES:"
        "TROUBLESHOOTING:"
    )

    local missing_sections=()
    for section in "${required_sections[@]}"; do
        if ! [[ "$output" =~ "$section" ]]; then
            missing_sections+=("$section")
        fi
    done

    [[ ${#missing_sections[@]} -eq 0 ]] || {
        echo "ERROR: Help output missing required sections" >&2
        echo "Missing: ${missing_sections[*]}" >&2
        return 1
    }

    # Verify help processed correctly
    assert_argument_processed "--help"
}

# ========================================
# FR-7.5: Error Handling Validation
# ========================================
# Requirement: Invalid options produce clear errors and suggest --help
# Critical: NEGATIVE TEST - must prove error handling works

@test "FR-7.5: Invalid option produces error and suggests --help" {
    run_modern_setup --invalid-option
    assert_failure

    # Should mention the invalid option
    [[ "$output" =~ "--invalid-option" || "$output" =~ "invalid" || "$output" =~ "Unknown option" ]] || {
        echo "ERROR: Error message doesn't mention invalid option" >&2
        echo "Expected: Error message containing '--invalid-option' or 'invalid' or 'Unknown option'" >&2
        echo "Actual output:" >&2
        echo "$output" >&2
        return 1
    }

    # Should suggest --help
    [[ "$output" =~ "--help" || "$output" =~ "help" ]] || {
        echo "ERROR: Error message doesn't suggest --help" >&2
        echo "Expected: Error message suggesting --help for usage information" >&2
        echo "Actual output:" >&2
        echo "$output" >&2
        return 1
    }
}

# ========================================
# FR-7.6: Combined Flags Validation
# ========================================
# Requirement: Multiple debug flags can be combined
# Critical: Must prove all flags work simultaneously

@test "FR-7.6: Combining flags works correctly" {
    run_modern_setup --dry-run --debug-verbose --debug-trace
    assert_success

    # Should have dry-run indicators
    [[ "$output" =~ \[DRY\ RUN\] || "$output" =~ "Would execute:" || "$output" =~ "DRY RUN" ]] || {
        echo "ERROR: Combined flags missing dry-run indicators" >&2
        return 1
    }

    # Should have debug markers
    [[ "$output" =~ \[DEBUG\] ]] || {
        echo "ERROR: Combined flags missing [DEBUG] markers" >&2
        return 1
    }

    # Should have trace markers
    [[ "$output" =~ \[TRACE\] ]] || {
        echo "ERROR: Combined flags missing [TRACE] markers" >&2
        return 1
    }

    # Verify no errors despite multiple flags
    assert_no_errors_in_output
}

# ========================================
# FR-7.7: Positional Arguments Rejection
# ========================================
# Requirement: Script should reject unexpected positional arguments
# Critical: NEGATIVE TEST - proves argument validation works

@test "FR-7.7: Positional arguments are rejected with clear error" {
    run_modern_setup unexpected-argument
    assert_failure

    # Should mention positional argument issue
    [[ "$output" =~ "Unexpected argument" || "$output" =~ "positional" || "$output" =~ "unexpected-argument" ]] || {
        echo "ERROR: Error message doesn't indicate positional argument problem" >&2
        echo "Actual output:" >&2
        echo "$output" >&2
        return 1
    }

    # Should suggest help
    [[ "$output" =~ "--help" || "$output" =~ "help" ]] || {
        echo "ERROR: Error message doesn't suggest --help" >&2
        return 1
    }
}

# ========================================
# FR-7.8: Debug Trace Different from Verbose
# ========================================
# Requirement: --debug-trace produces DIFFERENT output than --debug-verbose
# Critical: Must prove flags are not identical in behavior

@test "FR-7.8: --debug-trace produces different output than --debug-verbose" {
    # Run with debug-verbose only
    run_modern_setup --dry-run --debug-verbose
    assert_success
    local verbose_output="$output"

    # Run with debug-trace only
    run_modern_setup --dry-run --debug-trace
    assert_success
    local trace_output="$output"

    # Outputs should be different
    [[ "$verbose_output" != "$trace_output" ]] || {
        echo "ERROR: --debug-trace and --debug-verbose produce identical output" >&2
        echo "These flags should have different behavioral effects" >&2
        return 1
    }

    # Trace should have [TRACE] markers
    [[ "$trace_output" =~ \[TRACE\] ]] || {
        echo "ERROR: --debug-trace output missing [TRACE] markers" >&2
        return 1
    }

    # Verbose should have [DEBUG] markers
    [[ "$verbose_output" =~ \[DEBUG\] ]] || {
        echo "ERROR: --debug-verbose output missing [DEBUG] markers" >&2
        return 1
    }
}

# ========================================
# FR-7.9: Help Short Flag
# ========================================
# Requirement: -h short flag works identically to --help
# Critical: Must prove short and long forms are equivalent

@test "FR-7.9: -h short flag works identically to --help" {
    # Run with --help
    run_modern_setup --help
    assert_success
    local long_help="$output"

    # Run with -h
    run_modern_setup -h
    assert_success
    local short_help="$output"

    # Outputs should be identical
    [[ "$long_help" == "$short_help" ]] || {
        echo "ERROR: -h and --help produce different output" >&2
        echo "Short and long forms should be equivalent" >&2
        return 1
    }
}

# ========================================
# FR-7.10: Success Indicators in Dry-Run
# ========================================
# Requirement: Dry-run should show success indicators
# Critical: Must prove success is clearly communicated

@test "FR-7.10: Dry-run mode shows clear success completion" {
    run_modern_setup --dry-run
    assert_success

    # Should have success indicators
    assert_success_indicators_present

    # Should explicitly state dry-run completion
    [[ "$output" =~ "DRY RUN completed" || "$output" =~ "completed successfully" ]] || {
        echo "ERROR: No clear dry-run completion message" >&2
        return 1
    }
}

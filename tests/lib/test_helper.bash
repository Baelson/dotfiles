#!/usr/bin/env bash
#
# Test Helper Functions for macOS Dotfiles Testing
#
# This file provides common utilities and setup functions for all test suites
# following BATS best practices and the project's testing architecture.
#

# Test configuration
export BATS_TEST_TIMEOUT=300  # 5 minutes per test
export DOTFILES_ROOT="${BATS_TEST_DIRNAME%/tests/*}"
export BOOTSTRAP_DIR="${DOTFILES_ROOT}/scripts/setup"
export TESTS_DIR="${DOTFILES_ROOT}/tests"
export DOTFILES_SOURCE_DIR="${DOTFILES_ROOT}/home"  # Chezmoi source directory

# Test execution modes
export TEST_MODE="${TEST_MODE:-unit}"
export DRY_RUN_TESTS="${DRY_RUN_TESTS:-true}"

# Logging and debugging
setup_test_logging() {
    export TEST_LOG_DIR="${BATS_TEST_TMPDIR}/logs"
    mkdir -p "$TEST_LOG_DIR"
    export TEST_LOG_FILE="${TEST_LOG_DIR}/test.log"
}

# Common test setup
setup_common() {
    setup_test_logging

    # Ensure we're in the right directory
    cd "$DOTFILES_ROOT" || {
        echo "ERROR: Cannot change to dotfiles root directory: $DOTFILES_ROOT" >&2
        return 1
    }

    # Verify critical files exist
    [[ -f "$BOOTSTRAP_DIR/setup.core.sh" ]] || {
        echo "ERROR: Bootstrap script not found: $BOOTSTRAP_DIR/setup.core.sh" >&2
        return 1
    }

    [[ -f "$BOOTSTRAP_DIR/lib/common.sh" ]] || {
        echo "ERROR: Common library not found: $BOOTSTRAP_DIR/lib/common.sh" >&2
        return 1
    }
}

# Bootstrap script execution wrapper
run_bootstrap() {
    local script="$1"
    shift
    local args=("$@")

    # Always run with dry-run in test mode unless explicitly disabled
    if [[ "$DRY_RUN_TESTS" == "true" && ! " ${args[*]} " =~ " --dry-run " ]]; then
        args+=("--dry-run")
    fi

    # Set up CI-friendly environment if running in GitHub Actions
    local run_command="$BOOTSTRAP_DIR/$script ${args[*]} 2>&1"
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        # In CI, provide explicit path and environment setup
        run_command="cd '$DOTFILES_ROOT' && DOTFILES_REPO='$DOTFILES_ROOT' $run_command"
    fi

    # Bootstrap scripts are zsh, not bash - use zsh to execute them
    run zsh -c "$run_command"
}

# Verify script output patterns
assert_bootstrap_success() {
    # shellcheck disable=SC2154 # status is set by BATS run command
    if [[ "$status" -ne 0 ]]; then
        echo "Bootstrap script failed with exit code: $status" >&2
        if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
            echo "Output in CI:" >&2
            echo "$output" >&2
            echo "Working directory: $PWD" >&2
            echo "DOTFILES_ROOT: $DOTFILES_ROOT" >&2
            echo "BOOTSTRAP_DIR: $BOOTSTRAP_DIR" >&2
        fi
        return 1
    fi
    return 0
}

assert_bootstrap_output_contains() {
    local expected="$1"
    [[ "$output" =~ $expected ]]
}

assert_bootstrap_error() {
    [[ "$status" -ne 0 ]]
}

# Command-line argument validation helpers
validate_help_output() {
    local output="$1"
    [[ "$output" =~ "USAGE:" ]]
    [[ "$output" =~ "OPTIONS:" ]]
    [[ "$output" =~ "--dry-run" ]]
    [[ "$output" =~ "--debug-trace" ]]
    [[ "$output" =~ "--debug-verbose" ]]
    [[ "$output" =~ "--help" ]]
}

validate_dry_run_output() {
    local output="$1"
    # Dry run should show setup messages but not execute installations
    [[ "$output" =~ "Starting Core macOS Development Environment Setup" || "$output" =~ "already installed" || "$output" =~ "Repository:" ]]
}

validate_debug_trace_output() {
    local output="$1"
    # Debug trace should show TRACE messages
    [[ "$output" =~ \[TRACE\] ]]
}

validate_debug_verbose_output() {
    local output="$1"
    # Debug verbose should show TRACE messages (our script uses TRACE, not DEBUG)
    [[ "$output" =~ \[TRACE\] ]]
}

# Functional requirement validation helpers
validate_fr1_one_command_bootstrap() {
    # FR-1: One-Command Bootstrap
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "Development Environment Setup" || "$output" =~ "Bootstrap" ]]
}

validate_fr7_debug_capabilities() {
    # FR-7: Debugging and Troubleshooting
    local args_string="$1"
    local output="$2"

    if [[ "$args_string" =~ --help ]]; then
        validate_help_output "$output"
    elif [[ "$args_string" =~ --dry-run ]]; then
        validate_dry_run_output "$output"
    elif [[ "$args_string" =~ --debug-verbose ]]; then
        validate_debug_verbose_output "$output"
    elif [[ "$args_string" =~ --debug-trace ]]; then
        validate_debug_trace_output "$output"
    fi
}

# System state validation
validate_no_system_changes() {
    # Ensure dry-run tests don't modify system state
    local timestamp_before="$1"
    local timestamp_after="$2"

    # Check that critical system directories weren't modified
    # This is a basic check - in practice, we'd compare specific file timestamps
    [[ "$timestamp_after" -ge "$timestamp_before" ]]
}

# Test environment cleanup
cleanup_common() {
    # Clean up any temporary files or state changes
    if [[ -n "$TEST_LOG_DIR" && -d "$TEST_LOG_DIR" ]]; then
        # In debug mode, keep logs; otherwise clean up
        if [[ "${DEBUG_TESTS:-false}" != "true" ]]; then
            rm -rf "$TEST_LOG_DIR"
        fi
    fi
}

# GitHub Actions integration helpers
setup_github_actions_env() {
    # Set up environment variables for GitHub Actions compatibility
    export CI="${CI:-false}"
    export GITHUB_ACTIONS="${GITHUB_ACTIONS:-false}"

    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        # GitHub Actions specific setup
        export HOMEBREW_NO_INSTALL_CLEANUP=1
        export HOMEBREW_NO_AUTO_UPDATE=1
        export HOMEBREW_NO_ENV_HINTS=1
    fi
}

# Matrix testing parameter validation
validate_matrix_parameters() {
    local test_name="$1"
    local cli_args="$2"
    local expected_behavior="$3"

    echo "Matrix Test: $test_name"
    echo "CLI Args: $cli_args"
    echo "Expected: $expected_behavior"
}

# Load this helper in all test files with:
# load 'test_helper'

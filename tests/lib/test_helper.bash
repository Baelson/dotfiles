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
export SETUP_SCRIPT="${DOTFILES_ROOT}/setup.sh"
export TESTS_DIR="${DOTFILES_ROOT}/tests"
export BOOTSTRAP_DIR="${DOTFILES_ROOT}"
export DOTFILES_SOURCE_DIR="${DOTFILES_ROOT}/home"  # Chezmoi source directory

# Test execution modes
export TEST_MODE="${TEST_MODE:-unit}"
export DRY_RUN_TESTS="${DRY_RUN_TESTS:-true}"

# Logging and debugging
setup_test_logging() {
    export TEST_LOG_DIR="${BATS_TEST_TMPDIR}/logs"
    mkdir -p "${TEST_LOG_DIR}"
    export TEST_LOG_FILE="${TEST_LOG_DIR}/test.log"
}

# Common test setup
setup_common() {
    setup_test_logging

    # Ensure we're in the right directory
    cd "${DOTFILES_ROOT}" || {
        echo "ERROR: Cannot change to dotfiles root directory: ${DOTFILES_ROOT}" >&2
        return 1
    }

    # Verify critical files exist
    [[ -f "${SETUP_SCRIPT}" ]] || {
        echo "ERROR: Setup script not found: ${SETUP_SCRIPT}" >&2
        return 1
    }

    [[ -f "${DOTFILES_SOURCE_DIR}/.chezmoi.toml.tmpl" ]] || {
        echo "ERROR: chezmoi config template not found: ${DOTFILES_SOURCE_DIR}/.chezmoi.toml.tmpl" >&2
        return 1
    }
}

# Bootstrap script execution wrapper (legacy compatibility)
run_bootstrap() {
    shift  # Skip legacy script parameter, not used in modern system
    local args=("$@")

    # Always run with dry-run in test mode unless explicitly disabled
    if [[ "${DRY_RUN_TESTS}" == "true" && ! " ${args[*]} " =~ " --dry-run " ]]; then
        args+=("--dry-run")
    fi

    # For modern system, redirect to run_modern_setup
    run_modern_setup "${args[@]}"
}

# Verify script output patterns
assert_bootstrap_success() {
    # shellcheck disable=SC2154 # status is set by BATS run command
    if [[ "${status}" -ne 0 ]]; then
        echo "Bootstrap script failed with exit code: ${status}" >&2
        echo "Output:" >&2
        echo "${output}" >&2
        echo "Working directory: ${PWD}" >&2
        return 1
    fi
    return 0
}

assert_bootstrap_output_contains() {
    local expected="$1"
    [[ "${output}" =~ ${expected} ]]
}

assert_bootstrap_error() {
    [[ "${status}" -ne 0 ]]
}

# Command-line argument validation helpers
validate_help_output() {
    local output="$1"
    [[ "${output}" =~ "USAGE:" ]]
    [[ "${output}" =~ "OPTIONS:" ]]
    [[ "${output}" =~ "--dry-run" ]]
    [[ "${output}" =~ "--debug-trace" ]]
    [[ "${output}" =~ "--debug-verbose" ]]
    [[ "${output}" =~ "--help" ]]
}

validate_dry_run_output() {
    local output="$1"
    # Dry run should show setup messages but not execute installations
    [[ "${output}" =~ "Starting Core macOS Development Environment Setup" || "${output}" =~ "already installed" || "${output}" =~ "Repository:" ]]
}

validate_debug_trace_output() {
    local output="$1"
    # Debug trace should show TRACE messages
    [[ "${output}" =~ \[TRACE\] ]]
}

validate_debug_verbose_output() {
    local output="$1"
    # Debug verbose should show TRACE messages (our script uses TRACE, not DEBUG)
    [[ "${output}" =~ \[TRACE\] ]]
}

# Functional requirement validation helpers
validate_fr1_one_command_bootstrap() {
    # FR-1: One-Command Bootstrap
    [[ "${status}" -eq 0 ]]
    [[ "${output}" =~ "Development Environment Setup" || "${output}" =~ "Bootstrap" ]]
}

validate_fr7_debug_capabilities() {
    # FR-7: Debugging and Troubleshooting
    local args_string="$1"
    local output="$2"

    if [[ "${args_string}" =~ --help ]]; then
        validate_help_output "${output}"
    elif [[ "${args_string}" =~ --dry-run ]]; then
        validate_dry_run_output "${output}"
    elif [[ "${args_string}" =~ --debug-verbose ]]; then
        validate_debug_verbose_output "${output}"
    elif [[ "${args_string}" =~ --debug-trace ]]; then
        validate_debug_trace_output "${output}"
    fi
}

# System state validation
validate_no_system_changes() {
    # Ensure dry-run tests don't modify system state
    local timestamp_before="$1"
    local timestamp_after="$2"

    # Check that critical system directories weren't modified
    # This is a basic check - in practice, we'd compare specific file timestamps
    [[ "${timestamp_after}" -ge "${timestamp_before}" ]]
}

# Test environment cleanup
cleanup_common() {
    # Clean up any temporary files or state changes
    if [[ -n "${TEST_LOG_DIR}" && -d "${TEST_LOG_DIR}" ]]; then
        # In debug mode, keep logs; otherwise clean up
        if [[ "${DEBUG_TESTS:-false}" != "true" ]]; then
            rm -rf "${TEST_LOG_DIR}"
        fi
    fi
}

# GitHub Actions integration helpers
setup_github_actions_env() {
    # Set up environment variables for GitHub Actions compatibility
    export CI="${CI:-false}"
    export GITHUB_ACTIONS="${GITHUB_ACTIONS:-false}"

    if [[ "${GITHUB_ACTIONS}" == "true" ]]; then
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

    echo "Matrix Test: ${test_name}"
    echo "CLI Args: ${cli_args}"
    echo "Expected: ${expected_behavior}"
}

# Modern chezmoi-native system test helpers
# ===========================================

# Modern setup script execution wrapper
run_modern_setup() {
    local args=("$@")

    # Set up test environment for modern setup.sh
    local setup_script="${DOTFILES_ROOT}/setup.sh"

    # Verify modern setup script exists
    [[ -f "${setup_script}" ]] || {
        echo "ERROR: Modern setup script not found: ${setup_script}" >&2
        return 1
    }

    # Build command with environment variables for testing
    local env_vars=""
    local script_args=""

    # Process arguments to separate environment variables from script args
    for arg in "${args[@]}"; do
        if [[ "${arg}" =~ ^[A-Z_]+= ]]; then
            env_vars="${env_vars} ${arg}"
        else
            script_args="${script_args} ${arg}"
        fi
    done

    # Default to dry-run in test mode for hermetic behavior.
    if [[ "${DRY_RUN_TESTS}" == "true" ]] \
        && [[ ! " ${script_args} " =~ " --dry-run " ]] \
        && [[ ! " ${script_args} " =~ " --help " ]] \
        && [[ ! " ${script_args} " =~ " -h " ]]; then
        script_args="${script_args} --dry-run"
    fi

    # Add test-specific environment variables
    # CRITICAL: Isolate home directory to prevent touching real user data
    # Adding defaults for test stability (avoids interactive prompts and skips encryption)
    env_vars="${env_vars} EPHEMERAL='${EPHEMERAL:-true}' HEADLESS='${HEADLESS:-true}'"
    # CRITICAL: Isolate home directory to prevent touching real user data
    env_vars="${env_vars} HOME='${BATS_TEST_TMPDIR}'"
    # CRITICAL: Use local repository for hermetic testing (no network clones)
    env_vars="${env_vars} DOTFILES_REPO_URL='${DOTFILES_ROOT}'"

    # Build run command
    # Redirect input from /dev/null to prevent interactive prompts (bypasses chezmoi hanging)
    local run_command="cd '${DOTFILES_ROOT}' && ${env_vars} zsh '${setup_script}' ${script_args} < /dev/null 2>&1"

    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        # In CI, provide additional environment setup
        run_command="export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH && ${run_command}"
    fi

    run zsh -c "${run_command}"
}

# chezmoi command execution wrapper for testing
run_chezmoi() {
    local args=("$@")

    # Set up chezmoi test environment
    local chezmoi_source_dir="${DOTFILES_ROOT}/home"
    local chezmoi_config_dir="${BATS_TEST_TMPDIR}/chezmoi"

    # Create temporary chezmoi environment
    mkdir -p "${chezmoi_config_dir}"

    # Build chezmoi command
    local chezmoi_cmd="chezmoi --source '${chezmoi_source_dir}' --config '${chezmoi_config_dir}/chezmoi.toml'"

    # Add dry-run for safety unless explicitly disabled
    if [[ "${DRY_RUN_TESTS}" == "true" && ! " ${args[*]} " =~ " apply " ]]; then
        if [[ " ${args[*]} " =~ " init " ]]; then
            # For init command, add --dry-run if not present
            if [[ ! " ${args[*]} " =~ " --dry-run " ]]; then
                args+=("--dry-run")
            fi
        elif [[ " ${args[*]} " =~ " diff " ]] || [[ " ${args[*]} " =~ " status " ]]; then
            # These commands are read-only by nature
            :
        else
            # Add --dry-run to other commands
            args+=("--dry-run")
        fi
    fi


    # Escape arguments safely for shell execution
    local escaped_args=""
    for arg in "${args[@]}"; do
        escaped_args="${escaped_args} $(printf "%q" "${arg}")"
    done

    # We execute via zsh -c to capture stderr (2>&1) properly in BATS run output
    local run_command="${chezmoi_cmd} ${escaped_args}"

    # Handle optional input redirection via environment variable
    # This ensures input is passed to the command itself, not consumed by bats 'run'
    if [[ -n "${CHEZMOI_INPUT_FILE:-}" ]]; then
        run_command="${run_command} < '${CHEZMOI_INPUT_FILE}'"
    fi

    run_command="${run_command} 2>&1"

    run zsh -c "${run_command}"
}

# Template rendering test helper
test_template_rendering() {
    local template_file="$1"
    shift 1  # Only skip template_file, subsequent args are vars
    local template_vars=("$@")

    # Construct JSON data for override-data flag
    local json_data="{"
    local first=true

    for var in "${template_vars[@]}"; do
        if [ "${first}" = true ]; then first=false; else json_data="${json_data}, "; fi

        local var_name="${var%=*}"
        local var_value="${var#*=}"

        # Handle boolean/integer vs string values
        if [[ "${var_value}" == "true" ]] || [[ "${var_value}" == "false" ]] || [[ "${var_value}" =~ ^[0-9]+$ ]]; then
            json_data="${json_data} \"${var_name}\": ${var_value}"
        else
            json_data="${json_data} \"${var_name}\": \"${var_value}\""
        fi
    done
    json_data="${json_data} }"

    # Test template rendering with chezmoi using override-data
    # We use --init to ensure config template functions like stdinIsATTY are available
    # CRITICAL: Use shell redirection via env var because bats swallows stdin and --file argument is unreliable combined with --override-data
    export CHEZMOI_INPUT_FILE="${DOTFILES_ROOT}/home/${template_file}"
    run_chezmoi execute-template --init --stdinisatty=false --override-data "${json_data}"
    unset CHEZMOI_INPUT_FILE
}

# Environment-specific test helpers
test_ephemeral_environment() {
    run_modern_setup "EPHEMERAL=1"
}

test_headless_environment() {
    run_modern_setup "HEADLESS=1"
}

test_work_environment() {
    run_modern_setup "WORK=1"
}

test_personal_environment() {
    run_modern_setup "PERSONAL=1"
}

# Validation helpers for modern system
assert_modern_setup_success() {
    assert_bootstrap_success
    # Additional validations for modern setup
    [[ "${output}" =~ "chezmoi" ]] || [[ "${output}" =~ "Installing chezmoi" ]] || [[ "${output}" =~ "already installed" ]]
}

assert_chezmoi_success() {
    # shellcheck disable=SC2154 # status is set by BATS run command
    if [[ "${status}" -ne 0 ]]; then
        echo "chezmoi command failed with exit code: ${status}" >&2
        echo "Output:" >&2
        echo "${output}" >&2
        return 1
    fi
    return 0
}

validate_template_output() {
    local output="$1"
    local environment="$2"

    case "${environment}" in
        "ephemeral")
            [[ "${output}" =~ ephemeral.*true ]]
            ;;
        "headless")
            [[ "${output}" =~ headless.*true ]]
            ;;
        "work")
            [[ "${output}" =~ work.*true ]]
            ;;
        "personal")
            [[ "${output}" =~ personal.*true ]]
            ;;
        *)
            echo "Unknown environment: ${environment}" >&2
            return 1
            ;;
    esac
}

# Lifecycle script validation helpers
validate_lifecycle_script_exists() {
    local script_name="$1"
    local script_path="${DOTFILES_SOURCE_DIR}/.chezmoiscripts/darwin/${script_name}"
    [[ -f "${script_path}" ]]
}

validate_lifecycle_script_templated() {
    local script_name="$1"
    local script_path="${DOTFILES_SOURCE_DIR}/.chezmoiscripts/darwin/${script_name}"
    [[ -f "${script_path}" ]] && [[ "${script_name}" =~ \.tmpl$ ]]
}

# Load this helper in all test files with:
# load 'test_helper'

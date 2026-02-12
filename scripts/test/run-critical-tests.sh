#!/usr/bin/env bash
#
# Critical Tests Runner for Pre-commit Hook
#
# This script runs a subset of critical tests before commits to catch
# major issues early without running the full test suite.
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TESTS_DIR="$DOTFILES_ROOT/tests"
FR1_TEST_FILE="$TESTS_DIR/system/test_fr1_modern_bootstrap.bats"
FR7_TEST_FILE="$TESTS_DIR/system/test_fr7_debug_modes.bats"
FR3_TEST_FILE="$TESTS_DIR/integration/test_fr3_configuration_management.bats"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_required_bats_file() {
    local test_file="$1"
    local failure_message="$2"
    shift 2
    local bats_args=("$@")

    if [[ ! -f "$test_file" ]]; then
        log_error "Required test file missing: $test_file"
        exit 1
    fi

    local bats_exit_code=0
    if [[ ${#bats_args[@]} -gt 0 ]]; then
        bats "${bats_args[@]}" "$test_file" || bats_exit_code=$?
    else
        bats "$test_file" || bats_exit_code=$?
    fi

    if [[ $bats_exit_code -ne 0 ]]; then
        log_error "$failure_message"
        exit 1
    fi
}

main() {
    log_info "Running critical tests for pre-commit validation..."

    # Change to dotfiles root
    cd "$DOTFILES_ROOT" || {
        log_error "Cannot change to dotfiles root: $DOTFILES_ROOT"
        exit 1
    }

    # Check if BATS is installed
    if ! command -v bats &> /dev/null; then
        log_warn "BATS not found. Installing via Homebrew..."
        if command -v brew &> /dev/null; then
            brew install bats-core
        else
            log_error "Homebrew not found. Please install BATS manually: brew install bats-core"
            exit 1
        fi
    fi

    # Verify test structure exists
    if [[ ! -d "$TESTS_DIR" ]]; then
        log_error "Tests directory not found: $TESTS_DIR"
        exit 1
    fi

    # Run critical tests (subset for speed)
    log_info "Running FR-1 Bootstrap tests..."
    run_required_bats_file "$FR1_TEST_FILE" "FR-1 Bootstrap tests failed"

    log_info "Running FR-7 Debug Capabilities tests (sample)..."
    # Run critical FR-7 checks for speed while still proving core debug behavior.
    run_required_bats_file \
        "$FR7_TEST_FILE" \
        "Critical FR-7 tests failed" \
        --filter "^FR-7\\.(1|2|10):"

    log_info "Running basic configuration validation..."
    run_required_bats_file \
        "$FR3_TEST_FILE" \
        "Configuration validation tests failed" \
        --filter "^FR-3\\.(1|2):"

    log_info "✅ Critical tests passed successfully!"
}

main "$@"

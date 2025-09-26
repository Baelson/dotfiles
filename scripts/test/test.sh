#!/usr/bin/env bash
#
# Test Runner Script for Dotfiles Testing
#
# This script provides an easy way to run BATS tests with different configurations
# and options, making testing more accessible and ergonomic.
#
# Usage: ./scripts/test.sh [OPTIONS] [TEST_PATTERN]
#
# Options:
#   --quick          Run only critical tests (fast subset)
#   --unit           Run only unit tests
#   --integration    Run only integration tests
#   --system         Run only system tests
#   --all            Run all tests (default)
#   --verbose        Show detailed test output
#   --debug          Show debug information
#   --install-bats   Install BATS if not available
#   --help           Display this help message
#
# Test Patterns:
#   fr1              Run FR-1 (Bootstrap) tests
#   fr2              Run FR-2 (Package Management) tests
#   fr3              Run FR-3 (Configuration Management) tests
#   fr4              Run FR-4 (Shell Environment) tests
#   fr5              Run FR-5 (Application Preferences) tests
#   fr6              Run FR-6 (Environment Templating) tests
#   fr7              Run FR-7 (Debug Capabilities) tests
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TESTS_DIR="$DOTFILES_ROOT/tests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Options
QUICK_MODE=false
UNIT_ONLY=false
INTEGRATION_ONLY=false
SYSTEM_ONLY=false
ALL_TESTS=true
VERBOSE=false
DEBUG=false
INSTALL_BATS=false
TEST_PATTERN=""

# Test counters
tests_run=0
tests_passed=0
tests_failed=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

show_help() {
    cat << EOF
Test Runner Script for Dotfiles Testing

Usage: $0 [OPTIONS] [TEST_PATTERN]

Options:
  --quick          Run only critical tests (fast subset)
  --unit           Run only unit tests
  --integration    Run only integration tests
  --system         Run only system tests
  --all            Run all tests (default)
  --verbose        Show detailed test output
  --debug          Show debug information
  --install-bats   Install BATS if not available
  --help           Display this help message

Test Patterns:
  fr1              Run FR-1 (Bootstrap) tests
  fr2              Run FR-2 (Package Management) tests
  fr3              Run FR-3 (Configuration Management) tests
  fr4              Run FR-4 (Shell Environment) tests
  fr5              Run FR-5 (Application Preferences) tests
  fr6              Run FR-6 (Environment Templating) tests
  fr7              Run FR-7 (Debug Capabilities) tests

Examples:
  $0                              # Run all tests
  $0 --quick                      # Run quick test subset
  $0 --unit                       # Run only unit tests
  $0 fr1                          # Run FR-1 bootstrap tests
  $0 --system --verbose           # Run system tests with verbose output
  $0 --install-bats --quick       # Install BATS and run quick tests

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                QUICK_MODE=true
                ALL_TESTS=false
                shift
                ;;
            --unit)
                UNIT_ONLY=true
                ALL_TESTS=false
                shift
                ;;
            --integration)
                INTEGRATION_ONLY=true
                ALL_TESTS=false
                shift
                ;;
            --system)
                SYSTEM_ONLY=true
                ALL_TESTS=false
                shift
                ;;
            --all)
                ALL_TESTS=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --install-bats)
                INSTALL_BATS=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            fr[1-7])
                TEST_PATTERN="$1"
                ALL_TESTS=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

check_bats_installation() {
    if command -v bats &> /dev/null; then
        local version
        version=$(bats --version 2>/dev/null | head -1)
        log_info "BATS found: $version"
        return 0
    else
        log_warning "BATS not found"
        return 1
    fi
}

install_bats() {
    log_info "Installing BATS..."

    if command -v brew &> /dev/null; then
        log_info "Installing BATS via Homebrew..."
        if brew install bats-core; then
            log_success "BATS installed successfully"
            return 0
        else
            log_error "Failed to install BATS via Homebrew"
            return 1
        fi
    else
        log_error "Homebrew not available. Please install BATS manually:"
        log_error "  brew install bats-core"
        return 1
    fi
}

get_test_files() {
    local test_files=()

    if [[ "$QUICK_MODE" == "true" ]]; then
        # Quick mode: run only essential tests for faster feedback
        test_files=(
            "$TESTS_DIR/system/test_fr1_modern_bootstrap.bats"
            "$TESTS_DIR/unit/test_brewfile_syntax.bats"
            "$TESTS_DIR/unit/test_security_secrets.bats"
        )
    elif [[ "$UNIT_ONLY" == "true" ]]; then
        # Unit tests only
        if [[ -n "$TEST_PATTERN" ]]; then
            test_files=("$TESTS_DIR/unit/test_${TEST_PATTERN}_*.bats")
        else
            test_files=("$TESTS_DIR/unit/"*.bats)
        fi
    elif [[ "$INTEGRATION_ONLY" == "true" ]]; then
        # Integration tests only
        if [[ -n "$TEST_PATTERN" ]]; then
            test_files=("$TESTS_DIR/integration/test_${TEST_PATTERN}_*.bats")
        else
            test_files=("$TESTS_DIR/integration/"*.bats)
        fi
    elif [[ "$SYSTEM_ONLY" == "true" ]]; then
        # System tests only
        if [[ -n "$TEST_PATTERN" ]]; then
            test_files=("$TESTS_DIR/system/test_${TEST_PATTERN}_*.bats")
        else
            test_files=("$TESTS_DIR/system/"*.bats)
        fi
    elif [[ -n "$TEST_PATTERN" ]]; then
        # Specific functional requirement
        test_files=(
            "$TESTS_DIR/unit/test_${TEST_PATTERN}_*.bats"
            "$TESTS_DIR/integration/test_${TEST_PATTERN}_*.bats"
            "$TESTS_DIR/system/test_${TEST_PATTERN}_*.bats"
        )
    else
        # All tests
        test_files=(
            "$TESTS_DIR/unit/"*.bats
            "$TESTS_DIR/integration/"*.bats
            "$TESTS_DIR/system/"*.bats
        )
    fi

    # Filter out non-existent files
    local existing_files=()
    for file in "${test_files[@]}"; do
        if [[ -f "$file" ]]; then
            existing_files+=("$file")
        fi
    done

    echo "${existing_files[@]}"
}

run_tests() {
    local test_files=("$@")

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warning "No test files found matching the criteria"
        return 0
    fi

    log_info "Running ${#test_files[@]} test file(s)..."
    echo ""

    # Build BATS command
    local bats_cmd="bats"

    if [[ "$VERBOSE" == "true" ]]; then
        bats_cmd="$bats_cmd --show-output-of-passing-tests"
    fi

    if [[ "$DEBUG" == "true" ]]; then
        bats_cmd="$bats_cmd --tap"
    fi

    # Add test files
    bats_cmd="$bats_cmd ${test_files[*]}"

    log_debug "BATS command: $bats_cmd"

    # Run tests
    local start_time
    start_time=$(date +%s)

    if eval "$bats_cmd"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_success "All tests passed! (${duration}s)"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_error "Some tests failed! (${duration}s)"
        return 1
    fi
}

show_test_summary() {
    echo ""
    echo "🧪 Test Runner Summary"
    echo "======================"

    if [[ "$QUICK_MODE" == "true" ]]; then
        echo "Mode: Quick (critical tests only)"
    elif [[ "$UNIT_ONLY" == "true" ]]; then
        echo "Mode: Unit tests only"
    elif [[ "$INTEGRATION_ONLY" == "true" ]]; then
        echo "Mode: Integration tests only"
    elif [[ "$SYSTEM_ONLY" == "true" ]]; then
        echo "Mode: System tests only"
    elif [[ -n "$TEST_PATTERN" ]]; then
        echo "Mode: $TEST_PATTERN tests only"
    else
        echo "Mode: All tests"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo "Output: Verbose"
    fi

    if [[ "$DEBUG" == "true" ]]; then
        echo "Debug: Enabled"
    fi

    echo ""
}

main() {
    echo "🧪 Dotfiles Test Runner"
    echo "======================="
    echo ""

    # Change to dotfiles root
    cd "$DOTFILES_ROOT" || {
        log_error "Cannot change to dotfiles root: $DOTFILES_ROOT"
        exit 1
    }

    # Check if tests directory exists
    if [[ ! -d "$TESTS_DIR" ]]; then
        log_error "Tests directory not found: $TESTS_DIR"
        exit 1
    fi

    # Check BATS installation
    if ! check_bats_installation; then
        if [[ "$INSTALL_BATS" == "true" ]]; then
            if ! install_bats; then
                exit 1
            fi
        else
            log_error "BATS is required but not installed"
            log_info "Run with --install-bats to install it automatically"
            log_info "Or install manually: brew install bats-core"
            exit 1
        fi
    fi

    # Get test files to run
    local test_files
    # Use portable array population compatible with macOS bash 3.2 (no readarray)
    IFS=$'\n' test_files=($(get_test_files))
    unset IFS

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warning "No test files found"
        exit 0
    fi

    # Show what we're about to run
    show_test_summary

    log_info "Test files to run:"
    for file in "${test_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo ""

    # Run the tests
    if run_tests "${test_files[@]}"; then
        log_success "🎉 Test run completed successfully!"
        exit 0
    else
        log_error "❌ Test run completed with failures"
        echo ""
        echo "💡 Next steps:"
        echo "   1. Review the failed tests above"
        echo "   2. Run with --verbose for more details"
        echo "   3. Run with --debug for TAP output"
        echo "   4. Check the test files for specific issues"
        exit 1
    fi
}

# Parse arguments and run main function
parse_arguments "$@"
main

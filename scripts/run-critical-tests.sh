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
DOTFILES_ROOT="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$DOTFILES_ROOT/tests"

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
    if [[ -f "$TESTS_DIR/system/test_fr1_bootstrap.bats" ]]; then
        if ! bats "$TESTS_DIR/system/test_fr1_bootstrap.bats"; then
            log_error "FR-1 Bootstrap tests failed"
            exit 1
        fi
    else
        log_warn "FR-1 test file not found, skipping..."
    fi
    
    log_info "Running FR-7 Debug Capabilities tests (sample)..."
    if [[ -f "$TESTS_DIR/system/test_fr7_debug_capabilities.bats" ]]; then
        # Run just a few critical FR-7 tests for speed
        if ! bats --filter "FR-7.1\|FR-7.2\|FR-7.12" "$TESTS_DIR/system/test_fr7_debug_capabilities.bats"; then
            log_error "Critical FR-7 tests failed"
            exit 1
        fi
    else
        log_warn "FR-7 test file not found, skipping..."
    fi
    
    log_info "Running basic configuration validation..."
    if [[ -f "$TESTS_DIR/integration/test_fr3_configuration_management.bats" ]]; then
        # Run just configuration existence tests for speed
        if ! bats --filter "FR-3.1\|FR-3.2" "$TESTS_DIR/integration/test_fr3_configuration_management.bats"; then
            log_error "Configuration validation tests failed"
            exit 1
        fi
    else
        log_warn "FR-3 test file not found, skipping..."
    fi
    
    log_info "✅ Critical tests passed successfully!"
}

main "$@"
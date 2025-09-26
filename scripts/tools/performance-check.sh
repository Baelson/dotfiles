#!/usr/bin/env bash
#
# Performance Check Script for Pre-commit Hook
#
# This script validates that setup dry-run execution completes
# within acceptable time limits to catch performance regressions.
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SETUP_SCRIPT="$DOTFILES_ROOT/setup.sh"
PERFORMANCE_LIMIT=120  # 120 seconds for dry-run

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
    log_info "Running performance check (dry-run timing validation)..."

    # Change to dotfiles root
    cd "$DOTFILES_ROOT" || {
        log_error "Cannot change to dotfiles root: $DOTFILES_ROOT"
        exit 1
    }

    # Verify setup script exists
    if [[ ! -f "$SETUP_SCRIPT" ]]; then
        log_error "Setup script not found: $SETUP_SCRIPT"
        exit 1
    fi

    # Performance test: time the dry-run execution
    log_info "Timing setup dry-run execution..."

    start_time=$(date +%s)

    # Run setup in dry-run mode with timeout
    if timeout 180s "$SETUP_SCRIPT" --dry-run --debug-verbose > /dev/null 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        log_info "Dry-run completed in ${duration} seconds"

        # Check if within performance limits
        if [[ $duration -gt $PERFORMANCE_LIMIT ]]; then
            log_error "Performance regression detected!"
            log_error "Dry-run took ${duration}s (limit: ${PERFORMANCE_LIMIT}s)"
            log_error "Please investigate setup script performance"
            exit 1
        else
            log_info "✅ Performance check passed (${duration}s < ${PERFORMANCE_LIMIT}s)"
        fi
    else
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Performance check failed: Bootstrap dry-run timed out (>180s)"
            log_error "This indicates a serious performance regression"
        else
            log_error "Performance check failed: Bootstrap dry-run failed with exit code $exit_code"
        fi
        exit 1
    fi

    log_info "✅ Performance validation completed successfully!"
}

main "$@"

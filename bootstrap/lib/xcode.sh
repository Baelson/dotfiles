#!/bin/zsh
#
# Xcode CLI Tools Installation Module
#
# This module provides functions for installing and managing Xcode CLI Tools
# on macOS systems.
#
# Usage: source "$(dirname "$0")/lib/xcode.sh"
#

# Guard against multiple sourcing
if [[ -n "${XCODE_MODULE_LOADED:-}" ]]; then
    return 0
fi
readonly XCODE_MODULE_LOADED=1

#======================================
# Xcode CLI Tools Functions
#======================================

install_xcode_cli_tools() {
    debug_trace "→ Entering: install_xcode_cli_tools"

    if xcode-select --print-path &> /dev/null; then
        log_success "Xcode CLI Tools already installed"
        debug_trace "← Exiting: install_xcode_cli_tools (already installed)"
        return 0
    fi

    log "Installing Xcode Command Line Tools..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would run: xcode-select --install"
        log_dry_run "Would wait for installation to complete with user interaction"
        debug_trace "← Exiting: install_xcode_cli_tools (dry-run)"
        return 0
    fi

    # Trigger the installation
    debug_verbose "Triggering Xcode CLI Tools installation"
    xcode-select --install &> /dev/null || true

    # Wait for installation to complete
    log "Waiting for Xcode CLI Tools installation to complete..."
    log "⏳ This may take several minutes and require user interaction..."

    local timeout=600  # 10 minutes timeout
    local elapsed=0

    until xcode-select --print-path &> /dev/null; do
        sleep 5
        ((elapsed += 5))

        if [[ $elapsed -ge $timeout ]]; then
            log_error "Xcode CLI Tools installation timed out after ${timeout} seconds"
            log_error "Please check the installation manually and try again"
            exit 1
        fi
    done

    log_success "Xcode CLI Tools installed successfully"
    debug_trace "← Exiting: install_xcode_cli_tools"
}

# Check if Xcode CLI Tools are installed
check_xcode_cli_tools() {
    if xcode-select --print-path &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Get Xcode CLI Tools version information
get_xcode_cli_tools_info() {
    if check_xcode_cli_tools; then
        local path
        path=$(xcode-select --print-path)
        debug_verbose "Xcode CLI Tools path: $path"

        # Try to get version info
        if command -v xcodebuild &> /dev/null; then
            local version
            version=$(xcodebuild -version 2>/dev/null | head -1)
            debug_verbose "Xcode version: $version"
        fi
    else
        debug_verbose "Xcode CLI Tools not installed"
    fi
}

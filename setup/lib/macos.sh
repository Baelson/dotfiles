#!/bin/zsh
#
# macOS Configuration Module
#
# This module provides functions for configuring macOS system settings
# and preferences.
#
# Usage: source "$(dirname "$0")/lib/macos.sh"
#

# Guard against multiple sourcing
if [[ -n "${MACOS_MODULE_LOADED:-}" ]]; then
    return 0
fi
readonly MACOS_MODULE_LOADED=1

#======================================
# macOS Configuration Functions
#======================================

configure_macos() {
    debug_trace "→ Entering: configure_macos"
    log "⚙️  Applying basic macOS configuration..."

    # Enable key repeat for all applications
    run_command "defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false" "Disable press-and-hold for keys"

    # Set faster key repeat rates
    run_command "defaults write NSGlobalDomain KeyRepeat -int 2" "Set fast key repeat rate"
    run_command "defaults write NSGlobalDomain InitialKeyRepeat -int 15" "Set fast initial key repeat"

    # Show all filename extensions in Finder
    run_command "defaults write NSGlobalDomain AppleShowAllExtensions -bool true" "Show all file extensions"

    # Show hidden files in Finder
    run_command "defaults write com.apple.finder AppleShowAllFiles -bool true" "Show hidden files in Finder"

    # Restart Finder to apply changes
    run_command "killall Finder &> /dev/null || true" "Restart Finder to apply changes"

    log_success "Basic macOS configuration applied"
    debug_trace "← Exiting: configure_macos"
}

# Configure macOS development settings
configure_macos_development() {
    debug_trace "→ Entering: configure_macos_development"
    log "🔧 Applying macOS development configuration..."

    # Disable Gatekeeper for development (be careful with this)
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would disable Gatekeeper for development"
        log_dry_run "Would configure Xcode settings"
    else
        # Only disable Gatekeeper if explicitly requested
        if [[ "${DISABLE_GATEKEEPER:-false}" == "true" ]]; then
            run_command "sudo spctl --master-disable" "Disable Gatekeeper for development"
        fi

        # Configure Xcode settings if Xcode is installed
        if command -v xcodebuild &> /dev/null; then
            run_command "defaults write com.apple.dt.Xcode DVTTextShowInvisibleCharacters -bool true" "Show invisible characters in Xcode"
            run_command "defaults write com.apple.dt.Xcode DVTTextShowLineNumbers -bool true" "Show line numbers in Xcode"
        fi
    fi

    log_success "macOS development configuration applied"
    debug_trace "← Exiting: configure_macos_development"
}

# Configure macOS security settings
configure_macos_security() {
    debug_trace "→ Entering: configure_macos_security"
    log "🔒 Applying macOS security configuration..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would configure security settings"
        log_dry_run "Would enable FileVault if not already enabled"
    else
        # Enable FileVault if not already enabled
        if ! fdesetup isactive &> /dev/null; then
            log_warning "FileVault is not enabled. Consider enabling it for security."
            log_warning "Run 'sudo fdesetup enable' to enable FileVault"
        else
            log_success "FileVault is already enabled"
        fi

        # Configure firewall
        run_command "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on" "Enable firewall"
    fi

    log_success "macOS security configuration applied"
    debug_trace "← Exiting: configure_macos_security"
}

# Check macOS version and compatibility
check_macos_compatibility() {
    debug_trace "→ Entering: check_macos_compatibility"

    local os_version
    os_version=$(sw_vers -productVersion)
    debug_verbose "macOS version: $os_version"

    # Check if version is supported (macOS 12+)
    local major_version
    major_version=$(echo "$os_version" | cut -d. -f1)

    if [[ $major_version -ge 12 ]]; then
        log_success "macOS version $os_version is supported"
        return 0
    else
        log_error "macOS version $os_version is not supported (requires macOS 12+)"
        return 1
    fi
}

# Get macOS system information
get_macos_info() {
    debug_trace "→ Entering: get_macos_info"

    local os_version
    os_version=$(sw_vers -productVersion)
    debug_verbose "macOS version: $os_version"

    local build_version
    build_version=$(sw_vers -buildVersion)
    debug_verbose "Build version: $build_version"

    local product_name
    product_name=$(sw_vers -productName)
    debug_verbose "Product name: $product_name"

    # Check architecture
    local arch
    arch=$(uname -m)
    debug_verbose "Architecture: $arch"

    # Check if running on Apple Silicon
    if [[ "$arch" == "arm64" ]]; then
        debug_verbose "Running on Apple Silicon"
    else
        debug_verbose "Running on Intel"
    fi
}

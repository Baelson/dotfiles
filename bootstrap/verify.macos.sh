#!/bin/zsh
#
# Verification Script for macOS-specific Setup
#
# This script validates that all macOS-specific components from setup.macos.sh
# are properly installed and configured
#
# Usage: ./bootstrap/verify.macos.sh
#

set -euo pipefail

# Configuration and Common Library
readonly SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"

# Source common functions
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
    init_logging "verify.macos"
    setup_error_trap "verify.macos"
    check_macos
else
    # Fallback logging if common library is not available
    readonly REPO_DIR="${REPO_DIR:-"$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Git/dotfiles")"}"
    readonly LOG_FILE="$SCRIPT_DIR/verify.macos_$(date +'%Y-%m-%d_%H-%M-%S').log"

    # Basic colors and logging functions (fallback - consistent with setup.core.sh)
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'

    log() {
        local msg="${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
        echo -e "$msg"
        [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    }

    log_success() {
        local msg="${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
        echo -e "$msg"
        [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1" >> "$LOG_FILE"
    }

    log_warning() {
        local msg="${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
        echo -e "$msg"
        [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1" >> "$LOG_FILE"
    }

    log_error() {
        local msg="${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
        echo -e "$msg" >&2
        [[ -n "${LOG_FILE:-}" ]] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1" >> "$LOG_FILE"
    }
fi

# Validation counters
validation_passed=0
validation_failed=0

validate_item() {
    local description="$1"
    local command="$2"

    if eval "$command" &> /dev/null; then
        log_success "$description"
        ((++validation_passed))
        return 0
    else
        log_error "$description"
        ((++validation_failed))
        return 1
    fi
}

main() {
    # Initialize log file if not using common library
    [[ -n "${LOG_FILE:-}" ]] && touch "$LOG_FILE"

    log "🔍 Verifying macOS-specific setup components..."
    echo ""

    # Brewfile Package Verification
    log "📦 Brewfile Package Verification:"
    if [ -f "$REPO_DIR/Brewfile" ]; then
        # Core CLI tools
        validate_item "git package" 'brew list git'
        validate_item "uv package" 'brew list uv'
        validate_item "mas package" 'brew list mas'
        validate_item "antigen package" 'brew list antigen'
        validate_item "neovim package" 'brew list neovim'

        # Key casks
        validate_item "visual-studio-code cask" 'brew list --cask visual-studio-code'
        validate_item "iterm2 cask" 'brew list --cask iterm2'
        validate_item "docker cask" 'brew list --cask docker'

        # Sample MAS apps (if signed in)
        if mas account &> /dev/null; then
            validate_item "Xcode MAS app" 'mas list | grep -q Xcode'
            validate_item "Keynote MAS app" 'mas list | grep -q Keynote'
        else
            log_warning "Not signed into Mac App Store - skipping MAS app verification"
        fi
    else
        log_error "Brewfile not found at $REPO_DIR/Brewfile"
    fi
    echo ""

    # macOS Configuration Verification
    log "⚙️  macOS Configuration Verification:"

    # Key repeat settings
    local key_repeat=$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo "not set")
    if [ "$key_repeat" = "2" ]; then
        log_success "Fast key repeat enabled (KeyRepeat=2)"
    else
        log_warning "Key repeat setting: $key_repeat (expected: 2)"
    fi

    # Initial key repeat
    local initial_repeat=$(defaults read NSGlobalDomain InitialKeyRepeat 2>/dev/null || echo "not set")
    if [ "$initial_repeat" = "15" ]; then
        log_success "Fast initial key repeat enabled (InitialKeyRepeat=15)"
    else
        log_warning "Initial key repeat setting: $initial_repeat (expected: 15)"
    fi

    # Show all extensions
    local show_extensions=$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null || echo "not set")
    if [ "$show_extensions" = "1" ]; then
        log_success "Show all file extensions enabled"
    else
        log_warning "Show all extensions setting: $show_extensions (expected: 1)"
    fi

    # Show hidden files
    local show_hidden=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || echo "not set")
    if [ "$show_hidden" = "1" ]; then
        log_success "Show hidden files in Finder enabled"
    else
        log_warning "Show hidden files setting: $show_hidden (expected: 1)"
    fi
    echo ""

    # Summary
    log "📊 macOS Setup Verification Summary:"
    log "   ✅ Passed: $validation_passed checks"
    log "   ❌ Failed: $validation_failed checks"
    echo ""

    if [ $validation_failed -eq 0 ]; then
        log_success "🎉 All macOS-specific setup components verified!"
        log "macOS configuration is properly applied"
        [[ -n "${LOG_FILE:-}" ]] && log "Log file: $LOG_FILE"
        return 0
    else
        log_error "❌ Some macOS setup components failed verification"
        log "Consider re-running setup.macos.sh to fix issues"
        [[ -n "${LOG_FILE:-}" ]] && log "Log file: $LOG_FILE"
        return 1
    fi
}

# Handle script interruption
trap 'log_error "macOS verification script interrupted"; exit 1' INT TERM

# Run main function
main "$@"

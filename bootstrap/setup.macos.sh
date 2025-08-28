#!/bin/zsh
#
# macOS-specific Setup Script
#
# This script handles macOS-specific configuration and package installation
# Run after the initial bootstrap (setup.core.sh) completes
#
# Usage: ./bootstrap/setup.macos.sh
#

set -euo pipefail

# Configuration and Common Library
readonly SCRIPT_DIR="$(cd "${0:A:h}" && pwd)"

# Source common functions
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
    init_logging "setup.macos"
    setup_error_trap "setup.macos"
    check_macos
else
    # Fallback logging if common library is not available
    readonly REPO_DIR="${REPO_DIR:-"$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Git/dotfiles")"}"
    readonly LOG_FILE="$REPO_DIR/bootstrap/macos-setup_$(date +'%Y-%m-%d_%H-%M-%S').log"

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

main() {
    log "🔧 Starting macOS-specific setup..."

    # Ensure we're in the correct directory
    cd "$REPO_DIR"

    # Install packages from Brewfile
    install_packages

    # Run basic macOS configuration
    configure_macos

    log_success "macOS-specific setup completed!"
    log "Next: Phase 2 (Chezmoi Migration) - See docs/PRD.md for details"
}

install_packages() {
    log "📦 Installing packages from Brewfile..."

    # Validate REPO_DIR is set and accessible
    if [[ -z "${REPO_DIR:-}" ]]; then
        log_error "REPO_DIR is not set"
        exit 1
    fi

    if [[ ! -d "$REPO_DIR" ]]; then
        log_error "Repository directory does not exist: $REPO_DIR"
        exit 1
    fi

    if [ ! -f "$REPO_DIR/Brewfile" ]; then
        log_error "Brewfile not found in $REPO_DIR"
        exit 1
    fi

    # Install packages using brew bundle
    brew bundle --file="$REPO_DIR/Brewfile" || {
        log_error "Failed to install packages from Brewfile"
        exit 1
    }

    log_success "Packages installed successfully"
}

configure_macos() {
    log "⚙️  Applying basic macOS configuration..."

    # Enable key repeat for all applications
    defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

    # Set faster key repeat rates
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15

    # Show all filename extensions in Finder
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true

    # Show hidden files in Finder
    defaults write com.apple.finder AppleShowAllFiles -bool true

    # Restart Finder to apply changes
    killall Finder &> /dev/null || true

    log_success "Basic macOS configuration applied"
}

# Handle script interruption
trap 'log_error "macOS setup script interrupted"; exit 1' INT TERM

# Run main function
main "$@"

#!/bin/zsh
#
# Simple Bootstrap Script for macOS Development Environment
#
# This script handles the minimal setup needed to get the repository
# and then hands off to the full bootstrap system.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/bootstrap.sh | zsh
#        ./bootstrap.sh
#

set -euo pipefail

# Configuration
readonly REPO_URL="https://github.com/Baelson/dotfiles.git"
readonly REPO_DIR="$HOME/Git/dotfiles"

main() {
    echo "🚀 Starting macOS Development Environment Bootstrap..."
    echo "📍 Repository: $REPO_URL"
    echo "📍 Target Directory: $REPO_DIR"
    echo ""

    check_prerequisites
    setup_directory_structure
    clone_repository_if_needed
    verify_repository_structure
    handoff_to_core_setup
}

check_prerequisites() {
    echo "🔍 Checking prerequisites..."

    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ Error: This script is designed for macOS only"
        exit 1
    fi

    # Check if git is available
    if ! command -v git &> /dev/null; then
        echo "❌ Error: Git is not installed"
        echo "💡 Please install Xcode Command Line Tools first:"
        echo "   xcode-select --install"
        exit 1
    fi

    echo "✅ Prerequisites check passed"
}

setup_directory_structure() {
    echo "📁 Setting up directory structure..."

    # Create Git directory if it doesn't exist
    if [[ ! -d "$HOME/Git" ]]; then
        mkdir -p "$HOME/Git"
        echo "✅ Created $HOME/Git directory"
    fi

    echo "✅ Directory structure ready"
}

clone_repository_if_needed() {
    echo "📥 Checking repository status..."

    if [[ -d "$REPO_DIR/.git" ]]; then
        echo "✅ Repository already exists at $REPO_DIR"

        # Update existing repository (skip if there are conflicts)
        echo "🔄 Updating existing repository..."
        cd "$REPO_DIR"
        git fetch origin main 2>/dev/null || {
            echo "⚠️  Warning: Could not fetch updates, continuing with existing version"
        }
        return 0
    fi

    echo "📥 Cloning repository..."

    # Try SSH first, fallback to HTTPS
    if ! git clone "$REPO_URL" "$REPO_DIR" 2>/dev/null; then
        echo "⚠️  SSH clone failed, trying HTTPS..."
        local https_url="${REPO_URL/git@github.com:/https://github.com/}"
        git clone "$https_url" "$REPO_DIR" || {
            echo "❌ Error: Failed to clone repository"
            echo "💡 Please check your internet connection and try again"
            exit 1
        }
    fi

    echo "✅ Repository cloned successfully"
}

verify_repository_structure() {
    echo "🔍 Verifying repository structure..."

    # Check if we're in the right directory
    if [[ ! -f "$REPO_DIR/scripts/setup/setup.core.sh" ]]; then
        echo "❌ Error: Required file scripts/setup/setup.core.sh not found"
        echo "💡 Repository structure may be corrupted, try removing $REPO_DIR and re-running"
        exit 1
    fi

    if [[ ! -f "$REPO_DIR/scripts/setup/lib/common.sh" ]]; then
        echo "❌ Error: Required file scripts/setup/lib/common.sh not found"
        echo "💡 Repository structure may be corrupted, try removing $REPO_DIR and re-running"
        exit 1
    fi

    echo "✅ Repository structure verified"
}

handoff_to_core_setup() {
    echo ""
    echo "🔄 Repository ready! Handing off to core setup..."
    echo "📍 Switching to: $REPO_DIR"
    echo ""

    cd "$REPO_DIR"

    # Execute the core setup script with any arguments passed to this script
    exec ./scripts/setup/setup.core.sh "$@"
}

# Handle script interruption
trap 'echo "❌ Bootstrap interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"

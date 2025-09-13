#!/bin/zsh
#
# One-Line Installer for macOS Development Environment
#
# This script leverages chezmoi's native remote install capability
# with fallback for curl-pipe-to-shell compatibility
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/install.sh | zsh
#   EPHEMERAL=1 curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/install.sh | zsh
#   ASK=1 curl -fsSL https://raw.githubusercontent.com/Baelson/dotfiles/main/install.sh | zsh
#

set -euo pipefail

# Configuration
readonly REPO_OWNER="Baelson"
readonly REPO_NAME="dotfiles"
readonly REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"

# Environment variables for customization
readonly EPHEMERAL="${EPHEMERAL:-}"
readonly HEADLESS="${HEADLESS:-}"
readonly ASK="${ASK:-}"

main() {
    echo "🚀 Starting macOS Development Environment Setup..."
    echo "📍 Repository: ${REPO_OWNER}/${REPO_NAME}"
    echo ""

    check_prerequisites
    install_chezmoi_if_needed
    run_chezmoi_init

    echo ""
    echo "🎉 Setup completed successfully!"
    echo "💡 Run 'chezmoi edit' to modify configurations"
    echo "💡 Run 'chezmoi apply --dry-run' to preview changes"
    echo "💡 Run 'chezmoi apply' to apply pending changes"
}

check_prerequisites() {
    echo "🔍 Checking prerequisites..."

    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ Error: This installer is designed for macOS only"
        echo "💡 For other platforms, please use chezmoi directly:"
        echo "   sh -c \"\$(curl -fsLS get.chezmoi.io)\" -- init ${REPO_OWNER} --apply"
        exit 1
    fi

    # Check if git is available (needed for chezmoi)
    if ! command -v git &> /dev/null; then
        echo "📱 Git not found. Installing Xcode CLI Tools..."
        xcode-select --install

        # Wait for installation
        until command -v git &> /dev/null; do
            echo "⏳ Waiting for Xcode CLI Tools installation..."
            sleep 5
        done
        echo "✅ Xcode CLI Tools installed"
    fi

    echo "✅ Prerequisites satisfied"
}

install_chezmoi_if_needed() {
    if command -v chezmoi &> /dev/null; then
        echo "✅ chezmoi already installed: $(chezmoi --version | head -1)"
        return 0
    fi

    echo "📦 Installing chezmoi..."

    # Use chezmoi's official installer
    sh -c "$(curl -fsLS get.chezmoi.io)"

    # Add to PATH for current session
    export PATH="$HOME/bin:$PATH"

    if command -v chezmoi &> /dev/null; then
        echo "✅ chezmoi installed successfully: $(chezmoi --version | head -1)"
    else
        echo "❌ chezmoi installation failed"
        exit 1
    fi
}

run_chezmoi_init() {
    echo "🏠 Initializing dotfiles with chezmoi..."

    # Build chezmoi init command with environment-specific options
    local -a chezmoi_args=(
        "--apply"
        "--verbose"
    )

    # Add data for template processing
    if [[ -n "$EPHEMERAL" ]]; then
        chezmoi_args+=("--data" "ephemeral=true")
    fi

    if [[ -n "$HEADLESS" ]]; then
        chezmoi_args+=("--data" "headless=true")
    fi

    # Interactive mode allows for prompts
    if [[ -z "$ASK" ]] && [[ -t 0 ]]; then
        echo "💬 Running in interactive mode (set ASK=1 to force prompts)"
    fi

    # Initialize chezmoi with the repository
    echo "🔧 Running: chezmoi init ${chezmoi_args[*]} ${REPO_OWNER}"
    chezmoi init "${chezmoi_args[@]}" "${REPO_OWNER}"
}

# Error handling
trap 'echo "❌ Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"

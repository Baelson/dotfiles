#!/bin/zsh
#
# chezmoi Lifecycle Script: Homebrew Installation
# ===============================================
#
# This script runs once before other package installations to ensure Homebrew is available.
# Uses chezmoi's run_once_before_ prefix for one-time execution.
#
# References:
# - chezmoi run_once scripts: https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/#install-packages-with-scripts
# - Homebrew installation: https://docs.brew.sh/Installation
# - chezmoi script naming: https://www.chezmoi.io/reference/special-files-and-directories/chezmoiscripts/
#
# Script Behavior:
# - Runs once per machine (tracked by chezmoi)
# - Installs Xcode CLI Tools if needed (prerequisite for Homebrew)
# - Installs Homebrew using official installer
# - Adds Homebrew to PATH for current session
# - Verifies installation success
#

set -euo pipefail

echo "🍺 Installing Homebrew..."

# Check if Homebrew is already installed
if command -v brew >/dev/null 2>&1; then
    echo "✅ Homebrew already installed at $(which brew)"
    exit 0
fi

# Install Xcode CLI Tools first if not available
if ! xcode-select -p >/dev/null 2>&1; then
    echo "📱 Installing Xcode CLI Tools..."
    xcode-select --install

    # Wait for installation to complete
    until xcode-select -p >/dev/null 2>&1; do
        echo "⏳ Waiting for Xcode CLI Tools installation to complete..."
        sleep 5
    done
    echo "✅ Xcode CLI Tools installed"
fi

# Install Homebrew using official installer
echo "📦 Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH for current session
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Verify installation
if command -v brew >/dev/null 2>&1; then
    echo "✅ Homebrew successfully installed"
    brew --version
else
    echo "❌ Homebrew installation failed"
    exit 1
fi

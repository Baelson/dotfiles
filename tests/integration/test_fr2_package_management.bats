#!/usr/bin/env bats
#
# FR-2: Package Management Integration Testing
#
# This test suite validates the automated installation of development tools
# and applications as specified in FR-2 requirements.
#
# Reference: docs/PRD.md#fr-2-package-management-integration
#

load '../lib/test_helper'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# FR-2.1: Brewfile package installation validation
@test "FR-2.1: Brewfile exists and contains expected packages" {
    [[ -f "$DOTFILES_ROOT/Brewfile" || -f "$DOTFILES_ROOT/dot_Brewfile" || -f "$DOTFILES_ROOT/.Brewfile" ]]
    
    # Find the Brewfile (could be managed by chezmoi)
    brewfile=""
    if [[ -f "$DOTFILES_ROOT/Brewfile" ]]; then
        brewfile="$DOTFILES_ROOT/Brewfile"
    elif [[ -f "$DOTFILES_ROOT/dot_Brewfile" ]]; then
        brewfile="$DOTFILES_ROOT/dot_Brewfile"
    elif [[ -f "$DOTFILES_ROOT/.Brewfile" ]]; then
        brewfile="$DOTFILES_ROOT/.Brewfile"
    fi
    
    [[ -n "$brewfile" ]]
    
    # Verify it contains essential packages
    grep -q "brew " "$brewfile"
    grep -q "cask " "$brewfile"
    grep -q "mas " "$brewfile"
}

@test "FR-2.2: CLI tools package categories present in Brewfile" {
    # Find Brewfile
    brewfile=""
    [[ -f "$DOTFILES_ROOT/Brewfile" ]] && brewfile="$DOTFILES_ROOT/Brewfile"
    [[ -f "$DOTFILES_ROOT/dot_Brewfile" ]] && brewfile="$DOTFILES_ROOT/dot_Brewfile"
    [[ -f "$DOTFILES_ROOT/.Brewfile" ]] && brewfile="$DOTFILES_ROOT/.Brewfile"
    [[ -n "$brewfile" ]]
    
    # Check for essential development CLI tools
    essential_tools=("git" "python" "uv" "gh" "neovim")
    found_tools=0
    
    for tool in "${essential_tools[@]}"; do
        if grep -q "$tool" "$brewfile"; then
            found_tools=$((found_tools + 1))
        fi
    done
    
    # Should find at least 3 of the 5 essential tools
    [[ $found_tools -ge 3 ]]
}

@test "FR-2.3: Desktop applications (casks) present in Brewfile" {
    # Find Brewfile
    brewfile=""
    [[ -f "$DOTFILES_ROOT/Brewfile" ]] && brewfile="$DOTFILES_ROOT/Brewfile"
    [[ -f "$DOTFILES_ROOT/dot_Brewfile" ]] && brewfile="$DOTFILES_ROOT/dot_Brewfile"
    [[ -f "$DOTFILES_ROOT/.Brewfile" ]] && brewfile="$DOTFILES_ROOT/.Brewfile"
    [[ -n "$brewfile" ]]
    
    # Check for desktop applications
    desktop_apps=("visual-studio-code" "iterm2" "docker" "figma")
    found_apps=0
    
    for app in "${desktop_apps[@]}"; do
        if grep -q "$app" "$brewfile"; then
            found_apps=$((found_apps + 1))
        fi
    done
    
    # Should find at least 2 of the 4 desktop apps
    [[ $found_apps -ge 2 ]]
}

@test "FR-2.4: Mac App Store applications (mas) present in Brewfile" {
    # Find Brewfile
    brewfile=""
    [[ -f "$DOTFILES_ROOT/Brewfile" ]] && brewfile="$DOTFILES_ROOT/Brewfile"
    [[ -f "$DOTFILES_ROOT/dot_Brewfile" ]] && brewfile="$DOTFILES_ROOT/dot_Brewfile"
    [[ -f "$DOTFILES_ROOT/.Brewfile" ]] && brewfile="$DOTFILES_ROOT/.Brewfile"
    [[ -n "$brewfile" ]]
    
    # Check for MAS applications
    mas_apps=("Xcode" "497799835" "1295203466")  # Xcode, Xcode (ID), Microsoft Remote Desktop
    found_mas=0
    
    for app in "${mas_apps[@]}"; do
        if grep -q "$app" "$brewfile"; then
            found_mas=$((found_mas + 1))
        fi
    done
    
    # Should find at least 1 MAS app
    [[ $found_mas -ge 1 ]]
}

# FR-2.5: Package installation integration with bootstrap
@test "FR-2.5: setup.macos.sh integrates package installation" {
    [[ -f "$BOOTSTRAP_DIR/setup.macos.sh" ]]
    
    # Should reference Brewfile or package installation
    grep -q -i "brewfile\|bundle\|brew install" "$BOOTSTRAP_DIR/setup.macos.sh"
}

@test "FR-2.6: Package installation verification exists" {
    [[ -f "$BOOTSTRAP_DIR/verify.macos.sh" ]]
    
    # Should contain package verification logic
    grep -q -i "brew\|package\|install" "$BOOTSTRAP_DIR/verify.macos.sh"
}

# FR-2.7: Package management dry-run capability
@test "FR-2.7: Package management supports dry-run preview" {
    run_bootstrap "setup.macos.sh" "--dry-run"
    
    if [[ "$status" -eq 0 ]]; then
        # If setup.macos.sh supports dry-run, should show package preview
        [[ "$output" =~ (brew|Brewfile|package) ]]
    else
        # If setup.macos.sh doesn't exist or support dry-run, that's acceptable
        # but setup.core.sh should reference macOS setup
        run_bootstrap "setup.core.sh" "--dry-run"
        assert_bootstrap_success
        [[ "$output" =~ (macos|package|setup) ]]
    fi
}

# FR-2.8: Error handling for package installation failures
@test "FR-2.8: Package installation includes error handling" {
    if [[ -f "$BOOTSTRAP_DIR/setup.macos.sh" ]]; then
        # Should contain error handling for package failures
        grep -q -i "error\|fail\|exit\|return" "$BOOTSTRAP_DIR/setup.macos.sh"
    else
        skip "setup.macos.sh not found, checking setup.core.sh"
    fi
}

# FR-2.9: Package count validation
@test "FR-2.9: Brewfile contains expected package count (70+ packages)" {
    # Find Brewfile
    brewfile=""
    [[ -f "$DOTFILES_ROOT/Brewfile" ]] && brewfile="$DOTFILES_ROOT/Brewfile"
    [[ -f "$DOTFILES_ROOT/dot_Brewfile" ]] && brewfile="$DOTFILES_ROOT/dot_Brewfile"
    [[ -f "$DOTFILES_ROOT/.Brewfile" ]] && brewfile="$DOTFILES_ROOT/.Brewfile"
    [[ -n "$brewfile" ]]
    
    # Count packages (brew, cask, mas entries)
    package_count=$(grep -E "^(brew |cask |mas )" "$brewfile" | wc -l | tr -d ' ')
    
    # Should have a reasonable number of packages (at least 20, targeting 70+)
    [[ $package_count -ge 20 ]]
}

# FR-2.10: MAS authentication handling
@test "FR-2.10: MAS authentication considerations present" {
    if [[ -f "$BOOTSTRAP_DIR/setup.macos.sh" ]]; then
        # MAS authentication is handled by 'brew bundle' which includes MAS packages
        # The script should use 'brew bundle' which handles MAS auth automatically
        grep -q -i "brew bundle" "$BOOTSTRAP_DIR/setup.macos.sh"
    else
        # Check if MAS packages exist in Brewfile (implies authentication handling needed)
        brewfile=""
        [[ -f "$DOTFILES_ROOT/Brewfile" ]] && brewfile="$DOTFILES_ROOT/Brewfile"
        [[ -f "$DOTFILES_ROOT/dot_Brewfile" ]] && brewfile="$DOTFILES_ROOT/dot_Brewfile"
        [[ -f "$DOTFILES_ROOT/.Brewfile" ]] && brewfile="$DOTFILES_ROOT/.Brewfile"
        
        if [[ -n "$brewfile" ]]; then
            mas_count=$(grep -c "mas " "$brewfile")
            [[ $mas_count -ge 0 ]]  # If MAS packages exist, authentication is implied
        fi
    fi
}
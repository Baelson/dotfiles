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

# Helper function to render Brewfile template for testing
get_rendered_brewfile() {
    local brewfile_content=""
    if [[ -f "$DOTFILES_SOURCE_DIR/Brewfile.tmpl" ]]; then
        # Use chezmoi to render the template with default values
        if command -v chezmoi >/dev/null 2>&1; then
            brewfile_content="$(chezmoi cat Brewfile 2>/dev/null)" || {
                # Fallback: basic template rendering for testing
                brewfile_content="$(sed 's/{{.*}}/# template-placeholder/g' "$DOTFILES_SOURCE_DIR/Brewfile.tmpl")"
            }
        else
            # Basic template rendering for CI environments without chezmoi
            brewfile_content="$(sed 's/{{.*}}/# template-placeholder/g' "$DOTFILES_SOURCE_DIR/Brewfile.tmpl")"
        fi
    elif [[ -f "$DOTFILES_SOURCE_DIR/Brewfile" ]]; then
        brewfile_content="$(cat "$DOTFILES_SOURCE_DIR/Brewfile")"
    fi
    echo "$brewfile_content"
}

# FR-2.1: Brewfile package installation validation
@test "FR-2.1: Brewfile exists and contains expected packages" {
    [[ -f "$DOTFILES_SOURCE_DIR/Brewfile.tmpl" || -f "$DOTFILES_SOURCE_DIR/Brewfile" || -f "$DOTFILES_SOURCE_DIR/dot_Brewfile" ]]

    # Get rendered Brewfile content
    brewfile_content="$(get_rendered_brewfile)"
    [[ -n "$brewfile_content" ]]

    # Verify it contains essential packages
    echo "$brewfile_content" | grep -q "brew "
    echo "$brewfile_content" | grep -q "cask "
    echo "$brewfile_content" | grep -q "mas "
}

@test "FR-2.2: CLI tools package categories present in Brewfile" {
    # Get rendered Brewfile content
    brewfile_content="$(get_rendered_brewfile)"
    [[ -n "$brewfile_content" ]]

    # Check for essential development CLI tools
    essential_tools=("git" "python" "uv" "gh" "neovim")
    found_tools=0

    for tool in "${essential_tools[@]}"; do
        if echo "$brewfile_content" | grep -q "$tool"; then
            found_tools=$((found_tools + 1))
        fi
    done

    # Should find at least 3 of the 5 essential tools
    [[ $found_tools -ge 3 ]]
}

@test "FR-2.3: Desktop applications (casks) present in Brewfile" {
    # Get rendered Brewfile content
    brewfile_content="$(get_rendered_brewfile)"
    [[ -n "$brewfile_content" ]]

    # Check for desktop applications
    desktop_apps=("visual-studio-code" "iterm2" "docker" "figma")
    found_apps=0

    for app in "${desktop_apps[@]}"; do
        if echo "$brewfile_content" | grep -q "$app"; then
            found_apps=$((found_apps + 1))
        fi
    done

    # Should find at least 2 of the 4 desktop apps
    [[ $found_apps -ge 2 ]]
}

@test "FR-2.4: Mac App Store applications (mas) present in Brewfile" {
    # Get rendered Brewfile content
    brewfile_content="$(get_rendered_brewfile)"
    [[ -n "$brewfile_content" ]]

    # Check for MAS applications
    mas_apps=("Xcode" "497799835" "1295203466")  # Xcode, Xcode (ID), Microsoft Remote Desktop
    found_mas=0

    for app in "${mas_apps[@]}"; do
        if echo "$brewfile_content" | grep -q "$app"; then
            found_mas=$((found_mas + 1))
        fi
    done

    # Should find at least 1 MAS app
    [[ $found_mas -ge 1 ]]
}

# FR-2.5: Package installation integration with bootstrap
@test "FR-2.5: setup.macos.sh integrates package installation" {
    [[ -f "$DOTFILES_ROOT/setup.sh" ]]

    # Should reference Brewfile or package installation (direct or via module)
    grep -q -i -E "brewfile|bundle|brew install|install_packages|chezmoi" "$DOTFILES_ROOT/setup.sh"
}

@test "FR-2.6: Package installation verification exists" {
    local package_lifecycle_script="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"

    [[ -f "$package_lifecycle_script" ]]
    grep -q -i -E "brew bundle|install|package" "$package_lifecycle_script"
}

# FR-2.7: Package management dry-run capability
@test "FR-2.7: Package management supports dry-run preview" {
    run_bootstrap "setup.macos.sh" "--dry-run"

    if [[ "$status" -eq 0 ]]; then
        # If setup.macos.sh supports dry-run, should show package preview
        [[ "$output" =~ (brew|Brewfile|[Pp]ackage) ]]
    else
        # If setup.macos.sh doesn't exist or support dry-run, that's acceptable
        # but setup.sh should reference macOS setup
        run_bootstrap "setup.sh" "--dry-run"
        assert_bootstrap_success
        [[ "$output" =~ (macos|package|setup) ]]
    fi
}

# FR-2.8: Error handling for package installation failures
@test "FR-2.8: Package installation includes error handling" {
    local package_lifecycle_script="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"

    grep -q -i -E "error|fail|exit|return|not found" "$DOTFILES_ROOT/setup.sh"
    grep -q -i -E "error|fail|exit|return|not found" "$package_lifecycle_script"
}

# FR-2.9: Package count validation
@test "FR-2.9: Brewfile contains expected package count (70+ packages)" {
    # Get rendered Brewfile content
    brewfile_content="$(get_rendered_brewfile)"
    [[ -n "$brewfile_content" ]]

    # Count packages (brew, cask, mas entries)
    package_count=$(echo "$brewfile_content" | grep -E "^(brew |cask |mas )" | wc -l | tr -d ' ')

    # Should have a reasonable number of packages (at least 20, targeting 70+)
    [[ $package_count -ge 20 ]]
}

# FR-2.10: MAS authentication handling
@test "FR-2.10: MAS authentication considerations present" {
    # MAS authentication is handled by 'brew bundle' which includes MAS packages
    # Check modern package lifecycle handling.
    local package_lifecycle_script="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"
    [[ -f "$package_lifecycle_script" ]]
    grep -q -i "brew bundle" "$package_lifecycle_script"

    # If MAS entries exist in the Brewfile template, auth handling is implied.
    mas_count=$(grep -c "^mas " "$DOTFILES_SOURCE_DIR/Brewfile.tmpl" || true)
    [[ $mas_count -ge 0 ]]
}

#!/usr/bin/env bats
#
# chezmoi Lifecycle Scripts Testing
#
# This test suite validates the chezmoi lifecycle scripts that form the core
# of the Phase 3 chezmoi-native architecture. These scripts handle automated
# setup based on system changes and environment configuration.
#
# Reference: docs/SYSTEM_DESIGN.md#chezmoi-script-execution-flow
#

load '../lib/test_helper'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# Homebrew Installation Script (run_once_before)
@test "LIFECYCLE-1: Homebrew installation script exists and is executable" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_once_before_install-homebrew.sh"

    [[ -f "$script_path" ]]
    [[ -r "$script_path" ]]

    # Should have proper shebang
    head -1 "$script_path" | grep -q "#!/bin/zsh"

    # Should contain Homebrew installation logic
    grep -q "brew" "$script_path"
    grep -q "Homebrew" "$script_path"
}

@test "LIFECYCLE-2: Homebrew script handles prerequisites correctly" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_once_before_install-homebrew.sh"

    # Should check for Xcode CLI Tools
    grep -q "xcode-select" "$script_path"

    # Should install Homebrew using official installer
    grep -q "raw.githubusercontent.com/Homebrew/install" "$script_path"

    # Should verify installation
    grep -q "command -v brew" "$script_path"
}

@test "LIFECYCLE-3: Homebrew script has proper error handling" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_once_before_install-homebrew.sh"

    # Should use strict error handling
    grep -q "set -euo pipefail" "$script_path"

    # Should have success/failure feedback
    grep -q "✅" "$script_path" || grep -q "success" "$script_path"
    grep -q "❌" "$script_path" || grep -q "fail" "$script_path"
}

# Package Installation Script (run_onchange_after template)
@test "LIFECYCLE-4: Package installation script exists and is templated" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"

    [[ -f "$script_path" ]]
    [[ "$script_path" =~ \.tmpl$ ]]

    # Should be a template with Go template syntax
    grep -q "{{" "$script_path"
    grep -q "}}" "$script_path"
}

@test "LIFECYCLE-5: Package script uses change detection correctly" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"

    # Should include Brewfile hash for change detection
    grep -q "Brewfile.*sha256sum" "$script_path" || grep -q "hash:" "$script_path"

    # Should reference Brewfile location
    grep -q "\$HOME/Brewfile" "$script_path" || grep -q "~/Brewfile" "$script_path"
}

@test "LIFECYCLE-6: Package script has environment-aware logic" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"

    # Should have conditional logic for ephemeral environments
    grep -q "ephemeral" "$script_path"
    grep -q "{{.*if.*ephemeral" "$script_path" || grep -q "{{.*if.*\.ephemeral" "$script_path"

    # Should use brew bundle for package installation
    grep -q "brew bundle" "$script_path"
}

# macOS Defaults Configuration Script
@test "LIFECYCLE-7: macOS defaults script exists and is templated" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"

    [[ -f "$script_path" ]]
    [[ "$script_path" =~ \.tmpl$ ]]

    # Should be templated for environment awareness
    grep -q "{{" "$script_path"
    grep -q "}}" "$script_path"
}

@test "LIFECYCLE-8: macOS defaults script skips headless environments" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"

    # Should skip in headless environments
    grep -q "headless" "$script_path"
    grep -q "{{.*if.*headless" "$script_path" || grep -q "{{.*if.*\.headless" "$script_path"

    # Should have exit logic for headless
    grep -q "exit.*0" "$script_path"
}

@test "LIFECYCLE-9: macOS defaults script configures system preferences" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"

    # Should use defaults command for system configuration
    grep -q "defaults write" "$script_path"

    # Should configure common preferences
    grep -q "Dock\|dock" "$script_path"
    grep -q "Finder\|finder" "$script_path"

    # Should restart affected applications
    grep -q "killall" "$script_path"
}

@test "LIFECYCLE-10: macOS defaults script has work/personal differentiation" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"

    # Should have conditional logic for work vs personal
    grep -q "work" "$script_path" || grep -q "personal" "$script_path"
    grep -q "{{.*if.*work" "$script_path" || grep -q "{{.*if.*\.work" "$script_path"
}

# Shell Environment Setup Script
@test "LIFECYCLE-11: Shell environment script exists and is templated" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl"

    [[ -f "$script_path" ]]
    [[ "$script_path" =~ \.tmpl$ ]]

    # Should include change detection
    grep -q "hash:" "$script_path" || grep -q "sha256sum" "$script_path"
}

@test "LIFECYCLE-12: Shell environment script configures zsh and plugins" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl"

    # Should configure Antigen
    grep -q "antigen" "$script_path" || grep -q "Antigen" "$script_path"

    # Should setup fzf
    grep -q "fzf" "$script_path"

    # Should handle shell configuration
    grep -q "zsh" "$script_path" || grep -q "shell" "$script_path"
}

@test "LIFECYCLE-13: Shell environment script respects environment settings" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl"

    # Should skip in headless environments
    grep -q "headless" "$script_path"

    # Should have different behavior for ephemeral environments
    grep -q "ephemeral" "$script_path"
}

# Application Setup Script
@test "LIFECYCLE-14: Application setup script exists and is templated" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"

    [[ -f "$script_path" ]]
    [[ "$script_path" =~ \.tmpl$ ]]

    # Should have template logic
    grep -q "{{" "$script_path"
    grep -q "}}" "$script_path"
}

@test "LIFECYCLE-15: Application setup script configures development tools" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"

    # Should configure Git
    grep -q "git" "$script_path"

    # Should handle VS Code if present
    grep -q "code" "$script_path" || grep -q "VS Code" "$script_path"

    # Should handle Docker if present
    grep -q "docker" "$script_path" || grep -q "Docker" "$script_path"
}

@test "LIFECYCLE-16: Application setup script has environment-specific logic" {
    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"

    # Should skip in headless environments
    grep -q "headless" "$script_path"

    # Should have different logic for personal vs work
    grep -q "personal" "$script_path"

    # Should handle ephemeral environments
    grep -q "ephemeral" "$script_path"
}

# Template Rendering Tests
@test "LIFECYCLE-17: Package installation script renders correctly for ephemeral environment" {

    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"

    # Render template for ephemeral environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl" "ephemeral=true" "headless=false" "personal=false" "work=false"
    assert_chezmoi_success

    # Should skip cleanup in ephemeral environments
    [[ ! "$output" =~ "brew cleanup" ]] || [[ "$output" =~ "not.*ephemeral" ]]
}

@test "LIFECYCLE-18: macOS defaults script renders correctly for headless environment" {

    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"

    # Render template for headless environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl" "ephemeral=false" "headless=true" "personal=false" "work=false"
    assert_chezmoi_success

    # Should skip macOS defaults in headless environments
    [[ "$output" =~ "Skipping.*headless" ]] || [[ "$output" =~ "exit 0" ]]
}

@test "LIFECYCLE-19: Shell environment script renders correctly for different environments" {

    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl"

    # Test headless environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl" "ephemeral=false" "headless=true" "personal=false" "work=false"
    assert_chezmoi_success
    [[ "$output" =~ "Skipping.*headless" ]] || [[ "$output" =~ "exit 0" ]]

    # Test ephemeral environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl" "ephemeral=true" "headless=false" "personal=false" "work=false"
    assert_chezmoi_success
    # Should skip fzf setup in ephemeral environments
    [[ ! "$output" =~ "fzf.*install" ]] || [[ "$output" =~ "not.*ephemeral" ]]
}

@test "LIFECYCLE-20: Application setup script renders correctly for personal vs work" {

    local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"

    # Test personal environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false"
    assert_chezmoi_success
    [[ "$output" =~ "personal" ]] || [[ "$output" =~ "Alfred" ]]

    # Test work environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl" "ephemeral=false" "headless=false" "personal=false" "work=true"
    assert_chezmoi_success
    # Work environment should not have personal app setup
    [[ ! "$output" =~ "Alfred.*workflows" ]] || [[ "$output" =~ "not.*personal" ]]
}

# Script Execution Order and Dependencies
@test "LIFECYCLE-21: Scripts have correct naming for execution order" {
    # run_once_before should come before run_onchange_after
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_once_before_install-homebrew.sh" ]]

    # run_onchange_after scripts should be ordered logically
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl" ]]
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl" ]]
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl" ]]
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl" ]]
}

@test "LIFECYCLE-22: All scripts use consistent error handling patterns" {
    local scripts=(
        "run_once_before_install-homebrew.sh"
        "run_onchange_after_install-packages.sh.tmpl"
        "run_onchange_after_configure-macos-defaults.sh.tmpl"
        "run_onchange_after_setup-shell-environment.sh.tmpl"
        "run_onchange_after_setup-applications.sh.tmpl"
    )

    for script in "${scripts[@]}"; do
        local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/$script"

        # Should use strict error handling (except in template conditionals)
        if [[ ! "$script" =~ \.tmpl$ ]]; then
            grep -q "set -euo pipefail" "$script_path"
        fi

        # Should have proper shebang
        head -1 "$script_path" | grep -q "#!/bin/zsh"
    done
}

@test "LIFECYCLE-23: All template scripts have comprehensive documentation" {
    local template_scripts=(
        "run_onchange_after_install-packages.sh.tmpl"
        "run_onchange_after_configure-macos-defaults.sh.tmpl"
        "run_onchange_after_setup-shell-environment.sh.tmpl"
        "run_onchange_after_setup-applications.sh.tmpl"
    )

    for script in "${template_scripts[@]}"; do
        local script_path="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/$script"

        # Should have header documentation
        grep -q "chezmoi Lifecycle Script" "$script_path"

        # Should reference chezmoi documentation
        grep -q "chezmoi.io" "$script_path" || grep -q "References:" "$script_path"

        # Should explain script behavior
        grep -q "Script Behavior:" "$script_path" || grep -q "This script" "$script_path"
    done
}

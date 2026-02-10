#!/usr/bin/env bats
#
# FR-1: Modern chezmoi-native Bootstrap Testing
#
# This test suite validates the modern chezmoi-native bootstrap functionality
# using setup.sh as specified in FR-1 requirements. This complements the legacy
# bootstrap tests in test_fr1_bootstrap.bats.
#
# Reference: docs/PRD.md#fr-1-one-command-bootstrap
#

load '../lib/test_helper'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# FR-1.1: Modern setup.sh execution
@test "FR-1.1M: setup.sh executes without errors" {
    # Skip if chezmoi not available (install would be tested in integration)
    if ! command -v chezmoi &> /dev/null; then
        skip "chezmoi not installed - would be installed by setup.sh"
    fi

    run_modern_setup
    assert_modern_setup_success

    # Should show modern bootstrap progression
    [[ "$output" =~ "macOS Development Environment Setup" || "$output" =~ "Starting macOS" || "$output" =~ "chezmoi" ]]
}

@test "FR-1.2M: Modern bootstrap provides clear progress feedback" {
    if ! command -v chezmoi &> /dev/null; then
        skip "chezmoi not installed"
    fi

    run_modern_setup
    assert_modern_setup_success

    # Should show progress indicators for modern workflow
    [[ "$output" =~ "🚀" || "$output" =~ "✅" || "$output" =~ "📦" || "$output" =~ "🔧" ]]

    # Should show chezmoi-specific steps
    [[ "$output" =~ "chezmoi" || "$output" =~ "Installing chezmoi" || "$output" =~ "already installed" ]]
}

@test "FR-1.3M: Modern bootstrap handles prerequisites" {
    if ! command -v chezmoi &> /dev/null; then
        skip "chezmoi not installed"
    fi

    run_modern_setup
    assert_modern_setup_success

    # Should check for and handle prerequisites
    [[ "$output" =~ "prerequisites" || "$output" =~ "Xcode" || "$output" =~ "git" || "$output" =~ "chezmoi" ]]
}

@test "FR-1.4M: Modern bootstrap supports environment variables" {
    if ! command -v chezmoi &> /dev/null; then
        skip "chezmoi not installed"
    fi

    # Test ephemeral environment
    run_modern_setup "EPHEMERAL=1"
    assert_modern_setup_success
    [[ "$output" =~ "chezmoi" ]]

    # Test headless environment
    run_modern_setup "HEADLESS=1"
    assert_modern_setup_success
    [[ "$output" =~ "chezmoi" ]]
}

@test "FR-1.5M: Modern bootstrap integrates with chezmoi properly" {
    if ! command -v chezmoi &> /dev/null; then
        skip "chezmoi not installed"
    fi

    run_modern_setup
    assert_modern_setup_success

    # Should use chezmoi init workflow
    [[ "$output" =~ "chezmoi init" || "$output" =~ "Initializing dotfiles" ]]
}

# chezmoi Integration Tests
@test "FR-1.6M: chezmoi configuration template renders correctly" {
    # Test that .chezmoi.toml.tmpl can be rendered
    test_template_rendering ".chezmoi.toml.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false"
    assert_chezmoi_success

    # Should contain configuration sections
    [[ "$output" =~ "\[data\]" ]]
    [[ "$output" =~ "ephemeral = false" ]]
    [[ "$output" =~ "headless = false" ]]
    [[ "$output" =~ "personal = true" ]]
    [[ "$output" =~ "work = false" ]]
}

@test "FR-1.7M: chezmoi detects environment correctly" {
    # Test ephemeral environment template
    test_template_rendering ".chezmoi.toml.tmpl" "ephemeral=true" "headless=false" "personal=false" "work=false"
    assert_chezmoi_success
    [[ "$output" =~ "ephemeral = true" ]]

    # Test headless environment template
    test_template_rendering ".chezmoi.toml.tmpl" "ephemeral=false" "headless=true" "personal=false" "work=false"
    assert_chezmoi_success
    [[ "$output" =~ "headless = true" ]]

    # Test work environment template
    test_template_rendering ".chezmoi.toml.tmpl" "ephemeral=false" "headless=false" "personal=false" "work=true"
    assert_chezmoi_success
    [[ "$output" =~ "work = true" ]]
}

@test "FR-1.8M: Brewfile template renders environment-specific packages" {
    # Test personal environment Brewfile
    test_template_rendering "Brewfile.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false" "hostname=personal-mac"
    assert_chezmoi_success

    # Should include personal packages
    [[ "$output" =~ "discord" ]] || [[ "$output" =~ "figma" ]]
    [[ "$output" =~ "mas.*Amphetamine" ]] || [[ "$output" =~ "mas.*Final Cut Pro" ]]

    # Test work environment Brewfile
    test_template_rendering "Brewfile.tmpl" "ephemeral=false" "headless=false" "personal=false" "work=true" "hostname=work-laptop"
    assert_chezmoi_success

    # Should include work packages but not personal ones
    [[ "$output" =~ "Slack" ]]
    [[ ! "$output" =~ "discord" ]]
}

@test "FR-1.9M: Ephemeral environment renders minimal packages" {
    # Test ephemeral environment Brewfile
    test_template_rendering "Brewfile.tmpl" "ephemeral=true" "headless=false" "personal=false" "work=false" "hostname=ci-runner"
    assert_chezmoi_success

    # Should exclude ephemeral packages
    [[ ! "$output" =~ "mas" ]]  # No Mac App Store apps
    [[ ! "$output" =~ "ddrescue" ]]  # No media utilities
    [[ ! "$output" =~ "ffmpeg" ]]

    # Should still include core tools
    [[ "$output" =~ "chezmoi" ]]
    [[ "$output" =~ "git" ]]
    [[ "$output" =~ "coreutils" ]]
}

@test "FR-1.10M: Headless environment excludes GUI applications" {
    # Test headless environment Brewfile
    test_template_rendering "Brewfile.tmpl" "ephemeral=false" "headless=true" "personal=false" "work=false" "hostname=server-01"
    assert_chezmoi_success

    # Should exclude GUI applications
    [[ ! "$output" =~ "cask" ]]  # No cask applications
    [[ ! "$output" =~ "visual-studio-code" ]]
    [[ ! "$output" =~ "iterm2" ]]

    # Should still include CLI tools
    [[ "$output" =~ "chezmoi" ]]
    [[ "$output" =~ "git" ]]
    [[ "$output" =~ "fzf" ]]
}

# Lifecycle Script Validation
@test "FR-1.11M: All required lifecycle scripts exist" {
    # Check run_once_before scripts
    validate_lifecycle_script_exists "run_once_before_install-homebrew.sh"

    # Check run_onchange_after template scripts
    validate_lifecycle_script_exists "run_onchange_after_install-packages.sh.tmpl"
    validate_lifecycle_script_exists "run_onchange_after_configure-macos-defaults.sh.tmpl"
    validate_lifecycle_script_exists "run_onchange_after_setup-shell-environment.sh.tmpl"
    validate_lifecycle_script_exists "run_onchange_after_setup-applications.sh.tmpl"
}

@test "FR-1.12M: Lifecycle scripts are properly templated" {
    # Check that templated scripts have .tmpl extension
    validate_lifecycle_script_templated "run_onchange_after_install-packages.sh.tmpl"
    validate_lifecycle_script_templated "run_onchange_after_configure-macos-defaults.sh.tmpl"
    validate_lifecycle_script_templated "run_onchange_after_setup-shell-environment.sh.tmpl"
    validate_lifecycle_script_templated "run_onchange_after_setup-applications.sh.tmpl"
}

@test "FR-1.13M: Modern system has proper error handling" {
    if ! command -v chezmoi &> /dev/null; then
        skip "chezmoi not installed"
    fi

    # Test with invalid environment variable (should still work)
    run_modern_setup "INVALID_VAR=1"

    # Should either succeed or fail gracefully with clear error
    if [[ "$status" -ne 0 ]]; then
        # If it fails, should have clear error message
        [[ "$output" =~ "error" || "$output" =~ "Error" || "$output" =~ "ERROR" ]]
    else
        # If it succeeds, should have normal output
        [[ "$output" =~ "chezmoi" ]]
    fi
}

@test "FR-1.14M: Modern bootstrap script structure is correct" {
    # Verify setup.sh has required structure
    [[ -f "$DOTFILES_ROOT/setup.sh" ]]

    # Should be executable
    [[ -x "$DOTFILES_ROOT/setup.sh" ]]

    # Should have proper shebang
    head -1 "$DOTFILES_ROOT/setup.sh" | grep -q "#!/bin/zsh"

    # Should contain key functions/concepts
    grep -q "chezmoi" "$DOTFILES_ROOT/setup.sh"
    grep -q "main()" "$DOTFILES_ROOT/setup.sh"
}

@test "FR-1.15M: Documentation references match implementation" {
    # Check that documented URLs in setup.sh actually work
    local documented_url
    documented_url=$(grep -o "https://raw.githubusercontent.com/[^\"]*setup.sh" "$DOTFILES_ROOT/setup.sh" | head -1)

    if [[ -n "$documented_url" ]]; then
        # Should reference the correct repository and file
        [[ "$documented_url" =~ "Baelson/dotfiles" ]]
        [[ "$documented_url" =~ "setup.sh" ]]
    fi

    # Check for chezmoi documentation references
    grep -q "chezmoi.io" "$DOTFILES_ROOT/setup.sh" || grep -q "chezmoi" "$DOTFILES_ROOT/setup.sh"
}

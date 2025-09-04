#!/usr/bin/env bats
#
# FR-1: One-Command Bootstrap Testing
#
# This test suite validates the single-command bootstrap functionality
# as specified in FR-1 requirements.
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

@test "FR-1.1: setup.core.sh executes without errors in dry-run mode" {
    run_bootstrap "setup.core.sh" "--dry-run"
    assert_bootstrap_success
    validate_fr1_one_command_bootstrap
    
    # Should show bootstrap progression
    [[ "$output" =~ "Bootstrap" || "$output" =~ "Setup" || "$output" =~ "macOS" ]]
}

@test "FR-1.2: Bootstrap provides clear progress feedback" {
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-verbose"
    assert_bootstrap_success
    
    # Should show progress indicators
    [[ "$output" =~ "Checking" || "$output" =~ "Installing" || "$output" =~ "Setting up" || "$output" =~ "Verifying" ]]
    
    # Should show step-by-step progression
    [[ "$output" =~ "Prerequisites" || "$output" =~ "Xcode" || "$output" =~ "Homebrew" || "$output" =~ "Git" ]]
}

@test "FR-1.3: Bootstrap handles fresh macOS prerequisites" {
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-trace"
    assert_bootstrap_success
    
    # Should check for and plan to install prerequisites
    [[ "$output" =~ "Xcode CLI Tools" || "$output" =~ "xcode-select" ]]
    [[ "$output" =~ "Homebrew" || "$output" =~ "brew" ]]
    [[ "$output" =~ "Git" || "$output" =~ "git" ]]
}
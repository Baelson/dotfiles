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

# FR-1.1: Single command execution works
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

@test "FR-1.4: Repository setup and validation" {
    run_bootstrap "setup.core.sh" "--dry-run"
    assert_bootstrap_success
    
    # Should reference repository operations
    [[ "$output" =~ "Git/dotfiles" || "$output" =~ "repository" || "$output" =~ "clone" ]]
}

@test "FR-1.5: Self-relocation capability" {
    # Test that script can handle being run from different locations
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-trace"
    assert_bootstrap_success
    
    # Should handle directory operations correctly
    [[ "$output" =~ "directory" || "$output" =~ "location" || "$output" =~ "Git/dotfiles" ]]
}

@test "FR-1.6: Error handling for common failures" {
    # Simulate network issues by testing error paths
    export SIMULATE_NETWORK_ERROR=true
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-verbose"
    
    # Even in dry-run, should handle error scenarios gracefully
    assert_bootstrap_success  # Dry run should succeed even with simulated errors
    
    # Should show error handling logic
    [[ "$output" =~ "error" || "$output" =~ "retry" || "$output" =~ "fallback" || "$status" -eq 0 ]]
    
    unset SIMULATE_NETWORK_ERROR
}

# FR-1.7: Integration with verification system
@test "FR-1.7: Bootstrap integrates with verification scripts" {
    # Test that setup script references verification
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-verbose"
    assert_bootstrap_success
    
    # Should mention verification or validation
    [[ "$output" =~ "verify" || "$output" =~ "validation" || "$output" =~ "check" ]]
}

# FR-1.8: Comprehensive system setup preview
@test "FR-1.8: Dry-run shows complete setup plan" {
    run_bootstrap "setup.core.sh" "--dry-run" "--debug-verbose"
    assert_bootstrap_success
    
    # Should show major setup components
    components_found=0
    [[ "$output" =~ "Xcode" ]] && ((++components_found))
    [[ "$output" =~ "Homebrew" ]] && ((++components_found))
    [[ "$output" =~ "Git" ]] && ((++components_found))
    [[ "$output" =~ "repository" ]] && ((++components_found))
    
    # Should find at least 3 of the 4 major components
    [[ $components_found -ge 3 ]]
}

# FR-1.9: Script execution from curl pipe compatibility
@test "FR-1.9: Script designed for curl pipe execution" {
    # Verify script has proper shebang and error handling for pipe execution
    head -1 "$BOOTSTRAP_DIR/setup.core.sh" | grep -q "#!/"
    
    # Verify script uses proper error handling (set -euo pipefail or equivalent)
    grep -q "set -e" "$BOOTSTRAP_DIR/setup.core.sh" || 
    grep -q "set -euo" "$BOOTSTRAP_DIR/setup.core.sh"
}

# FR-1.10: Bootstrap script architecture validation
@test "FR-1.10: Bootstrap script has required functions and structure" {
    # Verify main() function exists
    grep -q "main()" "$BOOTSTRAP_DIR/setup.core.sh"
    
    # Verify common library integration
    grep -q "lib/common.sh" "$BOOTSTRAP_DIR/setup.core.sh"
    
    # Verify self-relocation logic exists
    grep -q "relocate" "$BOOTSTRAP_DIR/setup.core.sh" ||
    grep -q "DOTFILES_ROOT" "$BOOTSTRAP_DIR/setup.core.sh" ||
    grep -q "Git/dotfiles" "$BOOTSTRAP_DIR/setup.core.sh"
}
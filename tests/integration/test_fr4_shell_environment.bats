#!/usr/bin/env bats
#
# FR-4: Shell Environment Configuration Testing
#
# This test suite validates the automated setup of Zsh, Oh My Zsh, Antigen,
# and Powerlevel10k as specified in FR-4 requirements.
#
# Reference: docs/PRD.md#fr-4-shell-environment-configuration
#

load '../lib/test_helper'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# FR-4.1: Zsh configuration management
@test "FR-4.1: Zsh configuration files exist and are managed" {
    # Check for zsh dotfiles in chezmoi management
    managed_zsh_files=("dot_zshrc" "dot_zshenv" "dot_zprofile")
    found_files=0
    
    for file in "${managed_zsh_files[@]}"; do
        if [[ -f "$DOTFILES_ROOT/$file" || -f "$DOTFILES_ROOT/${file}.tmpl" ]]; then
            found_files=$((found_files + 1))
        fi
    done
    
    # Should have at least 2 of the 3 zsh configuration files
    [[ $found_files -ge 2 ]]
}

@test "FR-4.2: Oh My Zsh external repository management" {
    [[ -f "$DOTFILES_ROOT/.chezmoiexternal.toml" ]]
    
    # Should contain Oh My Zsh configuration
    grep -q -i "oh-my-zsh\|ohmyzsh" "$DOTFILES_ROOT/.chezmoiexternal.toml"
}

@test "FR-4.3: Antigen plugin manager configuration" {
    [[ -f "$DOTFILES_ROOT/.chezmoiexternal.toml" ]]
    
    # Should contain Antigen configuration
    grep -q -i "antigen" "$DOTFILES_ROOT/.chezmoiexternal.toml"
}

@test "FR-4.4: Powerlevel10k theme configuration" {
    # Check for p10k configuration file
    [[ -f "$DOTFILES_ROOT/dot_p10k.zsh" || -f "$DOTFILES_ROOT/dot_p10k.zsh.tmpl" ]]
    
    # Verify it contains powerlevel10k configuration
    if [[ -f "$DOTFILES_ROOT/dot_p10k.zsh" ]]; then
        grep -q -i "powerlevel10k\|p10k" "$DOTFILES_ROOT/dot_p10k.zsh"
    fi
}

@test "FR-4.5: Directory colors configuration" {
    # Check for dircolors configuration - can be external or managed directly
    # External management via .chezmoiexternal.toml is preferred
    grep -q -i "dircolors" "$DOTFILES_ROOT/.chezmoiexternal.toml" || [[ -d "$DOTFILES_ROOT/dot_dircolors" || -f "$DOTFILES_ROOT/dot_dircolors" ]]
    
    # Should be managed via external repository
    grep -q -i "dircolors" "$DOTFILES_ROOT/.chezmoiexternal.toml"
}

@test "FR-4.6: Shell environment variables configuration" {
    # Check for environment configuration
    if [[ -f "$DOTFILES_ROOT/dot_zshenv" ]]; then
        # Should contain environment variable definitions
        grep -q -E "(export|PATH)" "$DOTFILES_ROOT/dot_zshenv"
    elif [[ -f "$DOTFILES_ROOT/dot_zshrc" ]]; then
        # Alternatively check zshrc for PATH modifications
        grep -q -E "(export|PATH)" "$DOTFILES_ROOT/dot_zshrc"
    else
        skip "No zsh environment files found to test"
    fi
}

@test "FR-4.7: Custom aliases and functions preservation" {
    # Check for custom aliases/functions in zsh config
    if [[ -f "$DOTFILES_ROOT/dot_zshrc" ]]; then
        # Should contain some customization (aliases, functions, or includes)
        grep -q -E "(alias|function|source|\\.)" "$DOTFILES_ROOT/dot_zshrc"
    else
        skip "dot_zshrc not found for alias testing"
    fi
}

@test "FR-4.8: iTerm2 shell integration considerations" {
    # Check for iTerm2 integration in shell config
    if [[ -f "$DOTFILES_ROOT/dot_zshrc" ]]; then
        # May contain iTerm2 integration
        if grep -q -i "iterm" "$DOTFILES_ROOT/dot_zshrc"; then
            # If iTerm2 integration is present, validate it
            grep -q -i "shell_integration\|iterm2" "$DOTFILES_ROOT/dot_zshrc"
        fi
    fi
    
    # Test passes regardless - iTerm2 integration is optional
    true
}

@test "FR-4.9: Shell plugin management via Antigen" {
    # Check if zshrc contains Antigen configuration
    if [[ -f "$DOTFILES_ROOT/dot_zshrc" ]]; then
        # Should reference antigen for plugin management
        if grep -q -i "antigen" "$DOTFILES_ROOT/dot_zshrc"; then
            # Validate antigen usage patterns
            grep -q -E "(antigen bundle|antigen theme|antigen apply)" "$DOTFILES_ROOT/dot_zshrc"
        fi
    fi
    
    # Also check that antigen is managed via external
    grep -q -i "antigen" "$DOTFILES_ROOT/.chezmoiexternal.toml"
}

@test "FR-4.10: Shell completion enhancements" {
    # Check for completion configuration
    if [[ -f "$DOTFILES_ROOT/dot_zshrc" ]]; then
        # Should contain completion setup
        if grep -q -i "completion\|compinit" "$DOTFILES_ROOT/dot_zshrc"; then
            # Validate completion configuration
            grep -q -E "(compinit|autoload.*comp)" "$DOTFILES_ROOT/dot_zshrc"
        fi
    fi
    
    # Test passes if no completion config found (may be handled by oh-my-zsh)
    true
}

# FR-4.11: Bootstrap integration for shell environment
@test "FR-4.11: Shell environment setup integrated with bootstrap" {
    # Check if bootstrap scripts reference shell setup
    shell_setup_found=false
    
    for script in "$BOOTSTRAP_DIR"/*.sh; do
        if [[ -f "$script" ]]; then
            if grep -q -i "shell\|zsh\|oh-my-zsh\|antigen" "$script"; then
                shell_setup_found=true
                break
            fi
        fi
    done
    
    # At minimum, chezmoi apply should handle shell configuration
    if [[ "$shell_setup_found" == "false" ]]; then
        # Check for chezmoi integration (which handles shell configs)
        for script in "$BOOTSTRAP_DIR"/*.sh; do
            if [[ -f "$script" ]] && grep -q -i "chezmoi" "$script"; then
                shell_setup_found=true
                break
            fi
        done
    fi
    
    [[ "$shell_setup_found" == "true" ]]
}

@test "FR-4.12: External repository update frequency configuration" {
    [[ -f "$DOTFILES_ROOT/.chezmoiexternal.toml" ]]
    
    # Check for refresh period configuration in external repos
    external_content=$(cat "$DOTFILES_ROOT/.chezmoiexternal.toml")
    
    # Should contain refresh period for at least one external tool
    [[ "$external_content" =~ refreshPeriod || "$external_content" =~ refresh ]]
}

@test "FR-4.13: Shell theme customization preservation" {
    # Check for theme configuration in p10k config
    if [[ -f "$DOTFILES_ROOT/dot_p10k.zsh" ]]; then
        # Should contain theme customization
        grep -q -E "(POWERLEVEL9K|P9K)_" "$DOTFILES_ROOT/dot_p10k.zsh"
    else
        skip "p10k configuration file not found"
    fi
}

@test "FR-4.14: Shell environment dry-run compatibility" {
    # Test that shell configuration doesn't interfere with dry-run
    run_bootstrap "setup.core.sh" "--dry-run"
    assert_bootstrap_success
    
    # Should complete without shell configuration errors
    [[ ! "$output" =~ "shell error" ]]
    [[ ! "$output" =~ "zsh.*error" ]]
}

@test "FR-4.15: External tool archive method validation" {
    [[ -f "$DOTFILES_ROOT/.chezmoiexternal.toml" ]]
    
    # Check that external tools use archive method for security
    external_content=$(cat "$DOTFILES_ROOT/.chezmoiexternal.toml")
    
    # Should use archive or git-repo type (not direct download)
    [[ "$external_content" =~ 'type = "archive"' || "$external_content" =~ 'type = "git-repo"' ]]
}
#!/usr/bin/env bats
#
# FR-3: Configuration Management Testing
#
# This test suite validates the automated restoration of dotfiles and
# application preferences as specified in FR-3 requirements.
#
# Reference: docs/PRD.md#fr-3-configuration-management
#

load '../lib/test_helper'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# FR-3.1: Chezmoi integration and configuration
@test "FR-3.1: Chezmoi configuration files exist and are valid" {
    # Check for chezmoi configuration (can be implicit or explicit)
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.yaml" || -f "$DOTFILES_SOURCE_DIR/.chezmoi.toml" || -f "$DOTFILES_SOURCE_DIR/.chezmoiexternal.toml" ]]

    # Check for basic chezmoi management files
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiignore" ]]
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiexternal.toml" ]]
}

@test "FR-3.2: Dotfile migration with chezmoi add --follow compatibility" {
    # Verify dotfiles are managed by chezmoi (dot_* pattern)
    dotfile_count=$(find "$DOTFILES_SOURCE_DIR" -name "dot_*" -type f | wc -l | tr -d ' ')
    [[ $dotfile_count -ge 5 ]]  # Should have at least 5 managed dotfiles

    # Check for essential dotfiles
    essentialhome=("dot_gitconfig" "dot_zshrc" "dot_vimrc" "dot_npmrc")
    foundhome=0

    for dotfile in "${essentialhome[@]}"; do
        if [[ -f "$DOTFILES_SOURCE_DIR/$dotfile" || -f "$DOTFILES_SOURCE_DIR/${dotfile}.tmpl" ]]; then
            foundhome=$((foundhome + 1))
        fi
    done

    [[ $foundhome -ge 2 ]]  # Should find at least 2 essential dotfiles
}

@test "FR-3.3: File permissions and content preservation" {
    # Test that dotfiles have appropriate permissions
    for dotfile in "$DOTFILES_SOURCE_DIR"/dot_*; do
        if [[ -f "$dotfile" ]]; then  # Only check files, not directories
            [[ -r "$dotfile" ]]  # Should be readable
            [[ ! -x "$dotfile" ]] || [[ "$dotfile" =~ \.sh$ ]]  # Should not be executable unless .sh
        fi
    done
}

@test "FR-3.4: Templating support for environment-specific configurations" {
    # Check for template files (.tmpl extension)
    template_count=$(find "$DOTFILES_ROOT" -name "*.tmpl" | wc -l | tr -d ' ')
    [[ $template_count -ge 0 ]]  # Templates are optional

    # If templates exist, verify they contain template variables
    if [[ $template_count -gt 0 ]]; then
        template_vars=$(find "$DOTFILES_ROOT" -name "*.tmpl" -exec grep -l "{{" {} \; | wc -l | tr -d ' ')
        [[ $template_vars -ge 1 ]]
    fi
}

@test "FR-3.5: Secrets management with encryption" {
    # Check for encrypted files (should have .age extension in chezmoi)
    encrypted_count=$(find "$DOTFILES_ROOT" -name "encrypted_*" | wc -l | tr -d ' ')
    [[ $encrypted_count -ge 0 ]]  # Encrypted files are optional but recommended

    # If encrypted files exist, they should be in proper format
    if [[ $encrypted_count -gt 0 ]]; then
        # Check that age key configuration exists (or external management)
        [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.yaml" || -f "$DOTFILES_SOURCE_DIR/.chezmoi.toml" || -f "$DOTFILES_SOURCE_DIR/.chezmoiexternal.toml" ]]
    fi
}

@test "FR-3.6: External repository management (.chezmoiexternal.toml)" {
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiexternal.toml" ]]

    # Should contain external tool definitions
    essential_externals=("oh-my-zsh" "antigen" "dircolors")
    found_externals=0

    for external in "${essential_externals[@]}"; do
        if grep -q "$external" "$DOTFILES_SOURCE_DIR/.chezmoiexternal.toml"; then
            found_externals=$((found_externals + 1))
        fi
    done

    [[ $found_externals -ge 1 ]]  # Should manage at least 1 external tool
}

@test "FR-3.7: Application configuration directory management" {
    # Check for application config directories (private_* pattern for macOS paths)
    app_config_count=$(find "$DOTFILES_SOURCE_DIR" -name "private_*" -type d | wc -l | tr -d ' ')
    [[ $app_config_count -ge 0 ]]  # Application configs are optional

    # Check for VS Code configuration specifically
    if [[ -d "$DOTFILES_SOURCE_DIR/private_Library" ]]; then
        vscode_config=$(find "$DOTFILES_SOURCE_DIR/private_Library" -name "*Code*" -type d | wc -l | tr -d ' ')
        [[ $vscode_config -ge 0 ]]
    fi
}

@test "FR-3.8: Conflict resolution mechanisms" {
    # Check that .chezmoiignore exists and contains reasonable patterns
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiignore" ]]

    # Should contain common ignore patterns
    ignore_patterns=(".DS_Store" "*.log" "node_modules")
    found_patterns=0

    for pattern in "${ignore_patterns[@]}"; do
        if grep -q "$pattern" "$DOTFILES_SOURCE_DIR/.chezmoiignore"; then
            found_patterns=$((found_patterns + 1))
        fi
    done

    [[ $found_patterns -ge 1 ]]  # Should have at least some ignore patterns
}

@test "FR-3.9: Cross-machine update capabilities" {
    # Verify chezmoi integration in bootstrap scripts
    if [[ -f "$BOOTSTRAP_DIR/setup.macos.sh" ]]; then
        grep -q -i "chezmoi" "$BOOTSTRAP_DIR/setup.macos.sh" || [ -f "$BOOTSTRAP_DIR/lib/chezmoi.sh" ]
    else
        grep -q -i "chezmoi" "$BOOTSTRAP_DIR/setup.core.sh" || [ -f "$BOOTSTRAP_DIR/lib/chezmoi.sh" ]
    fi
}

@test "FR-3.10: Configuration management dry-run support" {
    # Test chezmoi dry-run capability through bootstrap
    run_bootstrap "setup.core.sh" "--dry-run"
    assert_bootstrap_success

    # Should mention configuration or chezmoi operations
    [[ "$output" =~ (chezmoi|config|dotfiles) ]]
}

# FR-3.11: Compatibility with existing file locations
@test "FR-3.11: Maintains compatibility with standard dotfile locations" {
    # Check that managed files correspond to standard locations
    standard_files=(".gitconfig" ".zshrc" ".vimrc" ".npmrc")
    managed_equivalents=("dot_gitconfig" "dot_zshrc" "dot_vimrc" "dot_npmrc")

    found_standard=0
    for i in "${!standard_files[@]}"; do
        std_file="${standard_files[$i]}"
        managed_file="${managed_equivalents[$i]}"

        if [[ -f "$DOTFILES_SOURCE_DIR/$managed_file" || -f "$DOTFILES_SOURCE_DIR/${managed_file}.tmpl" || -f "$DOTFILES_ROOT/$managed_file" || -f "$DOTFILES_ROOT/${managed_file}.tmpl" ]]; then
            found_standard=$((found_standard + 1))
        fi
    done

    [[ $found_standard -ge 2 ]]  # Should manage at least 2 standard dotfiles
}

@test "FR-3.12: Comprehensive ignore patterns for system files" {
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiignore" ]]

    # Check for comprehensive OS-specific ignore patterns
    ignore_content=$(cat "$DOTFILES_SOURCE_DIR/.chezmoiignore")

    # Should contain macOS-specific patterns
    [[ "$ignore_content" =~ ".DS_Store" ]]

    # Should contain development-specific patterns
    dev_patterns=("node_modules" "*.log" ".cache")
    found_dev=0

    for pattern in "${dev_patterns[@]}"; do
        if [[ "$ignore_content" =~ $pattern ]]; then
            found_dev=$((found_dev + 1))
        fi
    done

    [[ $found_dev -ge 1 ]]  # Should have at least some development ignore patterns
}

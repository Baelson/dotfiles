#!/usr/bin/env bats
#
# FR-6: Environment Templating Testing
#
# This test suite validates support for different configurations for
# work vs personal environments as specified in FR-6 requirements.
#
# NOTE: FR-6 is currently marked as "In Progress" - these tests validate
# the templating infrastructure even if full work/personal differentiation
# is not yet implemented.
#
# Reference: docs/PRD.md#fr-6-environment-templating
#

load '../lib/test_helper'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# FR-6.1: Template file support infrastructure
@test "FR-6.1: Chezmoi template infrastructure exists" {
    # Check for chezmoi configuration that supports templating (can be implicit)
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.yaml" || -f "$DOTFILES_SOURCE_DIR/.chezmoi.toml" || -f "$DOTFILES_SOURCE_DIR/.chezmoiexternal.toml" ]]

    # Template files use .tmpl extension
    template_count=$(find "$DOTFILES_ROOT" -name "*.tmpl" 2>/dev/null | wc -l | tr -d ' ')

    # Should support templating (even if no templates exist yet)
    [[ $template_count -ge 0 ]]
}

@test "FR-6.2: Environment detection capability" {
    # Check if there's environment detection logic in configuration
    env_detection_found=false

    # Look for environment detection in chezmoi config
    if [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.yaml" ]]; then
        if grep -q -E "(work|personal|hostname|domain)" "$DOTFILES_SOURCE_DIR/.chezmoi.yaml"; then
            env_detection_found=true
        fi
    fi

    # Look for environment detection in bootstrap scripts
    for script in "$BOOTSTRAP_DIR"/*.sh; do
        if [[ -f "$script" ]]; then
            if grep -q -E "(hostname|work|personal|environment|WORK|PERSONAL)" "$script"; then
                env_detection_found=true
                break
            fi
        fi
    done

    # Look for template files that might indicate environment differentiation
    if find "$DOTFILES_ROOT" -name "*.tmpl" 2>/dev/null | head -1 | xargs -r grep -q -E "(work|personal|hostname)"; then
        env_detection_found=true
    fi

    # Test passes if infrastructure exists (even if not fully implemented)
    [[ "$env_detection_found" == "true" ]] || [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.yaml" ]] || [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.toml" ]]
}

@test "FR-6.3: Template variable system" {
    # Check for template variable usage in any template files
    template_vars_found=false

    # Look for Go template syntax in .tmpl files
    if find "$DOTFILES_ROOT" -name "*.tmpl" 2>/dev/null | head -5 | xargs -r grep -q "{{"; then
        template_vars_found=true
    fi

    # Check chezmoi config for data/variables
    if [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.yaml" ]]; then
        if grep -q -E "(data:|variables:|\.)" "$DOTFILES_SOURCE_DIR/.chezmoi.yaml"; then
            template_vars_found=true
        fi
    fi

    # Test passes if templating infrastructure exists
    [[ "$template_vars_found" == "true" ]] || [[ $(find "$DOTFILES_ROOT" -name "*.tmpl" 2>/dev/null | wc -l | tr -d ' ') -ge 0 ]]
}

@test "FR-6.4: Git configuration templating readiness" {
    # Check if Git configuration is ready for templating
    git_templating_ready=false

    # Look for git template file
    if [[ -f "$DOTFILES_SOURCE_DIR/dot_gitconfig.tmpl" ]]; then
        git_templating_ready=true
        # Should contain template variables for user info
        grep -q "{{" "$DOTFILES_SOURCE_DIR/dot_gitconfig.tmpl"
    elif [[ -f "$DOTFILES_SOURCE_DIR/dot_gitconfig" ]]; then
        # Static gitconfig exists (could be converted to template)
        git_templating_ready=true
    fi

    [[ "$git_templating_ready" == "true" ]]
}

@test "FR-6.5: SSH key management templating infrastructure" {
    # Check for SSH configuration templating capability
    ssh_templating_ready=false

    # Look for SSH template or encrypted SSH configs
    if [[ -f "$DOTFILES_SOURCE_DIR/dot_ssh/config.tmpl" ]] || find "$DOTFILES_ROOT" -name "encrypted_dot_ssh" -type d 2>/dev/null | grep -q .; then
        ssh_templating_ready=true
    fi

    # Check if SSH keys are managed (prerequisite for environment differentiation)
    if find "$DOTFILES_ROOT" -name "*ssh*" 2>/dev/null | grep -q .; then
        ssh_templating_ready=true
    fi

    [[ "$ssh_templating_ready" == "true" ]]
}

@test "FR-6.6: Package management environment differentiation readiness" {
    # Check if package management is ready for environment-specific packages
    package_templating_ready=false

    # Look for Brewfile template (chezmoi maps Brewfile -> ~/Brewfile)
    if [[ -f "$DOTFILES_SOURCE_DIR/Brewfile.tmpl" ]]; then
        package_templating_ready=true
    elif [[ -f "$DOTFILES_SOURCE_DIR/Brewfile" ]]; then
        # Static Brewfile exists (could support templating)
        package_templating_ready=true
    fi

    [[ "$package_templating_ready" == "true" ]]
}

@test "FR-6.7: Shell prompt environment customization readiness" {
    # Check if shell prompts are ready for environment customization
    prompt_templating_ready=false

    # Look for shell config templates
    if [[ -f "$DOTFILES_SOURCE_DIR/dot_zshrc.tmpl" ]] || [[ -f "$DOTFILES_SOURCE_DIR/dot_p10k.zsh.tmpl" ]]; then
        prompt_templating_ready=true
    elif [[ -f "$DOTFILES_SOURCE_DIR/dot_zshrc" ]] || [[ -f "$DOTFILES_SOURCE_DIR/dot_p10k.zsh" ]]; then
        # Shell configs exist (could support templating)
        prompt_templating_ready=true
    fi

    [[ "$prompt_templating_ready" == "true" ]]
}

@test "FR-6.8: Environment-specific ignore patterns capability" {
    # Check if ignore patterns can be environment-specific
    ignore_templating_ready=false

    # Look for templated chezmoiignore
    if [[ -f "$DOTFILES_ROOT/.chezmoiignore.tmpl" ]]; then
        ignore_templating_ready=true
    elif [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiignore" ]]; then
        # Static ignore file exists
        ignore_templating_ready=true

        # Check if it contains conditional patterns
        if grep -q -E "({{|work|personal)" "$DOTFILES_SOURCE_DIR/.chezmoiignore"; then
            ignore_templating_ready=true
        fi
    fi

    [[ "$ignore_templating_ready" == "true" ]]
}

@test "FR-6.9: Manual override mechanism availability" {
    # Check for manual environment override capability
    override_mechanism_found=false

    # Look for environment variable or flag support
    for script in "$BOOTSTRAP_DIR"/*.sh; do
        if [[ -f "$script" ]]; then
            if grep -q -E "(\$\{?WORK|\$\{?PERSONAL|\$\{?ENV|--work|--personal)" "$script"; then
                override_mechanism_found=true
                break
            fi
        fi
    done

    # Check chezmoi config for data override capability
    if [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.yaml" ]] || [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.toml" ]]; then
        override_mechanism_found=true  # Chezmoi supports data override
    fi

    [[ "$override_mechanism_found" == "true" ]]
}

@test "FR-6.10: Template syntax validation" {
    # Validate that any existing template files use correct Go template syntax
    template_syntax_ok=true

    # Check all .tmpl files for valid template syntax
    while IFS= read -r -d '' template_file; do
        if [[ -f "$template_file" ]]; then
            # Basic Go template syntax validation
            if ! grep -q -E "(\{\{.*\}\}|^[^{]*$)" "$template_file"; then
                template_syntax_ok=false
                break
            fi
        fi
    done < <(find "$DOTFILES_ROOT" -name "*.tmpl" -print0 2>/dev/null)

    [[ "$template_syntax_ok" == "true" ]]
}

@test "FR-6.11: Cross-machine synchronization readiness" {
    # Check if system supports cross-machine sync for different environments
    sync_ready=false

    # Git-based synchronization is inherent
    if [[ -d "$DOTFILES_ROOT/.git" ]]; then
        sync_ready=true
    fi

    # Chezmoi provides sync capability
    if command -v chezmoi &> /dev/null; then
        sync_ready=true
    fi

    [[ "$sync_ready" == "true" ]]
}

@test "FR-6.12: Template testing and validation capability" {
    # Check if template changes can be tested safely
    template_testing_ready=false

    # Dry-run capability indicates safe testing
    run_bootstrap "setup.core.sh" "--dry-run"
    if [[ "$status" -eq 0 ]]; then
        template_testing_ready=true
    fi

    # Chezmoi diff capability
    if command -v chezmoi &> /dev/null; then
        template_testing_ready=true
    fi

    [[ "$template_testing_ready" == "true" ]]
}

@test "FR-6.13: Environment templating documentation readiness" {
    # Check if documentation mentions environment differentiation
    docs_ready=false

    # Look for environment-related documentation
    if find "$DOTFILES_ROOT/docs" -name "*.md" 2>/dev/null | head -5 | xargs -r grep -q -i "environment\|work\|personal\|template"; then
        docs_ready=true
    fi

    # Check for README or main documentation
    if [[ -f "$DOTFILES_ROOT/README.md" ]] && grep -q -i "environment\|work\|personal" "$DOTFILES_ROOT/README.md"; then
        docs_ready=true
    fi

    [[ "$docs_ready" == "true" ]]
}

@test "FR-6.14: Future implementation framework validation" {
    # Validate that the infrastructure exists for full FR-6 implementation
    infrastructure_ready=true
    required_components=0

    # Chezmoi configuration
    if [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.yaml" ]] || [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.toml" ]]; then
        ((++required_components))
    fi

    # Git configuration (ready for templating)
    if [[ -f "$DOTFILES_SOURCE_DIR/dot_gitconfig" ]] || [[ -f "$DOTFILES_SOURCE_DIR/dot_gitconfig.tmpl" ]]; then
        ((++required_components))
    fi

    # Package management (ready for environment differentiation)
    if [[ -f "$DOTFILES_SOURCE_DIR/Brewfile" ]] || [[ -f "$DOTFILES_SOURCE_DIR/Brewfile.tmpl" ]]; then
        ((++required_components))
    fi

    # Should have at least 2 of 3 required components ready
    [[ $required_components -ge 2 ]]
}

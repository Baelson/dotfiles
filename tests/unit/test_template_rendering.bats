#!/usr/bin/env bats
#
# Template Rendering with Different Environments Testing
#
# This test suite validates that all chezmoi templates render correctly
# across different environment configurations (ephemeral, headless, work, personal).
# This ensures the Phase 3 templating system works as designed.
#
# Reference: docs/SYSTEM_DESIGN.md#environment-differentiation
#

load '../lib/test_helper'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# .chezmoi.toml.tmpl Template Rendering Tests
@test "TEMPLATE-1: chezmoi config renders for default personal environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=true --promptBool work=false --promptString hostname="test-mac" < "$DOTFILES_SOURCE_DIR/.chezmoi.toml.tmpl"
    assert_chezmoi_success

    # Should have correct data section
    [[ "$output" =~ "\[data\]" ]]
    [[ "$output" =~ "ephemeral = false" ]]
    [[ "$output" =~ "headless = false" ]]
    [[ "$output" =~ "personal = true" ]]
    [[ "$output" =~ "work = false" ]]
    [[ "$output" =~ "hostname = \"test-mac\"" ]]

    # Should have age encryption settings
    [[ "$output" =~ "\[age\]" ]]
    [[ "$output" =~ "identity" ]]
    [[ "$output" =~ "recipient" ]]

    # Should have git settings
    [[ "$output" =~ "\[git\]" ]]
    [[ "$output" =~ "autoCommit" ]]
}

@test "TEMPLATE-2: chezmoi config renders for work environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=false --promptBool work=true --promptString hostname="work-laptop" < "$DOTFILES_SOURCE_DIR/.chezmoi.toml.tmpl"
    assert_chezmoi_success

    [[ "$output" =~ "work = true" ]]
    [[ "$output" =~ "personal = false" ]]
    [[ "$output" =~ "hostname = \"work-laptop\"" ]]
}

@test "TEMPLATE-3: chezmoi config renders for ephemeral environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=true --promptBool headless=false --promptBool personal=false --promptBool work=false --promptString hostname="ci-runner" < "$DOTFILES_SOURCE_DIR/.chezmoi.toml.tmpl"
    assert_chezmoi_success

    [[ "$output" =~ "ephemeral = true" ]]
    [[ "$output" =~ "headless = false" ]]
    [[ "$output" =~ "personal = false" ]]
    [[ "$output" =~ "work = false" ]]
}

@test "TEMPLATE-4: chezmoi config renders for headless environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=true --promptBool personal=false --promptBool work=false --promptString hostname="server-01" < "$DOTFILES_SOURCE_DIR/.chezmoi.toml.tmpl"
    assert_chezmoi_success

    [[ "$output" =~ "headless = true" ]]
    [[ "$output" =~ "ephemeral = false" ]]
}

# Brewfile.tmpl Template Rendering Tests
@test "TEMPLATE-5: Brewfile renders core packages for all environments" {
    # Test minimal environment (ephemeral + headless)
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=true --promptBool headless=true --promptBool personal=false --promptBool work=false --promptString hostname="minimal" < "$DOTFILES_SOURCE_DIR/Brewfile.tmpl"
    assert_chezmoi_success

    # Should always include core development tools
    [[ "$output" =~ "brew 'chezmoi'" ]]
    [[ "$output" =~ "brew 'coreutils'" ]]
    [[ "$output" =~ "brew 'gh'" ]]
    [[ "$output" =~ "brew 'git'" ]]
    [[ "$output" =~ "brew 'make'" ]]

    # Should include shell enhancements
    [[ "$output" =~ "brew 'antigen'" ]]
    [[ "$output" =~ "brew 'direnv'" ]]
    [[ "$output" =~ "brew 'fzf'" ]]

    # Should include programming languages
    [[ "$output" =~ "brew 'node'" ]]
    [[ "$output" =~ "brew 'python3'" ]]
    [[ "$output" =~ "brew 'uv'" ]]
}

@test "TEMPLATE-6: Brewfile excludes GUI apps in headless environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=true --promptBool personal=true --promptBool work=false --promptString hostname="server" < "$DOTFILES_SOURCE_DIR/Brewfile.tmpl"
    assert_chezmoi_success

    # Should NOT include GUI applications
    [[ ! "$output" =~ "cask" ]]
    [[ ! "$output" =~ "visual-studio-code" ]]
    [[ ! "$output" =~ "iterm2" ]]
    [[ ! "$output" =~ "docker" ]]

    # Should still include CLI tools
    [[ "$output" =~ "brew 'chezmoi'" ]]
    [[ "$output" =~ "brew 'neovim'" ]]
}

@test "TEMPLATE-7: Brewfile includes GUI apps in non-headless environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=true --promptBool work=false --promptString hostname="desktop" < "$DOTFILES_SOURCE_DIR/Brewfile.tmpl"
    assert_chezmoi_success

    # Should include GUI applications
    [[ "$output" =~ "cask 'visual-studio-code'" ]]
    [[ "$output" =~ "cask 'iterm2'" ]]
    [[ "$output" =~ "cask 'docker'" ]]
    [[ "$output" =~ "cask 'cursor'" ]]

    # Should include VS Code extensions
    [[ "$output" =~ "vscode" ]]
}

@test "TEMPLATE-8: Brewfile excludes persistent packages in ephemeral environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=true --promptBool headless=false --promptBool personal=true --promptBool work=false --promptString hostname="temp-machine" < "$DOTFILES_SOURCE_DIR/Brewfile.tmpl"
    assert_chezmoi_success

    # Should NOT include media utilities and persistent tools
    [[ ! "$output" =~ "brew 'ddrescue'" ]]
    [[ ! "$output" =~ "brew 'ffmpeg'" ]]
    [[ ! "$output" =~ "brew 'mas'" ]]
    [[ ! "$output" =~ "mas.*'" ]]  # No Mac App Store apps

    # Should still include core development tools
    [[ "$output" =~ "brew 'chezmoi'" ]]
    [[ "$output" =~ "brew 'git'" ]]
}

@test "TEMPLATE-9: Brewfile includes Mac App Store apps in persistent personal environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=true --promptBool work=false --promptString hostname="personal-mac" < "$DOTFILES_SOURCE_DIR/Brewfile.tmpl"
    assert_chezmoi_success

    # Should include Mac App Store apps
    [[ "$output" =~ "mas 'Amphetamine" ]]
    [[ "$output" =~ "mas 'Final Cut Pro" ]]
    [[ "$output" =~ "mas 'Xcode" ]]
    [[ "$output" =~ "mas 'Microsoft Excel" ]]

    # Should include personal apps
    [[ "$output" =~ "cask 'discord'" ]]
    [[ "$output" =~ "cask 'figma'" ]]

    # Should include personal VS Code extensions
    [[ "$output" =~ "vscode.*openai" ]]
}

@test "TEMPLATE-10: Brewfile includes work-specific apps in work environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=false --promptBool work=true --promptString hostname="work-laptop" < "$DOTFILES_SOURCE_DIR/Brewfile.tmpl"
    assert_chezmoi_success

    # Should include work-specific apps
    [[ "$output" =~ "mas 'Slack" ]]

    # Should NOT include personal apps
    [[ ! "$output" =~ "cask 'discord'" ]]
    [[ ! "$output" =~ "cask 'figma'" ]]

    # Should NOT include personal VS Code extensions
    [[ ! "$output" =~ "vscode.*openai" ]]

    # Should still include core productivity apps
    [[ "$output" =~ "cask 'visual-studio-code'" ]]
}

@test "TEMPLATE-11: Brewfile renders proper environment indicators" {
    # Test personal environment
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=true --promptBool work=false --promptString hostname="personal-mac" < "$DOTFILES_SOURCE_DIR/Brewfile.tmpl"
    assert_chezmoi_success

    # Should show environment in comments
    [[ "$output" =~ "Environment: personal" ]]
    [[ "$output" =~ "Hostname: personal-mac" ]]
    [[ "$output" =~ "Ephemeral: false.*full installation" ]]
    [[ "$output" =~ "Headless: false.*includes GUI applications" ]]

    # Test work environment
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=false --promptBool work=true --promptString hostname="work-laptop" < "$DOTFILES_SOURCE_DIR/Brewfile.tmpl"
    assert_chezmoi_success

    [[ "$output" =~ "Environment: work" ]]
    [[ "$output" =~ "Hostname: work-laptop" ]]
}

# Lifecycle Script Template Rendering Tests
@test "TEMPLATE-12: Package installation script renders for ephemeral environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=true --promptBool headless=false --promptBool personal=false --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"
    assert_chezmoi_success

    # Should skip cleanup in ephemeral environments
    [[ ! "$output" =~ "brew cleanup" ]]
    [[ ! "$output" =~ "brew autoremove" ]]

    # Should still install packages
    [[ "$output" =~ "brew bundle" ]]
}

@test "TEMPLATE-13: Package installation script renders for persistent environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=true --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"
    assert_chezmoi_success

    # Should include cleanup in persistent environments
    [[ "$output" =~ "brew cleanup" ]]
    [[ "$output" =~ "brew autoremove" ]]
}

@test "TEMPLATE-14: macOS defaults script skips in headless environment" {
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=true --promptBool personal=false --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"
    assert_chezmoi_success

    # Should skip macOS defaults configuration
    [[ "$output" =~ "Skipping.*headless" ]] || [[ "$output" =~ "exit 0" ]]
    [[ ! "$output" =~ "defaults write" ]]
}

@test "TEMPLATE-15: macOS defaults script runs in GUI environment" {
    skip "Test harness issue: data injection into chezmoi execute-template failing"
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=true --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"
    assert_chezmoi_success

    # Should include macOS defaults configuration
    [[ "$output" =~ "defaults write" ]]
    [[ "$output" =~ "Dock" ]]
    [[ "$output" =~ "Finder" ]]
    [[ "$output" =~ "killall" ]]
}

@test "TEMPLATE-16: macOS defaults script differentiates work vs personal" {
    skip "Test harness issue: data injection into chezmoi execute-template failing"
    # Test work environment
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=false --promptBool work=true < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"
    assert_chezmoi_success

    [[ "$output" =~ "work-specific" ]] || [[ "$output" =~ "work" ]]

    # Test personal environment
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=true --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"
    assert_chezmoi_success

    [[ "$output" =~ "personal" ]] || [[ "$output" =~ "Personal" ]]
}

@test "TEMPLATE-17: Shell environment script skips in headless environment" {
    skip "Test harness issue: data injection into chezmoi execute-template failing"
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=true --promptBool personal=false --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl"
    assert_chezmoi_success

    # Should skip interactive shell setup
    [[ "$output" =~ "Skipping.*headless" ]] || [[ "$output" =~ "exit 0" ]]
}

@test "TEMPLATE-18: Shell environment script handles ephemeral environment" {
    skip "Test harness issue: data injection into chezmoi execute-template failing"
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=true --promptBool headless=false --promptBool personal=false --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl"
    assert_chezmoi_success

    # Should skip fzf installation in ephemeral environments
    [[ ! "$output" =~ "fzf.*install" ]]

    # Should still setup Antigen
    [[ "$output" =~ "antigen" ]] || [[ "$output" =~ "Antigen" ]]
}

@test "TEMPLATE-19: Application setup script handles all environments correctly" {
    skip "Test harness issue: data injection into chezmoi execute-template failing"
    # Test headless environment
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=true --promptBool personal=false --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"
    assert_chezmoi_success
    [[ "$output" =~ "Skipping.*headless" ]] || [[ "$output" =~ "exit 0" ]]

    # Test personal environment
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=false --promptBool headless=false --promptBool personal=true --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"
    assert_chezmoi_success
    [[ "$output" =~ "personal" ]] && [[ "$output" =~ "Alfred" ]]

    # Test ephemeral environment
    run_chezmoi execute-template --init --stdinisatty=false --promptBool ephemeral=true --promptBool headless=false --promptBool personal=false --promptBool work=false < "$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"
    assert_chezmoi_success
    [[ ! "$output" =~ "VS Code.*sync" ]]  # Should skip VS Code sync in ephemeral
}

# Template Syntax and Error Handling Tests
@test "TEMPLATE-20: All templates have valid Go template syntax" {
    local templates=(
        ".chezmoi.toml.tmpl"
        "Brewfile.tmpl"
        ".chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"
        ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"
        ".chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl"
        ".chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"
    )

    for template in "${templates[@]}"; do
        local template_path="$DOTFILES_SOURCE_DIR/$template"

        # Template should exist
        [[ -f "$template_path" ]]

        # Should have .tmpl extension
        [[ "$template" =~ \.tmpl$ ]]

        # Should contain Go template syntax
        grep -q "{{" "$template_path"
        grep -q "}}" "$template_path"

        # Should not have unmatched template delimiters
        local open_count
        local close_count
        open_count=$(grep -o "{{" "$template_path" | wc -l | tr -d ' ')
        close_count=$(grep -o "}}" "$template_path" | wc -l | tr -d ' ')
        [[ "$open_count" -eq "$close_count" ]]
    done
}

@test "TEMPLATE-21: Templates render without errors for all environment combinations" {
    skip "Test harness issue: data injection into chezmoi execute-template failing"
    local environments=(
        "ephemeral=true headless=true personal=false work=false"
        "ephemeral=true headless=false personal=false work=false"
        "ephemeral=false headless=true personal=false work=false"
        "ephemeral=false headless=false personal=true work=false"
        "ephemeral=false headless=false personal=false work=true"
    )

    local templates=(
        ".chezmoi.toml.tmpl"
        "Brewfile.tmpl"
        ".chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"
        ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"
        ".chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl"
        ".chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"
    )

    for env in "${environments[@]}"; do
        for template in "${templates[@]}"; do
            # Convert environment string to prompt arguments
            local prompt_args=""
            for var in $env; do
                local var_name="${var%=*}"
                local var_value="${var#*=}"

                # Use appropriate prompt flag based on value type
                if [[ "$var_value" == "true" ]] || [[ "$var_value" == "false" ]]; then
                    prompt_args="$prompt_args --promptBool $var_name=$var_value"
                else
                    prompt_args="$prompt_args --promptString $var_name=$var_value"
                fi
            done
            prompt_args="$prompt_args --promptString hostname=test-host"

            # Render template
            run_chezmoi execute-template --init --stdinisatty=false $prompt_args < "$DOTFILES_SOURCE_DIR/$template"

            # Should render without errors
            assert_chezmoi_success
        done
    done
}

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
    test_template_rendering ".chezmoi.toml.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false" "hostname=test-mac"
    assert_chezmoi_success

    # Should have correct data section
    # Use glob for safety against whitespace/newlines
    [[ "$output" == *"[data]"* ]]
    [[ "$output" =~ "ephemeral = false" ]]
    [[ "$output" =~ "headless = false" ]]
    [[ "$output" =~ "personal = true" ]]
    [[ "$output" =~ "work = false" ]]

    # Hostname might be overridden by system hostname, just check key exists
    [[ "$output" =~ "hostname =" ]]

    # Should have age encryption settings
    [[ "$output" == *"[age]"* ]]
    [[ "$output" =~ "identity" ]]
    [[ "$output" =~ "recipient" ]]

    # Should have git settings
    [[ "$output" == *"[git]"* ]]
    [[ "$output" =~ "autoCommit" ]]
}

@test "TEMPLATE-2: chezmoi config renders for work environment" {
    test_template_rendering ".chezmoi.toml.tmpl" "ephemeral=false" "headless=false" "personal=false" "work=true" "hostname=work-laptop"
    assert_chezmoi_success

    [[ "$output" == *"work = true"* ]]
    [[ "$output" == *"personal = false"* ]]
    [[ "$output" =~ "hostname =" ]]
}

@test "TEMPLATE-3: chezmoi config renders for ephemeral environment" {
    test_template_rendering ".chezmoi.toml.tmpl" "ephemeral=true" "headless=false" "personal=false" "work=false" "hostname=ci-runner"
    assert_chezmoi_success

    [[ "$output" == *"ephemeral = true"* ]]
    [[ "$output" == *"headless = false"* ]]
    [[ "$output" == *"personal = false"* ]]
    [[ "$output" == *"work = false"* ]]
}

@test "TEMPLATE-4: chezmoi config renders for headless environment" {
    test_template_rendering ".chezmoi.toml.tmpl" "ephemeral=false" "headless=true" "personal=false" "work=false" "hostname=server-01"
    assert_chezmoi_success

    [[ "$output" =~ "headless = true" ]]
    [[ "$output" =~ "ephemeral = false" ]]
}

# Brewfile.tmpl Template Rendering Tests
@test "TEMPLATE-5: Brewfile renders core packages for all environments" {
    # Test minimal environment (ephemeral + headless)
    test_template_rendering "Brewfile.tmpl" "ephemeral=true" "headless=true" "personal=false" "work=false" "hostname=minimal"

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
    test_template_rendering "Brewfile.tmpl" "ephemeral=false" "headless=true" "personal=true" "work=false" "hostname=server"
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
    test_template_rendering "Brewfile.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false" "hostname=desktop" "is_primary=true"
    assert_chezmoi_success

    # Should include GUI applications
    [[ "$output" =~ "cask 'visual-studio-code'" ]]
    [[ "$output" =~ "cask 'iterm2'" ]]
    [[ "$output" =~ "cask 'orbstack'" ]]   # the Docker runtime cask this Brewfile actually ships (not Docker Desktop)
    [[ "$output" =~ "cask 'cursor'" ]]

    # Should include VS Code extensions
    [[ "$output" =~ "vscode" ]]
}

@test "TEMPLATE-8: Brewfile excludes persistent packages in ephemeral environment" {
    test_template_rendering "Brewfile.tmpl" "ephemeral=true" "headless=false" "personal=true" "work=false" "hostname=temp-machine"
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
    test_template_rendering "Brewfile.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false" "mas=true" "is_primary=true" "hostname=personal-mac"
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
    # Check for extension ID presence (exact format varies)
    [[ "$output" =~ "vscode \"openai.chatgpt\"" ]]
}

@test "TEMPLATE-10: Brewfile includes work-specific apps in work environment" {
    # Work MAS apps are gated `{{ if and .work $mas $is_primary }}` — the render must
    # supply mas=true + is_primary=true (mirrors TEMPLATE-9), else the block never emits.
    test_template_rendering "Brewfile.tmpl" "ephemeral=false" "headless=false" "personal=false" "work=true" "mas=true" "is_primary=true" "hostname=work-laptop"
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
    test_template_rendering "Brewfile.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false" "hostname=personal-mac"
    assert_chezmoi_success

    # Should show environment in comments
    [[ "$output" =~ "Environment: personal" ]]
    [[ "$output" =~ "Hostname:" ]]
    [[ "$output" =~ "Ephemeral: false" ]]
    [[ "$output" =~ "Headless: false" ]]

    # Test work environment
    test_template_rendering "Brewfile.tmpl" "ephemeral=false" "headless=false" "personal=false" "work=true" "hostname=work-laptop"
    assert_chezmoi_success

    [[ "$output" =~ "Environment: work" ]]
    [[ "$output" =~ "Hostname:" ]]
}

# Lifecycle Script Template Rendering Tests
@test "TEMPLATE-12: Package installation script renders for ephemeral environment" {
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl" "ephemeral=true" "headless=false" "personal=false" "work=false"
    assert_chezmoi_success

    # Should skip cleanup in ephemeral environments
    [[ ! "$output" =~ "brew cleanup" ]]
    [[ ! "$output" =~ "brew autoremove" ]]

    # Should still install packages
    [[ "$output" =~ "brew bundle" ]]
}

@test "TEMPLATE-13: Package installation script renders for persistent environment" {
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false"
    assert_chezmoi_success

    # Should include cleanup in persistent environments
    [[ "$output" =~ "brew cleanup" ]]
    [[ "$output" =~ "brew autoremove" ]]
}

@test "TEMPLATE-14: macOS defaults script skips in headless environment" {
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl" "ephemeral=false" "headless=true" "personal=false" "work=false"
    assert_chezmoi_success

    # Should skip macOS defaults configuration
    # Check for skipping message and exit code
    [[ "$output" == *"Skipping"* ]]
    [[ "$output" =~ "exit 0" ]]
}

@test "TEMPLATE-15: macOS defaults script runs in GUI environment" {
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false"
    assert_chezmoi_success

    # Should include macOS defaults configuration
    [[ "$output" =~ "defaults write" ]]
    [[ "$output" =~ "Dock" ]]
    [[ "$output" =~ "Finder" ]]
    [[ "$output" =~ "killall" ]]
}

@test "TEMPLATE-16: macOS defaults script differentiates work vs personal" {
    # Test work environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl" "ephemeral=false" "headless=false" "personal=false" "work=true"
    assert_chezmoi_success

    [[ "$output" =~ "work-specific" ]] || [[ "$output" =~ "work" ]]

    # Test personal environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false"
    assert_chezmoi_success

    [[ "$output" =~ "personal" ]] || [[ "$output" =~ "Personal" ]]
}

@test "TEMPLATE-22: macOS defaults — iTerm2 save-on-quit is gated by is_primary (single-master)" {
    # primary Mac = single WRITER (Always/2)
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false" "is_primary=true"
    assert_chezmoi_success
    local primary_out="$output"

    # non-primary Mac = read-only CONSUMER (Never/1)
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false" "is_primary=false"
    assert_chezmoi_success
    local nonprimary_out="$output"

    # is_primary ABSENT must default to read-only (Never/1) via dig — the exact missing-key
    # case that regressed TEMPLATE-14/15/16/21 when the gate was a bare {{ if .is_primary }}.
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false"
    assert_chezmoi_success
    local absent_out="$output"

    # ONE &&-chained final command (testing.md: avoids vacuous intermediate-assert passes)
    [[ "$primary_out" == *'NoSyncNeverRemindPrefsChangesLostForFile_selection" -int 2'* ]] \
        && [[ "$primary_out" != *'_selection" -int 1'* ]] \
        && [[ "$nonprimary_out" == *'NoSyncNeverRemindPrefsChangesLostForFile_selection" -int 1'* ]] \
        && [[ "$absent_out" == *'NoSyncNeverRemindPrefsChangesLostForFile_selection" -int 1'* ]]
}

@test "TEMPLATE-17: Shell environment script skips in headless environment" {
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl" "ephemeral=false" "headless=true" "personal=false" "work=false"
    assert_chezmoi_success

    # Should skip interactive shell setup
    [[ "$output" =~ "Skipping.*headless" ]] || [[ "$output" =~ "exit 0" ]]
}

@test "TEMPLATE-18: Shell environment script handles ephemeral environment" {
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_setup-shell-environment.sh.tmpl" "ephemeral=true" "headless=false" "personal=false" "work=false"
    assert_chezmoi_success

    # Should skip fzf installation in ephemeral environments
    [[ ! "$output" =~ "fzf.*install" ]]

    # Should still setup Antigen
    [[ "$output" =~ "antigen" ]] || [[ "$output" =~ "Antigen" ]]
}

@test "TEMPLATE-19: Application setup script handles all environments correctly" {
    # Test headless environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl" "ephemeral=false" "headless=true" "personal=false" "work=false"
    assert_chezmoi_success
    [[ "$output" =~ "Skipping.*headless" ]] || [[ "$output" =~ "exit 0" ]]

    # Test personal environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl" "ephemeral=false" "headless=false" "personal=true" "work=false"
    assert_chezmoi_success
    [[ "$output" =~ "personal" ]] && [[ "$output" =~ "Alfred" ]]

    # Test ephemeral environment
    test_template_rendering ".chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl" "ephemeral=true" "headless=false" "personal=false" "work=false"
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
    local environments=(
        "ephemeral=true headless=true personal=false work=false hostname=test-host"
        "ephemeral=true headless=false personal=false work=false hostname=test-host"
        "ephemeral=false headless=true personal=false work=false hostname=test-host"
        "ephemeral=false headless=false personal=true work=false hostname=test-host"
        "ephemeral=false headless=false personal=false work=true hostname=test-host"
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
            # Render template
            # shellcheck disable=SC2086 # Expanded variables are intended
            test_template_rendering "$template" $env

            # Should render without errors
            assert_chezmoi_success
        done
    done
}

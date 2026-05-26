#!/usr/bin/env bats
#
# REHOME NOTE (2026-05-23): tests FR-5.1, FR-5.5, FR-5.9 were deleted from this
# file when Phase 5M.1 (2026-05-07) moved home/private_Library/ off the public
# peer into dotfiles-private. They test only private_Library content (VS Code
# User settings, encrypted commercial-app licenses, Cursor User settings).
# When dotfiles-private gains a tests/ directory, re-home them there pointing
# at $DOTFILES_PRIVATE_SOURCE_DIR/private_Library. See:
#   ~/Git/Projects/Active/dotfiles-private/docs/plans/next-session-prompts/
#   2026-05-23-post-p0-cleanup-kickoff.md §WS2
#
# FR-5: Application Preferences Restoration — Behavioral Tests
#
# Proves that application configurations (VS Code, Git, iTerm2,
# encrypted licenses) are tracked by chezmoi and would deploy correctly.
#
# Reference: docs/PRD.md#fr-5-application-preferences-restoration
#

load '../lib/test_helper'
load '../lib/behavioral_helpers'

setup() {
    setup_common
    setup_github_actions_env
}

teardown() {
    cleanup_common
}

# ── FR-5.2: Git configuration has user identity ─────────────

@test "FR-5.2: Given dot_gitconfig, when inspected, then user name and email are configured" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/dot_gitconfig" ]] || skip "dot_gitconfig not found"

    # When
    local gitconfig
    gitconfig=$(cat "$DOTFILES_SOURCE_DIR/dot_gitconfig")

    # Then — [user] section with name and email
    [[ "$gitconfig" =~ "name" ]] || {
        echo "dot_gitconfig missing user name configuration" >&2
        return 1
    }
    [[ "$gitconfig" =~ "email" ]] || {
        echo "dot_gitconfig missing user email configuration" >&2
        return 1
    }
}

# ── FR-5.3: iTerm2 dynamic profiles managed ─────────────────

@test "FR-5.3: Given chezmoi source, when iTerm2 paths checked, then DynamicProfiles exist" {
    # Given/When
    local iterm_profiles
    iterm_profiles=$(find "$DOTFILES_SOURCE_DIR" -path "*iTerm2*DynamicProfiles*" -type d 2>/dev/null | head -1)

    # Then
    [[ -n "$iterm_profiles" ]] || skip "No iTerm2 DynamicProfiles in chezmoi source"

    # And — at least one profile JSON exists
    find "$iterm_profiles" -name "*.json" -type f | grep -q . || {
        echo "iTerm2 DynamicProfiles directory exists but no .json profiles inside" >&2
        return 1
    }
}

# ── FR-5.4: macOS defaults script configures system preferences ─

@test "FR-5.4: Given macOS defaults lifecycle script, when rendered, then defaults write commands exist" {
    # Given
    local script=".chezmoiscripts/darwin/run_onchange_after_configure-macos-defaults.sh.tmpl"
    [[ -f "$DOTFILES_SOURCE_DIR/$script" ]]

    # When
    assert_template_renders "$script" "ephemeral=false" "headless=false" "work=false" "personal=true"

    # Then — rendered script contains macOS defaults commands
    assert_rendered_contains "defaults write"
}

# ── FR-5.6: No plaintext credentials in tracked configs ──────

@test "FR-5.6: Given all tracked config files, when scanned, then no plaintext credentials found" {
    # Given/When — scan config files for credential patterns
    local credential_found=false
    while IFS= read -r config_file; do
        if [[ -f "$config_file" ]] && grep -qE "(password|api_key|secret_key).*[:=].*['\"][A-Za-z0-9+/]{20,}['\"]" "$config_file" 2>/dev/null; then
            echo "Potential plaintext credential in: $config_file" >&2
            credential_found=true
        fi
    done < <(find "$DOTFILES_SOURCE_DIR" -name "*.json" -o -name "*.conf" -o -name "*.cfg" 2>/dev/null | grep -v ".age$" | grep -v "encrypted_")

    # Then
    [[ "$credential_found" == "false" ]] || {
        echo "Plaintext credentials found in tracked configuration files" >&2
        return 1
    }
}

# ── FR-5.7: Application setup script configures dev tools ────

@test "FR-5.7: Given application setup lifecycle script, when rendered, then dev tools are configured" {
    # Given
    local script=".chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"
    [[ -f "$DOTFILES_SOURCE_DIR/$script" ]]

    # When
    assert_template_renders "$script" "ephemeral=false" "headless=false" "work=false" "personal=true"

    # Then — script configures at least one application
    # (VS Code extensions, defaults write, or similar)
    local has_app_config=false
    if echo "$output" | grep -qiE "code|vscode|defaults|dockutil|killall"; then
        has_app_config=true
    fi

    [[ "$has_app_config" == "true" ]] || {
        echo "Application setup script doesn't appear to configure any applications" >&2
        return 1
    }
}

# ── FR-5.8: Headless skips application setup (NEGATIVE) ──────

@test "FR-5.8: Given headless environment, when app setup script renders, then GUI configuration is skipped" {
    # Given
    local script=".chezmoiscripts/darwin/run_onchange_after_setup-applications.sh.tmpl"
    [[ -f "$DOTFILES_SOURCE_DIR/$script" ]]

    # When — render for headless
    assert_template_renders "$script" "ephemeral=false" "headless=true" "work=false" "personal=true"

    # Then — headless renders an early exit before any GUI configuration
    # The template adds `exit 0` after the headless skip message, so at runtime
    # no GUI-specific commands (VS Code, Docker, Alfred) would execute.
    assert_rendered_contains "exit 0"
    assert_rendered_contains "[Ss]kipping.*headless"
}

# ── FR-5.10: Dry-run doesn't modify application state ───────
# (Removed along with setup.sh in ISSUE-019. The steady-state dry-run is now
# `chezmoi apply --dry-run`, which is a chezmoi feature, not something this
# suite needs to re-prove.)

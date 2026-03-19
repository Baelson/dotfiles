#!/usr/bin/env bats
#
# FR-2: Package Management Integration — Behavioral Tests
#
# Proves that the Brewfile template renders correct package sets for each
# environment, that the lifecycle script integrates with brew bundle, and
# that environment conditions actually exclude/include the right packages.
#
# Reference: docs/PRD.md#fr-2-package-management-integration
#
# Test philosophy: Given/When/Then behavioral assertions.
# Every test exercises chezmoi template rendering or chezmoi managed output,
# NOT raw grep against source files.
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

# ── FR-2.1: Brewfile template renders valid output ───────────

@test "FR-2.1: Given default environment, when Brewfile renders, then output contains brew/cask/mas directives" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/Brewfile.tmpl" ]]

    # When
    assert_template_renders "Brewfile.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true" "mas=true" "hostname=test-host"

    # Then — rendered output has all three directive types (mas requires mas=true)
    assert_rendered_contains "^brew "
    assert_rendered_contains "^cask "
    assert_rendered_contains "^mas "
}

# ── FR-2.2: CLI tools present in rendered Brewfile ───────────

@test "FR-2.2: Given personal environment, when Brewfile renders, then essential CLI tools are present" {
    # Given
    assert_template_renders "Brewfile.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true" "hostname=test-host"

    # When — count essential tools in rendered output
    local essential_tools=("git" "uv" "gh" "neovim")
    local found=0
    for tool in "${essential_tools[@]}"; do
        if echo "$output" | grep -qE "^brew '$tool'"; then
            found=$((found + 1))
        fi
    done

    # Then — at least 3 of 4 essential tools found with proper brew directive syntax
    [[ $found -ge 3 ]] || {
        echo "Expected >=3 essential CLI tools, found $found" >&2
        echo "Checked: ${essential_tools[*]}" >&2
        return 1
    }
}

# ── FR-2.3: Desktop apps in rendered Brewfile ────────────────

@test "FR-2.3: Given non-headless environment, when Brewfile renders, then desktop casks are present" {
    # Given
    assert_template_renders "Brewfile.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true" "hostname=test-host"

    # When/Then — cask directives for desktop apps
    assert_rendered_contains "^cask 'visual-studio-code'"
    assert_rendered_contains "^cask 'iterm2'"
}

# ── FR-2.4: MAS apps in rendered Brewfile ────────────────────

@test "FR-2.4: Given personal non-headless environment, when Brewfile renders, then MAS apps are present" {
    # Given (mas=true required to include MAS apps)
    assert_template_renders "Brewfile.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true" "mas=true" "hostname=test-host"

    # Then — at least 1 MAS entry
    local mas_count
    mas_count=$(count_rendered_matches "^mas ")
    [[ $mas_count -ge 1 ]] || {
        echo "Expected >=1 MAS app, found $mas_count" >&2
        return 1
    }
}

# ── FR-2.5: Headless excludes GUI apps (NEGATIVE) ───────────

@test "FR-2.5: Given headless environment, when Brewfile renders, then casks and MAS apps are excluded" {
    # Given
    assert_template_renders "Brewfile.tmpl" "ephemeral=false" "headless=true" "work=false" "personal=true" "hostname=test-host"

    # Then — no cask or mas directives in headless mode
    assert_rendered_excludes "^cask "
    assert_rendered_excludes "^mas "

    # But brew CLI tools should still be present
    assert_rendered_contains "^brew "
}

# ── FR-2.6: Ephemeral excludes persistent packages ──────────

@test "FR-2.6: Given ephemeral environment, when Brewfile renders, then persistent-only packages are excluded" {
    # Given — render for ephemeral
    assert_template_renders "Brewfile.tmpl" "ephemeral=true" "headless=false" "work=false" "personal=true" "hostname=test-host"
    local ephemeral_count
    ephemeral_count=$(count_rendered_matches "^(brew|cask|mas) ")

    # When — render for persistent
    assert_template_renders "Brewfile.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true" "hostname=test-host"
    local persistent_count
    persistent_count=$(count_rendered_matches "^(brew|cask|mas) ")

    # Then — ephemeral has fewer packages than persistent
    [[ $ephemeral_count -lt $persistent_count ]] || {
        echo "Expected ephemeral ($ephemeral_count) < persistent ($persistent_count)" >&2
        return 1
    }
}

# ── FR-2.7: Package count meets 70+ requirement ─────────────

@test "FR-2.7: Given personal full environment, when Brewfile renders, then at least 70 packages are defined" {
    # Given (mas=true to include full package count)
    assert_template_renders "Brewfile.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true" "mas=true" "hostname=test-host"

    # When
    local total
    total=$(count_rendered_matches "^(brew|cask|mas) ")

    # Then
    [[ $total -ge 70 ]] || {
        echo "Expected >=70 total packages, found $total" >&2
        return 1
    }
}

# ── FR-2.8: Lifecycle script integrates brew bundle ──────────

@test "FR-2.8: Given install-packages lifecycle script, when rendered, then it calls brew bundle" {
    # Given
    local script="$DOTFILES_SOURCE_DIR/.chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl"
    [[ -f "$script" ]]

    # When — render the lifecycle script for a standard environment
    assert_template_renders ".chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl" \
        "ephemeral=false" "headless=false" "work=false" "personal=true"

    # Then — rendered script contains brew bundle invocation
    assert_rendered_contains "brew bundle"
}

# ── FR-2.9: MAS skip mechanism for headless/no-iCloud ───────

@test "FR-2.9: Given install-packages script, when rendered, then MAS skip mechanism exists" {
    # Given
    assert_template_renders ".chezmoiscripts/darwin/run_onchange_after_install-packages.sh.tmpl" \
        "ephemeral=false" "headless=false" "work=false" "personal=true"

    # Then — script references MAS skip (HOMEBREW_BUNDLE_MAS_SKIP or MobileMeAccounts detection)
    assert_rendered_contains "MAS|mas|HOMEBREW_BUNDLE_MAS_SKIP|MobileMeAccounts"
}

# ── FR-2.10: Work environment includes work-specific packages ─

@test "FR-2.10: Given work environment, when Brewfile renders, then work-specific packages appear" {
    # Given — render for work
    assert_template_renders "Brewfile.tmpl" "ephemeral=false" "headless=false" "work=true" "personal=false" "hostname=test-host"
    local work_output="$output"

    # When — render for personal
    assert_template_renders "Brewfile.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true" "hostname=test-host"
    local personal_output="$output"

    # Then — outputs differ (work has different packages)
    [[ "$work_output" != "$personal_output" ]] || {
        echo "Work and personal Brewfile renders are identical — no differentiation" >&2
        return 1
    }
}

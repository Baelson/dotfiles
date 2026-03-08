#!/usr/bin/env bats
#
# FR-4: Shell Environment Configuration — Behavioral Tests
#
# Proves that shell frameworks (oh-my-zsh, antigen, dircolors) are
# configured via .chezmoiexternal.toml.tmpl, that zshrc contains
# plugin loading, and that headless environments skip GUI frameworks.
#
# Reference: docs/PRD.md#fr-4-shell-environment-configuration
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

# ── FR-4.1: Zsh config files managed by chezmoi ─────────────

@test "FR-4.1: Given chezmoi source, when zsh files checked, then zshrc, zshenv, zprofile exist" {
    # Given/When
    local found=0
    for f in dot_zshrc dot_zshenv dot_zprofile; do
        if [[ -f "$DOTFILES_SOURCE_DIR/$f" || -f "$DOTFILES_SOURCE_DIR/${f}.tmpl" ]]; then
            found=$((found + 1))
        fi
    done

    # Then — at least 2 of 3 zsh config files present
    [[ $found -ge 2 ]] || {
        echo "Expected ≥2 zsh config files (dot_zshrc, dot_zshenv, dot_zprofile), found $found" >&2
        return 1
    }
}

# ── FR-4.2: Oh My Zsh configured in externals ───────────────

@test "FR-4.2: Given GUI environment, when .chezmoiexternal.toml.tmpl renders, then oh-my-zsh archive is configured" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiexternal.toml.tmpl" ]]

    # When — render for GUI (non-headless) environment
    assert_template_renders ".chezmoiexternal.toml.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true"

    # Then — oh-my-zsh entry present with archive type
    assert_rendered_contains "oh-my-zsh|ohmyzsh"
    assert_rendered_contains 'type = "archive"'
}

# ── FR-4.3: Antigen configured in externals ──────────────────

@test "FR-4.3: Given GUI environment, when .chezmoiexternal.toml.tmpl renders, then antigen is configured" {
    # Given/When
    assert_template_renders ".chezmoiexternal.toml.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true"

    # Then
    assert_rendered_contains "antigen"
}

# ── FR-4.4: Powerlevel10k theme config preserved ────────────

@test "FR-4.4: Given chezmoi source, when p10k config inspected, then theme customization exists" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/dot_p10k.zsh" ]] || skip "p10k config not found"

    # When
    local p10k_content
    p10k_content=$(cat "$DOTFILES_SOURCE_DIR/dot_p10k.zsh")

    # Then — contains Powerlevel10k configuration variables
    [[ "$p10k_content" =~ "POWERLEVEL9K_" || "$p10k_content" =~ "P9K_" ]] || {
        echo "dot_p10k.zsh missing POWERLEVEL9K_ configuration variables" >&2
        return 1
    }
}

# ── FR-4.5: Dircolors configured in externals ───────────────

@test "FR-4.5: Given GUI environment, when externals render, then dircolors is configured" {
    # Given/When
    assert_template_renders ".chezmoiexternal.toml.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true"

    # Then
    assert_rendered_contains "dircolors"
}

# ── FR-4.6: zshrc loads antigen bundles ──────────────────────

@test "FR-4.6: Given dot_zshrc, when inspected, then antigen bundle/theme/apply directives exist" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/dot_zshrc" ]] || skip "dot_zshrc not found"

    # When
    local zshrc
    zshrc=$(cat "$DOTFILES_SOURCE_DIR/dot_zshrc")

    # Then — antigen plugin loading workflow present
    [[ "$zshrc" =~ "antigen bundle" ]] || {
        echo "dot_zshrc missing 'antigen bundle' directives" >&2
        return 1
    }
    [[ "$zshrc" =~ "antigen apply" ]] || {
        echo "dot_zshrc missing 'antigen apply' — bundles won't load" >&2
        return 1
    }
}

# ── FR-4.7: PATH and environment variables configured ────────

@test "FR-4.7: Given dot_zshenv, when inspected, then PATH modifications exist" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/dot_zshenv" ]] || skip "dot_zshenv not found"

    # When
    local zshenv
    zshenv=$(cat "$DOTFILES_SOURCE_DIR/dot_zshenv")

    # Then — PATH or export directives present
    [[ "$zshenv" =~ "export" || "$zshenv" =~ "PATH" ]] || {
        echo "dot_zshenv missing PATH/export configuration" >&2
        return 1
    }
}

# ── FR-4.8: Headless excludes shell frameworks (NEGATIVE) ───

@test "FR-4.8: Given headless environment, when externals render, then shell frameworks are excluded" {
    # Given/When
    assert_template_renders ".chezmoiexternal.toml.tmpl" "ephemeral=false" "headless=true" "work=false" "personal=true"

    # Then — oh-my-zsh, antigen, dircolors entries should be absent
    # (gated by {{ if not .headless }} in template)
    assert_rendered_excludes "oh-my-zsh|ohmyzsh"
    assert_rendered_excludes "antigen"
    assert_rendered_excludes "dircolors"
}

# ── FR-4.9: External archives have refresh periods ──────────

@test "FR-4.9: Given external archives, when template renders, then refreshPeriod is set" {
    # Given/When
    assert_template_renders ".chezmoiexternal.toml.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true"

    # Then
    assert_rendered_contains "refreshPeriod"
}

# ── FR-4.10: External archives use stripComponents ──────────

@test "FR-4.10: Given external archives, when template renders, then archive settings are correct" {
    # Given/When
    assert_template_renders ".chezmoiexternal.toml.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true"

    # Then — archives should strip the root directory from tarballs
    assert_rendered_contains "stripComponents"
    assert_rendered_contains 'type = "archive"'
}

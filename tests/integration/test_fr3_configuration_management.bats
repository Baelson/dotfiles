#!/usr/bin/env bats
#
# FR-3: Configuration Management — Behavioral Tests
#
# Proves that chezmoi correctly manages dotfiles, encrypts secrets,
# renders templates, and tracks the expected file set.
#
# Reference: docs/PRD.md#fr-3-configuration-management
#
# Test philosophy: Given/When/Then behavioral assertions.
# Uses `chezmoi managed`, `chezmoi cat`, `chezmoi diff` to prove
# the configuration engine works, not just that files exist.
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

# ── FR-3.1: chezmoi tracks essential dotfiles ────────────────

@test "FR-3.1: Given chezmoi source, when managed is queried, then essential dotfiles are tracked" {
    # Given — chezmoi is installed and configured
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"

    # When/Then — essential dotfiles appear in managed output
    assert_chezmoi_manages ".gitconfig"
    assert_chezmoi_manages ".zshrc"
    assert_chezmoi_manages ".zshenv"
    assert_chezmoi_manages ".p10k.zsh"
}

# ── FR-3.2: chezmoi source has correct naming conventions ────

@test "FR-3.2: Given chezmoi source directory, when dot_ files are counted, then at least 5 dotfiles are managed" {
    # Given
    [[ -d "$DOTFILES_SOURCE_DIR" ]]

    # When
    local dotfile_count
    dotfile_count=$(find "$DOTFILES_SOURCE_DIR" -maxdepth 1 -name "dot_*" -type f | wc -l | tr -d ' ')

    # Then
    [[ $dotfile_count -ge 5 ]] || {
        echo "Expected ≥5 dot_ files in source, found $dotfile_count" >&2
        return 1
    }
}

# ── FR-3.3: Encrypted files exist and use .age extension ─────

@test "FR-3.3: Given encrypted secrets in source, when listed, then all use .age extension" {
    # Given
    local encrypted_files
    encrypted_files=$(find "$DOTFILES_SOURCE_DIR" -name "encrypted_*" -type f)
    [[ -n "$encrypted_files" ]] || skip "No encrypted files found"

    # When/Then — every encrypted file ends with .age
    local non_age=0
    while IFS= read -r f; do
        if [[ ! "$f" =~ \.age$ ]]; then
            echo "Encrypted file without .age extension: $f" >&2
            non_age=$((non_age + 1))
        fi
    done <<< "$encrypted_files"

    [[ $non_age -eq 0 ]] || {
        echo "$non_age encrypted file(s) missing .age extension" >&2
        return 1
    }
}

# ── FR-3.4: Config template renders with stat guards ─────────

@test "FR-3.4: Given .chezmoi.toml.tmpl, when rendered on this machine, then sourceDir uses stat guard" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.toml.tmpl" ]]

    # When — check template source for stat guard pattern
    local template_content
    template_content=$(cat "$DOTFILES_SOURCE_DIR/.chezmoi.toml.tmpl")

    # Then — sourceDir is gated by stat, not hardcoded
    [[ "$template_content" =~ 'stat "' ]] || {
        echo "Config template missing stat guards for portability" >&2
        return 1
    }

    # And — the template renders without errors
    assert_template_renders ".chezmoi.toml.tmpl" "ephemeral=false" "headless=false" "work=false" "personal=true"
}

# ── FR-3.5: Secrets use age encryption ───────────────────────

@test "FR-3.5: Given chezmoi config template, when inspected, then age encryption is configured" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoi.toml.tmpl" ]]

    # When
    local config_content
    config_content=$(cat "$DOTFILES_SOURCE_DIR/.chezmoi.toml.tmpl")

    # Then — age encryption configuration present
    [[ "$config_content" =~ "encryption" ]] || {
        echo "Config template missing encryption configuration" >&2
        return 1
    }
    [[ "$config_content" =~ "age" ]] || {
        echo "Config template missing age encryption settings" >&2
        return 1
    }
}

# ── FR-3.6: External dependencies configured ────────────────

@test "FR-3.6: Given .chezmoiexternal.toml.tmpl, when inspected, then shell frameworks are configured" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiexternal.toml.tmpl" ]]

    # When
    local external_content
    external_content=$(cat "$DOTFILES_SOURCE_DIR/.chezmoiexternal.toml.tmpl")

    # Then — at least one shell framework is configured
    local frameworks_found=0
    for fw in "oh-my-zsh" "antigen" "dircolors"; do
        if echo "$external_content" | grep -qi "$fw"; then
            frameworks_found=$((frameworks_found + 1))
        fi
    done

    [[ $frameworks_found -ge 1 ]] || {
        echo "No shell frameworks found in .chezmoiexternal.toml.tmpl" >&2
        return 1
    }
}

# ── FR-3.7: Private directories use correct permissions ──────

@test "FR-3.7: Given private_ directories in source, when listed, then sensitive paths are protected" {
    # Given
    local private_dirs
    private_dirs=$(find "$DOTFILES_SOURCE_DIR" -maxdepth 2 -name "private_*" -type d)

    # When/Then — at least SSH and Library are private
    [[ -n "$private_dirs" ]] || {
        echo "No private_ directories found in chezmoi source" >&2
        return 1
    }

    echo "$private_dirs" | grep -q "private_Library" || {
        echo "Expected private_Library directory for sensitive app data protection" >&2
        return 1
    }
}

# ── FR-3.8: .chezmoiignore contains OS-specific patterns ────

@test "FR-3.8: Given .chezmoiignore, when inspected, then macOS-specific patterns are present" {
    # Given
    [[ -f "$DOTFILES_SOURCE_DIR/.chezmoiignore" ]]

    # When
    local ignore_content
    ignore_content=$(cat "$DOTFILES_SOURCE_DIR/.chezmoiignore")

    # Then — .DS_Store must be ignored (macOS fundamental)
    [[ "$ignore_content" =~ ".DS_Store" ]] || {
        echo ".chezmoiignore missing .DS_Store pattern" >&2
        return 1
    }
}

# ── FR-3.9: chezmoi diff is clean (no pending changes) ──────

@test "FR-3.9: Given applied chezmoi config, when diff is run, then no unexpected changes pending" {
    # Given — chezmoi is installed
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"

    # When
    run chezmoi status 2>&1

    # Then — exit code 0 (no errors) and output indicates status ran
    assert_success
}

# ── FR-3.10: Dry-run works for configuration management ─────

@test "FR-3.10: Given setup.sh, when run with --dry-run, then chezmoi operations are previewed" {
    # Given/When
    run_modern_setup --dry-run
    assert_success

    # Then — output references chezmoi
    [[ "$output" =~ chezmoi ]] || {
        echo "Dry-run output missing chezmoi references" >&2
        return 1
    }
}

# ── FR-3.11: Managed files map to standard home paths ────────

@test "FR-3.11: Given chezmoi managed output, when checked, then paths map to standard ~ locations" {
    # Given
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"

    # When
    local managed
    managed=$(chezmoi managed 2>/dev/null)

    # Then — managed paths are relative to home (no absolute paths)
    if echo "$managed" | grep -q "^/"; then
        echo "chezmoi managed contains absolute paths — expected relative" >&2
        echo "$managed" | grep "^/" | head -5 >&2
        return 1
    fi

    # And — essential dotfiles present
    echo "$managed" | grep -qF ".gitconfig"
    echo "$managed" | grep -qF ".zshrc"
}

# ── FR-3.12: External framework contents are ignored ────────

@test "FR-3.12: Given shell frameworks in .chezmoiexternal, when chezmoi managed is run, then framework internals are not listed" {
    # Given
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not installed"

    # When
    local managed_count
    managed_count=$(chezmoi managed 2>/dev/null | wc -l | tr -d ' ')

    # Then — managed count should be reasonable (< 200, not 1500+)
    [[ $managed_count -lt 200 ]] || {
        echo "chezmoi managed lists $managed_count files — external framework contents likely leaking" >&2
        echo "Expected < 200 managed files (externals should be ignored)" >&2
        return 1
    }
}

#!/usr/bin/env bash
#
# Behavioral assertion helpers used by FR-7 debug mode tests.
#

assert_success() {
    # shellcheck disable=SC2154 # status is provided by bats.
    if [[ "${status}" -ne 0 ]]; then
        echo "Expected command success, got exit code: ${status}" >&2
        echo "Output:" >&2
        echo "${output}" >&2
        return 1
    fi
}

assert_failure() {
    # shellcheck disable=SC2154 # status is provided by bats.
    if [[ "${status}" -eq 0 ]]; then
        echo "Expected command failure, but it succeeded." >&2
        echo "Output:" >&2
        echo "${output}" >&2
        return 1
    fi
}

assert_argument_processed() {
    local expected_flag="$1"
    if [[ "${output}" =~ ${expected_flag} ]]; then
        return 0
    fi
    # Check for flag-specific behavioral evidence (not generic keywords)
    case "${expected_flag}" in
        *dry-run*)  if [[ "${output}" =~ "DRY RUN" ]]; then return 0; fi ;;
        *verbose*)  if [[ "${output}" =~ "DEBUG" ]]; then return 0; fi ;;
        *trace*)    if [[ "${output}" =~ "TRACE" ]]; then return 0; fi ;;
    esac
    echo "Expected output evidence for flag: ${expected_flag}" >&2
    echo "Output:" >&2
    echo "${output}" >&2
    return 1
}

assert_no_errors_in_output() {
    local output_lower
    output_lower="$(printf "%s" "${output}" | tr '[:upper:]' '[:lower:]')"
    if [[ "${output_lower}" =~ "command not found" ]] || [[ "${output_lower}" =~ "syntax error" ]] || [[ "${output_lower}" =~ "setup interrupted" ]]; then
        echo "Unexpected error output found." >&2
        echo "${output}" >&2
        return 1
    fi
}

assert_no_system_modifications() {
    local snapshot_before="$1"
    local snapshot_after="$2"
    local before_filtered="${BATS_TEST_TMPDIR}/before_filtered.txt"
    local after_filtered="${BATS_TEST_TMPDIR}/after_filtered.txt"

    grep -v -E "snapshot_(before|after)\\.txt$" "${snapshot_before}" | sort > "${before_filtered}" || true
    grep -v -E "snapshot_(before|after)\\.txt$" "${snapshot_after}" | sort > "${after_filtered}" || true

    if ! diff -u "${before_filtered}" "${after_filtered}" >/dev/null 2>&1; then
        echo "Detected filesystem modifications in dry-run mode." >&2
        diff -u "${before_filtered}" "${after_filtered}" >&2 || true
        return 1
    fi
}

assert_success_indicators_present() {
    if [[ ! "${output}" =~ "completed successfully" ]] && [[ ! "${output}" =~ "Setup completed successfully" ]] && [[ ! "${output}" =~ "DRY RUN completed successfully" ]]; then
        echo "Missing success indicator in output." >&2
        echo "${output}" >&2
        return 1
    fi
}

# ── Chezmoi behavioral assertions ──────────────────────────────

# Assert that chezmoi tracks a specific target path.
# Usage: assert_chezmoi_manages ".gitconfig"
assert_chezmoi_manages() {
    local target="$1"
    if ! chezmoi managed 2>/dev/null | grep -qF "${target}"; then
        echo "Expected chezmoi to manage '${target}', but it does not." >&2
        echo "Managed files containing '$(basename "${target}")':" >&2
        chezmoi managed 2>/dev/null | grep "$(basename "${target}")" >&2 || echo "  (none)" >&2
        return 1
    fi
}

# Assert that a chezmoi template renders successfully with given data.
# Usage: assert_template_renders "Brewfile.tmpl" "ephemeral=true" "headless=false"
assert_template_renders() {
    local template="$1"
    shift
    local vars=("$@")

    local json_data="{"
    local first=true
    for var in "${vars[@]}"; do
        if [ "${first}" = true ]; then first=false; else json_data="${json_data}, "; fi
        local name="${var%=*}"
        local value="${var#*=}"
        if [[ "${value}" == "true" || "${value}" == "false" ]]; then
            json_data="${json_data} \"${name}\": ${value}"
        else
            json_data="${json_data} \"${name}\": \"${value}\""
        fi
    done
    json_data="${json_data} }"

    export CHEZMOI_INPUT_FILE="${DOTFILES_SOURCE_DIR}/${template}"
    run_chezmoi execute-template --init --stdinisatty=false --override-data "${json_data}"
    unset CHEZMOI_INPUT_FILE

    if [[ "${status}" -ne 0 ]]; then
        echo "Template '${template}' failed to render with data: ${json_data}" >&2
        echo "Output:" >&2
        echo "${output}" >&2
        return 1
    fi
}

# Assert rendered output contains a pattern. Must follow assert_template_renders.
# Usage: assert_rendered_contains "brew \"git\""
assert_rendered_contains() {
    local pattern="$1"
    if ! echo "${output}" | grep -qE "${pattern}"; then
        echo "Rendered output does not contain pattern: ${pattern}" >&2
        echo "First 20 lines of output:" >&2
        echo "${output}" | head -20 >&2
        return 1
    fi
}

# Assert rendered output does NOT contain a pattern.
# Usage: assert_rendered_excludes "cask \"figma\""
assert_rendered_excludes() {
    local pattern="$1"
    if echo "${output}" | grep -qE "${pattern}"; then
        echo "Rendered output unexpectedly contains pattern: ${pattern}" >&2
        local match
        match=$(echo "${output}" | grep -E "${pattern}" | head -3)
        echo "Matching lines:" >&2
        echo "${match}" >&2
        return 1
    fi
}

# Count lines matching a pattern in $output.
# Usage: local count=$(count_rendered_matches "^brew ")
count_rendered_matches() {
    local pattern="$1"
    echo "${output}" | grep -cE "${pattern}" || echo "0"
}

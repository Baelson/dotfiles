#!/usr/bin/env bats

load '../lib/test_helper'

setup() {
    setup_common
}

@test "DEBUG: Inspect override-data context with --file" {
    # Create a temporary template that dumps data
    local debug_tmpl="$DOTFILES_ROOT/home/debug.tmpl"
    echo '{{ . | toJson }}' > "$debug_tmpl"

    # Call the helper with some data
    # This uses run_chezmoi -> chezmoi execute-template --init ... --override-data JSON --file FILE
    test_template_rendering "debug.tmpl" "ephemeral=true" "foo=bar" "intval=42" "check_false=false"

    echo "DEBUG OUTPUT: $output"

    # Verify execution success first
    [ "$status" -eq 0 ]

    # Verify keys exist in JSON output
    # We must ensure it's not matching the error message
    # Allow for optional whitespace after colon (chezmoi output might be compact)
    [[ "$output" =~ "\"ephemeral\": true" ]] || [[ "$output" =~ "\"ephemeral\":true" ]]
    [[ "$output" =~ "\"foo\": \"bar\"" ]] || [[ "$output" =~ "\"foo\":\"bar\"" ]]
    [[ "$output" =~ "\"check_false\": false" ]] || [[ "$output" =~ "\"check_false\":false" ]]
}

@test "DEBUG: Verify headless key injection" {
    local debug_tmpl="$DOTFILES_ROOT/home/debug_headless.tmpl"
    echo '{{ .headless }}' > "$debug_tmpl"

    test_template_rendering "debug_headless.tmpl" "headless=true"

    assert_chezmoi_success
    [[ "$output" == "true" ]]
}

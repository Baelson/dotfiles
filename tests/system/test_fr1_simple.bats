#!/usr/bin/env bats

load '../lib/test_helper'

setup() {
    setup_common
}

teardown() {
    cleanup_common
}

@test "FR-1.1: setup.core.sh executes without errors in dry-run mode" {
    run_bootstrap "setup.core.sh" "--dry-run"
    assert_bootstrap_success
}
#!/usr/bin/env bats

@test "FR-1.1: setup.core.sh exists" {
    [ -f "setup/setup.core.sh" ]
}

@test "FR-1.2: setup.core.sh is executable" {
    [ -x "setup/setup.core.sh" ]
}

#!/usr/bin/env bats

@test "FR-1.1: setup.core.sh exists" {
    [ -f "bootstrap/setup.core.sh" ]
}

@test "FR-1.2: setup.core.sh is executable" {
    [ -x "bootstrap/setup.core.sh" ]
}

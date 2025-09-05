#!/usr/bin/env bats

@test "simple test" {
    run echo "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}

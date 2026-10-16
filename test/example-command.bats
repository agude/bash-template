#!/usr/bin/env bats

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    COMMAND="$BATS_TEST_DIRNAME/../bin/example-command"
}

@test "greets the world without arguments" {
    run "$COMMAND"
    assert_success
    assert_output "Hello, world!"
}

@test "greets each name in order" {
    run "$COMMAND" Ada Grace
    assert_success
    assert_line --index 0 "Hello, Ada!"
    assert_line --index 1 "Hello, Grace!"
}

@test "-- ends option parsing" {
    run "$COMMAND" -- --literal
    assert_success
    assert_output "Hello, --literal!"
}

@test "--help prints usage" {
    run "$COMMAND" --help
    assert_success
    assert_output --partial "Usage: example-command"
}

@test "an unknown option fails with usage" {
    run "$COMMAND" --bogus
    assert_failure 2
    assert_output --partial "unknown option: --bogus"
}

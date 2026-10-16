#!/usr/bin/env bats
# Tests for scripts/init. Successful runs copy the committed HEAD and clone
# the Bats submodules from GitHub, so commit template changes first and run
# these tests with network access.

setup() {
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'
    TEMPLATE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    INIT="$TEMPLATE_ROOT/scripts/init"
    DEST="$BATS_TEST_TMPDIR/out"
}

# Clone the template into a fixture repository that runs the working-tree
# scripts/init, so a test can commit a defect into the template content.
make_fixture() {
    FIXTURE="$BATS_TEST_TMPDIR/fixture"
    git clone --quiet "$TEMPLATE_ROOT" "$FIXTURE"
    cp "$INIT" "$FIXTURE/scripts/init"
}

commit_fixture() {
    (
        cd "$FIXTURE" || return 1
        git add --all
        git -c user.name=Test -c user.email=test@example.com commit --quiet --message "Inject a defect"
    )
}

assert_no_dest() {
    assert [ ! -e "$DEST" ]
    # The staging directory is removed as well.
    assert_equal "$(find "$BATS_TEST_TMPDIR" -maxdepth 1 -name '.init.*')" ""
}

@test "--help prints usage and succeeds" {
    run "$INIT" --help
    assert_success
    assert_output --partial "Usage: scripts/init <dest> <name>"
}

@test "missing arguments are a usage error" {
    run "$INIT" "$DEST"
    assert_failure 2
    assert_no_dest
}

@test "an unknown option is a usage error" {
    run "$INIT" "$DEST" my-tool --bogus
    assert_failure 2
    assert_no_dest
}

@test "an invalid name fails without creating dest" {
    run "$INIT" "$DEST" My_Tool --ref HEAD
    assert_failure 1
    assert_output --partial "name 'My_Tool' must match"
    assert_no_dest
}

@test "a name that contains the placeholder fails" {
    run "$INIT" "$DEST" example-command-tools --ref HEAD
    assert_failure 1
    assert_output --partial "contains the template placeholder"
    assert_no_dest
}

@test "an existing dest fails and is left untouched" {
    mkdir "$DEST"
    touch "$DEST/keep"
    run "$INIT" "$DEST" my-tool --ref HEAD
    assert_failure 1
    assert_output --partial "destination already exists"
    assert_equal "$(ls -A "$DEST")" "keep"
}

@test "an unknown ref fails without creating dest" {
    run "$INIT" "$DEST" my-tool --ref no-such-ref
    assert_failure 1
    assert_output --partial "unknown ref: no-such-ref"
    assert_no_dest
}

@test "a leftover placeholder fails without creating dest" {
    make_fixture
    echo "EXAMPLE_COMMAND_DEBUG=1" >"$FIXTURE/leftover.txt"
    commit_fixture
    run "$FIXTURE/scripts/init" "$DEST" my-tool --ref HEAD
    assert_failure 1
    assert_output --partial "leftover.txt"
    assert_no_dest
}

@test "a leftover placeholder in a file name fails without creating dest" {
    make_fixture
    touch "$FIXTURE/Example_Command.txt"
    commit_fixture
    run "$FIXTURE/scripts/init" "$DEST" my-tool --ref HEAD
    assert_failure 1
    assert_output --partial "Example_Command.txt"
    assert_no_dest
}

@test "an unclosed marker block fails without creating dest" {
    make_fixture
    printf '# init:template-begin\necho template\n' >"$FIXTURE/unclosed.sh"
    commit_fixture
    run "$FIXTURE/scripts/init" "$DEST" my-tool --ref HEAD
    assert_failure 1
    assert_output --partial "block template is never closed"
    assert_no_dest
}

@test "the project is renamed and keeps the pinned submodules" {
    run "$INIT" "$DEST" my-tool --ref HEAD
    assert_success

    run git --git-dir="$DEST/.git" grep --cached -niE 'example[-_]command|init:[a-z]+-(begin|end)'
    assert_failure 1
    run git --git-dir="$DEST/.git" ls-files
    refute_output --regexp '[Ee]xample[-_][Cc]ommand'
    assert_line 'bin/my-tool'
    assert_line 'test/my-tool.bats'
    assert [ -x "$DEST/bin/my-tool" ]
    run grep -x 'name = "my-tool"' "$DEST/pyproject.toml"
    assert_success
    run grep -x 'name = "my-tool"' "$DEST/uv.lock"
    assert_success

    # Each submodule is registered at the commit the template pins.
    local path pinned
    for path in test/bats test/test_helper/bats-support test/test_helper/bats-assert; do
        pinned="$(git --git-dir="$TEMPLATE_ROOT/.git" ls-tree HEAD -- "$path" | awk '{ print $3 }')"
        run git --git-dir="$DEST/.git" ls-files --stage -- "$path"
        assert_output --partial "160000 $pinned"
        assert [ -f "$DEST/$path/.git" ]
    done
    run git --git-dir="$DEST/.git" config --file "$DEST/.gitmodules" --get submodule.test/bats.url
    assert_output "https://github.com/bats-core/bats-core.git"
}

@test "template-only files and content are left out" {
    run "$INIT" "$DEST" my-tool --ref HEAD
    assert_success
    assert [ ! -e "$DEST/scripts" ]
    assert [ ! -e "$DEST/test/init" ]
    assert [ ! -e "$DEST/.github/workflows/template-test.yml" ]
    run grep -il 'template\|test-init\|export-ignore' "$DEST/justfile" "$DEST/.gitattributes" "$DEST/README.md" "$DEST/AGENTS.md"
    assert_failure 1
}

@test "the project is a Git repository with staged files and no commits" {
    run "$INIT" "$DEST" my-tool --ref HEAD
    assert_success
    cd "$DEST"
    assert_equal "$(git symbolic-ref --short HEAD)" "main"
    run git rev-parse --verify --quiet HEAD
    assert_failure
    run git status --porcelain --untracked-files=all
    refute_line --regexp '^[^A]'
    run uv lock --quiet
    assert_success
    run git diff --exit-code -- uv.lock
    assert_success
}

# Task runner for example-command. Run `just` to list the recipes.
#
# Recipes run under the first bash on PATH, which is Bash 3.2 in two CI legs,
# so recipe bodies follow the same Bash 3.2 rules as the scripts.

set shell := ["bash", "-euo", "pipefail", "-c"]

shell_files := "bin/* test/*.bats"
shfmt_style := "--indent 4 --case-indent"

# List the recipes.
default:
    @just --list

# Install the locked development tools.
sync:
    uv sync --locked

# Regenerate uv.lock after changing dependencies in pyproject.toml.
lock:
    uv lock

# Run every read-only static check.
lint:
    uv run --locked shellcheck {{ shell_files }}
    uv run --locked shfmt --diff {{ shfmt_style }} {{ shell_files }}
    uv run --locked actionlint
    uv run --locked zizmor --pedantic --quiet .github/workflows .github/dependabot.yml

# Apply the shell formatter.
format:
    uv run --locked shfmt --write {{ shfmt_style }} {{ shell_files }}

# Run the Bats suite. If EXPECT_BASH is set, require a bash of that version.
test:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -x test/bats/bin/bats ]]; then
        echo "test: Bats is missing; run: git submodule update --init" >&2
        exit 1
    fi
    version="$(bash -c 'echo "$BASH_VERSION"')"
    echo "test: bash $version"
    if [[ -n "${EXPECT_BASH:-}" && "$version" != "$EXPECT_BASH".* ]]; then
        echo "test: expected bash $EXPECT_BASH" >&2
        exit 1
    fi
    test/bats/bin/bats test/

# Run lint and test.
check: lint test

# Install the pre-commit hook, which runs `just lint`.
hooks-install:
    #!/usr/bin/env bash
    set -euo pipefail
    hooks_path="$(git config --get core.hooksPath || true)"
    if [[ -z "$hooks_path" ]]; then
        uv run --locked pre-commit install
        exit 0
    fi
    # Print a path with symbolic links resolved. Its last components may not
    # exist yet.
    canonical() {
        local path="$1" suffix=""
        while [[ ! -d "$path" ]]; do
            suffix="/$(basename "$path")$suffix"
            path="$(dirname "$path")"
        done
        printf '%s%s\n' "$(cd "$path" && pwd -P)" "$suffix"
    }
    # `pre-commit install` refuses to run while core.hooksPath is set, so
    # write a hook that calls the pre-commit runner at Git's effective path.
    # A hooks directory outside this repository is shared with other
    # repositories, and this project's hook must not replace theirs.
    hooks_dir="$(canonical "$(git rev-parse --path-format=absolute --git-path hooks)")"
    top="$(canonical "$(git rev-parse --show-toplevel)")"
    git_dir="$(canonical "$(git rev-parse --path-format=absolute --git-common-dir)")"
    case "$hooks_dir/" in
        "$top/"* | "$git_dir/"*) ;;
        *)
            echo "hooks-install: core.hooksPath is $hooks_path, which is outside this repository." >&2
            echo "hooks-install: Call 'just lint' from the pre-commit hook there, or give this" >&2
            echo "hooks-install: repository its own: git config core.hooksPath .git/hooks" >&2
            exit 1
            ;;
    esac
    hook="$hooks_dir/pre-commit"
    content="$(printf '%s\n' \
        '#!/usr/bin/env bash' \
        '# Installed by `just hooks-install`.' \
        'exec uv run --locked pre-commit run --hook-stage pre-commit')"
    if [[ -f "$hook" && "$(cat "$hook")" == "$content" ]]; then
        echo "hooks-install: already installed at $hook"
        exit 0
    fi
    if [[ -e "$hook" || -L "$hook" ]]; then
        backup="$(mktemp "$hook.backup.XXXXXX")"
        mv "$hook" "$backup"
        echo "hooks-install: moved the existing hook to $backup"
    fi
    mkdir -p "$(dirname "$hook")"
    printf '%s\n' "$content" > "$hook"
    chmod +x "$hook"
    echo "hooks-install: installed $hook"

# Remove the virtual environment.
clean:
    rm -rf .venv
# init:template-begin

# Lint scripts/init and run its Bats tests.
test-init:
    uv run --locked shellcheck scripts/init test/init/*.bats
    uv run --locked shfmt --diff {{ shfmt_style }} scripts/init test/init/*.bats
    test/bats/bin/bats test/init

# Create a project from HEAD, then check it.
test-generated:
    #!/usr/bin/env bash
    set -euo pipefail
    root="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/test-generated.XXXXXX")"
    trap 'rm -rf "$root"' EXIT
    scripts/init "$root/out" generated-command --ref HEAD
    cd "$root/out"
    just sync check
# init:template-end

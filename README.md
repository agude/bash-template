# example-command
<!-- init:template-begin -->

> **This repository is a template.** Create a project from it with
> `scripts/init`, as described below. `scripts/init` removes this section and
> every other template-only part.

## Creating a project

Requires Git, [uv](https://docs.astral.sh/uv/), and
[just](https://just.systems/).

```sh
git clone https://github.com/agude/bash-template.git ~/Projects/bash-template
cd ~/Projects/bash-template
scripts/init ~/Projects/my-tool my-tool
cd ~/Projects/my-tool
just sync && just hooks-install && just check
git commit
```

`scripts/init <dest> <name>` does the following:

1. Fetches `origin` and exports `origin/main` with `git archive`.
   Uncommitted changes in the clone are not used.
2. Renames `example-command` to `<name>` in file names and contents, and
   removes the template-only parts.
3. Fails, and creates nothing, if the placeholder remains.
4. Runs `uv lock` and `git init`, adds the Bats submodules again at the
   commits this template pins, and runs `git add`. It does not commit.

`--ref REF` copies `REF` instead of `origin/main`, without fetching.

## How the template works

`example-command` is the only placeholder. It names the project in
`pyproject.toml`, the script in `bin/`, and its test file.

Template-only content sits between `init:template-<begin|end>` marker
comments, and `scripts/init` removes it. Files that only the template needs
are marked `export-ignore` in `.gitattributes`, so `git archive` leaves them
out.

`git archive` does not export submodules, so `scripts/init` reads each
submodule's URL from `.gitmodules` and its pinned commit from the template's
tree, then adds it to the new repository with `git submodule add`.

## Maintaining the template

The template is itself a working project, so `just check` must pass. In
addition:

- `just test-init` lints `scripts/init` and runs its Bats tests.
- `just test-generated` creates a project from `HEAD` and checks it.

The Template test workflow runs both on Bash 5, in the `bash:3.2`
container, and on macOS, on every push and once a week. The weekly run
catches upstream releases that break new projects between Dependabot
updates.

---
<!-- init:template-end -->

A short description of example-command.

## Usage

```sh
bin/example-command --help
```

## Development

Requires [uv](https://docs.astral.sh/uv/), [just](https://just.systems/),
and the Git submodules:

```sh
git submodule update --init  # Fetch Bats and its helpers, if not cloned with --recurse-submodules.
just sync                    # Install the locked shellcheck, shfmt, and workflow linters.
just hooks-install           # Install the pre-commit hook, which runs `just lint`.
just check                   # Run lint and the Bats tests.
```

Run `just` to list every recipe.

## License

[CC0 1.0 Universal](LICENSE.md)

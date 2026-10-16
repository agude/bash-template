# example-command

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

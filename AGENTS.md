# AGENTS.md

Guidance for coding agents that work in this repository.

<!-- init:template-begin -->
## This repository is a template

`scripts/init` creates projects from this repository; `README.md` describes
how. When you change the template:

- Keep it a working project. `just check` must pass with the placeholder in
  place.
- Write the placeholder `example-command` only where the project's own name
  belongs. `init` replaces every occurrence and fails on any other case
  variant.
- Wrap template-only content in `init:template-<begin|end>` marker
  comments. Do not nest blocks.
- Mark files that only the template needs as `export-ignore` in
  `.gitattributes`.
- After changing `scripts/init`, run `just test-init` and
  `just test-generated`.

<!-- init:template-end -->
## Project

example-command is a Bash project. Its command is `bin/example-command`, and
its tests are Bats files in `test/`.

## Commands

Use the `just` recipes. CI calls the same recipes, so a local pass predicts a
CI pass.

| Recipe | Effect |
| --- | --- |
| `just sync` | Installs the locked tools: shellcheck, shfmt, actionlint, zizmor, and pre-commit. |
| `just lint` | Runs shellcheck, shfmt in diff mode, actionlint, and zizmor. Read-only. |
| `just format` | Applies shfmt. |
| `just test` | Runs the Bats suite with the vendored Bats. |
| `just check` | Runs lint and test. Run it before every commit. |
| `just lock` | Updates `uv.lock` after a tool change. |

## Bash 3.2

Every script and every recipe body must run under Bash 3.2, the macOS system
Bash. CI runs the tests on Bash 5, in the `bash:3.2` container, and on macOS
with `/bin/bash`. Do not use:

- associative arrays (`declare -A`)
- `mapfile` or `readarray`
- namerefs (`declare -n`, `local -n`)
- case modification (`${var,,}`, `${var^^}`)
- `wait -n`
- `|&` or `&>>`
- `coproc`

Under `set -u`, Bash 3.2 treats `"${arr[@]}"` on an empty array as an unbound
variable. Expand a possibly empty array as `${arr[@]+"${arr[@]}"}`.

Use only the portable forms of the userland tools, because macOS ships the
BSD versions and the container ships BusyBox:

- `sed`: no `-i`. Write to a temporary file and copy it back.
- `date`: no `-d`.
- `readlink`: no `-f`.
- `grep`: no `-P`, `--exclude`, or `--exclude-dir`.

## Rules

- Tools come from `uv.lock`. Add a tool with `uv add --dev`, and commit
  `uv.lock`.
- `exclude-newer = "7 days"` in `pyproject.toml` hides releases younger than
  a week. Do not remove it to get a newer release; wait for the release to
  age.
- Bats, bats-support, and bats-assert are Git submodules pinned to release
  commits. Dependabot proposes updates; do not move them by hand without a
  reason.
- Workflows call `just` recipes and nothing else, apart from setup steps. To
  change what CI does, change a recipe.
- Actions are pinned to a full commit SHA with a `# vX.Y.Z` comment, the
  container image is pinned by digest, every checkout sets
  `persist-credentials: false`, and each workflow starts from
  `permissions: {}`. zizmor enforces this in `just lint`.
- Dependabot does not update these pins, so bump them by hand:
  - `just-version` in every workflow.
  - The `bash:3.2` image digest in the workflows.
  - The uv `version` in the CI lint job. It matches the uv in Dependabot's
    updater, so the lint job proves that Dependabot can update `uv.lock`.
    Raise it, and `required-version` in `pyproject.toml`, only after a
    Dependabot job log shows a newer uv.
- The pre-commit hook runs `just lint` and changes nothing. If it fails, run
  `just format`, then commit again.

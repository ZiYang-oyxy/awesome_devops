# Repository Guidelines

## Project Structure & Module Organization
- `ad`: main Bash entrypoint for commands (`put/get`, `deploy`, `publish`, `doctor`, tool dispatch).
- `lib/`: shared shell helpers (for example `lib/common.sh`).
- `tools/`: built-in utilities invoked via `ad <tool>`.
- `plugins/<name>/install`: optional plugin installers, enabled with `ad deploy <name>`.
- `ext_tools/` and `experimental/`: external or experimental tools.
- `docs/`: usage assets (GIF/SVG) referenced by `README.md`.
- `config.example` -> copy to `config` for local/server-specific values.

## Build, Test, and Development Commands
- `./offline_install.sh`: install from local checkout to `~/.awesome_devops` and refresh `~/bin/ad` symlink.
- `ad help`: list built-in commands, tools, and deployable plugins.
- `ad tree`: inspect repository tool layout.
- `ad doctor env`: verify effective runtime config and external passthrough state.
- `ad deploy xfinder`: install one plugin (replace with other plugin names).
- `ad publish`: package and upload release artifacts (`tar`, installer, `latest_version`); requires valid upload/download URLs in config.

## Coding Style & Naming Conventions
- Shell-first project: prefer Bash with `#!/bin/bash` and fail-fast behavior (`set -e` where appropriate).
- Use 4-space indentation, lowercase/snake_case function names, and descriptive local variables.
- Keep command names short and lowercase (`tools/<tool>`), and plugin directories aligned with deploy names.
- Quote variable expansions unless intentional word splitting is required.

## Testing Guidelines
- No global CI test suite is defined; use smoke tests for changes to core flows.
- Minimum manual checks after edits: `ad help`, `ad tree`, `ad doctor env`, and one representative tool invocation.
- For `plugins/pssh`, optional Python tests exist at `plugins/pssh/test/test.py` and require `TEST_HOSTS` and `TEST_USER`.

## Commit & Pull Request Guidelines
- Follow Conventional Commits seen in history, e.g. `feat(ad): ...`, `fix(nvim): ...`, `docs(readme): ...`.
- Keep commits focused by area (core command, tool, plugin, or docs) and use imperative summaries.
- PRs should include: purpose, key changed paths, manual verification commands run, and related issue/task links.
- For user-facing behavior changes, update `README.md` and relevant docs assets in `docs/`.

## Security & Configuration Tips
- Never commit secrets or environment-specific endpoints; keep local overrides in untracked config.
- Validate upload/download endpoints before `ad publish` to avoid broken release artifacts.

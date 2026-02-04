---
name: nvim-config-rules
description: Neovim config conventions for separating plugin specs in lua/plugins and implementation/config in lua/config. Use when editing ~/.config/nvim, Lazy.nvim specs, keymaps/autocmds/options, or reorganizing plugin setup.
---

# Neovim Config Rules

## Overview

Apply a consistent split: plugin declarations live in `lua/plugins/`, and plugin configuration or setup lives in `lua/config/`.

Key distinction: `lua/plugins/` is the **plugin spec + load control layer**, while `lua/config/` is the **runtime behavior layer**.

## Rules

1) **Plugin specs go in `lua/plugins/`**
   - Keep entries minimal: plugin name, dependencies, lazy keys, events, opts.
   - Prefer `config = function() require("config.<name>").setup() end` for non-trivial setup.
   - This is where Lazy.nvim reads specs to decide **what loads when**.

2) **All changes must be limited to this `nvim` directory**
   - Do not edit files outside `~/.config/nvim` unless explicitly asked.

3) **Plugin configuration lives in `lua/config/`**
   - Put `setup()` logic, plugin-specific keymaps, and plugin-specific autocmds here.
   - Example module shape:
      - `lua/config/<name>.lua` exporting `setup()`
   - Treat this as runtime behavior; do not assume a lazy-loaded plugin API is already available here.

4) **Global editor config stays in `lua/config/`**
   - General options, non-plugin keymaps, generic autocmds.
   - Keep plugin-specific logic out of `config/options.lua`, `config/keymaps.lua`, `config/autocmds.lua`.
   - If a keymap calls a plugin API, define it in the plugin's `config` or `keys` spec.

5) **One plugin, one pair of files**
   - `lua/plugins/<plugin>.lua` declares the plugin.
   - `lua/config/<plugin>.lua` holds the setup for that plugin.

6) **Load-order guardrails**
   - Code that calls a plugin API must execute **after** the plugin loads.
   - Use the plugin spec `config` callback (or `opts`) to ensure ordering.

7) **LazyVim auto-load entrypoints are special**
   - LazyVim auto-loads only `lua/config/options.lua`, `lua/config/keymaps.lua`, `lua/config/autocmds.lua`, and `lua/config/lazy.lua`.
   - Do not `require` those files (or `lazyvim.config`) manually.

## Workflow

1) Identify whether the change is plugin declaration or plugin behavior.
2) If it changes plugin behavior, add or update `lua/config/<plugin>.lua`.
3) In the plugin spec, call the config module with `require("config.<plugin>").setup()`.
4) Move any plugin-specific keymaps/autocmds out of general config files.

## LazyVim Notes

- **Special entrypoints**: LazyVim auto-loads `lua/config/options.lua`, `lua/config/keymaps.lua`, `lua/config/autocmds.lua`, and `lua/config/lazy.lua` at the appropriate times.
- **Do not `require` these files manually**, and do not `require("lazyvim.config")` from your config. LazyVim loads them.
- Load order matters:
  - `lua/config/options.lua` loads before Lazy.nvim startup.
  - `lua/config/keymaps.lua` and `lua/config/autocmds.lua` load on `VeryLazy` (late).
- Use `vim.keymap.set` in user config (not `LazyVim.safe_keymap_set`).
- LazyVim defaults load before your config; treat `lua/config/*` as overrides/additions.
- To disable a default autocmd, delete its augroup by name (defaults use `lazyvim_` prefix).

Additional modules under `lua/config/` (for example `lua/config/telescope.lua`) are a local convention and are **not** part of LazyVim's special auto-loaded entrypoints. Load them explicitly from:
- the corresponding plugin spec (`config = function() require("config.<plugin>").setup() end`), or
- one of the four entrypoints above, if it is truly global and safe to run at that time.

## LazyVim References

- **Adding plugins**: See `references/lazyvim-plugins.md`.
- **Adding keymaps**: See `references/lazyvim-keymaps.md`.
- **Full plugin examples**: See `references/lazyvim-examples.md`.

## Repo Examples

- `lua/config/lazy.lua` imports `{ import = "plugins" }` as the spec entrypoint.
- `lua/plugins/telescope.lua` uses `config = function() require("config.telescope").setup() end`.
- `lua/plugins/snacks.lua` uses `opts = require("config.snacks")` for options-only config.

## Examples

- Add a new plugin:
  - Create `lua/plugins/foo.lua` with the spec.
  - Create `lua/config/foo.lua` with a `setup()` function.
- Move plugin config out of general files:
  - Telescope mappings/settings should live in `lua/config/telescope.lua`.

## Non-goals

- Do not refactor unrelated Lua code.
- Do not change plugin manager or lazy-loading strategy unless explicitly asked.

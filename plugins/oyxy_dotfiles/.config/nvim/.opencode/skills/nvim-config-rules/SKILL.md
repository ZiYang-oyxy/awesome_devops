---
name: nvim-config-rules
description: Neovim config conventions for separating plugin specs in lua/plugins and implementation/config in lua/config. Use when editing ~/.config/nvim, Lazy.nvim specs, keymaps/autocmds/options, or reorganizing plugin setup.
---

# Neovim Config Rules

## Overview

Apply a consistent split: plugin declarations live in `lua/plugins/`, and plugin configuration or setup lives in `lua/config/`.

## Rules

1) **Plugin specs go in `lua/plugins/`**
   - Keep entries minimal: plugin name, dependencies, lazy keys, events, opts.
   - Prefer `config = function() require("config.<name>").setup() end` for non-trivial setup.

2) **All changes must be limited to this `nvim` directory**
   - Do not edit files outside `~/.config/nvim` unless explicitly asked.

3) **Plugin configuration lives in `lua/config/`**
   - Put `setup()` logic, plugin-specific keymaps, and plugin-specific autocmds here.
   - Example module shape:
     - `lua/config/<name>.lua` exporting `setup()`

4) **Global editor config stays in `lua/config/`**
   - General options, non-plugin keymaps, generic autocmds.
   - Keep plugin-specific logic out of `config/options.lua`, `config/keymaps.lua`, `config/autocmds.lua`.

5) **One plugin, one pair of files**
   - `lua/plugins/<plugin>.lua` declares the plugin.
   - `lua/config/<plugin>.lua` holds the setup for that plugin.

## Workflow

1) Identify whether the change is plugin declaration or plugin behavior.
2) If it changes plugin behavior, add or update `lua/config/<plugin>.lua`.
3) In the plugin spec, call the config module with `require("config.<plugin>").setup()`.
4) Move any plugin-specific keymaps/autocmds out of general config files.

## Examples

- Add a new plugin:
  - Create `lua/plugins/foo.lua` with the spec.
  - Create `lua/config/foo.lua` with a `setup()` function.
- Move plugin config out of general files:
  - Telescope mappings/settings should live in `lua/config/telescope.lua`.

## Non-goals

- Do not refactor unrelated Lua code.
- Do not change plugin manager or lazy-loading strategy unless explicitly asked.

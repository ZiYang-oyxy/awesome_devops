# LazyVim Plugins Reference

## Sources

- https://www.lazyvim.org/configuration/plugins
- https://github.com/folke/lazy.nvim

## Essentials

- Put plugin specs in any file under `lua/plugins/*.lua` (per-plugin or grouped).
- Each spec file returns a Lua table of plugin specs.
- Common spec keys include: `cmd`, `keys`, `opts`, `dependencies`, `event`, `ft`.
- `opts` is passed to the plugin's `setup()`.

## Customizing and Disabling

- Disable a plugin by adding a spec with `enabled = false` (do not delete defaults).
- Customize an included plugin by adding another spec for the same plugin.
- Merge rules:
  - `cmd`, `event`, `ft`, `keys`, `dependencies`: your lists extend defaults.
  - `opts`: your options are merged with defaults.
  - Other properties: override defaults.
- For list fields and `opts`, you can use a function to modify existing values.

## Keymap Behavior in Plugin Specs

- `keys` extends by default.
- Disable a default keymap with `{ "<lhs>", false }` and match the original `mode`.
- Override by re-adding the same `lhs` with a new `rhs`.
- Replace all keymaps by setting `keys` to a function that returns the full list (or `{}` to disable all).

## Examples

```lua
-- Disable a plugin
return {
  { "folke/trouble.nvim", enabled = false },
}
```

```lua
-- Extend plugin options with a function
return {
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-emoji" },
    opts = function(_, opts)
      table.insert(opts.sources, { name = "emoji" })
    end,
  },
}
```

```lua
-- Disable and override keymaps in a plugin spec
return {
  "nvim-telescope/telescope.nvim",
  keys = {
    { "<leader>/", false },
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
  },
}
```

```lua
-- Disable a keymap with a non-default mode
return {
  "folke/flash.nvim",
  keys = {
    { "s", mode = { "n", "x", "o" }, false },
  },
}
```

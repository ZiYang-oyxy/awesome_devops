# LazyVim Plugin Examples Reference

## Source

- https://www.lazyvim.org/configuration/examples

## Spec File Structure

Every Lua file under `lua/plugins/` is auto-loaded by lazy.nvim. A typical file ends with `return { ... }`.

```lua
-- lua/plugins/<something>.lua
-- Every spec file under the "plugins" directory is loaded automatically by lazy.nvim.
-- In your plugin files, you can:
-- * add extra plugins
-- * disable/enable LazyVim plugins
-- * override the configuration of LazyVim plugins
return {
  -- plugin specs go here
}
```

## Common Patterns

```lua
-- Add a new plugin (minimal spec)
{ "ellisonleao/gruvbox.nvim" }
```

```lua
-- Configure LazyVim itself (example: colorscheme)
{
  "LazyVim/LazyVim",
  opts = { colorscheme = "gruvbox" },
}
```

```lua
-- Change a plugin's options (opts merged with defaults)
{
  "folke/trouble.nvim",
  opts = { use_diagnostic_signs = true },
}
```

```lua
-- Disable a plugin
{ "folke/trouble.nvim", enabled = false }
```

```lua
-- Extend existing options with a function and add dependencies
{
  "hrsh7th/nvim-cmp",
  dependencies = { "hrsh7th/cmp-emoji" },
  opts = function(_, opts)
    table.insert(opts.sources, { name = "emoji" })
  end,
}
```

```lua
-- Add/override keymaps for a plugin
{
  "nvim-telescope/telescope.nvim",
  keys = {
    {
      "<leader>fp",
      function()
        require("telescope.builtin").find_files({
          cwd = require("lazy.core.config").options.root,
        })
      end,
      desc = "Find Plugin File",
    },
  },
}
```

```lua
-- Override plugin options directly (example: Telescope UI defaults)
{
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = {
      layout_strategy = "horizontal",
      layout_config = { prompt_position = "top" },
      sorting_strategy = "ascending",
      winblend = 0,
    },
  },
}
```

```lua
-- Add LSP servers via nvim-lspconfig (auto-installed by mason)
{
  "neovim/nvim-lspconfig",
  opts = { servers = { pyright = {} } },
}
```

## Custom LSP Setup Flow (Summary)

- Add dependency as needed.
- Register `on_attach` behavior.
- Intercept server setup via `opts.setup[server] = function(...) return true end`.

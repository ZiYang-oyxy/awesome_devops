# LazyVim Keymaps Reference

## Source

- https://www.lazyvim.org/configuration/keymaps

## Placement by Scope

- **Global (always active):** `lua/config/keymaps.lua`.
- **Plugin-specific:** define in the plugin spec via `keys`.
- **LSP-specific:** define in the LSP server config via the `keys` option.

## Overriding Existing Mappings

- Disable/remove the existing mapping first in the correct location.
- **Global defaults:** use `vim.keymap.del(...)`.
- **LSP keys tables:** disable with `{ "gd", false }` (or the relevant lhs).

## Global LSP Keymaps (All Servers)

Use the `servers["*"]` key to apply to every LSP server:

```lua
{
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      ["*"] = {
        keys = {
          { "K", vim.lsp.buf.hover, desc = "Hover" },
          { "gd", false },
          { "<leader>ca", vim.lsp.buf.code_action, desc = "Code Action", has = "codeAction" },
        },
      },
    },
  },
}
```

## Server-Specific LSP Keymaps

```lua
{
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      vtsls = {
        keys = {
          {
            "<leader>co",
            function()
              vim.lsp.buf.code_action({
                apply = true,
                context = { only = { "source.organizeImports" }, diagnostics = {} },
              })
            end,
            desc = "Organize Imports",
          },
        },
      },
    },
  },
}
```

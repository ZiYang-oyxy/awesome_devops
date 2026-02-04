---@diagnostic disable: undefined-global
local M = {}

function M.setup()
  local telescope = require("telescope.builtin")

  -- Cscope-like mappings mapped to LSP/Telescope.
  vim.keymap.set("n", "<C-2>s", function()
    vim.lsp.buf.workspace_symbol(vim.fn.expand("<cword>"))
  end, { desc = "LSP Workspace Symbols" })
  vim.keymap.set("n", "<C-2>g", vim.lsp.buf.definition, { desc = "LSP Definition" })
  vim.keymap.set("n", "<C-2>c", vim.lsp.buf.incoming_calls, { desc = "LSP Incoming Calls" })
  vim.keymap.set("n", "<C-2>t", vim.lsp.buf.references, { desc = "LSP References" })
  vim.keymap.set("n", "<C-2>d", vim.lsp.buf.outgoing_calls, { desc = "LSP Outgoing Calls" })
  vim.keymap.set("n", "<C-2>e", function()
    telescope.live_grep()
  end, { desc = "Live Grep" })
  vim.keymap.set("n", "<C-2>f", function()
    telescope.find_files()
  end, { desc = "Find Files" })
  vim.keymap.set("n", "<C-2>i", function()
    telescope.grep_string({
      search = vim.fn.expand("<cfile>"),
    })
  end, { desc = "Grep Current File Name" })
end

return M

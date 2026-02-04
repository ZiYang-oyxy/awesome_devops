---@diagnostic disable: undefined-global
local M = {}

local function telescope_or_fallback(telescope_action, fallback)
  return function()
    local ok, telescope = pcall(require, "telescope.builtin")
    if ok then
      telescope_action(telescope)
      return
    end

    if fallback then
      fallback()
    else
      vim.notify("Telescope is not available", vim.log.levels.WARN)
    end
  end
end

function M.setup()
  -- Cscope-like mappings mapped to LSP/Telescope.
  vim.keymap.set("n", "<C-2>s", telescope_or_fallback(function(telescope)
    telescope.lsp_workspace_symbols({
      query = vim.fn.expand("<cword>"),
    })
  end, function()
    vim.lsp.buf.workspace_symbol(vim.fn.expand("<cword>"))
  end), { desc = "LSP Workspace Symbols" })
  vim.keymap.set("n", "<C-2>g", vim.lsp.buf.definition, { desc = "LSP Definition" })
  vim.keymap.set("n", "<C-2>c", vim.lsp.buf.incoming_calls, { desc = "LSP Incoming Calls" })
  vim.keymap.set("n", "<C-2>t", vim.lsp.buf.references, { desc = "LSP References" })
  vim.keymap.set("n", "<C-2>d", vim.lsp.buf.outgoing_calls, { desc = "LSP Outgoing Calls" })
  vim.keymap.set("n", "<C-2>e", telescope_or_fallback(function(telescope)
    telescope.live_grep()
  end), { desc = "Live Grep" })
  vim.keymap.set("n", "<C-2>f", telescope_or_fallback(function(telescope)
    telescope.find_files()
  end), { desc = "Find Files" })
  vim.keymap.set("n", "<C-2>i", telescope_or_fallback(function(telescope)
    telescope.grep_string({
      search = vim.fn.expand("<cfile>"),
    })
  end), { desc = "Grep Current File Name" })
end

return M

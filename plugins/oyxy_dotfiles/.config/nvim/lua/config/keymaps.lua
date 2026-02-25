-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set

local function copy_current_file_path()
  local file_path = vim.fn.expand("%:p")
  if file_path == "" then
    vim.notify("Current buffer has no file path", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", file_path)
  vim.notify("Copied full path: " .. file_path)
end

local function export_mermaid_svg()
  local input_file = vim.fn.expand("%:p")
  if input_file == "" then
    vim.notify("Current buffer has no file path", vim.log.levels.WARN)
    return
  end

  if vim.bo.filetype ~= "mermaid" and not input_file:match("%.mmd$") and not input_file:match("%.mermaid$") then
    vim.notify("Current buffer is not a Mermaid file", vim.log.levels.WARN)
    return
  end

  local mmdc_path = vim.fn.exepath("mmdc")
  if mmdc_path == "" then
    vim.notify("mmdc not found in PATH", vim.log.levels.ERROR)
    return
  end

  if vim.bo.modified then
    vim.cmd("write")
  end

  local output_file = vim.fn.expand("%:p:r") .. ".svg"
  vim.notify("Exporting Mermaid: " .. output_file)
  vim.system({ mmdc_path, "-i", input_file, "-o", output_file }, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify("Mermaid exported: " .. output_file)
      else
        local error_message = result.stderr ~= "" and result.stderr or result.stdout
        vim.notify("Mermaid export failed: " .. error_message, vim.log.levels.ERROR)
      end
    end)
  end)
end

keymap("n", "<leader>q", "<cmd>qa!<cr>", { desc = "Quit all" })
keymap("n", "S", "<cmd>wa<cr>", { desc = "Write all" })
do
  local ok_mark, mark = pcall(require, "mark")
  if ok_mark and mark then
    local function feed_default_key(lhs)
      local keys = vim.api.nvim_replace_termcodes(lhs, true, false, true)
      vim.api.nvim_feedkeys(keys, "n", true)
    end

    local function should_skip_mark_mapping()
      local ft = vim.bo.filetype
      local bt = vim.bo.buftype
      return ft == "snacks_dashboard" or bt == "nofile"
    end

    keymap({ "n", "x" }, "!", function()
      if should_skip_mark_mapping() then
        feed_default_key("!")
        return
      end
      mark.mark_word_or_selection({ group = vim.v.count })
    end, { desc = "Mark: Toggle word or selection", silent = true })
    keymap("n", "<leader><cr>", function()
      mark.clear_all()
    end, { desc = "Mark: Clear all", silent = true })
    keymap("n", "n", function()
      mark.search_any_mark(false, vim.v.count1)
    end, { desc = "Mark: Next any match", silent = true })
    keymap("n", "N", function()
      mark.search_any_mark(true, vim.v.count1)
    end, { desc = "Mark: Prev any match", silent = true })
    keymap("n", "#", function()
      mark.search_word_or_selection_mark(false, vim.v.count1)
    end, { desc = "Mark: Next word/selection mark", silent = true })
    keymap("n", "@", function()
      mark.search_word_or_selection_mark(true, vim.v.count1)
    end, { desc = "Mark: Prev word/selection mark", silent = true })
    keymap("n", "<leader>`", function()
      mark.list()
    end, { desc = "Mark: List all", silent = true, nowait = true })
  end
end
keymap({ "n", "x" }, "<leader>y", '"+y', { desc = "Copy to clipboard" })
keymap({ "n", "x" }, "<leader>p", '"+p', { desc = "Paste from clipboard" })
keymap("n", ";", ":", { desc = "Command mode" })
keymap("t", "<C-\\>", "<C-\\><C-n>", { desc = "Terminal: Normal mode" })
-- keymap("t", "<Esc>", "<C-\\><C-n>", { desc = "Terminal: Normal mode (Esc)" })
keymap("n", "<leader>a", "A", { desc = "Append end of line" })
keymap("x", "q", "<Nop>", { desc = "Disable macro recording" })
keymap("x", "Q", "<Nop>", { desc = "Disable Ex mode" })
keymap("n", "-", "^")
keymap("n", "=", "$")
keymap("v", "-", "^")
keymap("v", "=", "$")
keymap("v", "$", "%", { desc = "Jump to match" })
keymap("n", "<leader>ss", "<cmd>source $MYVIMRC<cr>", { desc = "Reload config" })
keymap("n", "<leader>ee", "<cmd>edit ~/Documents/byte/Notes/note.md<cr>", { desc = "Edit note.md" })
keymap("n", "<leader>cp", copy_current_file_path, { desc = "Copy full file path" })
keymap("n", "<leader>mmd", export_mermaid_svg, { desc = "Mermaid: Export SVG" })
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "mdx" },
  callback = function(event)
    vim.keymap.set("n", "<leader>cp", copy_current_file_path, { buffer = event.buf, desc = "Copy full file path" })
  end,
})
keymap("n", "<C-p>", function()
  require("config.telescope").toggle_oldfiles()
end, { desc = "Toggle Recent" })
keymap("n", "<F7>", function()
  require("trouble").toggle({
    mode = "lsp",
    warn_no_results = false,
    open_no_results = true,
    win = {
      position = "left",
      size = 0.3,
    },
  })
end, { desc = "Trouble LSP (toggle)" })
local diagnostic_virtual_text_on_config = vim.deepcopy(vim.diagnostic.config().virtual_text)
if diagnostic_virtual_text_on_config == nil or diagnostic_virtual_text_on_config == false then
  diagnostic_virtual_text_on_config = true
end

local inlay_hints_enabled = false

local function refresh_current_buffer_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.diagnostic.hide(nil, bufnr)
  vim.diagnostic.show(nil, bufnr)
end

local function is_virtual_text_enabled()
  return vim.diagnostic.config().virtual_text ~= false
end

local function is_diagnostics_enabled()
  if vim.diagnostic.is_enabled then
    return vim.diagnostic.is_enabled()
  end
  if vim.diagnostic.is_disabled then
    return not vim.diagnostic.is_disabled()
  end
  return true
end

local function set_diagnostics_enabled(enabled)
  if vim.fn.has("nvim-0.10") == 0 then
    if enabled then
      pcall(vim.diagnostic.enable)
    else
      pcall(vim.diagnostic.disable)
    end
    return
  end
  vim.diagnostic.enable(enabled)
end

local function set_virtual_text_enabled(enabled)
  local next_virtual_text = enabled and diagnostic_virtual_text_on_config or false
  vim.diagnostic.config({ virtual_text = next_virtual_text })
  refresh_current_buffer_diagnostics()
end

local function set_inlay_hints_enabled(enabled)
  if not vim.lsp.inlay_hint then
    return false
  end

  inlay_hints_enabled = enabled
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
      pcall(vim.lsp.inlay_hint.enable, enabled, { bufnr = bufnr })
    end
  end

  return true
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("user_inlay_hints_default", { clear = true }),
  callback = function(event)
    if not vim.lsp.inlay_hint then
      return
    end
    pcall(vim.lsp.inlay_hint.enable, inlay_hints_enabled, { bufnr = event.buf })
  end,
})

set_diagnostics_enabled(false)
set_virtual_text_enabled(false)
set_inlay_hints_enabled(false)

keymap("n", "<F12>", function()
  local inlay_supported = vim.lsp.inlay_hint ~= nil
  local all_enabled = is_diagnostics_enabled() and is_virtual_text_enabled() and (not inlay_supported or inlay_hints_enabled)
  local next_enabled = not all_enabled

  set_diagnostics_enabled(next_enabled)
  set_virtual_text_enabled(next_enabled)
  if inlay_supported then
    set_inlay_hints_enabled(next_enabled)
  end

  if inlay_supported then
    vim.notify("Diagnostics + LSP virtual text + inlay hints: " .. (next_enabled and "ON" or "OFF"))
  else
    vim.notify("Diagnostics + virtual text: " .. (next_enabled and "ON" or "OFF") .. " (inlay hints unsupported)")
  end
end, { desc = "Diagnostics + LSP Virtual Text + Inlay Hint (toggle)" })

keymap("n", "<leader>tv", function()
  local next_enabled = not is_virtual_text_enabled()
  set_virtual_text_enabled(next_enabled)
  vim.notify("Diagnostic virtual text: " .. (next_enabled and "ON" or "OFF"))
end, { desc = "LSP Diagnostic Virtual Text (toggle)" })

keymap("n", "<leader>ti", function()
  if not vim.lsp.inlay_hint then
    vim.notify("Current Neovim version does not support LSP inlay hints", vim.log.levels.WARN)
    return
  end

  local next_enabled = not inlay_hints_enabled
  set_inlay_hints_enabled(next_enabled)
  vim.notify("LSP inlay hints: " .. (next_enabled and "ON" or "OFF"))
end, { desc = "LSP Inlay Hint (toggle)" })

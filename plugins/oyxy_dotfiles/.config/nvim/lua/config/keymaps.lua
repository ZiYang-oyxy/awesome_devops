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
keymap({ "n", "x" }, "<leader>y", '"+y', { desc = "Copy to clipboard" })
keymap({ "n", "x" }, "<leader>p", '"+p', { desc = "Paste from clipboard" })
keymap({ "n", "x" }, "y", '"0y')
keymap({ "n", "x" }, "p", '"0p')
keymap("n", ";", ":", { desc = "Command mode" })
keymap("t", "<C-\\>", "<C-\\><C-n>", { desc = "Terminal: Normal mode" })
-- keymap("t", "<Esc>", "<C-\\><C-n>", { desc = "Terminal: Normal mode (Esc)" })
keymap("n", "<leader>a", "A", { desc = "Append end of line" })
keymap({ "n", "v" }, "d", '"_d') -- 使用黑洞寄存器clipboard
keymap("n", "q", "<Nop>", { desc = "Disable macro recording" })
keymap("n", "Q", "<Nop>", { desc = "Disable Ex mode" })
keymap("n", "-", "^")
keymap("n", "=", "$")
keymap("v", "-", "^")
keymap("v", "=", "$")
keymap({ "n", "v" }, "$", "%", { desc = "Jump to match" })
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
local function refresh_current_buffer_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.diagnostic.hide(nil, bufnr)
  vim.diagnostic.show(nil, bufnr)
end

keymap("n", "<leader>tv", function()
  local current_virtual_text = vim.diagnostic.config().virtual_text
  local enabled = current_virtual_text ~= false
  local next_virtual_text
  if enabled then
    next_virtual_text = false
  else
    next_virtual_text = diagnostic_virtual_text_on_config
  end

  vim.diagnostic.config({ virtual_text = next_virtual_text })
  refresh_current_buffer_diagnostics()
  vim.notify("Diagnostic virtual text: " .. (next_virtual_text ~= false and "ON" or "OFF"))
end, { desc = "LSP Diagnostic Virtual Text (toggle)" })
keymap("n", "<leader>ti", function()
  if not vim.lsp.inlay_hint then
    vim.notify("Current Neovim version does not support LSP inlay hints", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
  vim.notify("LSP inlay hints: " .. (not enabled and "ON" or "OFF"))
end, { desc = "LSP Inlay Hint (toggle)" })
keymap("n", "<C-a>", function()
  require("codex").toggle()
end, { desc = "Codex: Toggle" })
keymap("x", "<C-a>", function()
  pcall(vim.cmd, "normal! \\27")
  require("codex").actions.send_selection()
end, { desc = "Codex: Send selection" })

-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set

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
keymap("n", "<C-a>", function()
  require("codex").toggle()
end, { desc = "Codex: Toggle" })
keymap("v", "<C-a>", function()
  require("codex").actions.send_selection()
end, { desc = "Codex: Send selection" })

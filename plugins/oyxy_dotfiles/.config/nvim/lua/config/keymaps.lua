-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set

keymap("n", "<leader>q", "<cmd>qa!<cr>", { desc = "Quit all" })
keymap("n", "<leader>a", "A", { desc = "Append end of line" })
-- keymap("n", "<leader>y", "+y", { desc = "Yank to clipboard" })
-- keymap("n", "<leader>p", "+p", { desc = "Paste from clipboard" })
keymap("x", "p", '"_dP') -- 使用黑洞寄存器，避免覆盖clipboard
keymap({ "n", "v" }, "d", '"_d') -- 使用黑洞寄存器clipboard
keymap("n", "q", "<Nop>", { desc = "Disable macro recording" })
keymap("n", "Q", "<Nop>", { desc = "Disable Ex mode" })
keymap("n", "-", "^")
keymap("n", "=", "$")
keymap("v", "-", "^")
keymap("v", "=", "$")
keymap({ "n", "v" }, "\\", "%", { desc = "Jump to match" })
keymap("n", "<leader>ss", "<cmd>source $MYVIMRC<cr>", { desc = "Reload config" })
keymap("n", "<leader>ee", "<cmd>edit ~/Documents/byte/Notes/note.md<cr>", { desc = "Edit note.md" })
keymap("n", "<F9>", function()
  require("trouble").toggle({
    mode = "lsp",
    warn_no_results = false,
    open_no_results = true,
    win = {
      position = "bottom",
    },
  })
end, { desc = "Trouble LSP (toggle)" })

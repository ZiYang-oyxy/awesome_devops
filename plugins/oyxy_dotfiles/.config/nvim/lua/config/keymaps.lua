-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set

keymap("n", "<leader>q", "<cmd>qa!<cr>", { desc = "Quit all" })
keymap("n", "q", "<Nop>", { desc = "Disable macro recording" })
keymap("n", "Q", "<Nop>", { desc = "Disable Ex mode" })
keymap("n", "<leader>ss", "<cmd>source $MYVIMRC<cr>", { desc = "Reload config" })
keymap("n", "<leader>ee", "<cmd>edit ~/Documents/byte/Notes/note.md<cr>", { desc = "Edit note.md" })

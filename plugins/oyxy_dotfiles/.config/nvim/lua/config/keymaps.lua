local keymap = vim.keymap.set

keymap("n", "<leader>q", "<cmd>qa!<cr>", { desc = "Quit all" })
keymap("n", "<F8>", function()
  Snacks.picker.explorer({ cwd = LazyVim.root() })
end, { desc = "Snacks explorer (root)" })
keymap("n", "<leader>ss", "<cmd>source $MYVIMRC<cr>", { desc = "Reload config" })
keymap("n", "<leader>ee", "<cmd>edit ~/.config/nvim/lua/config/keymaps.lua<cr>", { desc = "Edit keymaps" })

local function toggle_telescope_oldfiles()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "TelescopePrompt" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end
  require("telescope.builtin").oldfiles()
end
keymap("n", "<C-p>", toggle_telescope_oldfiles, { desc = "Toggle Recent" })

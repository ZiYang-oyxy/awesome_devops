---@diagnostic disable: undefined-global
local M = {}

function M.setup()
  local actions = require("telescope.actions")

  local function toggle_telescope_aerial()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "TelescopePrompt" then
        vim.api.nvim_win_close(win, true)
        return
      end
    end
    require("telescope").extensions.aerial.aerial()
  end

  vim.keymap.set("n", "<F7>", toggle_telescope_aerial, { desc = "Toggle Telescope Aerial" })

  require("telescope").setup({
    defaults = {
      mappings = {
        i = {
          ["<F7>"] = actions.close,
          ["<C-p>"] = actions.close,
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
        },
        n = {
          ["<F7>"] = actions.close,
          ["<C-p>"] = actions.close,
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
        },
      },
    },
  })
end

return M

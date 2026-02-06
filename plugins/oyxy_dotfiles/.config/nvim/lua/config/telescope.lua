---@diagnostic disable: undefined-global
local M = {}

function M.toggle_oldfiles()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "TelescopePrompt" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end
  require("telescope.builtin").oldfiles()
end

function M.setup()
  local actions = require("telescope.actions")

  local function toggle_telescope_aerial()
    local telescope = require("telescope")
    local ok = pcall(telescope.load_extension, "aerial")
    if not ok then
      return
    end
    local aerial = telescope.extensions.aerial
    if not aerial or not aerial.aerial then
      return
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "TelescopePrompt" then
        vim.api.nvim_win_close(win, true)
        return
      end
    end
    aerial.aerial()
  end

  vim.keymap.set("n", "<F7>", toggle_telescope_aerial, { desc = "Toggle Telescope Aerial" })
  vim.keymap.set("n", "<C-p>", M.toggle_oldfiles, { desc = "Toggle Recent" })

  require("telescope").setup({
    defaults = {
      prompt_prefix = "   ",
      selection_caret = " ",
      path_display = { "truncate" },
      layout_config = {
        width = 0.90,
        preview_cutoff = 1,
        horizontal = {
          preview_width = 0.6,
        },
        -- height = 0.85,
        -- height = 0.3,
        -- prompt_position = "top",
      },
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

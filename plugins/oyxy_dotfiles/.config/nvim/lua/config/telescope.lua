---@diagnostic disable: undefined-global
local M = {}

function M.toggle_oldfiles()
  local ok_snacks, snacks = pcall(require, "snacks")
  if ok_snacks and snacks.picker and snacks.picker.get then
    local active = snacks.picker.get({ tab = true })
    if #active > 0 then
      active[1]:close()
      return
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft == "TelescopePrompt" or ft == "snacks_picker_input" or ft == "snacks_picker_list" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end
  LazyVim.pick("oldfiles")()
end

function M.setup()
  local actions = require("telescope.actions")

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
          ["<C-p>"] = actions.close,
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
        },
        n = {
          ["<C-p>"] = actions.close,
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
        },
      },
    },
  })
end

return M

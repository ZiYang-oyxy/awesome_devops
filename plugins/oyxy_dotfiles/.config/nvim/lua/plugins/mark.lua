-- All mark.nvim configuration (opts + keymaps) lives in this file.
-- `keymaps.preset = "none"` disables every built-in mapping; the `keys`
-- table below is the single source of truth. Do not add mark mappings
-- in lua/config/keymaps.lua.

local function should_skip_mark_mapping()
  return vim.bo.filetype == "snacks_dashboard" or vim.bo.buftype == "nofile"
end

local function feed_default_key(lhs)
  local keys = vim.api.nvim_replace_termcodes(lhs, true, false, true)
  vim.api.nvim_feedkeys(keys, "n", true)
end

return {
  {
    "ZiYang-oyxy/vim-mark.nvim",
    main = "mark",
    lazy = false,
    opts = {
      search_global_progress = true,
      mark_only = true,
      auto_save = true,
      auto_load = true,
      ui = {
        enhanced_picker = false,
        float_list = true,
      },
      keymaps = { preset = "none" },
    },
    keys = {
      {
        "!",
        function()
          if should_skip_mark_mapping() then
            feed_default_key("!")
            return
          end
          require("mark").mark_word_or_selection({ group = vim.v.count })
        end,
        mode = { "n", "x" },
        desc = "Mark: Toggle word or selection",
        silent = true,
      },
      {
        "n",
        function()
          require("mark").search_current_mark(false, vim.v.count1)
        end,
        desc = "Mark: Next same-color match",
        silent = true,
      },
      {
        "N",
        function()
          require("mark").search_current_mark(true, vim.v.count1)
        end,
        desc = "Mark: Prev same-color match",
        silent = true,
      },
      {
        "#",
        function()
          require("mark").search_word_or_selection_mark(false, vim.v.count1)
        end,
        desc = "Mark: Next any-color match",
        silent = true,
      },
      {
        "@",
        function()
          require("mark").search_word_or_selection_mark(true, vim.v.count1)
        end,
        desc = "Mark: Prev any-color match",
        silent = true,
      },
      {
        "<leader><cr>",
        function()
          require("mark").clear_all()
        end,
        desc = "Mark: Clear all",
        silent = true,
      },
      {
        "<leader>`",
        function()
          require("mark").list()
        end,
        desc = "Mark: List all",
        silent = true,
        nowait = true,
      },
    },
  },
}

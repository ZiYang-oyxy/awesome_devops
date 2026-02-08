return {
  {
    "ZiYang-oyxy/vim-mark.nvim",
    main = "mark",
    lazy = false,
    opts = {
      search_global_progress = true,
      mark_only = true,
      keymaps = { preset = "none" },
      auto_save = true,
      auto_load = false,
      ui = {
        enhanced_picker = false,
        float_list = true,
      },
    },
    keys = {
      {
        "!",
        function()
          require("mark").mark_word_or_selection({ group = vim.v.count })
        end,
        mode = { "n", "x" },
        desc = "Mark: Toggle word or selection",
        silent = true,
      },
      {
        "<leader><cr>",
        function()
          require("mark").clear_all()
        end,
        mode = "n",
        desc = "Mark: Clear all",
        silent = true,
      },
      {
        "n",
        function()
          require("mark").search_any_mark(false, vim.v.count1)
        end,
        mode = "n",
        desc = "Mark: Next any match",
        silent = true,
      },
      {
        "N",
        function()
          require("mark").search_any_mark(true, vim.v.count1)
        end,
        mode = "n",
        desc = "Mark: Prev any match",
        silent = true,
      },
      {
        "#",
        function()
          local mark = require("mark")
          if mark.search_next(true, nil, vim.v.count1) then
            return ""
          end
          if mark.get_count() > 0 then
            mark.search_any_mark(true, vim.v.count1)
            return ""
          end
          vim.schedule(function()
            local pattern = vim.fn.getreg("/")
            if type(pattern) ~= "string" or pattern == "" then
              return
            end
            if not pcall(vim.regex, pattern) then
              return
            end
            mark.mark_regex({ pattern = pattern })
            vim.cmd("silent! nohlsearch")
          end)
          return "#"
        end,
        mode = "n",
        expr = true,
        desc = "Mark: Prev (native fallback + record)",
        silent = true,
      },
      {
        "@",
        function()
          require("mark").search_current_mark(true, vim.v.count1)
        end,
        mode = "n",
        desc = "Mark: Prev current match",
        silent = true,
      },
      {
        "<leader>`",
        function()
          require("mark").list()
        end,
        mode = "n",
        desc = "Mark: List all",
        silent = true,
        nowait = true,
      },
    },
  },
}

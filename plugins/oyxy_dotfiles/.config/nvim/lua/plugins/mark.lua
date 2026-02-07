return {
  {
    dir = "/Volumes/code/vibecoding/mark/vim-mark_cx",
    name = "mark.nvim",
    main = "mark",
    lazy = false,
    opts = {
      search_global_progress = true,
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
          require("mark").search_current_mark(false, vim.v.count1)
        end,
        mode = "n",
        desc = "Mark: Next current match",
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

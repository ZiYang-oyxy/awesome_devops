local mark_opts = {
  keymaps = { preset = "none" },
  auto_save = true,
  auto_load = false,
  ui = {
    enhanced_picker = false,
    float_list = true,
  },
}

local function clear_builtin_mark_keymaps(mark)
  for _, mapping in ipairs(mark._applied_keymaps or {}) do
    pcall(vim.keymap.del, mapping.mode, mapping.lhs)
  end
  mark._applied_keymaps = {}
end

local function with_mark(callback)
  return function()
    local mark = require("mark")
    if not mark._setup_done then
      mark.setup(vim.deepcopy(mark_opts))
      clear_builtin_mark_keymaps(mark)
    end
    return callback(mark)
  end
end

return {
  {
    dir = "/Volumes/code/vibecoding/mark/vim-mark_cx",
    enabled = true,
    name = "mark.nvim",
    main = "mark",
    lazy = true,
    opts = mark_opts,
    keys = {
      { "!", mode = { "n", "x" }, desc = "Mark: Toggle word or selection" },
      { "<leader><cr>", mode = "n", desc = "Mark: Clear all" },
      { "<leader>`", mode = "n", desc = "Mark: List all" },
    },
    config = function(_, opts)
      local mark = require("mark")
      mark.setup(opts)
      clear_builtin_mark_keymaps(mark)

      local function map(lhs, cb, mode, desc, extra)
        local map_opts = vim.tbl_extend("force", { silent = true, desc = desc }, extra or {})
        vim.keymap.set(mode, lhs, cb, map_opts)
      end

      map(
        "!",
        with_mark(function(m)
          m.mark_word_or_selection({ group = vim.v.count })
        end),
        { "n", "x" },
        "Mark: Toggle word or selection"
      )

      map(
        "<leader><cr>",
        with_mark(function(m)
          m.clear_all()
        end),
        "n",
        "Mark: Clear all"
      )

      map(
        "n",
        with_mark(function(m)
          m.search_any_mark(false, vim.v.count1)
        end),
        "n",
        "Mark: Next any match"
      )

      map(
        "N",
        with_mark(function(m)
          m.search_any_mark(true, vim.v.count1)
        end),
        "n",
        "Mark: Prev any match"
      )

      map(
        "#",
        with_mark(function(m)
          m.search_current_mark(false, vim.v.count1)
        end),
        "n",
        "Mark: Next current match"
      )

      map(
        "@",
        with_mark(function(m)
          m.search_current_mark(true, vim.v.count1)
        end),
        "n",
        "Mark: Prev current match"
      )

      map(
        "<leader>`",
        with_mark(function(m)
          m.list()
        end),
        "n",
        "Mark: List all",
        { nowait = true }
      )
    end,
  },
}

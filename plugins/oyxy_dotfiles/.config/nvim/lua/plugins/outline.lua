return {
  {
    "hedyhli/outline.nvim",
    opts = function(_, opts)
      opts = opts or {}
      opts.outline_window = vim.tbl_deep_extend("force", opts.outline_window or {}, {
        position = "left",
        width = 22,
        relative_width = true,
        auto_close = false,
        auto_jump = false,
        show_numbers = false,
        show_relative_numbers = false,
        show_cursorline = true,
      })

      opts.outline_items = vim.tbl_deep_extend("force", opts.outline_items or {}, {
        show_symbol_details = true,
        show_symbol_lineno = false,
        highlight_hovered_item = true,
        auto_set_cursor = true,
        auto_update_events = {
          follow = { "CursorMoved", "CursorMovedI", "WinEnter", "BufEnter" },
          items = { "InsertLeave", "WinEnter", "BufEnter", "BufWritePost", "TextChanged", "TextChangedI" },
        },
      })

      opts.preview_window = vim.tbl_deep_extend("force", opts.preview_window or {}, {
        live = true,
        auto_preview = false,
        width = 45,
        min_width = 35,
        relative_width = true,
      })

      opts.symbol_folding = vim.tbl_deep_extend("force", opts.symbol_folding or {}, {
        autofold_depth = false,
        auto_unfold = { hovered = true, only = true },
      })

      opts.providers = vim.tbl_deep_extend("force", opts.providers or {}, {
        priority = { "lsp", "markdown", "man" },
      })

      return opts
    end,
  },
}

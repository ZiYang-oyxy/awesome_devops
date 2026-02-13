return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_z = {
        {
          "diagnostics",
          sources = { "nvim_diagnostic" },
          sections = { "error" },
          symbols = { error = " " },
          colored = true,
          always_visible = false,
        },
        {
          function()
            return "🪄"
          end,
          cond = function()
            return require("config.autoformat_toggle").is_enabled()
          end,
        },
      }
    end,
  },
}

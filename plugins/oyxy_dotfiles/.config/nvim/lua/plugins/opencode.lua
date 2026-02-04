return {
  {
    "NickvanDyke/opencode.nvim",
    dependencies = {
      -- Recommended for `ask()` and `select()`. Required for `snacks` provider.
      -- Loads `snacks.nvim` types for configuration intellisense.
      { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    },
    config = function()
      require("config.opencode").setup()
    end,
  },
}

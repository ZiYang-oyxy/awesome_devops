return {
  {
    "folke/snacks.nvim",
    opts = require("config.snacks").opts,
    config = function(_, opts)
      require("config.snacks").setup(opts)
    end,
  },
}

return {
  {
    "hamidi-dev/kaleidosearch.nvim",
    dependencies = {
      "stevearc/dressing.nvim", -- optional for nice input
    },
    config = function()
      require("config.kaleidosearch").setup()
    end,
  },
}

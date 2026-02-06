return {
  {
    "hamidi-dev/kaleidosearch.nvim",
    config = function()
      require("config.kaleidosearch").setup({
        regex_mode = true,
      })
    end,
  },
}

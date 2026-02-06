return {
  {
    "hamidi-dev/kaleidosearch.nvim",
    enabled = false,
    config = function()
      require("config.kaleidosearch").setup({
        regex_mode = true,
      })
    end,
  },
}

return {
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        indicator = {
          style = "underline",
        },
      },
    },
    config = function(_, opts)
      require("config.bufferline").setup(opts)
    end,
  },
}

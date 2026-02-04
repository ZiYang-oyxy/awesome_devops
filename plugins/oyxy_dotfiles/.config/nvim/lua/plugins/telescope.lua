return {
  {
    "nvim-telescope/telescope.nvim",
    config = function()
      require("config.telescope").setup()
    end,
    keys = {
      { "<leader>ss", false },
    },
  },
}

return {
  {
    "nvim-telescope/telescope.nvim",
    enabled = false,
    config = function()
      require("config.telescope").setup()
    end,
    keys = {
      { "<leader>ss", false },
    },
  },
}

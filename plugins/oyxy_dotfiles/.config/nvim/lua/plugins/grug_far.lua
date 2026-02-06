return {
  {
    "MagicDuck/grug-far.nvim",
    config = function(_, opts)
      require("config.grug_far").setup(opts)
    end,
    keys = {
      { "<leader>sr", false, mode = { "n", "x" } },
      {
        "<leader>r",
        function()
          require("config.grug_far").open()
        end,
        mode = { "n", "x" },
        desc = "Search and Replace",
      },
    },
  },
}

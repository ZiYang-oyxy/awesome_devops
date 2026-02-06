return {
  {
    "nvim-telescope/telescope.nvim",
    -- enabled = false,
    config = function()
      require("config.telescope").setup()
    end,
    keys = {
      {
        "<C-p>",
        function()
          require("config.telescope").toggle_oldfiles()
        end,
        desc = "Toggle Recent",
      },
      { "<leader>ss", false },
    },
  },
}

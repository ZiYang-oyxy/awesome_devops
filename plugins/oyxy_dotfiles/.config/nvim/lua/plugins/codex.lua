return {
  {
    dir = "/Volumes/code/codex.nvim",
    opts = {
      panel = true,
      width = 0.5,
      border = "rounded",
      cmd = { "codex", "-m", "gpt-5.3-codex", "-c", 'model_reasoning_effort="medium"' },
    },
    config = function(_, opts)
      require("codex").setup(opts)
    end,
  },
}

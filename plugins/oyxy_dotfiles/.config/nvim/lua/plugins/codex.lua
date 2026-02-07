return {
  {
    "rhart92/codex.nvim",
    opts = {
      split = "vertical",
      size = 0.3,
      float = {
        width = 0.6,
        height = 0.6,
        border = "rounded",
        row = nil,
        col = nil,
        title = "Codex",
      },
      codex_cmd = { "codex", "-m", "gpt-5.3-codex", "-c", 'model_reasoning_effort="medium"' },
      focus_after_send = false,
      log_level = "warn",
      autostart = false,
    },
    config = function(_, opts)
      require("codex").setup(opts)
    end,
  },
}

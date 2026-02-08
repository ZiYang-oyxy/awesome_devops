return {
  {
    dir = "~/code/vim-mark.nvim",
    main = "mark",
    lazy = false,
    opts = {
      search_global_progress = true,
      mark_only = true,
      auto_save = true,
      auto_load = false,
      ui = {
        enhanced_picker = false,
        float_list = true,
      },
      preset = "none",
    },
  },
}

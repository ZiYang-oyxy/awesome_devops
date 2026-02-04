---@diagnostic disable: undefined-global

return {
  picker = {
    sources = {
      explorer = {
        config = function(opts)
          if opts.cwd == nil or opts.cwd == "" then
            local bufname = vim.api.nvim_buf_get_name(0)
            if bufname == "" then
              opts.cwd = vim.loop.cwd()
            else
              opts.cwd = vim.fn.fnamemodify(bufname, ":p:h")
            end
          end
          return opts
        end,
        layout = { layout = { position = "right" } },
        win = {
          list = {
            keys = {
              ["o"] = "confirm",
            },
          },
        },
        on_show = function(picker)
          picker.title = vim.fn.fnamemodify(picker:cwd(), ":p")
          picker:update_titles()
        end,
      },
    },
  },
}

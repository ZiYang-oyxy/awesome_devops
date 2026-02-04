---@diagnostic disable: undefined-global

return {
  picker = {
    sources = {
      explorer = {
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

local M = {}

function M.open()
  local ok, grug = pcall(require, "grug-far")
  if not ok then
    return
  end

  local current_file = vim.bo.buftype == "" and vim.fn.expand("%")
  if current_file == "" then
    current_file = nil
  end
  grug.open({
    transient = true,
    prefills = {
      paths = current_file and vim.fn.fnameescape(current_file) or nil,
    },
  })
end

function M.setup(_)
  -- Keep setup entrypoint for plugin-spec consistency.
end

return M

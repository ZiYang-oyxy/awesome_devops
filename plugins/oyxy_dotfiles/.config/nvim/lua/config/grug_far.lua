local M = {}

function M.open()
  local ok, grug = pcall(require, "grug-far")
  if not ok then
    return
  end

  local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
  grug.open({
    transient = true,
    prefills = {
      filesFilter = ext and ext ~= "" and "*." .. ext or nil,
    },
  })
end

function M.setup(_)
  -- Keep setup entrypoint for plugin-spec consistency.
end

return M

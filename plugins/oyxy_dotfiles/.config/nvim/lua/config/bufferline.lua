local M = {}

function M.setup(opts)
  local ok, bufferline = pcall(require, "bufferline")
  if not ok then
    return
  end

  bufferline.setup(opts or {})
end

return M

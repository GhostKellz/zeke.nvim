local M = {}

local defaults = {
  cmd = 'zeke',
  auto_reload = true,
  keymaps = {
    chat = '<leader>zc',
    edit = '<leader>ze',
    explain = '<leader>zx',
    create = '<leader>zf',
    analyze = '<leader>za'
  }
}

local config = defaults

function M.setup(opts)
  config = vim.tbl_deep_extend('force', defaults, opts or {})
end

function M.get()
  return config
end

return M
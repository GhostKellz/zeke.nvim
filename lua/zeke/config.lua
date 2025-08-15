local M = {}

local defaults = {
  cmd = 'zeke',
  binary_path = './zig-out/bin/zeke_nvim',
  auto_reload = true,
  show_errors_as_notifications = true,
  default_model = 'gpt-3.5-turbo',
  timeout_ms = 30000,
  keymaps = {
    chat = '<leader>zc',
    edit = '<leader>ze',
    explain = '<leader>zx',
    create = '<leader>zf',
    analyze = '<leader>za',
    models = '<leader>zm',
    tasks = '<leader>zt',
    chat_stream = '<leader>zs'
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
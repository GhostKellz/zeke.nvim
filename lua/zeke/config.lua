local M = {}

local default_config = {
  api_keys = {},
  default_provider = 'openai',
  default_model = 'gpt-4',
  temperature = 0.7,
  max_tokens = 2048,
  stream = false,
  auto_reload = true,
  keymaps = {
    chat = '<leader>zc',
    edit = '<leader>ze',
    explain = '<leader>zx',
    create = '<leader>zn',
    analyze = '<leader>za',
    models = '<leader>zm',
    tasks = '<leader>zt',
    chat_stream = '<leader>zs',
  },
  server = {
    host = '127.0.0.1',
    port = 7777,
    auto_start = true,
  },
}

local config = vim.deepcopy(default_config)

function M.setup(opts)
  config = vim.tbl_deep_extend('force', config, opts or {})

  if vim.env.OPENAI_API_KEY then
    config.api_keys.openai = vim.env.OPENAI_API_KEY
  end
  if vim.env.ANTHROPIC_API_KEY then
    config.api_keys.claude = vim.env.ANTHROPIC_API_KEY
  end
  if vim.env.GITHUB_TOKEN then
    config.api_keys.copilot = vim.env.GITHUB_TOKEN
  end
end

function M.get()
  return config
end

function M.set(key, value)
  local keys = vim.split(key, '.', { plain = true })
  local current = config

  for i = 1, #keys - 1 do
    if type(current[keys[i]]) ~= 'table' then
      current[keys[i]] = {}
    end
    current = current[keys[i]]
  end

  current[keys[#keys]] = value
end

return M
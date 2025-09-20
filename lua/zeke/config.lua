local M = {}

local default_config = {
  api_keys = {},
  default_provider = 'ghostllm',
  default_model = 'auto',
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
    toggle_chat = '<leader>zt',
    provider_status = '<leader>zp',
  },
  server = {
    host = '127.0.0.1',
    port = 7777,
    auto_start = true,
  },
  -- GhostLLM proxy configuration
  ghostllm = {
    base_url = 'http://localhost:8080',
    session_token = nil, -- Will be set from environment or auth
    enable_consent = true,
    auto_approve_read = true,
    auto_approve_write = false,
    fallback_providers = {'openai', 'claude', 'ollama'},
  },
  -- Zeke CLI integration
  zeke_cli = {
    auto_discover = true,
    websocket_port = 8081,
    timeout_ms = 5000,
    auto_start = true,
    session_dir = vim.fn.expand('~/.zeke/sessions'),
  },
  -- Provider routing preferences
  routing = {
    code_completion = 'ollama:deepseek-coder',
    reasoning = 'claude-3-sonnet',
    quick_tasks = 'gpt-3.5-turbo',
    fallback = {'ollama:llama3', 'gpt-3.5-turbo', 'claude-3-haiku'},
  },
  -- Cost and security settings
  security = {
    enable_consent = true,
    auto_approve_read = true,
    auto_approve_write = false,
    daily_limit_usd = 5.00,
    warn_threshold_usd = 4.00,
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
  if vim.env.GHOSTLLM_SESSION_TOKEN then
    config.ghostllm.session_token = vim.env.GHOSTLLM_SESSION_TOKEN
  end
  if vim.env.GHOSTLLM_URL then
    config.ghostllm.base_url = vim.env.GHOSTLLM_URL
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
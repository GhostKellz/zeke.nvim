--[[
  zeke.nvim Enhanced Configuration

  Supports:
  - Multiple Ollama hosts (localhost + remote IPs)
  - LiteLLM proxy servers
  - GitHub Copilot Pro
  - All 7+ AI providers
--]]

local M = {}

M.defaults = {
  -- Model selection
  default_model = 'smart',  -- 'smart', 'fast', 'balanced', or specific model ID

  -- Ollama hosts (localhost + remote)
  ollama_hosts = {
    localhost = "http://localhost:11434",
    -- Add your remote Ollama servers:
    -- server1 = "http://192.168.1.100:11434",
    -- workstation = "http://10.0.0.50:11434",
  },

  -- LiteLLM proxy servers
  litellm_hosts = {
    localhost = "http://localhost:4000",
    -- Add your LiteLLM proxies:
    -- production = "http://192.168.1.200:4000",
  },

  -- GitHub Copilot Pro
  copilot = {
    enabled = true,
    -- Models available via Copilot Pro subscription
    available_models = {
      "copilot-gpt-5-codex",
      "copilot-grok-fast",
      "copilot-sonnet-4.5",
      "copilot-gpt-5",
    },
  },

  -- Provider configuration
  providers = {
    claude = { enabled = true },
    openai = { enabled = true },
    xai = { enabled = true },
    google = { enabled = true },
    azure = { enabled = false },  -- Requires setup
    ollama = { enabled = true, default_host = "localhost" },
    copilot = { enabled = true },
    litellm = { enabled = true, default_host = "localhost" },
  },

  -- Model cycling behavior
  cycling = {
    -- Models to include in Tab cycling
    include_aliases = false,  -- Don't cycle through 'smart', 'fast' aliases
    include_copilot_pro = true,
    include_local = true,
    providers = { "claude", "openai", "xai", "google", "ollama", "copilot", "litellm" },
  },

  -- UI settings
  ui = {
    model_picker_height = 20,
    show_model_info = true,
    show_context_window = true,
    icons = true,
  },

  -- Keymaps
  keymaps = {
    enabled = true,
    prefix = '<leader>z',

    -- Main commands
    code = '<leader>zc',           -- :ZekeCode (main agent interface)
    chat = '<leader>zz',           -- Quick chat
    explain = '<leader>zx',        -- Explain code
    edit = '<leader>ze',           -- Edit with AI

    -- Model management
    model_picker = '<leader>zm',   -- Show model picker
    model_next = '<Tab>',          -- Cycle next model (in ZekeCode)
    model_prev = '<S-Tab>',        -- Cycle previous model
    model_info = '<leader>zi',     -- Show current model info

    -- Quick switches
    quick_smart = '<leader>zms',   -- Quick switch to 'smart'
    quick_fast = '<leader>zmf',    -- Quick switch to 'fast'
    quick_local = '<leader>zml',   -- Quick switch to local (Ollama)
  },

  -- Logging
  logger = {
    level = "INFO",
    file = "~/.cache/nvim/zeke.log",
    show_timestamp = true,
  },

  -- Selection tracking
  track_selection = true,
  selection = {
    debounce_ms = 100,
    visual_demotion_delay_ms = 50,
  },

  -- Diff management
  diff = {
    keep_terminal_focus = false,
    open_in_new_tab = false,
    auto_close_on_accept = true,
    show_diff_stats = true,
    vertical_split = true,
  },

  -- Auto-reload files after AI edits
  auto_reload = true,

  -- Future: Ghostlang integration
  ghostlang = {
    auto_detect = true,
    script_dirs = { ".zeke", "scripts" },
    fallback_to_lua = true,
  },
}

-- Current configuration (merged with user options)
M.options = {}

function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, opts)

  -- Validate Ollama hosts
  for name, host in pairs(M.options.ollama_hosts) do
    if not host:match("^https?://") then
      vim.notify(
        string.format("Invalid Ollama host '%s': %s (must start with http:// or https://)", name, host),
        vim.log.levels.WARN
      )
    end
  end

  -- Validate LiteLLM hosts
  for name, host in pairs(M.options.litellm_hosts) do
    if not host:match("^https?://") then
      vim.notify(
        string.format("Invalid LiteLLM host '%s': %s (must start with http:// or https://)", name, host),
        vim.log.levels.WARN
      )
    end
  end

  return M.options
end

-- Get Ollama host by name
function M.get_ollama_host(name)
  name = name or M.options.providers.ollama.default_host
  return M.options.ollama_hosts[name]
end

-- Get LiteLLM host by name
function M.get_litellm_host(name)
  name = name or M.options.providers.litellm.default_host
  return M.options.litellm_hosts[name]
end

-- List all configured Ollama hosts
function M.list_ollama_hosts()
  local hosts = {}
  for name, url in pairs(M.options.ollama_hosts) do
    table.insert(hosts, { name = name, url = url })
  end
  return hosts
end

-- List all configured LiteLLM hosts
function M.list_litellm_hosts()
  local hosts = {}
  for name, url in pairs(M.options.litellm_hosts) do
    table.insert(hosts, { name = name, url = url })
  end
  return hosts
end

return M

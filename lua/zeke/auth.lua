local M = {}

local api = vim.api
local config = require('zeke.config')

-- UI state
local auth_buf = nil
local auth_win = nil
local current_selection = 1

-- Authentication providers with their capabilities
local PROVIDERS = {
  {
    name = 'github',
    display_name = '🐙 GitHub (Copilot Pro)',
    description = 'OAuth sign-in for GitHub Copilot Pro subscription',
    auth_type = 'oauth',
    features = {'copilot', 'code-completion', 'pro-features'},
    icon = '🐙',
    setup_required = false,
  },
  {
    name = 'google',
    display_name = '🌐 Google (Vertex AI, Gemini, Grok)',
    description = 'OAuth sign-in for Google Cloud AI services',
    auth_type = 'oauth',
    features = {'vertex-ai', 'gemini', 'grok', 'cloud-ai'},
    icon = '🌐',
    setup_required = false,
  },
  {
    name = 'openai',
    display_name = '🧠 OpenAI (ChatGPT API)',
    description = 'API key authentication for OpenAI services',
    auth_type = 'api_key',
    features = {'gpt-4', 'gpt-3.5-turbo', 'dalle', 'whisper'},
    icon = '🧠',
    setup_required = true,
  },
  {
    name = 'anthropic',
    display_name = '🤖 Anthropic (Claude API)',
    description = 'API key authentication for Claude models',
    auth_type = 'api_key',
    features = {'claude-3-sonnet', 'claude-3-haiku', 'claude-3-opus'},
    icon = '🤖',
    setup_required = true,
  },
  {
    name = 'ollama',
    display_name = '🏠 Ollama (Local Models)',
    description = 'Auto-detect local Ollama installation',
    auth_type = 'auto_detect',
    features = {'local-models', 'privacy', 'offline'},
    icon = '🏠',
    setup_required = false,
  },
  {
    name = 'ghostllm',
    display_name = '🌐 GhostLLM (Unified Proxy)',
    description = 'Connect to GhostLLM proxy server',
    auth_type = 'proxy',
    features = {'unified-api', 'intelligent-routing', 'cost-optimization'},
    icon = '🌐',
    setup_required = true,
  },
}

-- Authentication status cache
local auth_status = {}

-- Initialize authentication system
function M.setup()
  -- Load authentication status
  M.refresh_auth_status()

  -- Auto-detect Ollama on startup
  vim.defer_fn(function()
    M.auto_detect_ollama()
  end, 1000)
end

-- Show authentication management UI
function M.show_auth_ui()
  M.refresh_auth_status()
  M.create_auth_buffer()
  M.create_auth_window()
  M.setup_keymaps()
  M.render_content()
end

-- Create authentication buffer
function M.create_auth_buffer()
  auth_buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  api.nvim_buf_set_option(auth_buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(auth_buf, 'filetype', 'zeke-auth')
  api.nvim_buf_set_option(auth_buf, 'modifiable', false)
end

-- Create floating window
function M.create_auth_window()
  local width = math.min(90, vim.o.columns - 4)
  local height = math.min(35, vim.o.lines - 4)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' 🔐 Zeke Authentication Center ',
    title_pos = 'center',
  }

  auth_win = api.nvim_open_win(auth_buf, true, win_config)

  -- Set window options
  api.nvim_win_set_option(auth_win, 'winhl', 'Normal:NormalFloat,FloatBorder:FloatBorder')
  api.nvim_win_set_option(auth_win, 'cursorline', true)
end

-- Setup keymaps
function M.setup_keymaps()
  local keymaps = {
    ['<CR>'] = M.authenticate_provider,
    ['a'] = M.authenticate_provider,
    ['d'] = M.disconnect_provider,
    ['r'] = M.refresh_auth_status,
    ['s'] = M.show_provider_status,
    ['t'] = M.test_provider_connection,
    ['c'] = M.clear_provider_cache,
    ['j'] = M.move_down,
    ['k'] = M.move_up,
    ['<Down>'] = M.move_down,
    ['<Up>'] = M.move_up,
    ['q'] = M.close_auth_ui,
    ['<Esc>'] = M.close_auth_ui,
  }

  for key, callback in pairs(keymaps) do
    api.nvim_buf_set_keymap(auth_buf, 'n', key, '', {
      callback = callback,
      noremap = true,
      silent = true,
    })
  end
end

-- Render authentication UI content
function M.render_content()
  local lines = {}

  -- Header
  table.insert(lines, '╭─────────────────────────────────────────────────────────────────────────────────────╮')
  table.insert(lines, '│                             🔐 Zeke Authentication Center                             │')
  table.insert(lines, '╰─────────────────────────────────────────────────────────────────────────────────────╯')
  table.insert(lines, '')

  -- Authentication overview
  local authenticated_count = 0
  for _, provider in ipairs(PROVIDERS) do
    if auth_status[provider.name] and auth_status[provider.name].authenticated then
      authenticated_count = authenticated_count + 1
    end
  end

  table.insert(lines, string.format('📊 Authentication Status: %d/%d providers authenticated',
    authenticated_count, #PROVIDERS))
  table.insert(lines, '')

  -- Provider list
  table.insert(lines, '🔗 Available Authentication Providers:')
  table.insert(lines, '')

  for i, provider in ipairs(PROVIDERS) do
    local status = auth_status[provider.name] or { authenticated = false }
    local is_selected = i == current_selection

    -- Selection indicator
    local prefix = is_selected and '▶ ' or '  '

    -- Authentication status
    local auth_icon = status.authenticated and '✅' or '❌'

    -- Provider line
    local line = string.format('%s%s %s %s',
      prefix,
      auth_icon,
      provider.icon,
      provider.display_name
    )

    table.insert(lines, line)

    -- Provider details (for selected item)
    if is_selected then
      table.insert(lines, '    📝 ' .. provider.description)
      table.insert(lines, '    🏷️  Features: ' .. table.concat(provider.features, ', '))
      table.insert(lines, '    🔧 Auth Type: ' .. provider.auth_type)

      if status.authenticated then
        if status.user_info then
          table.insert(lines, '    👤 User: ' .. status.user_info)
        end
        if status.last_used then
          table.insert(lines, '    🕒 Last Used: ' .. status.last_used)
        end
        if status.expires_at then
          table.insert(lines, '    ⏰ Expires: ' .. status.expires_at)
        end
      else
        if provider.setup_required then
          table.insert(lines, '    ⚠️  Setup Required: ' .. M.get_setup_instructions(provider.name))
        end
      end

      table.insert(lines, '')
    end
  end

  -- Controls
  table.insert(lines, '')
  table.insert(lines, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  table.insert(lines, '')
  table.insert(lines, '🎮 Controls:')
  table.insert(lines, '  [↑/↓] Navigate       [Enter/a] Authenticate    [d] Disconnect')
  table.insert(lines, '  [s] Show Status      [t] Test Connection      [r] Refresh')
  table.insert(lines, '  [c] Clear Cache      [q/Esc] Close')

  -- Update buffer
  api.nvim_buf_set_option(auth_buf, 'modifiable', true)
  api.nvim_buf_set_lines(auth_buf, 0, -1, false, lines)
  api.nvim_buf_set_option(auth_buf, 'modifiable', false)

  -- Position cursor on selected line
  local cursor_line = 8 + (current_selection - 1) * 1  -- Adjust based on content structure
  if current_selection > 1 then
    cursor_line = cursor_line + (current_selection - 1) * 6  -- Account for expanded details
  end
  api.nvim_win_set_cursor(auth_win, {cursor_line, 0})
end

-- Navigation functions
function M.move_down()
  if current_selection < #PROVIDERS then
    current_selection = current_selection + 1
    M.render_content()
  end
end

function M.move_up()
  if current_selection > 1 then
    current_selection = current_selection - 1
    M.render_content()
  end
end

-- Authentication functions
function M.authenticate_provider()
  local provider = PROVIDERS[current_selection]
  if not provider then return end

  M.close_auth_ui()

  if provider.auth_type == 'oauth' then
    M.oauth_authenticate(provider.name)
  elseif provider.auth_type == 'api_key' then
    M.api_key_authenticate(provider.name)
  elseif provider.auth_type == 'auto_detect' then
    M.auto_detect_authenticate(provider.name)
  elseif provider.auth_type == 'proxy' then
    M.proxy_authenticate(provider.name)
  end
end

function M.oauth_authenticate(provider_name)
  vim.notify('🔐 Starting ' .. provider_name .. ' OAuth authentication...', vim.log.levels.INFO)

  -- Use Rust backend for OAuth flow
  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')

    if provider_name == 'github' then
      return zeke_nvim.authenticate_github()
    elseif provider_name == 'google' then
      return zeke_nvim.authenticate_google()
    end
  end)

  if ok and result then
    vim.notify('✅ ' .. provider_name .. ' authentication successful!', vim.log.levels.INFO)
    M.refresh_auth_status()
  else
    vim.notify('❌ ' .. provider_name .. ' authentication failed: ' .. tostring(result), vim.log.levels.ERROR)
  end
end

function M.api_key_authenticate(provider_name)
  local prompt_text = provider_name == 'openai' and 'OpenAI API Key:' or 'Anthropic API Key:'

  vim.ui.input({
    prompt = prompt_text .. ' ',
    completion = 'file',
  }, function(api_key)
    if not api_key or api_key == '' then
      return
    end

    -- For OpenAI, also ask for organization (optional)
    if provider_name == 'openai' then
      vim.ui.input({
        prompt = 'OpenAI Organization (optional): ',
      }, function(organization)
        M.complete_api_key_auth(provider_name, api_key, organization)
      end)
    else
      M.complete_api_key_auth(provider_name, api_key)
    end
  end)
end

function M.complete_api_key_auth(provider_name, api_key, organization)
  vim.notify('🔐 Validating ' .. provider_name .. ' API key...', vim.log.levels.INFO)

  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')

    if provider_name == 'openai' then
      return zeke_nvim.authenticate_openai(api_key, organization)
    elseif provider_name == 'anthropic' then
      return zeke_nvim.authenticate_anthropic(api_key)
    end
  end)

  if ok and result then
    vim.notify('✅ ' .. provider_name .. ' API key validated successfully!', vim.log.levels.INFO)
    M.refresh_auth_status()
  else
    vim.notify('❌ Invalid ' .. provider_name .. ' API key: ' .. tostring(result), vim.log.levels.ERROR)
  end
end

function M.auto_detect_authenticate(provider_name)
  if provider_name == 'ollama' then
    M.auto_detect_ollama()
  end
end

function M.proxy_authenticate(provider_name)
  if provider_name == 'ghostllm' then
    vim.ui.input({
      prompt = 'GhostLLM Base URL (default: http://localhost:8080): ',
      default = 'http://localhost:8080',
    }, function(base_url)
      if not base_url or base_url == '' then
        base_url = 'http://localhost:8080'
      end

      vim.ui.input({
        prompt = 'GhostLLM Session Token (optional): ',
      }, function(session_token)
        M.complete_proxy_auth(provider_name, base_url, session_token)
      end)
    end)
  end
end

function M.complete_proxy_auth(provider_name, base_url, session_token)
  vim.notify('🔐 Connecting to ' .. provider_name .. '...', vim.log.levels.INFO)

  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.authenticate_ghostllm(base_url, session_token)
  end)

  if ok and result then
    vim.notify('✅ ' .. provider_name .. ' connection successful!', vim.log.levels.INFO)
    M.refresh_auth_status()
  else
    vim.notify('❌ ' .. provider_name .. ' connection failed: ' .. tostring(result), vim.log.levels.ERROR)
  end
end

function M.auto_detect_ollama()
  vim.notify('🔍 Auto-detecting Ollama...', vim.log.levels.INFO)

  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.detect_ollama()
  end)

  if ok and result then
    vim.notify('✅ Ollama detected and configured!', vim.log.levels.INFO)
    M.refresh_auth_status()
  else
    vim.notify('❌ Ollama not found. Is it running?', vim.log.levels.WARN)
  end
end

-- Other provider functions
function M.disconnect_provider()
  local provider = PROVIDERS[current_selection]
  if not provider then return end

  local confirmation = vim.fn.confirm(
    'Disconnect from ' .. provider.display_name .. '?',
    '&Yes\n&No',
    2
  )

  if confirmation == 1 then
    -- Clear authentication for provider
    local ok = pcall(function()
      local zeke_nvim = require('zeke_nvim')
      zeke_nvim.clear_authentication(provider.name)
    end)

    if ok then
      vim.notify('🔌 Disconnected from ' .. provider.display_name, vim.log.levels.INFO)
      M.refresh_auth_status()
      M.render_content()
    end
  end
end

function M.test_provider_connection()
  local provider = PROVIDERS[current_selection]
  if not provider then return end

  vim.notify('🧪 Testing ' .. provider.display_name .. ' connection...', vim.log.levels.INFO)

  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.test_provider_auth(provider.name)
  end)

  if ok and result then
    vim.notify('✅ ' .. provider.display_name .. ' connection test passed!', vim.log.levels.INFO)
  else
    vim.notify('❌ ' .. provider.display_name .. ' connection test failed: ' .. tostring(result), vim.log.levels.ERROR)
  end
end

function M.show_provider_status()
  local provider = PROVIDERS[current_selection]
  if not provider then return end

  local status = auth_status[provider.name] or {}
  local lines = {
    'Authentication status for ' .. provider.display_name .. ':',
    '',
    '🔗 Authenticated: ' .. (status.authenticated and 'Yes' or 'No'),
  }

  if status.user_info then
    table.insert(lines, '👤 User: ' .. status.user_info)
  end

  if status.features then
    table.insert(lines, '🏷️  Available Features:')
    for _, feature in ipairs(status.features) do
      table.insert(lines, '  • ' .. feature)
    end
  end

  if status.usage then
    table.insert(lines, '')
    table.insert(lines, '📊 Usage Statistics:')
    table.insert(lines, '  • Daily: ' .. (status.usage.daily or 0))
    table.insert(lines, '  • Monthly: ' .. (status.usage.monthly or 0))
  end

  M.show_info_popup('Provider Status - ' .. provider.display_name, lines)
end

function M.clear_provider_cache()
  local provider = PROVIDERS[current_selection]
  if not provider then return end

  local ok = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    zeke_nvim.clear_provider_cache(provider.name)
  end)

  if ok then
    vim.notify('🗑️  Cleared cache for ' .. provider.display_name, vim.log.levels.INFO)
  end
end

-- Helper functions
function M.refresh_auth_status()
  local ok, status = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.get_auth_status()
  end)

  if ok and status then
    auth_status = status
  else
    auth_status = {}
  end
end

function M.get_setup_instructions(provider_name)
  local instructions = {
    openai = 'Get API key from platform.openai.com',
    anthropic = 'Get API key from console.anthropic.com',
    ghostllm = 'Start GhostLLM proxy server',
  }

  return instructions[provider_name] or 'See documentation'
end

function M.show_info_popup(title, lines)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.min(70, vim.o.columns - 4)
  local height = math.min(#lines + 4, vim.o.lines - 4)

  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })

  -- Close on any key
  api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<cmd>close<cr>', { noremap = true, silent = true })
  api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<cr>', { noremap = true, silent = true })
  api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>close<cr>', { noremap = true, silent = true })
end

function M.close_auth_ui()
  if auth_win and api.nvim_win_is_valid(auth_win) then
    api.nvim_win_close(auth_win, true)
    auth_win = nil
  end
  if auth_buf and api.nvim_buf_is_valid(auth_buf) then
    api.nvim_buf_delete(auth_buf, { force = true })
    auth_buf = nil
  end
end

-- Public API functions
function M.is_authenticated(provider_name)
  return auth_status[provider_name] and auth_status[provider_name].authenticated or false
end

function M.get_auth_info(provider_name)
  return auth_status[provider_name]
end

function M.get_available_providers()
  local available = {}
  for _, provider in ipairs(PROVIDERS) do
    if M.is_authenticated(provider.name) then
      table.insert(available, provider.name)
    end
  end
  return available
end

-- Quick authentication commands
function M.quick_github_auth()
  M.oauth_authenticate('github')
end

function M.quick_google_auth()
  M.oauth_authenticate('google')
end

function M.quick_openai_auth(api_key, organization)
  if api_key then
    M.complete_api_key_auth('openai', api_key, organization)
  else
    M.api_key_authenticate('openai')
  end
end

function M.quick_anthropic_auth(api_key)
  if api_key then
    M.complete_api_key_auth('anthropic', api_key)
  else
    M.api_key_authenticate('anthropic')
  end
end

-- Cleanup
function M.cleanup()
  M.close_auth_ui()
  auth_status = {}
end

return M
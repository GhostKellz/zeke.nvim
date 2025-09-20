local M = {}

local api = vim.api
local config = require('zeke.config')

-- UI state
local providers_buf = nil
local providers_win = nil
local current_selection = 1

-- Provider status cache
local provider_status = {}
local cost_tracking = {}

-- Available providers with their capabilities
local PROVIDERS = {
  {
    name = 'ghostllm',
    display_name = '🌐 GhostLLM Proxy',
    description = 'Unified proxy with intelligent routing',
    capabilities = {'chat', 'code', 'streaming', 'multi-model', 'cost-optimization'},
    icon = '🌐',
    default_models = {'auto', 'claude-3-sonnet', 'gpt-4', 'llama3:8b'},
  },
  {
    name = 'claude',
    display_name = '🤖 Claude (Anthropic)',
    description = 'Advanced reasoning and code assistance',
    capabilities = {'chat', 'code', 'reasoning', 'long-context'},
    icon = '🤖',
    default_models = {'claude-3-sonnet', 'claude-3-haiku', 'claude-3-opus'},
  },
  {
    name = 'openai',
    display_name = '🧠 OpenAI GPT',
    description = 'General purpose AI with broad knowledge',
    capabilities = {'chat', 'code', 'reasoning', 'function-calling'},
    icon = '🧠',
    default_models = {'gpt-4', 'gpt-4-turbo', 'gpt-3.5-turbo'},
  },
  {
    name = 'ollama',
    display_name = '🏠 Ollama (Local)',
    description = 'Privacy-focused local models',
    capabilities = {'chat', 'code', 'offline', 'privacy'},
    icon = '🏠',
    default_models = {'llama3:8b', 'deepseek-coder:6.7b', 'codellama:7b'},
  },
  {
    name = 'copilot',
    display_name = '🚀 GitHub Copilot',
    description = 'Code-focused AI from Microsoft',
    capabilities = {'code', 'completion', 'github-integration'},
    icon = '🚀',
    default_models = {'copilot'},
  },
}

-- Initialize provider UI
function M.setup()
  -- Refresh provider status periodically
  vim.defer_fn(function()
    M.refresh_provider_status()
  end, 1000)
end

-- Show provider management UI
function M.show_provider_ui()
  M.refresh_provider_status()
  M.create_provider_buffer()
  M.create_provider_window()
  M.setup_keymaps()
  M.render_content()
end

-- Create provider buffer
function M.create_provider_buffer()
  providers_buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  api.nvim_buf_set_option(providers_buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(providers_buf, 'filetype', 'zeke-providers')
  api.nvim_buf_set_option(providers_buf, 'modifiable', false)
end

-- Create floating window
function M.create_provider_window()
  local width = math.min(100, vim.o.columns - 4)
  local height = math.min(40, vim.o.lines - 4)

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
    title = ' 🎯 Zeke Provider Management ',
    title_pos = 'center',
  }

  providers_win = api.nvim_open_win(providers_buf, true, win_config)

  -- Set window options
  api.nvim_win_set_option(providers_win, 'winhl', 'Normal:NormalFloat,FloatBorder:FloatBorder')
  api.nvim_win_set_option(providers_win, 'cursorline', true)
end

-- Setup keymaps
function M.setup_keymaps()
  local keymaps = {
    ['<CR>'] = M.select_provider,
    ['s'] = M.switch_provider,
    ['t'] = M.test_provider,
    ['r'] = M.refresh_provider_status,
    ['m'] = M.show_models,
    ['c'] = M.show_costs,
    ['h'] = M.show_health,
    ['<C-r>'] = M.restart_provider,
    ['j'] = M.move_down,
    ['k'] = M.move_up,
    ['<Down>'] = M.move_down,
    ['<Up>'] = M.move_up,
    ['q'] = M.close_provider_ui,
    ['<Esc>'] = M.close_provider_ui,
  }

  for key, callback in pairs(keymaps) do
    api.nvim_buf_set_keymap(providers_buf, 'n', key, '', {
      callback = callback,
      noremap = true,
      silent = true,
    })
  end
end

-- Render provider UI content
function M.render_content()
  local lines = {}

  -- Header
  table.insert(lines, '╭─────────────────────────────────────────────────────────────────────────────────────────╮')
  table.insert(lines, '│                                🎯 Zeke Provider Management                                 │')
  table.insert(lines, '╰─────────────────────────────────────────────────────────────────────────────────────────╯')
  table.insert(lines, '')

  -- Current provider status
  local current_provider = M.get_current_provider()
  table.insert(lines, '📍 Current Provider: ' .. (current_provider and current_provider.display_name or 'None'))
  table.insert(lines, '')

  -- Provider list
  table.insert(lines, '🔧 Available Providers:')
  table.insert(lines, '')

  for i, provider in ipairs(PROVIDERS) do
    local status = provider_status[provider.name] or { health = 'unknown', latency = 0 }
    local is_current = current_provider and current_provider.name == provider.name
    local is_selected = i == current_selection

    -- Selection indicator
    local prefix = is_selected and '▶ ' or '  '

    -- Current provider indicator
    if is_current then
      prefix = prefix .. '⭐ '
    else
      prefix = prefix .. '   '
    end

    -- Health status
    local health_icon = M.get_health_icon(status.health)

    -- Line content
    local line = string.format('%s%s %s %s',
      prefix,
      health_icon,
      provider.icon,
      provider.display_name
    )

    table.insert(lines, line)

    -- Provider details (for selected item)
    if is_selected then
      table.insert(lines, '    📝 ' .. provider.description)
      table.insert(lines, '    🏷️  Capabilities: ' .. table.concat(provider.capabilities, ', '))

      if status.models then
        table.insert(lines, '    🤖 Models: ' .. table.concat(status.models, ', '))
      end

      if status.latency and status.latency > 0 then
        table.insert(lines, '    ⚡ Latency: ' .. status.latency .. 'ms')
      end

      if cost_tracking[provider.name] then
        local cost = cost_tracking[provider.name]
        table.insert(lines, '    💰 Today: $' .. string.format('%.4f', cost.today))
      end

      table.insert(lines, '')
    end
  end

  -- Controls
  table.insert(lines, '')
  table.insert(lines, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  table.insert(lines, '')
  table.insert(lines, '🎮 Controls:')
  table.insert(lines, '  [↑/↓] Navigate    [Enter] Select Provider    [s] Switch Active')
  table.insert(lines, '  [t] Test Provider [m] Show Models           [c] Show Costs')
  table.insert(lines, '  [h] Health Check  [Ctrl+R] Restart          [r] Refresh')
  table.insert(lines, '  [q/Esc] Close')

  -- Update buffer
  api.nvim_buf_set_option(providers_buf, 'modifiable', true)
  api.nvim_buf_set_lines(providers_buf, 0, -1, false, lines)
  api.nvim_buf_set_option(providers_buf, 'modifiable', false)

  -- Position cursor on selected line
  local cursor_line = 8 + (current_selection - 1) * 1  -- Adjust based on content structure
  if current_selection > 1 then
    cursor_line = cursor_line + (current_selection - 1) * 5  -- Account for expanded details
  end
  api.nvim_win_set_cursor(providers_win, {cursor_line, 0})
end

-- Get health status icon
function M.get_health_icon(health)
  local icons = {
    healthy = '🟢',
    degraded = '🟡',
    unhealthy = '🔴',
    unknown = '⚪',
    testing = '🔄',
  }
  return icons[health] or icons.unknown
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

-- Provider actions
function M.select_provider()
  local provider = PROVIDERS[current_selection]
  if provider then
    M.switch_to_provider(provider.name)
  end
end

function M.switch_provider()
  M.select_provider()
end

function M.test_provider()
  local provider = PROVIDERS[current_selection]
  if provider then
    M.run_provider_test(provider.name)
  end
end

function M.show_models()
  local provider = PROVIDERS[current_selection]
  if provider then
    M.show_provider_models(provider.name)
  end
end

function M.show_costs()
  local provider = PROVIDERS[current_selection]
  if provider then
    M.show_provider_costs(provider.name)
  end
end

function M.show_health()
  local provider = PROVIDERS[current_selection]
  if provider then
    M.show_provider_health(provider.name)
  end
end

function M.restart_provider()
  local provider = PROVIDERS[current_selection]
  if provider then
    M.restart_provider_service(provider.name)
  end
end

-- Provider management functions
function M.switch_to_provider(provider_name)
  -- Use WebSocket client to switch provider
  local websocket = require('zeke.websocket')

  if websocket.is_connected() then
    websocket.switch_provider(provider_name)
  else
    -- Fallback to direct configuration
    config.set('default_provider', provider_name)
    vim.notify('Switched default provider to: ' .. provider_name, vim.log.levels.INFO)
  end

  M.refresh_provider_status()
  M.render_content()
end

function M.run_provider_test(provider_name)
  provider_status[provider_name] = { health = 'testing', latency = 0 }
  M.render_content()

  -- Run async test
  vim.defer_fn(function()
    local start_time = vim.loop.hrtime()

    -- Test the provider with a simple request
    local test_message = "Hello, this is a test message."

    local ok, result = pcall(function()
      local zeke_nvim = require('zeke_nvim')
      return zeke_nvim.test_provider(provider_name, test_message)
    end)

    local end_time = vim.loop.hrtime()
    local latency = math.floor((end_time - start_time) / 1000000)  -- Convert to ms

    if ok and result then
      provider_status[provider_name] = { health = 'healthy', latency = latency }
      vim.notify('✅ ' .. provider_name .. ' test passed (' .. latency .. 'ms)', vim.log.levels.INFO)
    else
      provider_status[provider_name] = { health = 'unhealthy', latency = 0 }
      vim.notify('❌ ' .. provider_name .. ' test failed: ' .. tostring(result), vim.log.levels.ERROR)
    end

    M.render_content()
  end, 100)
end

function M.show_provider_models(provider_name)
  -- Show models in a separate popup
  local models = provider_status[provider_name] and provider_status[provider_name].models or {}

  if #models == 0 then
    vim.notify('No models available for ' .. provider_name, vim.log.levels.WARN)
    return
  end

  local lines = {'Available models for ' .. provider_name .. ':', ''}
  for _, model in ipairs(models) do
    table.insert(lines, '  • ' .. model)
  end

  M.show_info_popup('Models - ' .. provider_name, lines)
end

function M.show_provider_costs(provider_name)
  local cost = cost_tracking[provider_name]

  if not cost then
    vim.notify('No cost data available for ' .. provider_name, vim.log.levels.WARN)
    return
  end

  local lines = {
    'Cost tracking for ' .. provider_name .. ':',
    '',
    '💰 Today: $' .. string.format('%.4f', cost.today),
    '📅 This week: $' .. string.format('%.4f', cost.week),
    '📊 This month: $' .. string.format('%.4f', cost.month),
    '',
    '📈 Recent usage:',
  }

  for _, usage in ipairs(cost.recent or {}) do
    table.insert(lines, '  • ' .. usage.time .. ': $' .. string.format('%.4f', usage.cost))
  end

  M.show_info_popup('Costs - ' .. provider_name, lines)
end

function M.show_provider_health(provider_name)
  local status = provider_status[provider_name] or {}

  local lines = {
    'Health status for ' .. provider_name .. ':',
    '',
    '🩺 Status: ' .. (status.health or 'unknown'),
    '⚡ Latency: ' .. (status.latency or 0) .. 'ms',
    '🔗 Endpoint: ' .. (status.endpoint or 'unknown'),
    '📊 Uptime: ' .. (status.uptime or 'unknown'),
  }

  if status.errors then
    table.insert(lines, '')
    table.insert(lines, '❌ Recent errors:')
    for _, error in ipairs(status.errors) do
      table.insert(lines, '  • ' .. error)
    end
  end

  M.show_info_popup('Health - ' .. provider_name, lines)
end

function M.restart_provider_service(provider_name)
  vim.notify('Restarting ' .. provider_name .. '...', vim.log.levels.INFO)

  -- Implementation depends on provider type
  if provider_name == 'ghostllm' then
    -- Restart GhostLLM proxy
    vim.fn.system('pkill -f ghostllm && ghostllm serve --dev &')
  elseif provider_name == 'ollama' then
    -- Restart Ollama service
    vim.fn.system('systemctl restart ollama || brew services restart ollama')
  end

  vim.defer_fn(function()
    M.refresh_provider_status()
    M.render_content()
  end, 2000)
end

-- Helper functions
function M.show_info_popup(title, lines)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.min(60, vim.o.columns - 4)
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

function M.get_current_provider()
  local cfg = config.get()
  local current_name = cfg.default_provider

  for _, provider in ipairs(PROVIDERS) do
    if provider.name == current_name then
      return provider
    end
  end

  return nil
end

function M.refresh_provider_status()
  -- Get status from Rust backend
  local ok, status = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.get_provider_status()
  end)

  if ok and status then
    provider_status = status.providers or {}
    cost_tracking = status.costs or {}
  end
end

function M.close_provider_ui()
  if providers_win and api.nvim_win_is_valid(providers_win) then
    api.nvim_win_close(providers_win, true)
    providers_win = nil
  end
  if providers_buf and api.nvim_buf_is_valid(providers_buf) then
    api.nvim_buf_delete(providers_buf, { force = true })
    providers_buf = nil
  end
end

-- Cleanup
function M.cleanup()
  M.close_provider_ui()
end

return M
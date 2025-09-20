local M = {}

local api = vim.api
local config = require('zeke.config')
local auth = require('zeke.auth')

-- UI state
local switcher_buf = nil
local switcher_win = nil
local current_selection = 1
local selected_tab = 1 -- 1 = providers, 2 = models

-- Available providers and models cache
local available_providers = {}
local available_models = {}
local current_provider = nil
local current_model = nil

-- Initialize switcher
function M.setup()
  -- Refresh available providers/models
  M.refresh_available_options()
end

-- Show quick switcher UI
function M.show_switcher()
  M.refresh_available_options()
  M.create_switcher_buffer()
  M.create_switcher_window()
  M.setup_keymaps()
  M.render_content()
end

-- Create switcher buffer
function M.create_switcher_buffer()
  switcher_buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  api.nvim_buf_set_option(switcher_buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(switcher_buf, 'filetype', 'zeke-switcher')
  api.nvim_buf_set_option(switcher_buf, 'modifiable', false)
end

-- Create floating window (compact size)
function M.create_switcher_window()
  local width = math.min(60, vim.o.columns - 4)
  local height = math.min(20, vim.o.lines - 4)

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
    title = ' ⚡ Quick Switcher ',
    title_pos = 'center',
  }

  switcher_win = api.nvim_open_win(switcher_buf, true, win_config)

  -- Set window options
  api.nvim_win_set_option(switcher_win, 'winhl', 'Normal:NormalFloat,FloatBorder:FloatBorder')
  api.nvim_win_set_option(switcher_win, 'cursorline', true)
end

-- Setup keymaps
function M.setup_keymaps()
  local keymaps = {
    ['<CR>'] = M.select_item,
    ['<Tab>'] = M.switch_tab,
    ['<S-Tab>'] = M.switch_tab_reverse,
    ['1'] = function() M.set_tab(1) end,
    ['2'] = function() M.set_tab(2) end,
    ['j'] = M.move_down,
    ['k'] = M.move_up,
    ['<Down>'] = M.move_down,
    ['<Up>'] = M.move_up,
    ['q'] = M.close_switcher,
    ['<Esc>'] = M.close_switcher,
    ['r'] = M.refresh_and_render,
  }

  for key, callback in pairs(keymaps) do
    api.nvim_buf_set_keymap(switcher_buf, 'n', key, '', {
      callback = callback,
      noremap = true,
      silent = true,
    })
  end
end

-- Render switcher content
function M.render_content()
  local lines = {}

  -- Header with tabs
  table.insert(lines, '╭──────────────────────────────────────────────────────────╮')
  table.insert(lines, '│                    ⚡ Quick Switcher                     │')
  table.insert(lines, '╰──────────────────────────────────────────────────────────╯')
  table.insert(lines, '')

  -- Tab navigation
  local provider_tab = selected_tab == 1 and '[🔌 Providers]' or ' 🔌 Providers '
  local model_tab = selected_tab == 2 and '[🤖 Models]' or ' 🤖 Models '
  table.insert(lines, '  ' .. provider_tab .. '   ' .. model_tab)
  table.insert(lines, '')

  -- Current status
  table.insert(lines, '📍 Current: ' .. (current_provider or 'None') ..
    ' → ' .. (current_model or 'None'))
  table.insert(lines, '')

  -- Content based on selected tab
  if selected_tab == 1 then
    M.render_providers(lines)
  else
    M.render_models(lines)
  end

  -- Controls
  table.insert(lines, '')
  table.insert(lines, '───────────────────────────────────────────────────────────')
  table.insert(lines, '🎮 [↑/↓] Navigate  [Enter] Select  [Tab] Switch  [r] Refresh')

  -- Update buffer
  api.nvim_buf_set_option(switcher_buf, 'modifiable', true)
  api.nvim_buf_set_lines(switcher_buf, 0, -1, false, lines)
  api.nvim_buf_set_option(switcher_buf, 'modifiable', false)

  -- Position cursor
  local base_line = 9  -- Start of content
  local cursor_line = base_line + current_selection - 1
  api.nvim_win_set_cursor(switcher_win, {math.max(1, cursor_line), 0})
end

-- Render providers tab
function M.render_providers(lines)
  table.insert(lines, '🔌 Available Providers:')
  table.insert(lines, '')

  if #available_providers == 0 then
    table.insert(lines, '  ❌ No authenticated providers found')
    table.insert(lines, '  💡 Run :ZekeAuth to set up providers')
    return
  end

  for i, provider in ipairs(available_providers) do
    local is_selected = i == current_selection and selected_tab == 1
    local is_current = provider.name == current_provider

    -- Selection indicator
    local prefix = is_selected and '▶ ' or '  '

    -- Current indicator
    if is_current then
      prefix = prefix .. '⭐ '
    else
      prefix = prefix .. '   '
    end

    -- Provider line
    local line = string.format('%s%s %s', prefix, provider.icon, provider.display_name)

    if provider.model_count then
      line = line .. string.format(' (%d models)', provider.model_count)
    end

    table.insert(lines, line)
  end
end

-- Render models tab
function M.render_models(lines)
  if not current_provider then
    table.insert(lines, '🤖 Models:')
    table.insert(lines, '')
    table.insert(lines, '  ❌ No provider selected')
    table.insert(lines, '  💡 Switch to Providers tab and select one')
    return
  end

  table.insert(lines, '🤖 Models for ' .. current_provider .. ':')
  table.insert(lines, '')

  local provider_models = available_models[current_provider] or {}

  if #provider_models == 0 then
    table.insert(lines, '  ❌ No models available')
    table.insert(lines, '  🔄 Refreshing models...')
    -- Trigger async model refresh
    M.refresh_models_for_provider(current_provider)
    return
  end

  for i, model in ipairs(provider_models) do
    local is_selected = i == current_selection and selected_tab == 2
    local is_current = model.name == current_model

    -- Selection indicator
    local prefix = is_selected and '▶ ' or '  '

    -- Current indicator
    if is_current then
      prefix = prefix .. '⭐ '
    else
      prefix = prefix .. '   '
    end

    -- Model line
    local line = prefix .. model.name

    if model.description then
      line = line .. ' - ' .. model.description
    end

    if model.capabilities then
      line = line .. ' (' .. table.concat(model.capabilities, ', ') .. ')'
    end

    table.insert(lines, line)
  end
end

-- Navigation functions
function M.move_down()
  local max_selection = selected_tab == 1 and #available_providers or
    #(available_models[current_provider] or {})

  if current_selection < max_selection then
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

function M.switch_tab()
  selected_tab = selected_tab == 1 and 2 or 1
  current_selection = 1
  M.render_content()
end

function M.switch_tab_reverse()
  M.switch_tab()
end

function M.set_tab(tab_num)
  if tab_num >= 1 and tab_num <= 2 then
    selected_tab = tab_num
    current_selection = 1
    M.render_content()
  end
end

-- Selection functions
function M.select_item()
  if selected_tab == 1 then
    M.select_provider()
  else
    M.select_model()
  end
end

function M.select_provider()
  local provider = available_providers[current_selection]
  if not provider then return end

  -- Switch to this provider
  M.switch_to_provider(provider.name)

  -- Switch to models tab to show available models
  selected_tab = 2
  current_selection = 1
  M.render_content()
end

function M.select_model()
  if not current_provider then return end

  local provider_models = available_models[current_provider] or {}
  local model = provider_models[current_selection]
  if not model then return end

  -- Switch to this model
  M.switch_to_model(model.name)

  -- Close switcher after selection
  M.close_switcher()
end

function M.switch_to_provider(provider_name)
  vim.notify('🔌 Switching to provider: ' .. provider_name, vim.log.levels.INFO)

  -- Use WebSocket client to switch provider if connected
  local websocket = require('zeke.websocket')
  if websocket.is_connected() then
    websocket.switch_provider(provider_name)
  else
    -- Fallback: update config directly
    config.set('default_provider', provider_name)
  end

  current_provider = provider_name
  M.refresh_models_for_provider(provider_name)
end

function M.switch_to_model(model_name)
  vim.notify('🤖 Switching to model: ' .. model_name, vim.log.levels.INFO)

  -- Update current model
  current_model = model_name
  config.set('default_model', model_name)

  -- Notify providers UI if open
  local providers_ui = require('zeke.providers_ui')
  if providers_ui then
    providers_ui.refresh_provider_status()
  end
end

-- Data refresh functions
function M.refresh_available_options()
  M.refresh_providers()
  M.refresh_current_status()
end

function M.refresh_providers()
  available_providers = {}

  -- Get authenticated providers from auth system
  local authenticated_providers = auth.get_available_providers()

  local provider_info = {
    github = { icon = '🐙', display_name = 'GitHub Copilot', capabilities = {'code', 'completion'} },
    google = { icon = '🌐', display_name = 'Google AI', capabilities = {'gemini', 'vertex-ai'} },
    openai = { icon = '🧠', display_name = 'OpenAI', capabilities = {'gpt-4', 'gpt-3.5'} },
    anthropic = { icon = '🤖', display_name = 'Anthropic', capabilities = {'claude-3'} },
    ollama = { icon = '🏠', display_name = 'Ollama', capabilities = {'local', 'privacy'} },
    ghostllm = { icon = '🌐', display_name = 'GhostLLM', capabilities = {'unified', 'routing'} },
  }

  for _, provider_name in ipairs(authenticated_providers) do
    local info = provider_info[provider_name]
    if info then
      local provider = {
        name = provider_name,
        icon = info.icon,
        display_name = info.display_name,
        capabilities = info.capabilities,
        model_count = 0, -- Will be updated async
      }
      table.insert(available_providers, provider)

      -- Start loading models for this provider
      M.refresh_models_for_provider(provider_name)
    end
  end
end

function M.refresh_models_for_provider(provider_name)
  -- Get models asynchronously
  vim.defer_fn(function()
    local ok, models = pcall(function()
      local zeke_nvim = require('zeke_nvim')
      return zeke_nvim.get_provider_models(provider_name)
    end)

    if ok and models then
      available_models[provider_name] = models

      -- Update model count for provider
      for _, provider in ipairs(available_providers) do
        if provider.name == provider_name then
          provider.model_count = #models
          break
        end
      end

      -- Re-render if switcher is open
      if switcher_win and api.nvim_win_is_valid(switcher_win) then
        M.render_content()
      end
    end
  end, 100)
end

function M.refresh_current_status()
  local cfg = config.get()
  current_provider = cfg.default_provider
  current_model = cfg.default_model

  -- Also try to get from active session
  local ok, status = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.get_current_provider_model()
  end)

  if ok and status then
    current_provider = status.provider or current_provider
    current_model = status.model or current_model
  end
end

function M.refresh_and_render()
  M.refresh_available_options()
  M.render_content()
end

-- Quick switching functions (for keybind shortcuts)
function M.quick_switch_provider()
  selected_tab = 1
  current_selection = 1
  M.show_switcher()
end

function M.quick_switch_model()
  selected_tab = 2
  current_selection = 1
  M.show_switcher()
end

function M.cycle_providers()
  if #available_providers == 0 then
    vim.notify('❌ No providers available', vim.log.levels.WARN)
    return
  end

  local current_index = 1
  for i, provider in ipairs(available_providers) do
    if provider.name == current_provider then
      current_index = i
      break
    end
  end

  local next_index = (current_index % #available_providers) + 1
  local next_provider = available_providers[next_index]

  M.switch_to_provider(next_provider.name)
end

function M.cycle_models()
  if not current_provider then
    vim.notify('❌ No provider selected', vim.log.levels.WARN)
    return
  end

  local provider_models = available_models[current_provider] or {}
  if #provider_models == 0 then
    vim.notify('❌ No models available for ' .. current_provider, vim.log.levels.WARN)
    return
  end

  local current_index = 1
  for i, model in ipairs(provider_models) do
    if model.name == current_model then
      current_index = i
      break
    end
  end

  local next_index = (current_index % #provider_models) + 1
  local next_model = provider_models[next_index]

  M.switch_to_model(next_model.name)
end

-- Status functions
function M.get_current_provider()
  return current_provider
end

function M.get_current_model()
  return current_model
end

function M.get_status_line()
  if current_provider and current_model then
    return string.format('⚡ %s:%s', current_provider, current_model)
  elseif current_provider then
    return string.format('⚡ %s:auto', current_provider)
  else
    return '⚡ No Provider'
  end
end

-- Cleanup
function M.close_switcher()
  if switcher_win and api.nvim_win_is_valid(switcher_win) then
    api.nvim_win_close(switcher_win, true)
    switcher_win = nil
  end
  if switcher_buf and api.nvim_buf_is_valid(switcher_buf) then
    api.nvim_buf_delete(switcher_buf, { force = true })
    switcher_buf = nil
  end
end

function M.cleanup()
  M.close_switcher()
  available_providers = {}
  available_models = {}
end

return M
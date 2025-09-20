local M = {}

local zeke_nvim = nil
local config = require('zeke.config')
local commands = require('zeke.commands')
local terminal = require('zeke.terminal')
local ui = require('zeke.ui')
local workspace = require('zeke.workspace')
local diff = require('zeke.diff')
local auth = require('zeke.auth')
local consent = require('zeke.consent')
local websocket = require('zeke.websocket')
local discovery = require('zeke.discovery')
local providers_ui = require('zeke.providers_ui')
local switcher = require('zeke.switcher')

function M.setup(opts)
  opts = opts or {}
  config.setup(opts)

  local ok, rust_module = pcall(require, 'zeke_nvim')
  if ok then
    zeke_nvim = rust_module
    zeke_nvim.setup(opts)
  else
    vim.notify('Failed to load zeke_nvim Rust module: ' .. tostring(rust_module), vim.log.levels.ERROR)
    return
  end

  commands.setup(zeke_nvim)
  terminal.setup(zeke_nvim)
  ui.setup()
  workspace.setup()
  diff.setup()
  auth.setup()
  consent.setup()
  websocket.setup()
  discovery.setup()
  providers_ui.setup()
  switcher.setup()

  vim.api.nvim_create_user_command('ZekeChat', function(args)
    commands.chat(args.args)
  end, { nargs = '?', desc = 'Chat with Zeke AI' })

  vim.api.nvim_create_user_command('ZekeEdit', function(args)
    commands.edit_buffer(args.args)
  end, { nargs = '?', desc = 'Edit current buffer with Zeke' })

  vim.api.nvim_create_user_command('ZekeExplain', function()
    commands.explain()
  end, { desc = 'Explain current buffer with Zeke' })

  vim.api.nvim_create_user_command('ZekeCreate', function(args)
    commands.create_file(args.args)
  end, { nargs = '?', desc = 'Create file with Zeke' })

  vim.api.nvim_create_user_command('ZekeAnalyze', function(args)
    local analysis_type = args.args or 'quality'
    commands.analyze(analysis_type)
  end, { nargs = '?', desc = 'Analyze code with Zeke' })

  vim.api.nvim_create_user_command('ZekeModels', function()
    commands.list_models()
  end, { desc = 'List available AI models' })

  vim.api.nvim_create_user_command('ZekeSetModel', function(args)
    commands.set_model(args.args)
  end, { nargs = '?', desc = 'Set AI model' })

  vim.api.nvim_create_user_command('ZekeCurrentModel', function()
    commands.get_current_model()
  end, { desc = 'Show current AI model' })

  vim.api.nvim_create_user_command('ZekeTasks', function()
    commands.list_tasks()
  end, { desc = 'List active Zeke tasks' })

  vim.api.nvim_create_user_command('ZekeCancelTask', function(args)
    local task_id = tonumber(args.args)
    commands.cancel_task(task_id)
  end, { nargs = '?', desc = 'Cancel a Zeke task' })

  vim.api.nvim_create_user_command('ZekeCancelAll', function()
    commands.cancel_all_tasks()
  end, { desc = 'Cancel all Zeke tasks' })

  vim.api.nvim_create_user_command('ZekeChatStream', function(args)
    commands.chat_stream(args.args)
  end, { nargs = '?', desc = 'Chat with Zeke AI (streaming)' })

  -- New UI and workspace commands
  vim.api.nvim_create_user_command('ZekeToggleChat', function()
    commands.toggle_chat()
  end, { desc = 'Toggle Zeke chat window' })

  vim.api.nvim_create_user_command('ZekeAddFile', function()
    commands.add_file_to_context()
  end, { desc = 'Add file to context' })

  vim.api.nvim_create_user_command('ZekeAddCurrent', function()
    commands.add_current_file_to_context()
  end, { desc = 'Add current file to context' })

  vim.api.nvim_create_user_command('ZekeAddSelection', function()
    commands.add_selection_to_context()
  end, { desc = 'Add selection to context' })

  vim.api.nvim_create_user_command('ZekeShowContext', function()
    commands.show_context()
  end, { desc = 'Show context summary' })

  vim.api.nvim_create_user_command('ZekeClearContext', function()
    commands.clear_context()
  end, { desc = 'Clear context' })

  vim.api.nvim_create_user_command('ZekeContextFiles', function()
    commands.show_context_files()
  end, { desc = 'Show context files' })

  vim.api.nvim_create_user_command('ZekeSaveConversation', function()
    commands.save_conversation()
  end, { desc = 'Save current conversation' })

  vim.api.nvim_create_user_command('ZekeLoadConversation', function()
    commands.list_conversations()
  end, { desc = 'Load conversation from history' })

  vim.api.nvim_create_user_command('ZekeSetProvider', function(args)
    commands.set_provider(args.args)
  end, { nargs = '?', desc = 'Set AI provider' })

  vim.api.nvim_create_user_command('ZekeSearch', function(args)
    commands.workspace_search(args.args)
  end, { nargs = '?', desc = 'Search workspace files' })

  -- Authentication commands
  vim.api.nvim_create_user_command('ZekeAuth', function()
    auth.show_auth_ui()
  end, { desc = 'Manage authentication for AI providers' })

  vim.api.nvim_create_user_command('ZekeAuthGitHub', function()
    auth.quick_github_auth()
  end, { desc = 'Authenticate with GitHub (Copilot Pro)' })

  vim.api.nvim_create_user_command('ZekeAuthGoogle', function()
    auth.quick_google_auth()
  end, { desc = 'Authenticate with Google (Vertex AI, Gemini)' })

  vim.api.nvim_create_user_command('ZekeAuthOpenAI', function(args)
    if args.args and args.args ~= '' then
      local parts = vim.split(args.args, ' ', { plain = true })
      auth.quick_openai_auth(parts[1], parts[2])
    else
      auth.quick_openai_auth()
    end
  end, { nargs = '?', desc = 'Authenticate with OpenAI API key [org]' })

  vim.api.nvim_create_user_command('ZekeAuthAnthropic', function(args)
    if args.args and args.args ~= '' then
      auth.quick_anthropic_auth(args.args)
    else
      auth.quick_anthropic_auth()
    end
  end, { nargs = '?', desc = 'Authenticate with Anthropic API key' })

  -- Provider management commands
  vim.api.nvim_create_user_command('ZekeProviders', function()
    providers_ui.show_provider_ui()
  end, { desc = 'Manage AI providers' })

  -- Quick switcher commands
  vim.api.nvim_create_user_command('ZekeSwitcher', function()
    switcher.show_switcher()
  end, { desc = 'Quick provider/model switcher' })

  vim.api.nvim_create_user_command('ZekeSwitchProvider', function()
    switcher.quick_switch_provider()
  end, { desc = 'Quick switch provider' })

  vim.api.nvim_create_user_command('ZekeSwitchModel', function()
    switcher.quick_switch_model()
  end, { desc = 'Quick switch model' })

  vim.api.nvim_create_user_command('ZekeCycleProvider', function()
    switcher.cycle_providers()
  end, { desc = 'Cycle through available providers' })

  vim.api.nvim_create_user_command('ZekeCycleModel', function()
    switcher.cycle_models()
  end, { desc = 'Cycle through available models' })

  -- Discovery and WebSocket commands
  vim.api.nvim_create_user_command('ZekeDiscovery', function()
    discovery.show_discovery_status()
  end, { desc = 'Show Zeke CLI discovery status' })

  vim.api.nvim_create_user_command('ZekeStartCLI', function(args)
    local port = args.args and tonumber(args.args) or nil
    discovery.start_zeke_cli(port)
  end, { nargs = '?', desc = 'Start Zeke CLI [port]' })

  vim.api.nvim_create_user_command('ZekeSessionManager', function()
    discovery.show_session_manager()
  end, { desc = 'Manage Zeke CLI sessions' })

  -- WebSocket connection commands
  vim.api.nvim_create_user_command('ZekeConnect', function()
    local session = discovery.ensure_connection()
    if session then
      websocket.connect(session)
    end
  end, { desc = 'Connect to Zeke CLI WebSocket' })

  vim.api.nvim_create_user_command('ZekeDisconnect', function()
    websocket.disconnect()
  end, { desc = 'Disconnect from Zeke CLI WebSocket' })

  vim.api.nvim_create_user_command('ZekeStatus', function()
    local health = websocket.health_check()
    print(vim.inspect(health))
  end, { desc = 'Show Zeke connection status' })

  local keymaps = config.get().keymaps
  if keymaps.chat then
    vim.keymap.set('n', keymaps.chat, function()
      vim.ui.input({prompt = 'Chat: '}, function(input)
        if input then commands.chat(input) end
      end)
    end, { desc = 'Chat with Zeke' })
  end

  if keymaps.edit then
    vim.keymap.set('n', keymaps.edit, function()
      vim.ui.input({prompt = 'Edit instruction: '}, function(input)
        if input then commands.edit_buffer(input) end
      end)
    end, { desc = 'Edit buffer with Zeke' })
  end

  if keymaps.explain then
    vim.keymap.set('n', keymaps.explain, commands.explain, { desc = 'Explain with Zeke' })
  end

  if keymaps.create then
    vim.keymap.set('n', keymaps.create, function()
      vim.ui.input({prompt = 'Create file: '}, function(input)
        if input then commands.create_file(input) end
      end)
    end, { desc = 'Create file with Zeke' })
  end

  if keymaps.analyze then
    vim.keymap.set('n', keymaps.analyze, function()
      commands.analyze('quality')
    end, { desc = 'Analyze code with Zeke' })
  end

  if keymaps.models then
    vim.keymap.set('n', keymaps.models, commands.list_models, { desc = 'List AI models' })
  end

  if keymaps.tasks then
    vim.keymap.set('n', keymaps.tasks, commands.list_tasks, { desc = 'List active tasks' })
  end

  if keymaps.chat_stream then
    vim.keymap.set('n', keymaps.chat_stream, function()
      vim.ui.input({prompt = 'Streaming Chat: '}, function(input)
        if input then commands.chat_stream(input) end
      end)
    end, { desc = 'Streaming chat with Zeke' })
  end

  -- Enhanced keybindings for switcher and providers
  if keymaps.toggle_chat then
    vim.keymap.set('n', keymaps.toggle_chat, commands.toggle_chat, { desc = 'Toggle Zeke chat' })
  end

  if keymaps.provider_status then
    vim.keymap.set('n', keymaps.provider_status, function()
      switcher.show_switcher()
    end, { desc = 'Quick provider/model switcher' })
  end

  -- Quick provider cycling
  vim.keymap.set('n', '<leader>zp', function()
    switcher.cycle_providers()
  end, { desc = 'Cycle AI providers' })

  vim.keymap.set('n', '<leader>zm', function()
    switcher.cycle_models()
  end, { desc = 'Cycle AI models' })

  -- Quick switcher popup
  vim.keymap.set('n', '<leader>zs', function()
    switcher.show_switcher()
  end, { desc = 'Show provider/model switcher' })

  -- Authentication shortcuts
  vim.keymap.set('n', '<leader>za', function()
    auth.show_auth_ui()
  end, { desc = 'Manage authentication' })

  -- Provider management
  vim.keymap.set('n', '<leader>zP', function()
    providers_ui.show_provider_ui()
  end, { desc = 'Manage providers' })

  if config.get().auto_reload then
    vim.api.nvim_create_autocmd('FocusGained', {
      pattern = '*',
      command = 'checktime'
    })
  end
end

-- Core AI functions
M.chat = commands.chat
M.edit = commands.edit_buffer
M.explain = commands.explain
M.create = commands.create_file
M.analyze = commands.analyze
M.list_models = commands.list_models
M.set_model = commands.set_model
M.get_current_model = commands.get_current_model
M.list_tasks = commands.list_tasks
M.cancel_task = commands.cancel_task
M.cancel_all_tasks = commands.cancel_all_tasks
M.chat_stream = commands.chat_stream

-- UI functions
M.toggle_chat = commands.toggle_chat
M.save_conversation = commands.save_conversation
M.list_conversations = commands.list_conversations

-- Workspace functions
M.add_file_to_context = commands.add_file_to_context
M.add_current_file_to_context = commands.add_current_file_to_context
M.add_selection_to_context = commands.add_selection_to_context
M.show_context = commands.show_context
M.clear_context = commands.clear_context
M.show_context_files = commands.show_context_files
M.workspace_search = commands.workspace_search

-- Provider functions
M.set_provider = commands.set_provider

-- Authentication functions
M.show_auth = auth.show_auth_ui
M.auth_github = auth.quick_github_auth
M.auth_google = auth.quick_google_auth
M.auth_openai = auth.quick_openai_auth
M.auth_anthropic = auth.quick_anthropic_auth

-- Provider management functions
M.show_providers = providers_ui.show_provider_ui
M.cycle_provider = switcher.cycle_providers
M.cycle_model = switcher.cycle_models
M.show_switcher = switcher.show_switcher

-- Discovery and WebSocket functions
M.show_discovery = discovery.show_discovery_status
M.start_cli = discovery.start_zeke_cli
M.connect = function()
  local session = discovery.ensure_connection()
  if session then
    websocket.connect(session)
  end
end
M.disconnect = websocket.disconnect
M.get_status = websocket.health_check

-- Utility functions
M.get_current_provider = switcher.get_current_provider
M.get_current_model = switcher.get_current_model
M.get_status_line = switcher.get_status_line
M.is_authenticated = auth.is_authenticated

return M
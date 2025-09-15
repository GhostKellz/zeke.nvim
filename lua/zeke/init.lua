local M = {}

local zeke_nvim = nil
local config = require('zeke.config')
local commands = require('zeke.commands')
local terminal = require('zeke.terminal')
local ui = require('zeke.ui')
local workspace = require('zeke.workspace')
local diff = require('zeke.diff')

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

return M
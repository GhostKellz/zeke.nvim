local M = {}

local config = require('zeke.config')
local commands = require('zeke.commands')

function M.setup(opts)
  config.setup(opts)
  
  -- Set up user commands
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
  
  -- Model management commands
  vim.api.nvim_create_user_command('ZekeModels', function()
    commands.list_models()
  end, { desc = 'List available AI models' })
  
  vim.api.nvim_create_user_command('ZekeSetModel', function(args)
    commands.set_model(args.args)
  end, { nargs = '?', desc = 'Set AI model' })
  
  vim.api.nvim_create_user_command('ZekeCurrentModel', function()
    commands.get_current_model()
  end, { desc = 'Show current AI model' })
  
  -- Task management commands
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
  
  -- Streaming commands
  vim.api.nvim_create_user_command('ZekeChatStream', function(args)
    commands.chat_stream(args.args)
  end, { nargs = '?', desc = 'Chat with Zeke AI (streaming)' })
  
  -- Set up keymaps
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
  
  -- Auto-reload files if enabled
  if config.get().auto_reload then
    vim.api.nvim_create_autocmd('FocusGained', {
      pattern = '*',
      command = 'checktime'
    })
  end
end

-- Expose command functions
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

return M
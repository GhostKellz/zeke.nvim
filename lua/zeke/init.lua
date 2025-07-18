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

return M
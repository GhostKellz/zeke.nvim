--[[
  zeke.nvim Commands Module (CLI-based)

  This module implements all the Neovim commands for zeke.nvim,
  using the CLI wrapper to communicate with Zeke v0.3.0.

  Refactored from HTTP API to CLI calls.
--]]

local M = {}

local cli = require('zeke.cli')
local logger = require('zeke.logger')
local diff = require('zeke.diff')
local backup = require('zeke.backup')
local safety = require('zeke.safety')
local progress = require('zeke.progress')

-- Helper: Get buffer content
local function get_buffer_content()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return table.concat(lines, '\n')
end

-- Helper: Get file path
local function get_current_file()
  return vim.fn.expand('%:p')
end

-- Helper: Get filetype
local function get_filetype()
  return vim.bo.filetype
end

-- Helper: Show floating window
local function show_floating_window(lines, opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('filetype', opts.filetype or 'markdown', { buf = buf })

  -- Set content
  if type(lines) == 'string' then
    lines = vim.split(lines, '\n', { plain = true })
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Calculate position
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- Open window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    title = opts.title or ' Zeke Response ',
    title_pos = 'center',
  })

  -- Set window options
  vim.api.nvim_set_option_value('wrap', true, { win = win })
  vim.api.nvim_set_option_value('linebreak', true, { win = win })

  -- Set keymaps for closing
  local close_keys = { 'q', '<Esc>' }
  for _, key in ipairs(close_keys) do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, ':close<CR>', { noremap = true, silent = true })
  end

  return buf, win
end

--[[
  Chat Command
--]]
function M.chat(message)
  if not message or message == '' then
    vim.ui.input({ prompt = 'Chat message: ' }, function(input)
      if input then
        M.chat(input)
      end
    end)
    return
  end

  logger.info('commands', 'Chat: ' .. message)

  -- Show loading notification
  vim.notify('Zeke is thinking...', vim.log.levels.INFO)

  -- Call CLI
  local response, err = cli.chat(message)

  if not response then
    vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    logger.error('commands', 'Chat failed: ' .. (err or 'unknown'))
    return
  end

  -- Show response in floating window
  show_floating_window(response, { title = ' Chat Response ' })
end

--[[
  Explain Command
--]]
function M.explain()
  logger.info('commands', 'Explain current buffer')

  local content = get_buffer_content()
  local filetype = get_filetype()

  vim.notify('Analyzing code...', vim.log.levels.INFO)

  local response, err = cli.explain(content, filetype)

  if not response then
    vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return
  end

  show_floating_window(response, { title = ' Code Explanation ' })
end

--[[
  Edit Buffer Command
--]]
function M.edit_buffer(instruction)
  if not instruction or instruction == '' then
    vim.ui.input({ prompt = 'Edit instruction: ' }, function(input)
      if input then
        M.edit_buffer(input)
      end
    end)
    return
  end

  logger.info('commands', 'Edit buffer: ' .. instruction)

  local file_path = get_current_file()
  if file_path == '' then
    vim.notify('Save the buffer first', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Safety confirmation with auto-backup
  safety.confirm_edit(bufnr, instruction, function(confirmed, backup_info)
    if not confirmed then
      logger.info('commands', 'Edit cancelled by user')
      return
    end

    -- Start step-based progress
    local prog = progress.steps("edit_buffer", {
      "Creating backup",
      "Sending to AI",
      "Generating edits",
      "Creating diff view",
    })

    prog.next() -- Step 2: Sending to AI
    prog.next() -- Step 3: Generating edits

    local response, err = cli.file_edit(file_path, instruction)

    if not response then
      prog.fail('Edit generation failed')

      -- Show backup restoration option if we have a backup
      if backup_info then
        vim.ui.select({ 'Yes', 'No' }, {
          prompt = 'Edit failed. Restore backup?',
        }, function(choice)
          if choice == 'Yes' then
            backup.restore_backup(backup_info.path, bufnr)
          end
        end)
      end
      return
    end

    prog.next() -- Step 4: Creating diff view

    -- Create diff
    local original_file = file_path
    local modified_content = response

    -- Show diff using zeke.diff module (with backup info for undo)
    diff.create_diff(original_file, modified_content, backup_info)

    prog.complete('Edit complete - Review changes in diff view')
  end)
end

--[[
  Create File Command
--]]
function M.create_file(description)
  if not description or description == '' then
    vim.ui.input({ prompt = 'File description: ' }, function(input)
      if input then
        M.create_file(input)
      end
    end)
    return
  end

  logger.info('commands', 'Create file: ' .. description)

  vim.ui.input({ prompt = 'File path: ' }, function(file_path)
    if not file_path then
      return
    end

    -- Infer language from extension
    local language = vim.fn.fnamemodify(file_path, ':e')

    vim.notify('Generating file...', vim.log.levels.INFO)

    local response, err = cli.generate(description, language)

    if not response then
      vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
      return
    end

    -- Write to file
    local file = io.open(file_path, 'w')
    if file then
      file:write(response)
      file:close()
      vim.notify('Created: ' .. file_path, vim.log.levels.INFO)
      -- Open the file
      vim.cmd('edit ' .. file_path)
    else
      vim.notify('Failed to write file', vim.log.levels.ERROR)
    end
  end)
end

--[[
  Analyze Command
--]]
function M.analyze(analysis_type)
  analysis_type = analysis_type or 'quality'
  logger.info('commands', 'Analyze: ' .. analysis_type)

  local file_path = get_current_file()
  if file_path == '' then
    vim.notify('Save the buffer first', vim.log.levels.WARN)
    return
  end

  vim.notify('Analyzing code (' .. analysis_type .. ')...', vim.log.levels.INFO)

  local response, err = cli.analyze(file_path, analysis_type)

  if not response then
    vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return
  end

  show_floating_window(response, { title = ' Analysis: ' .. analysis_type:upper() .. ' ' })
end

--[[
  Provider Management
--]]
function M.list_providers()
  logger.info('commands', 'List providers')

  local providers, err = cli.provider_list()

  if not providers then
    vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return
  end

  -- Show in floating window
  local lines = { '# Available Providers', '' }
  for i, provider in ipairs(providers) do
    table.insert(lines, i .. '. ' .. provider)
  end

  show_floating_window(lines, { title = ' Providers ' })
end

function M.set_provider(provider)
  if not provider or provider == '' then
    -- Show picker
    local providers, err = cli.provider_list()
    if not providers then
      vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
      return
    end

    vim.ui.select(providers, {
      prompt = 'Select provider:',
    }, function(choice)
      if choice then
        M.set_provider(choice)
      end
    end)
    return
  end

  logger.info('commands', 'Set provider: ' .. provider)

  local response, err = cli.provider_switch(provider)

  if not response then
    vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return
  end

  vim.notify('Provider set to: ' .. provider, vim.log.levels.INFO)
end

function M.provider_status()
  local response, err = cli.provider_status()

  if not response then
    vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return
  end

  show_floating_window(response, { title = ' Provider Status ' })
end

--[[
  Model Management
--]]
function M.list_models()
  logger.info('commands', 'List models')

  local response, err = cli.model_list()

  if not response then
    vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return
  end

  show_floating_window(response, { title = ' Available Models ' })
end

function M.set_model(model)
  if not model or model == '' then
    vim.ui.input({ prompt = 'Model name: ' }, function(input)
      if input then
        M.set_model(input)
      end
    end)
    return
  end

  logger.info('commands', 'Set model: ' .. model)

  local response, err = cli.model_set(model)

  if not response then
    vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return
  end

  vim.notify('Model set to: ' .. model, vim.log.levels.INFO)
end

function M.get_current_model()
  local response, err = cli.model_current()

  if not response then
    vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return
  end

  vim.notify('Current model: ' .. response, vim.log.levels.INFO)
end

-- Placeholder for show_model_picker (can be enhanced later)
function M.show_model_picker()
  M.list_models()
end

--[[
  Task Management (Placeholders)
--]]
function M.list_tasks()
  vim.notify('Task management coming soon', vim.log.levels.INFO)
end

function M.cancel_task(task_id)
  vim.notify('Task cancellation coming soon', vim.log.levels.INFO)
end

function M.cancel_all_tasks()
  vim.notify('Cancel all tasks coming soon', vim.log.levels.INFO)
end

return M

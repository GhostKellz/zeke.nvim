local M = {}

local terminal = require('zeke.terminal')

-- Helper function to escape shell arguments
local function escape_shell_arg(arg)
  return "'" .. arg:gsub("'", "'\"'\"'") .. "'"
end

-- Chat command
function M.chat(message)
  local cmd = string.format('nvim chat %s', escape_shell_arg(message or ''))
  terminal.execute_command(cmd, {
    on_success = function(content)
      terminal.show_response(content)
    end,
    on_error = function(error_msg)
      vim.notify('Chat failed: ' .. error_msg, vim.log.levels.ERROR)
    end
  })
end

-- Edit current buffer
function M.edit_buffer(instruction)
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code = table.concat(lines, '\n')
  
  local cmd = string.format('nvim edit %s %s', escape_shell_arg(code), escape_shell_arg(instruction or ''))
  terminal.execute_command(cmd, {
    on_success = function(content)
      -- Show the response and offer to apply changes
      terminal.show_response(content)
      
      -- Ask user if they want to apply the changes
      vim.ui.select({'Yes', 'No'}, {
        prompt = 'Apply changes to buffer?',
      }, function(choice)
        if choice == 'Yes' then
          M.apply_edit_to_buffer(buf, content)
        end
      end)
    end,
    on_error = function(error_msg)
      vim.notify('Edit failed: ' .. error_msg, vim.log.levels.ERROR)
    end,
    on_exit = function(code)
      if code == 0 then
        vim.cmd('checktime')
      end
    end
  })
end

-- Explain current selection or buffer
function M.explain(code)
  if not code then
    -- Get visual selection or current buffer
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    code = table.concat(lines, '\n')
  end
  
  local cmd = string.format('nvim explain %s', escape_shell_arg(code))
  terminal.execute_command(cmd, {
    on_success = function(content)
      terminal.show_response(content)
    end,
    on_error = function(error_msg)
      vim.notify('Explain failed: ' .. error_msg, vim.log.levels.ERROR)
    end
  })
end

-- Create new file
function M.create_file(description)
  local cmd = string.format('nvim create %s', escape_shell_arg(description or ''))
  terminal.execute_command(cmd, {
    on_success = function(content)
      -- Show response and offer to create the file
      terminal.show_response(content)
      
      -- Ask user for filename and whether to create the file
      vim.ui.input({
        prompt = 'Enter filename (or press Esc to cancel): ',
      }, function(filename)
        if filename and filename ~= '' then
          vim.ui.select({'Yes', 'No'}, {
            prompt = string.format('Create file "%s"?', filename),
          }, function(choice)
            if choice == 'Yes' then
              M.create_file_with_content(filename, content)
            end
          end)
        end
      end)
    end,
    on_error = function(error_msg)
      vim.notify('Create failed: ' .. error_msg, vim.log.levels.ERROR)
    end
  })
end

-- Analyze code
function M.analyze(analysis_type, code)
  if not code then
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    code = table.concat(lines, '\n')
  end
  
  analysis_type = analysis_type or 'quality'
  
  local cmd = string.format('nvim analyze %s %s', escape_shell_arg(code), escape_shell_arg(analysis_type))
  terminal.execute_command(cmd, {
    on_success = function(content)
      terminal.show_response(content)
    end,
    on_error = function(error_msg)
      vim.notify('Analysis failed: ' .. error_msg, vim.log.levels.ERROR)
    end
  })
end

-- Helper function to apply edits to buffer
function M.apply_edit_to_buffer(buf, content)
  -- Extract code blocks from the response
  local code_blocks = M.extract_code_blocks(content)
  
  if #code_blocks == 0 then
    vim.notify('No code blocks found in response', vim.log.levels.WARN)
    return
  end
  
  local code_block = code_blocks[1] -- Use the first code block
  local lines = vim.split(code_block, '\n', { plain = true })
  
  -- Apply changes to buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.notify('Changes applied to buffer', vim.log.levels.INFO)
end

-- Helper function to extract code blocks from markdown
function M.extract_code_blocks(content)
  local code_blocks = {}
  local in_code_block = false
  local current_block = {}
  
  for line in content:gmatch('[^\r\n]+') do
    if line:match('^```') then
      if in_code_block then
        -- End of code block
        table.insert(code_blocks, table.concat(current_block, '\n'))
        current_block = {}
        in_code_block = false
      else
        -- Start of code block
        in_code_block = true
      end
    elseif in_code_block then
      table.insert(current_block, line)
    end
  end
  
  return code_blocks
end

-- Helper function to create file with content
function M.create_file_with_content(filename, content)
  -- Extract code blocks
  local code_blocks = M.extract_code_blocks(content)
  local file_content = #code_blocks > 0 and code_blocks[1] or content
  
  -- Write to file
  local file = io.open(filename, 'w')
  if file then
    file:write(file_content)
    file:close()
    vim.notify(string.format('File created: %s', filename), vim.log.levels.INFO)
    
    -- Ask if user wants to open the file
    vim.ui.select({'Yes', 'No'}, {
      prompt = 'Open the created file?',
    }, function(choice)
      if choice == 'Yes' then
        vim.cmd('edit ' .. filename)
      end
    end)
  else
    vim.notify(string.format('Failed to create file: %s', filename), vim.log.levels.ERROR)
  end
end

-- Model management commands
function M.list_models()
  local cmd = 'model list'
  terminal.execute_command(cmd, {
    on_success = function(content)
      terminal.show_response(content)
    end,
    on_error = function(error_msg)
      vim.notify('Failed to list models: ' .. error_msg, vim.log.levels.ERROR)
    end
  })
end

function M.set_model(model_name)
  if not model_name or model_name == '' then
    vim.ui.input({
      prompt = 'Enter model name: ',
    }, function(input)
      if input then
        M.set_model(input)
      end
    end)
    return
  end
  
  local cmd = string.format('model set %s', escape_shell_arg(model_name))
  terminal.execute_command(cmd, {
    on_success = function(content)
      vim.notify('Model updated: ' .. content, vim.log.levels.INFO)
    end,
    on_error = function(error_msg)
      vim.notify('Failed to set model: ' .. error_msg, vim.log.levels.ERROR)
    end
  })
end

function M.get_current_model()
  local cmd = 'model current'
  terminal.execute_command(cmd, {
    on_success = function(content)
      vim.notify('Current model: ' .. content, vim.log.levels.INFO)
    end,
    on_error = function(error_msg)
      vim.notify('Failed to get current model: ' .. error_msg, vim.log.levels.ERROR)
    end
  })
end

-- Task management commands
function M.list_tasks()
  local tasks = terminal.get_active_tasks()
  
  if #tasks == 0 then
    vim.notify('No active tasks', vim.log.levels.INFO)
    return
  end
  
  local task_list = {'Active Zeke Tasks:', ''}
  for _, task in ipairs(tasks) do
    table.insert(task_list, string.format('Task #%d: %s (PID: %d, Duration: %ds)', 
      task.id, task.cmd, task.pid, task.duration))
  end
  
  terminal.show_response(table.concat(task_list, '\n'))
end

function M.cancel_task(task_id)
  if not task_id then
    vim.ui.input({
      prompt = 'Enter task ID to cancel: ',
    }, function(input)
      local id = tonumber(input)
      if id then
        M.cancel_task(id)
      end
    end)
    return
  end
  
  terminal.cancel_task(task_id)
end

function M.cancel_all_tasks()
  terminal.cancel_all_tasks()
end

-- Streaming chat command
function M.chat_stream(message)
  local cmd = string.format('nvim chat %s', escape_shell_arg(message or ''))
  
  -- Create a buffer for streaming output
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Zeke Streaming Chat')
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  -- Open in split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)
  
  local content_lines = {'Streaming response...', ''}
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)
  
  terminal.execute_command_stream(cmd, function(chunk)
    -- Append chunk to buffer
    table.insert(content_lines, chunk)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)
    
    -- Scroll to bottom
    vim.cmd('normal! G')
  end, {
    on_success = function(content)
      -- Replace with final content
      local lines = vim.split(content, '\n', { plain = true })
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    end,
    on_error = function(error_msg)
      vim.notify('Streaming chat failed: ' .. error_msg, vim.log.levels.ERROR)
    end
  })
end

return M
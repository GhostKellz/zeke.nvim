local M = {}

local uv = vim.loop
local config = require('zeke.config')
local logger = require('zeke.logger')

-- Active background tasks
local active_tasks = {}
local task_counter = 0

-- Terminal state
M.state = {
  buf = nil,
  win = nil,
  job_id = nil,
  provider = "native",  -- native, external, or custom
  external_cmd = nil,
}

-- Create floating terminal window
function M.create_float()
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = 'Zeke AI',
    title_pos = 'center'
  })
  
  return buf, win
end

-- Get the zeke binary path
local function get_zeke_binary()
  local config_opts = config.get()
  return config_opts.binary_path or './zig-out/bin/zeke_nvim'
end

-- Run zeke command in terminal
function M.run_command(cmd, opts)
  opts = opts or {}
  
  local buf, win = M.create_float()
  
  local full_cmd = get_zeke_binary() .. ' ' .. cmd
  
  vim.fn.termopen(full_cmd, {
    on_exit = function(_, code)
      if opts.on_exit then
        opts.on_exit(code)
      end
    end
  })
  
  vim.cmd('startinsert')
  
  -- Set up keymaps for terminal
  vim.api.nvim_buf_set_keymap(buf, 't', '<Esc>', '<C-\\><C-n>', {noremap = true})
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', {noremap = true})
  
  return buf, win
end

-- Execute command asynchronously with callbacks
function M.execute_command(cmd, opts)
  opts = opts or {}
  
  local full_cmd = get_zeke_binary() .. ' ' .. cmd
  local task_id = task_counter + 1
  task_counter = task_id
  
  -- Create a unique buffer for this task's output
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Zeke Task #' .. task_id)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'json')
  
  local stdout_chunks = {}
  local stderr_chunks = {}
  
  local handle, pid
  handle, pid = uv.spawn('sh', {
    args = { '-c', full_cmd },
    stdio = { nil, uv.new_pipe(false), uv.new_pipe(false) }
  }, function(code, signal)
    -- Process completion
    local stdout_data = table.concat(stdout_chunks, '')
    local stderr_data = table.concat(stderr_chunks, '')
    
    -- Clean up the task
    active_tasks[task_id] = nil
    
    vim.schedule(function()
      local success, response = M.parse_response(stdout_data)
      
      if success and response then
        if opts.on_success then
          opts.on_success(response.content)
        else
          M.show_response(response.content, buf)
        end
      else
        local error_msg = response and response.error or stderr_data or 'Unknown error'
        if opts.on_error then
          opts.on_error(error_msg)
        else
          M.show_error(error_msg, buf)
        end
      end
      
      if opts.on_exit then
        opts.on_exit(code)
      end
    end)
  end)
  
  if not handle then
    vim.schedule(function()
      local error_msg = 'Failed to start zeke process'
      if opts.on_error then
        opts.on_error(error_msg)
      else
        M.show_error(error_msg, buf)
      end
    end)
    return
  end
  
  -- Store task info
  active_tasks[task_id] = {
    handle = handle,
    pid = pid,
    cmd = cmd,
    buf = buf,
    start_time = vim.fn.localtime()
  }
  
  -- Read stdout
  if handle.stdout then
    uv.read_start(handle.stdout, function(err, data)
      if err then
        vim.schedule(function()
          local error_msg = 'Error reading stdout: ' .. err
          if opts.on_error then
            opts.on_error(error_msg)
          else
            M.show_error(error_msg, buf)
          end
        end)
      elseif data then
        table.insert(stdout_chunks, data)
        
        -- Stream partial updates if enabled
        if opts.on_stream then
          vim.schedule(function()
            opts.on_stream(data)
          end)
        end
      end
    end)
  end
  
  -- Read stderr
  if handle.stderr then
    uv.read_start(handle.stderr, function(err, data)
      if err then
        vim.schedule(function()
          local error_msg = 'Error reading stderr: ' .. err
          if opts.on_error then
            opts.on_error(error_msg)
          else
            M.show_error(error_msg, buf)
          end
        end)
      elseif data then
        table.insert(stderr_chunks, data)
      end
    end)
  end
  
  -- Show task started notification
  if opts.show_progress ~= false then
    M.show_task_started(task_id, cmd, buf)
  end
  
  return task_id
end

-- Parse JSON response from zeke binary
function M.parse_response(json_str)
  if not json_str or json_str == '' then
    return false, nil
  end
  
  local success, response = pcall(vim.fn.json_decode, json_str)
  if not success then
    return false, { error = 'Failed to parse response: ' .. json_str }
  end
  
  return response.success, response
end

-- Show response in a buffer
function M.show_response(content, buf)
  buf = buf or vim.api.nvim_create_buf(false, true)
  
  -- Split content into lines
  local lines = vim.split(content, '\n', { plain = true })
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Open in a split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_name(buf, 'Zeke Response')
  
  -- Add keymaps for the response buffer
  local opts = { buffer = buf, silent = true }
  vim.keymap.set('n', 'q', '<CMD>close<CR>', opts)
  vim.keymap.set('n', '<ESC>', '<CMD>close<CR>', opts)
end

-- Show error in a buffer
function M.show_error(error_msg, buf)
  buf = buf or vim.api.nvim_create_buf(false, true)
  
  local lines = {
    'Error occurred:',
    '',
    error_msg
  }
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'text')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Show as notification or buffer based on config
  local config_opts = config.get()
  if config_opts.show_errors_as_notifications then
    vim.notify(error_msg, vim.log.levels.ERROR, { title = 'Zeke Error' })
  else
    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_buf_set_name(buf, 'Zeke Error')
    
    local opts = { buffer = buf, silent = true }
    vim.keymap.set('n', 'q', '<CMD>close<CR>', opts)
    vim.keymap.set('n', '<ESC>', '<CMD>close<CR>', opts)
  end
end

-- Show task started notification
function M.show_task_started(task_id, cmd, buf)
  local message = string.format('Zeke Task #%d started: %s', task_id, cmd)
  vim.notify(message, vim.log.levels.INFO, { title = 'Zeke' })
  
  -- Add initial content to buffer
  local lines = {
    'Zeke Task #' .. task_id,
    'Command: ' .. cmd,
    'Status: Running...',
    'Started at: ' .. vim.fn.strftime('%H:%M:%S'),
    '',
    'Output will appear here...'
  }
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

-- Get active tasks
function M.get_active_tasks()
  local tasks = {}
  for task_id, task_info in pairs(active_tasks) do
    table.insert(tasks, {
      id = task_id,
      cmd = task_info.cmd,
      pid = task_info.pid,
      start_time = task_info.start_time,
      duration = vim.fn.localtime() - task_info.start_time
    })
  end
  return tasks
end

-- Cancel a task
function M.cancel_task(task_id)
  local task = active_tasks[task_id]
  if not task then
    vim.notify('Task #' .. task_id .. ' not found', vim.log.levels.WARN)
    return false
  end
  
  if task.handle then
    task.handle:kill('sigterm')
    active_tasks[task_id] = nil
    vim.notify('Task #' .. task_id .. ' cancelled', vim.log.levels.INFO)
    return true
  end
  
  return false
end

-- Cancel all active tasks
function M.cancel_all_tasks()
  local count = 0
  for task_id, _ in pairs(active_tasks) do
    if M.cancel_task(task_id) then
      count = count + 1
    end
  end
  
  if count > 0 then
    vim.notify(string.format('Cancelled %d tasks', count), vim.log.levels.INFO)
  else
    vim.notify('No active tasks to cancel', vim.log.levels.INFO)
  end
  
  return count
end

-- Execute command with streaming support
function M.execute_command_stream(cmd, on_chunk, opts)
  opts = opts or {}
  opts.on_stream = on_chunk
  return M.execute_command(cmd, opts)
end

-- Send file to AI context
function M.send_file_to_ai(file_path)
  if not file_path then
    logger.warn("terminal", "No file path provided")
    return false
  end

  local cmd = string.format('add "%s"', file_path)
  M.execute_command(cmd, {
    on_success = function(content)
      logger.info("terminal", "Added file to context: " .. file_path)
    end,
    on_error = function(error_msg)
      logger.error("terminal", "Failed to add file: " .. error_msg)
    end
  })

  return true
end

-- Send selection or data to AI
function M.send_to_ai(data)
  if not data then
    logger.warn("terminal", "No data to send")
    return false
  end

  local cmd
  if data.type == "selection" then
    cmd = string.format('selection "%s"', data.content:gsub('"', '\\"'))
  elseif data.type == "file" then
    cmd = string.format('add "%s"', data.file_path)
  else
    cmd = string.format('chat "%s"', data.content:gsub('"', '\\"'))
  end

  M.execute_command(cmd, {
    on_success = function(content)
      logger.debug("terminal", "Sent data to AI")
    end,
    on_error = function(error_msg)
      logger.error("terminal", "Failed to send data: " .. error_msg)
    end
  })

  return true
end

-- Get active terminal buffer number
function M.get_active_terminal_bufnr()
  return M.state.buf
end

-- Simple toggle terminal
function M.simple_toggle()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, false)
    M.state.win = nil
  else
    M.open()
  end
end

-- Open terminal
function M.open()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_set_current_win(M.state.win)
    return
  end

  local buf, win = M.create_float()
  M.state.buf = buf
  M.state.win = win

  -- Start terminal with zeke binary
  local zeke_cmd = get_zeke_binary()
  M.state.job_id = vim.fn.termopen(zeke_cmd, {
    on_exit = function(_, code)
      logger.debug("terminal", "Zeke terminal exited with code: " .. code)
      M.state.job_id = nil
    end
  })

  vim.cmd('startinsert')
end

-- Close terminal
function M.close()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, false)
    M.state.win = nil
  end
end

-- Focus toggle
function M.focus_toggle()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    local current_win = vim.api.nvim_get_current_win()
    if current_win == M.state.win then
      M.close()
    else
      vim.api.nvim_set_current_win(M.state.win)
    end
  else
    M.open()
  end
end

-- Ensure terminal is visible
function M.ensure_visible()
  if not M.state.win or not vim.api.nvim_win_is_valid(M.state.win) then
    M.open()
  end
end

return M
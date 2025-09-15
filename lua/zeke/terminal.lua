local M = {}

local active_tasks = {}
local next_task_id = 1

function M.setup(rust_module)
end

function M.show_response(content)
  local lines = vim.split(content, '\n', { plain = true })

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Zeke Response')
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  local width = math.min(vim.o.columns - 4, 100)
  local height = math.min(vim.o.lines - 4, 30)

  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })

  vim.api.nvim_win_set_option(win, 'wrap', true)
  vim.api.nvim_win_set_option(win, 'linebreak', true)
end

function M.execute_command(cmd, callbacks)
  local task_id = next_task_id
  next_task_id = next_task_id + 1

  local task = {
    id = task_id,
    cmd = cmd,
    pid = nil,
    start_time = os.time(),
    output = {},
    callbacks = callbacks or {},
  }

  active_tasks[task_id] = task

  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(task.output, line)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data and callbacks.on_error then
        local error_msg = table.concat(data, '\n')
        if error_msg ~= '' then
          callbacks.on_error(error_msg)
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      active_tasks[task_id] = nil

      local output = table.concat(task.output, '\n')

      if exit_code == 0 and callbacks.on_success then
        callbacks.on_success(output)
      elseif exit_code ~= 0 and callbacks.on_error then
        callbacks.on_error('Command failed with exit code: ' .. exit_code)
      end

      if callbacks.on_exit then
        callbacks.on_exit(exit_code)
      end
    end,
  })

  if job_id <= 0 then
    active_tasks[task_id] = nil
    if callbacks.on_error then
      callbacks.on_error('Failed to start command')
    end
    return nil
  end

  task.pid = job_id
  return task_id
end

function M.execute_command_stream(cmd, on_chunk, callbacks)
  local task_id = next_task_id
  next_task_id = next_task_id + 1

  local task = {
    id = task_id,
    cmd = cmd,
    pid = nil,
    start_time = os.time(),
    output = {},
    callbacks = callbacks or {},
  }

  active_tasks[task_id] = task

  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(task.output, line)
            if on_chunk then
              on_chunk(line)
            end
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data and callbacks.on_error then
        local error_msg = table.concat(data, '\n')
        if error_msg ~= '' then
          callbacks.on_error(error_msg)
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      active_tasks[task_id] = nil

      local output = table.concat(task.output, '\n')

      if exit_code == 0 and callbacks.on_success then
        callbacks.on_success(output)
      elseif exit_code ~= 0 and callbacks.on_error then
        callbacks.on_error('Command failed with exit code: ' .. exit_code)
      end

      if callbacks.on_exit then
        callbacks.on_exit(exit_code)
      end
    end,
  })

  if job_id <= 0 then
    active_tasks[task_id] = nil
    if callbacks.on_error then
      callbacks.on_error('Failed to start command')
    end
    return nil
  end

  task.pid = job_id
  return task_id
end

function M.get_active_tasks()
  local tasks = {}
  for _, task in pairs(active_tasks) do
    table.insert(tasks, {
      id = task.id,
      cmd = task.cmd,
      pid = task.pid,
      duration = os.time() - task.start_time,
    })
  end
  return tasks
end

function M.list_tasks()
  local tasks = M.get_active_tasks()

  if #tasks == 0 then
    vim.notify('No active tasks', vim.log.levels.INFO)
    return
  end

  local task_list = {'Active Zeke Tasks:', ''}
  for _, task in ipairs(tasks) do
    table.insert(task_list, string.format('Task #%d: %s (PID: %d, Duration: %ds)',
      task.id, task.cmd, task.pid, task.duration))
  end

  M.show_response(table.concat(task_list, '\n'))
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

  local task = active_tasks[task_id]
  if task and task.pid then
    vim.fn.jobstop(task.pid)
    active_tasks[task_id] = nil
    vim.notify(string.format('Task #%d cancelled', task_id), vim.log.levels.INFO)
  else
    vim.notify(string.format('Task #%d not found', task_id), vim.log.levels.WARN)
  end
end

function M.cancel_all_tasks()
  local count = 0
  for task_id, task in pairs(active_tasks) do
    if task.pid then
      vim.fn.jobstop(task.pid)
      active_tasks[task_id] = nil
      count = count + 1
    end
  end

  if count > 0 then
    vim.notify(string.format('Cancelled %d task(s)', count), vim.log.levels.INFO)
  else
    vim.notify('No active tasks to cancel', vim.log.levels.INFO)
  end
end

return M
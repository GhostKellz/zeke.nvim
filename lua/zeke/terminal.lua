local M = {}

local config = require('zeke.config')

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

-- Run zeke command in terminal
function M.run_command(cmd, opts)
  opts = opts or {}
  
  local buf, win = M.create_float()
  
  local full_cmd = config.get().cmd .. ' ' .. cmd
  
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

-- Execute zeke command and handle JSON response
function M.execute_command(cmd, opts)
  opts = opts or {}
  
  local full_cmd = config.get().cmd .. ' ' .. cmd
  
  vim.fn.jobstart(full_cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        local json_str = table.concat(data, '\n')
        if json_str ~= '' then
          local ok, response = pcall(vim.json.decode, json_str)
          if ok and response then
            if response.success then
              if opts.on_success then
                opts.on_success(response.content)
              else
                M.show_response(response.content)
              end
            else
              M.show_error(response.error or 'Unknown error')
            end
          else
            M.show_error('Failed to parse JSON response')
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local error_str = table.concat(data, '\n')
        if error_str ~= '' then
          M.show_error(error_str)
        end
      end
    end,
    on_exit = function(_, code)
      if opts.on_exit then
        opts.on_exit(code)
      end
    end
  })
end

-- Show response in a floating window
function M.show_response(content)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(content, '\n')
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  local width = math.min(100, math.floor(vim.o.columns * 0.8))
  local height = math.min(30, math.floor(vim.o.lines * 0.8))
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = 'Zeke AI Response',
    title_pos = 'center'
  })
  
  -- Set up keymaps for response window
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', {noremap = true})
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':q<CR>', {noremap = true})
end

-- Show error message
function M.show_error(error_msg)
  vim.notify('Zeke Error: ' .. error_msg, vim.log.levels.ERROR)
end

return M
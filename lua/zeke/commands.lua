local M = {}

local terminal = require('zeke.terminal')

-- Helper function to escape shell arguments
local function escape_shell_arg(arg)
  return "'" .. arg:gsub("'", "'\"'\"'") .. "'"
end

-- Chat command
function M.chat(message)
  local cmd = string.format('nvim chat %s', escape_shell_arg(message or ''))
  terminal.execute_command(cmd)
end

-- Edit current buffer
function M.edit_buffer(instruction)
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code = table.concat(lines, '\n')
  
  local cmd = string.format('nvim edit %s %s', escape_shell_arg(code), escape_shell_arg(instruction or ''))
  terminal.execute_command(cmd, {
    on_success = function(content)
      -- Show the response but also offer to apply changes
      terminal.show_response(content)
      -- TODO: Parse response and apply changes to buffer if user confirms
    end,
    on_exit = function(code)
      if code == 0 then
        -- Reload buffer after successful edit
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
  terminal.execute_command(cmd)
end

-- Create new file
function M.create_file(description)
  local cmd = string.format('nvim create %s', escape_shell_arg(description or ''))
  terminal.execute_command(cmd, {
    on_success = function(content)
      -- Show response and offer to create the file
      terminal.show_response(content)
      -- TODO: Parse response and create actual file if user confirms
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
  terminal.execute_command(cmd)
end

return M
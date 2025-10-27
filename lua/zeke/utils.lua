-- Utility functions for zeke.nvim
local M = {}

local logger = require('zeke.logger')

-- Token estimation (rough approximation)
function M.estimate_tokens(text)
  -- Rough estimate: ~4 characters per token
  -- This is simplified; actual tokenization varies by model
  local char_count = #text
  return math.ceil(char_count / 4)
end

-- Format token count for display
function M.format_tokens(count)
  if count < 1000 then
    return string.format("%d tokens", count)
  else
    return string.format("%.1fk tokens", count / 1000)
  end
end

-- Create backup of file
function M.backup_file(file_path)
  local backup_dir = vim.fn.expand("~/.cache/zeke/backups")
  vim.fn.mkdir(backup_dir, "p")

  -- Generate backup filename with timestamp
  local filename = vim.fn.fnamemodify(file_path, ":t")
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local backup_path = backup_dir .. "/" .. filename .. "." .. timestamp .. ".bak"

  -- Copy file
  local ok, err = pcall(function()
    local content = vim.fn.readfile(file_path)
    vim.fn.writefile(content, backup_path)
  end)

  if ok then
    logger.info('utils', 'Created backup: ' .. backup_path)
    return backup_path
  else
    logger.error('utils', 'Backup failed: ' .. tostring(err))
    return nil
  end
end

-- Count changed lines in diff
function M.count_changed_lines(diff_text)
  local added = 0
  local removed = 0

  for line in diff_text:gmatch("[^\r\n]+") do
    if line:match("^%+") and not line:match("^%+%+%+") then
      added = added + 1
    elseif line:match("^%-") and not line:match("^%-%-%%-") then
      removed = removed + 1
    end
  end

  return {
    added = added,
    removed = removed,
    total = added + removed
  }
end

-- Confirm action with user
function M.confirm(message, default)
  default = default or false
  local choices = default and {'Yes', 'No'} or {'No', 'Yes'}

  local result = nil
  vim.ui.select(choices, {
    prompt = message,
  }, function(choice)
    result = (choice == 'Yes')
  end)

  -- Wait for user input (blocking)
  while result == nil do
    vim.wait(100, function() return result ~= nil end)
  end

  return result
end

-- Format latency for display
function M.format_latency(ms)
  if ms < 1000 then
    return string.format("%dms", ms)
  elseif ms < 60000 then
    return string.format("%.1fs", ms / 1000)
  else
    return string.format("%dm%ds", math.floor(ms / 60000), math.floor((ms % 60000) / 1000))
  end
end

-- Truncate text to max tokens
function M.truncate_to_tokens(text, max_tokens)
  local estimated = M.estimate_tokens(text)

  if estimated <= max_tokens then
    return text, estimated
  end

  -- Truncate to approximately max_tokens
  local char_limit = max_tokens * 4
  local truncated = text:sub(1, char_limit)

  -- Try to truncate at a line boundary
  local last_newline = truncated:match(".*\n")
  if last_newline then
    truncated = last_newline
  end

  return truncated .. "\n\n[... truncated ...]", M.estimate_tokens(truncated)
end

-- Get visual selection range
function M.get_visual_range()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  return {
    start_line = start_pos[2],
    end_line = end_pos[2],
    start_col = start_pos[3],
    end_col = end_pos[3],
  }
end

-- Get visual selection text
function M.get_visual_selection()
  local range = M.get_visual_range()
  local lines = vim.fn.getline(range.start_line, range.end_line)

  if #lines == 0 then
    return ""
  end

  -- Handle single line selection
  if #lines == 1 then
    lines[1] = lines[1]:sub(range.start_col, range.end_col)
  else
    -- Multiline: trim first and last line
    lines[1] = lines[1]:sub(range.start_col)
    lines[#lines] = lines[#lines]:sub(1, range.end_col)
  end

  return table.concat(lines, '\n')
end

-- Check if selection is too large
function M.is_selection_too_large(text, max_lines)
  max_lines = max_lines or 1000
  local line_count = 0

  for _ in text:gmatch("[^\r\n]+") do
    line_count = line_count + 1
    if line_count > max_lines then
      return true
    end
  end

  return false
end

-- Format file size
function M.format_size(bytes)
  if bytes < 1024 then
    return string.format("%d B", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  else
    return string.format("%.1f MB", bytes / (1024 * 1024))
  end
end

return M

-- Context tools for gathering Neovim state
-- Inspired by claudecode.nvim MCP tools but adapted for local use

local M = {}

local logger = require('zeke.logger')

-- Get current file info
function M.get_current_file()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)

  if not path or path == "" then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  return {
    path = path,
    content = table.concat(lines, '\n'),
    language = vim.bo[buf].filetype,
    line_count = #lines,
    is_modified = vim.bo[buf].modified,
  }
end

-- Get current selection
function M.get_current_selection()
  local mode = vim.fn.mode()

  -- Check if in visual mode
  if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then
    return { text = "", isEmpty = true }
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local end_line = end_pos[2]

  local lines = vim.fn.getline(start_line, end_line)
  local text = table.concat(lines, '\n')

  return {
    text = text,
    start_line = start_line,
    end_line = end_line,
    isEmpty = text == "",
    filePath = vim.api.nvim_buf_get_name(0),
  }
end

-- Get latest selection (even if not in visual mode)
function M.get_latest_selection()
  -- Try to get marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  -- Check if marks are valid
  if start_pos[2] == 0 or end_pos[2] == 0 then
    return { text = "", isEmpty = true }
  end

  local start_line = start_pos[2]
  local end_line = end_pos[2]

  local lines = vim.fn.getline(start_line, end_line)
  local text = table.concat(lines, '\n')

  return {
    text = text,
    start_line = start_line,
    end_line = end_line,
    isEmpty = text == "",
    filePath = vim.api.nvim_buf_get_name(0),
  }
end

-- Get open editors (all loaded buffers with files)
function M.get_open_editors()
  local editors = {}
  local bufs = vim.api.nvim_list_bufs()

  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.bo[buf].buftype == "" then
        table.insert(editors, {
          path = name,
          language = vim.bo[buf].filetype,
          is_modified = vim.bo[buf].modified,
          line_count = vim.api.nvim_buf_line_count(buf),
        })
      end
    end
  end

  return editors
end

-- Get diagnostics for current buffer
function M.get_diagnostics(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local diagnostics = vim.diagnostic.get(buf)

  local result = {}
  for _, diag in ipairs(diagnostics) do
    table.insert(result, {
      line = diag.lnum + 1,  -- Convert to 1-based
      column = diag.col + 1,  -- Convert to 1-based
      severity = vim.diagnostic.severity[diag.severity],
      message = diag.message,
      source = diag.source,
      code = diag.code,
    })
  end

  logger.debug('context.tools', string.format('Found %d diagnostics', #result))
  return result
end

-- Get workspace folders
function M.get_workspace_folders()
  local cwd = vim.fn.getcwd()
  return {
    {
      uri = "file://" .. cwd,
      name = vim.fn.fnamemodify(cwd, ":t"),
      path = cwd,
    }
  }
end

-- Check if document is dirty (has unsaved changes)
function M.check_document_dirty(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  return vim.bo[buf].modified
end

-- Save document
function M.save_document(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  local path = vim.api.nvim_buf_get_name(buf)
  if not path or path == "" then
    return false, "No file path"
  end

  local ok, err = pcall(vim.cmd, 'write')
  if not ok then
    return false, tostring(err)
  end

  return true, "Saved successfully"
end

-- Open file in editor
function M.open_file(opts)
  if not opts.filePath then
    return false, "Missing filePath parameter"
  end

  local file_path = vim.fn.expand(opts.filePath)

  if vim.fn.filereadable(file_path) == 0 then
    return false, "File not found: " .. file_path
  end

  -- Open the file
  vim.cmd('edit ' .. vim.fn.fnameescape(file_path))

  -- Handle selection if provided
  if opts.startLine or opts.endLine then
    local start_line = opts.startLine or 1
    local end_line = opts.endLine or start_line

    -- Set cursor to start
    vim.api.nvim_win_set_cursor(0, {start_line, 0})

    -- Create visual selection if end line is different
    if end_line ~= start_line then
      vim.cmd('normal! V')
      vim.api.nvim_win_set_cursor(0, {end_line, 0})
    end
  end

  return true, "Opened file: " .. file_path
end

return M

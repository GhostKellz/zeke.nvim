local M = {}

-- Diff state
M.diff_buf = nil
M.diff_win = nil
M.original_content = nil
M.modified_content = nil
M.target_buffer = nil
M.is_diff_open = false

function M.setup()
  -- Create autocommands for cleanup
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      M.close_diff()
    end,
  })
end

function M.extract_code_blocks(content)
  local code_blocks = {}
  local in_code_block = false
  local current_block = {}
  local block_language = nil

  for line in content:gmatch('[^\r\n]+') do
    if line:match('^```') then
      if in_code_block then
        -- End of code block
        table.insert(code_blocks, {
          language = block_language,
          content = table.concat(current_block, '\n')
        })
        current_block = {}
        in_code_block = false
        block_language = nil
      else
        -- Start of code block
        in_code_block = true
        block_language = line:match('^```(.*)$')
        if block_language == '' then
          block_language = nil
        end
      end
    elseif in_code_block then
      table.insert(current_block, line)
    end
  end

  return code_blocks
end

function M.show_diff(original, modified, target_buf)
  M.original_content = original
  M.modified_content = modified
  M.target_buffer = target_buf or vim.api.nvim_get_current_buf()

  if M.is_diff_open then
    M.close_diff()
  end

  -- Create diff buffer
  M.diff_buf = vim.api.nvim_create_buf(false, true)

  -- Calculate window dimensions
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create floating window
  M.diff_win = vim.api.nvim_open_win(M.diff_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Code Diff - Press a to accept, r to reject, q to close ',
    title_pos = 'center',
  })

  -- Configure buffer
  vim.api.nvim_buf_set_option(M.diff_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.diff_buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(M.diff_buf, 'filetype', 'diff')
  vim.api.nvim_buf_set_option(M.diff_buf, 'modifiable', true)

  -- Generate diff content
  local diff_lines = M.generate_diff_display()
  vim.api.nvim_buf_set_lines(M.diff_buf, 0, -1, false, diff_lines)
  vim.api.nvim_buf_set_option(M.diff_buf, 'modifiable', false)

  -- Set up keymaps
  local opts = { buffer = M.diff_buf, noremap = true, silent = true }
  vim.keymap.set('n', 'a', M.accept_changes, opts)
  vim.keymap.set('n', 'r', M.reject_changes, opts)
  vim.keymap.set('n', 'q', M.close_diff, opts)
  vim.keymap.set('n', '<Esc>', M.close_diff, opts)
  vim.keymap.set('n', '<C-c>', M.close_diff, opts)

  M.is_diff_open = true

  -- Set cursor to first diff line
  vim.api.nvim_win_set_cursor(M.diff_win, {1, 0})
end

function M.generate_diff_display()
  local lines = {}

  -- Header
  table.insert(lines, '╔═══════════════════════════════════════════════════════════╗')
  table.insert(lines, '║                      CODE DIFF VIEW                      ║')
  table.insert(lines, '║  Press "a" to accept changes, "r" to reject, "q" to quit ║')
  table.insert(lines, '╚═══════════════════════════════════════════════════════════╝')
  table.insert(lines, '')

  -- Split content into lines
  local original_lines = vim.split(M.original_content, '\n')
  local modified_lines = vim.split(M.modified_content, '\n')

  -- Simple line-by-line diff
  local max_lines = math.max(#original_lines, #modified_lines)

  table.insert(lines, '┌─ ORIGINAL ─────────────────┬─ MODIFIED ─────────────────┐')

  for i = 1, max_lines do
    local orig_line = original_lines[i] or ''
    local mod_line = modified_lines[i] or ''

    -- Truncate long lines for display
    local max_width = math.floor((vim.o.columns * 0.9 - 6) / 2)
    if #orig_line > max_width then
      orig_line = orig_line:sub(1, max_width - 3) .. '...'
    end
    if #mod_line > max_width then
      mod_line = mod_line:sub(1, max_width - 3) .. '...'
    end

    local status = ''
    if orig_line ~= mod_line then
      if orig_line == '' then
        status = '+ '
      elseif mod_line == '' then
        status = '- '
      else
        status = '~ '
      end
    else
      status = '  '
    end

    -- Pad lines to equal width
    orig_line = orig_line .. string.rep(' ', max_width - #orig_line)
    mod_line = mod_line .. string.rep(' ', max_width - #mod_line)

    table.insert(lines, string.format('│%s%-*s│%s%-*s│',
      status, max_width, orig_line, status, max_width, mod_line))
  end

  table.insert(lines, '└────────────────────────────┴────────────────────────────┘')
  table.insert(lines, '')
  table.insert(lines, 'Statistics:')
  table.insert(lines, string.format('  Original: %d lines', #original_lines))
  table.insert(lines, string.format('  Modified: %d lines', #modified_lines))

  -- Count changes
  local added = 0
  local removed = 0
  local modified = 0

  for i = 1, max_lines do
    local orig = original_lines[i] or ''
    local mod = modified_lines[i] or ''

    if orig ~= mod then
      if orig == '' then
        added = added + 1
      elseif mod == '' then
        removed = removed + 1
      else
        modified = modified + 1
      end
    end
  end

  table.insert(lines, string.format('  Changes: +%d -%d ~%d', added, removed, modified))

  return lines
end

function M.accept_changes()
  if not M.target_buffer or not vim.api.nvim_buf_is_valid(M.target_buffer) then
    vim.notify('Target buffer is no longer valid', vim.log.levels.ERROR)
    M.close_diff()
    return
  end

  -- Apply changes to target buffer
  local lines = vim.split(M.modified_content, '\n')
  vim.api.nvim_buf_set_lines(M.target_buffer, 0, -1, false, lines)

  vim.notify('Changes accepted and applied', vim.log.levels.INFO)
  M.close_diff()
end

function M.reject_changes()
  vim.notify('Changes rejected', vim.log.levels.INFO)
  M.close_diff()
end

function M.close_diff()
  if M.diff_win and vim.api.nvim_win_is_valid(M.diff_win) then
    vim.api.nvim_win_close(M.diff_win, true)
  end

  if M.diff_buf and vim.api.nvim_buf_is_valid(M.diff_buf) then
    vim.api.nvim_buf_delete(M.diff_buf, { force = true })
  end

  M.diff_buf = nil
  M.diff_win = nil
  M.original_content = nil
  M.modified_content = nil
  M.target_buffer = nil
  M.is_diff_open = false
end

function M.show_ai_edit_diff(response)
  local current_buf = vim.api.nvim_get_current_buf()
  local current_lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
  local original_content = table.concat(current_lines, '\n')

  -- Extract code blocks from AI response
  local code_blocks = M.extract_code_blocks(response)

  if #code_blocks == 0 then
    vim.notify('No code blocks found in AI response', vim.log.levels.WARN)
    return
  end

  -- Use the first code block as the modified content
  local modified_content = code_blocks[1].content

  M.show_diff(original_content, modified_content, current_buf)
end

function M.preview_file_creation(content, filename)
  -- Create a temporary buffer to show the preview
  local preview_buf = vim.api.nvim_create_buf(false, true)

  -- Calculate window dimensions
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create floating window
  local preview_win = vim.api.nvim_open_win(preview_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Preview: ' .. filename .. ' - Press s to save, q to cancel ',
    title_pos = 'center',
  })

  -- Configure buffer
  vim.api.nvim_buf_set_option(preview_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(preview_buf, 'swapfile', false)

  -- Detect file type from extension
  local ft = vim.filetype.match({ filename = filename })
  if ft then
    vim.api.nvim_buf_set_option(preview_buf, 'filetype', ft)
  end

  -- Set content
  local lines = vim.split(content, '\n')
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(preview_buf, 'modifiable', false)

  -- Set up keymaps
  local opts = { buffer = preview_buf, noremap = true, silent = true }
  vim.keymap.set('n', 's', function()
    M.save_preview_file(content, filename, preview_buf, preview_win)
  end, opts)
  vim.keymap.set('n', 'q', function()
    M.close_preview(preview_buf, preview_win)
  end, opts)
  vim.keymap.set('n', '<Esc>', function()
    M.close_preview(preview_buf, preview_win)
  end, opts)
end

function M.save_preview_file(content, filename, buf, win)
  -- Write file
  local file = io.open(filename, 'w')
  if file then
    file:write(content)
    file:close()
    vim.notify('File saved: ' .. filename, vim.log.levels.INFO)

    -- Ask if user wants to open the file
    vim.ui.select({'Yes', 'No'}, {
      prompt = 'Open the created file?',
    }, function(choice)
      if choice == 'Yes' then
        vim.cmd('edit ' .. filename)
      end
    end)
  else
    vim.notify('Failed to save file: ' .. filename, vim.log.levels.ERROR)
  end

  M.close_preview(buf, win)
end

function M.close_preview(buf, win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

return M
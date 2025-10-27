-- Inline ghost text completions (like Copilot)
-- Inspired by copilot.vim and CopilotChat.nvim

local M = {}

local api = vim.api
local cli = require('zeke.cli')
local logger = require('zeke.logger')
local config = require('zeke.config')

-- Namespace for extmarks
M.ns_id = api.nvim_create_namespace('zeke_inline_completion')

-- State
M.state = {
  enabled = true,
  active_job = nil,
  suggestions = {},
  current_idx = 0,
  bufnr = nil,
  line = nil,
  col = nil,
  timer = nil,
  debounce_ms = 150,
}

-- Initialize inline completions
function M.setup()
  -- Create highlight group for ghost text
  api.nvim_set_hl(0, 'ZekeGhostText', { link = 'Comment', default = true })
  api.nvim_set_hl(0, 'ZekeGhostTextCounter', { link = 'DiagnosticHint', default = true })

  -- Setup autocommands
  local group = api.nvim_create_augroup('zeke_inline_completion', { clear = true })

  -- Trigger completions on text change
  api.nvim_create_autocmd('TextChangedI', {
    group = group,
    callback = function()
      M.on_text_changed()
    end,
  })

  -- Clear completions when cursor moves
  api.nvim_create_autocmd('CursorMovedI', {
    group = group,
    callback = function()
      -- Only clear if cursor moved away from suggestion position
      if M.state.bufnr and M.state.line then
        local cursor = api.nvim_win_get_cursor(0)
        if cursor[1] ~= M.state.line or cursor[2] ~= M.state.col then
          M.clear()
        end
      end
    end,
  })

  -- Clear completions on mode exit
  api.nvim_create_autocmd('InsertLeavePre', {
    group = group,
    callback = function()
      M.clear()
    end,
  })

  -- Clear completions on buffer delete
  api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(ev)
      if M.state.bufnr == ev.buf then
        M.clear()
      end
    end,
  })

  logger.debug('inline', 'Inline completions initialized')
end

-- Handle text changed event
function M.on_text_changed()
  if not M.state.enabled then
    return
  end

  -- Cancel existing timer
  if M.state.timer then
    vim.fn.timer_stop(M.state.timer)
    M.state.timer = nil
  end

  -- Debounce to avoid excessive API calls
  M.state.timer = vim.fn.timer_start(M.state.debounce_ms, function()
    vim.schedule(function()
      M.request_completion()
    end)
  end)
end

-- Request completion from Zeke
function M.request_completion()
  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col = cursor[2]

  -- Skip if not a code buffer
  local ft = api.nvim_buf_get_option(bufnr, 'filetype')
  if ft == '' or ft == 'zeke-chat' or ft == 'zeke-input' then
    return
  end

  -- Cancel any existing job
  if M.state.active_job then
    cli.cancel_stream(M.state.active_job)
    M.state.active_job = nil
  end

  -- Get context: previous lines + current line up to cursor
  local lines = api.nvim_buf_get_lines(bufnr, math.max(0, line_num - 20), line_num, false)
  local current_line = api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1] or ''
  local prefix = current_line:sub(1, col)

  table.insert(lines, prefix)
  local context = table.concat(lines, '\n')

  -- Build prompt
  local filename = api.nvim_buf_get_name(bufnr)
  local prompt = string.format(
    "Complete the following %s code. Provide ONLY the completion text that should appear after the cursor, nothing else:\n\n```%s\n%s",
    ft, ft, context
  )

  -- Store current position
  M.state.bufnr = bufnr
  M.state.line = line_num
  M.state.col = col

  -- Request completion via CLI
  local completion_text = ''
  M.state.active_job = cli.stream_chat(prompt,
    -- on_chunk
    function(chunk)
      completion_text = completion_text .. chunk
      vim.schedule(function()
        -- Parse and render partial completion
        M.render_suggestion(completion_text, bufnr, line_num, col)
      end)
    end,
    -- on_complete
    function(full_response, exit_code)
      vim.schedule(function()
        M.state.active_job = nil
        if exit_code == 0 then
          -- Clean up the response (remove markdown fences, etc.)
          local cleaned = M.clean_response(full_response)
          M.state.suggestions = { cleaned }
          M.state.current_idx = 1
          M.render_suggestion(cleaned, bufnr, line_num, col)
        end
      end)
    end
  )
end

-- Clean AI response to extract just the code
function M.clean_response(response)
  -- Remove markdown code blocks
  local cleaned = response:gsub('```[%w]*\n?', '')
  cleaned = cleaned:gsub('```', '')

  -- Remove common prefixes
  cleaned = cleaned:gsub('^Here[^\n]*\n', '')
  cleaned = cleaned:gsub('^The completion[^\n]*\n', '')

  -- Trim whitespace
  cleaned = cleaned:match('^%s*(.-)%s*$')

  return cleaned
end

-- Render suggestion as ghost text
function M.render_suggestion(text, bufnr, line_num, col)
  if not text or text == '' then
    return
  end

  -- Verify buffer is still valid and cursor hasn't moved
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  local cursor = api.nvim_win_get_cursor(0)
  if cursor[1] ~= line_num or cursor[2] ~= col then
    return
  end

  -- Clear previous suggestion
  api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)

  -- Split into lines
  local suggestion_lines = vim.split(text, '\n', { plain = true })

  if #suggestion_lines == 0 then
    return
  end

  -- First line: overlay at cursor position
  local first_line = suggestion_lines[1]
  if first_line and first_line ~= '' then
    api.nvim_buf_set_extmark(bufnr, M.ns_id, line_num - 1, col, {
      id = 1,
      virt_text = {{ first_line, 'ZekeGhostText' }},
      virt_text_pos = 'overlay',
      hl_mode = 'combine',
      priority = 100,
    })
  end

  -- Remaining lines: virtual lines below
  if #suggestion_lines > 1 then
    local virt_lines = {}
    for i = 2, #suggestion_lines do
      table.insert(virt_lines, {{ suggestion_lines[i], 'ZekeGhostText' }})
    end

    api.nvim_buf_set_extmark(bufnr, M.ns_id, line_num - 1, col, {
      id = 2,
      virt_lines = virt_lines,
      virt_lines_above = false,
      hl_mode = 'combine',
      priority = 100,
    })
  end

  -- Add suggestion counter if multiple suggestions
  if #M.state.suggestions > 1 then
    local counter_text = string.format(' [%d/%d]', M.state.current_idx, #M.state.suggestions)
    api.nvim_buf_set_extmark(bufnr, M.ns_id, line_num - 1, col, {
      id = 3,
      virt_text = {{ counter_text, 'ZekeGhostTextCounter' }},
      virt_text_pos = 'eol',
      hl_mode = 'combine',
      priority = 99,
    })
  end
end

-- Accept current suggestion
function M.accept()
  if not M.state.suggestions or #M.state.suggestions == 0 then
    return false
  end

  local suggestion = M.state.suggestions[M.state.current_idx]
  if not suggestion or suggestion == '' then
    return false
  end

  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col = cursor[2]

  -- Split suggestion into lines
  local lines = vim.split(suggestion, '\n', { plain = true })

  -- Get current line
  local current_line = api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1] or ''
  local before_cursor = current_line:sub(1, col)
  local after_cursor = current_line:sub(col + 1)

  -- Insert suggestion
  if #lines == 1 then
    -- Single line: insert at cursor
    local new_line = before_cursor .. lines[1] .. after_cursor
    api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, { new_line })

    -- Move cursor to end of insertion
    api.nvim_win_set_cursor(0, { line_num, #before_cursor + #lines[1] })
  else
    -- Multi-line: insert first line at cursor, rest as new lines
    local new_first_line = before_cursor .. lines[1]
    local new_lines = { new_first_line }

    for i = 2, #lines - 1 do
      table.insert(new_lines, lines[i])
    end

    -- Last line includes the after_cursor text
    table.insert(new_lines, lines[#lines] .. after_cursor)

    api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, new_lines)

    -- Move cursor to end of last inserted line (before after_cursor)
    api.nvim_win_set_cursor(0, { line_num + #lines - 1, #lines[#lines] })
  end

  -- Clear suggestion
  M.clear()

  return true
end

-- Accept only the next word
function M.accept_word()
  if not M.state.suggestions or #M.state.suggestions == 0 then
    return false
  end

  local suggestion = M.state.suggestions[M.state.current_idx]
  if not suggestion or suggestion == '' then
    return false
  end

  -- Extract first word (up to whitespace or punctuation)
  local word = suggestion:match('^[%w_]+')
  if not word then
    word = suggestion:match('^[^%s]+')
  end

  if not word then
    return false
  end

  -- Insert just the word
  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col = cursor[2]

  local current_line = api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1] or ''
  local new_line = current_line:sub(1, col) .. word .. current_line:sub(col + 1)

  api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, { new_line })
  api.nvim_win_set_cursor(0, { line_num, col + #word })

  -- Update suggestion to remove accepted word
  M.state.suggestions[M.state.current_idx] = suggestion:sub(#word + 1)

  -- Clear and re-render
  M.clear()
  if M.state.suggestions[M.state.current_idx] ~= '' then
    M.render_suggestion(M.state.suggestions[M.state.current_idx], bufnr, line_num, col + #word)
  end

  return true
end

-- Accept current line only
function M.accept_line()
  if not M.state.suggestions or #M.state.suggestions == 0 then
    return false
  end

  local suggestion = M.state.suggestions[M.state.current_idx]
  if not suggestion or suggestion == '' then
    return false
  end

  -- Extract first line
  local first_line = vim.split(suggestion, '\n', { plain = true })[1]

  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col = cursor[2]

  local current_line = api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1] or ''
  local new_line = current_line:sub(1, col) .. first_line .. current_line:sub(col + 1)

  api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, { new_line })
  api.nvim_win_set_cursor(0, { line_num, col + #first_line })

  M.clear()

  return true
end

-- Dismiss current suggestion
function M.dismiss()
  M.clear()
  M.state.suggestions = {}
  M.state.current_idx = 0
end

-- Cycle to next suggestion
function M.next()
  if not M.state.suggestions or #M.state.suggestions <= 1 then
    return
  end

  M.state.current_idx = M.state.current_idx % #M.state.suggestions + 1

  if M.state.bufnr and M.state.line and M.state.col then
    M.render_suggestion(
      M.state.suggestions[M.state.current_idx],
      M.state.bufnr,
      M.state.line,
      M.state.col
    )
  end
end

-- Cycle to previous suggestion
function M.previous()
  if not M.state.suggestions or #M.state.suggestions <= 1 then
    return
  end

  M.state.current_idx = M.state.current_idx - 1
  if M.state.current_idx < 1 then
    M.state.current_idx = #M.state.suggestions
  end

  if M.state.bufnr and M.state.line and M.state.col then
    M.render_suggestion(
      M.state.suggestions[M.state.current_idx],
      M.state.bufnr,
      M.state.line,
      M.state.col
    )
  end
end

-- Clear all suggestions
function M.clear()
  if M.state.timer then
    vim.fn.timer_stop(M.state.timer)
    M.state.timer = nil
  end

  if M.state.active_job then
    cli.cancel_stream(M.state.active_job)
    M.state.active_job = nil
  end

  if M.state.bufnr and api.nvim_buf_is_valid(M.state.bufnr) then
    api.nvim_buf_clear_namespace(M.state.bufnr, M.ns_id, 0, -1)
  end
end

-- Enable/disable completions
function M.enable()
  M.state.enabled = true
  logger.info('inline', 'Inline completions enabled')
end

function M.disable()
  M.state.enabled = false
  M.clear()
  logger.info('inline', 'Inline completions disabled')
end

function M.toggle()
  if M.state.enabled then
    M.disable()
  else
    M.enable()
  end
end

return M

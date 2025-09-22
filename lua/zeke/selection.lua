-- Selection tracking module for Zeke.nvim
-- Manages text selection tracking and communication with AI
local M = {}

local logger = require('zeke.logger')
local terminal = require('zeke.terminal')

-- State management
M.state = {
  latest_selection = nil,
  tracking_enabled = false,
  debounce_timer = nil,
  debounce_ms = 100,

  last_active_visual_selection = nil,
  demotion_timer = nil,
  visual_demotion_delay_ms = 50,

  callbacks = {},
}

-- Enable selection tracking
function M.enable(opts)
  opts = opts or {}

  if M.state.tracking_enabled then
    logger.debug("selection", "Selection tracking already enabled")
    return
  end

  M.state.tracking_enabled = true
  M.state.debounce_ms = opts.debounce_ms or 100
  M.state.visual_demotion_delay_ms = opts.visual_demotion_delay_ms or 50

  M._create_autocommands()
  logger.info("selection", "Selection tracking enabled")
end

-- Disable selection tracking
function M.disable()
  if not M.state.tracking_enabled then
    return
  end

  M.state.tracking_enabled = false

  M._clear_autocommands()

  -- Clear timers
  if M.state.debounce_timer then
    vim.loop.timer_stop(M.state.debounce_timer)
    M.state.debounce_timer = nil
  end

  if M.state.demotion_timer then
    vim.loop.timer_stop(M.state.demotion_timer)
    M.state.demotion_timer = nil
  end

  M.state.latest_selection = nil
  M.state.last_active_visual_selection = nil

  logger.info("selection", "Selection tracking disabled")
end

-- Create autocommands for selection tracking
function M._create_autocommands()
  local group = vim.api.nvim_create_augroup("ZekeSelection", { clear = true })

  -- Track cursor movements
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      M.on_cursor_moved()
    end,
  })

  -- Track mode changes
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      M.on_mode_changed()
    end,
  })

  -- Track text changes
  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    callback = function()
      M.on_text_changed()
    end,
  })
end

-- Clear autocommands
function M._clear_autocommands()
  vim.api.nvim_clear_autocmds({ group = "ZekeSelection" })
end

-- Handle cursor movement
function M.on_cursor_moved()
  M.debounce_update()
end

-- Handle mode changes
function M.on_mode_changed()
  M.debounce_update()
end

-- Handle text changes
function M.on_text_changed()
  local mode = vim.fn.mode()
  if mode == "n" or mode == "i" then
    -- Clear selection when text changes in normal or insert mode
    M.state.latest_selection = nil
    M._notify_callbacks("clear", nil)
  end
end

-- Debounced update function
function M.debounce_update()
  if M.state.debounce_timer then
    vim.loop.timer_stop(M.state.debounce_timer)
  end

  M.state.debounce_timer = vim.loop.new_timer()
  M.state.debounce_timer:start(M.state.debounce_ms, 0, vim.schedule_wrap(function()
    M.update_selection()
  end))
end

-- Update the current selection
function M.update_selection()
  local mode = vim.fn.mode()

  -- Handle visual modes
  if mode == "v" or mode == "V" or mode == "\22" then
    local selection = M.get_visual_selection()
    if selection then
      M.state.latest_selection = selection
      M.state.last_active_visual_selection = selection
      M._notify_callbacks("update", selection)
    end
  else
    -- Handle demotion of visual selection
    if M.state.last_active_visual_selection then
      if M.state.demotion_timer then
        vim.loop.timer_stop(M.state.demotion_timer)
      end

      M.state.demotion_timer = vim.loop.new_timer()
      M.state.demotion_timer:start(M.state.visual_demotion_delay_ms, 0, vim.schedule_wrap(function()
        M.state.last_active_visual_selection = nil
      end))
    end
  end
end

-- Get visual selection details
function M.get_visual_selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return nil
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")

  -- Normalize positions (ensure start comes before end)
  if start_pos[2] > end_pos[2] or
     (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
    start_pos, end_pos = end_pos, start_pos
  end

  local start_line = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_line = end_pos[2] - 1
  local end_col = end_pos[3]

  -- Get the selected text
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)

  if #lines == 0 then
    return nil
  end

  -- Adjust for partial line selections
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col + 1, end_col)
  else
    lines[1] = string.sub(lines[1], start_col + 1)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end

  local text = table.concat(lines, "\n")

  return {
    bufnr = bufnr,
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
    text = text,
    mode = mode,
    file_path = vim.api.nvim_buf_get_name(bufnr),
  }
end

-- Get the latest selection
function M.get_latest_selection()
  return M.state.latest_selection or M.state.last_active_visual_selection
end

-- Send selection to Zeke
function M.send_selection_to_zeke(selection)
  selection = selection or M.get_latest_selection()

  if not selection then
    logger.warn("selection", "No selection to send")
    return false
  end

  local file_info = selection.file_path ~= "" and
    string.format(" (from %s, lines %d-%d)",
      vim.fn.fnamemodify(selection.file_path, ":t"),
      selection.start_line + 1,
      selection.end_line + 1) or ""

  local message = string.format("Selected text%s:\n```\n%s\n```",
    file_info, selection.text)

  -- Send to terminal/AI
  terminal.send_to_ai({
    type = "selection",
    content = selection.text,
    file_path = selection.file_path,
    start_line = selection.start_line,
    end_line = selection.end_line,
  })

  logger.debug("selection", "Sent selection to Zeke")
  return true
end

-- Send current visual selection
function M.send_visual_selection()
  local selection = M.get_visual_selection()
  if selection then
    return M.send_selection_to_zeke(selection)
  end

  logger.warn("selection", "No visual selection found")
  return false
end

-- Register callback for selection events
function M.register_callback(callback)
  table.insert(M.state.callbacks, callback)
end

-- Notify callbacks of selection changes
function M._notify_callbacks(event, selection)
  for _, callback in ipairs(M.state.callbacks) do
    local ok, err = pcall(callback, event, selection)
    if not ok then
      logger.error("selection", "Callback error: " .. err)
    end
  end
end

-- Send selection with line range
function M.send_at_mention_for_visual_selection(line1, line2)
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)

  if not line1 or not line2 then
    -- Try to get from visual marks
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    line1 = start_pos[2]
    line2 = end_pos[2]
  end

  if line1 and line2 and line1 > 0 and line2 > 0 then
    local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
    local text = table.concat(lines, "\n")

    local selection = {
      bufnr = bufnr,
      start_line = line1 - 1,
      end_line = line2 - 1,
      text = text,
      file_path = file_path,
    }

    return M.send_selection_to_zeke(selection)
  end

  return M.send_visual_selection()
end

return M
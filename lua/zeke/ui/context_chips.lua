--[[
  Context Chips UI - Display @-mention contexts as chips

  Shows visual indicators of what context is included in the prompt:
  📄 file.lua  ✂️ Selection  🔍 Diagnostics

  Inspired by Claude Code's context chip display.
--]]

local M = {}

local api = vim.api

-- State
M.state = {
  namespace = api.nvim_create_namespace('zeke_context_chips'),
  bufnr = nil,
  chips = {},
}

---Create a floating window for context chips
---@param chips table List of chip objects {type, label, icon}
---@param opts table Options {relative, win, row, col}
---@return number bufnr, number winnr
function M.create_chip_window(chips, opts)
  opts = opts or {}

  -- Build chip text
  local chip_parts = {}
  for _, chip in ipairs(chips) do
    table.insert(chip_parts, string.format("%s %s", chip.icon, chip.label))
  end

  local text = "Context: " .. table.concat(chip_parts, "  │  ")

  -- Create buffer if needed
  if not M.state.bufnr or not api.nvim_buf_is_valid(M.state.bufnr) then
    M.state.bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(M.state.bufnr, 'bufhidden', 'wipe')
  end

  -- Set text
  api.nvim_buf_set_lines(M.state.bufnr, 0, -1, false, { text })

  -- Make read-only
  api.nvim_buf_set_option(M.state.bufnr, 'modifiable', false)

  -- Calculate window size
  local width = vim.fn.strdisplaywidth(text) + 2
  local height = 1

  -- Get editor dimensions
  local ui = api.nvim_list_uis()[1]
  local editor_width = ui and ui.width or 80
  local editor_height = ui and ui.height or 24

  -- Position at top center by default
  local row = opts.row or 1
  local col = opts.col or math.floor((editor_width - width) / 2)

  -- Cap width to editor
  if width > editor_width - 4 then
    width = editor_width - 4
  end

  -- Create floating window
  local win_opts = {
    relative = opts.relative or 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    focusable = false,
    zindex = 50,
  }

  -- If relative to another window, adjust
  if opts.win then
    win_opts.relative = 'win'
    win_opts.win = opts.win
  end

  local winnr = api.nvim_open_win(M.state.bufnr, false, win_opts)

  -- Set highlight
  api.nvim_win_set_option(winnr, 'winhighlight', 'Normal:ZekeContextChip,FloatBorder:ZekeContextChipBorder')

  M.state.chips = chips

  return M.state.bufnr, winnr
end

---Show context chips above a window
---@param chips table List of chip objects
---@param target_winnr number Window to show chips above
function M.show_above_window(chips, target_winnr)
  if not chips or #chips == 0 then
    return
  end

  target_winnr = target_winnr or api.nvim_get_current_win()

  -- Get window position
  local win_config = api.nvim_win_get_config(target_winnr)

  -- Calculate position
  local row = 0
  local col = 0

  if win_config.relative ~= '' then
    -- Floating window - position above it
    row = (win_config.row or 0) - 2
    col = win_config.col or 0
  else
    -- Normal window - position at top
    row = 0
    col = 0
  end

  return M.create_chip_window(chips, {
    relative = 'editor',
    row = row,
    col = col,
  })
end

---Show chips inline in a buffer
---@param bufnr number Buffer to show chips in
---@param line number Line number (0-indexed)
---@param chips table List of chip objects
function M.show_inline(bufnr, line, chips)
  if not chips or #chips == 0 then
    return
  end

  -- Build virtual text
  local virt_text = {}

  table.insert(virt_text, { "Context: ", "Comment" })

  for i, chip in ipairs(chips) do
    table.insert(virt_text, { chip.icon .. " ", "Special" })
    table.insert(virt_text, { chip.label, "ZekeContextChip" })

    if i < #chips then
      table.insert(virt_text, { "  │  ", "Comment" })
    end
  end

  -- Set extmark with virtual text
  api.nvim_buf_set_extmark(bufnr, M.state.namespace, line, 0, {
    virt_text = virt_text,
    virt_text_pos = 'eol',
    hl_mode = 'combine',
  })
end

---Clear all chip displays
function M.clear()
  -- Clear extmarks
  if M.state.bufnr and api.nvim_buf_is_valid(M.state.bufnr) then
    api.nvim_buf_clear_namespace(M.state.bufnr, M.state.namespace, 0, -1)
  end

  M.state.chips = {}
end

---Set up highlight groups
function M.setup_highlights()
  -- Default highlights (users can override)
  vim.api.nvim_set_hl(0, 'ZekeContextChip', {
    fg = '#61AFEF',
    bg = '#282C34',
    bold = true,
    default = true,
  })

  vim.api.nvim_set_hl(0, 'ZekeContextChipBorder', {
    fg = '#61AFEF',
    default = true,
  })
end

-- Initialize highlights
M.setup_highlights()

return M

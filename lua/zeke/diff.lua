-- Diff management module for Zeke.nvim
-- Provides native Neovim diff functionality with accept/reject capabilities
local M = {}

local logger = require('zeke.logger')

-- Configuration
M.config = {
  keep_terminal_focus = false,
  open_in_new_tab = false,
  hide_terminal_in_new_tab = false,
  auto_close_on_accept = true,
  show_diff_stats = true,
  vertical_split = true,
}

-- State management
M.state = {
  active_diffs = {},
  current_diff = nil,
  autocmd_group = nil,
}

-- Setup diff module
function M.setup(opts)
  opts = opts or {}

  -- Merge configuration
  for key, value in pairs(opts) do
    if M.config[key] ~= nil then
      M.config[key] = value
    end
  end

  -- Create autocmd group
  M.state.autocmd_group = vim.api.nvim_create_augroup("ZekeDiff", { clear = true })

  logger.debug("diff", "Diff module initialized")
end

-- Find main editor window (excludes terminals and sidebars)
local function find_main_editor_window()
  local windows = vim.api.nvim_list_wins()

  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
    local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
    local win_config = vim.api.nvim_win_get_config(win)

    local is_suitable = true

    -- Skip floating windows
    if win_config.relative and win_config.relative ~= "" then
      is_suitable = false
    end

    -- Skip terminals and prompts
    if is_suitable and (buftype == "terminal" or buftype == "prompt") then
      is_suitable = false
    end

    -- Skip file explorers and sidebars
    local excluded_filetypes = {
      "neo-tree", "neo-tree-popup", "NvimTree", "oil",
      "minifiles", "aerial", "tagbar", "qf", "help"
    }

    for _, ft in ipairs(excluded_filetypes) do
      if filetype == ft then
        is_suitable = false
        break
      end
    end

    if is_suitable then
      return win
    end
  end

  return nil
end

-- Find Zeke terminal window
local function find_zeke_terminal_window()
  local terminal = require('zeke.terminal')
  local terminal_bufnr = terminal.get_active_terminal_bufnr and terminal.get_active_terminal_bufnr()

  if not terminal_bufnr then
    return nil
  end

  -- Find window containing the terminal buffer
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == terminal_bufnr then
      return win
    end
  end

  return nil
end

-- Create diff view between two files
function M.create_diff(original_file, modified_file, opts)
  opts = opts or {}

  local diff_id = vim.fn.tempname()

  -- Create diff state
  local diff_state = {
    id = diff_id,
    original_file = original_file,
    modified_file = modified_file,
    original_buf = nil,
    modified_buf = nil,
    original_win = nil,
    modified_win = nil,
    tab = nil,
    accepted = false,
    rejected = false,
  }

  -- Store in active diffs
  M.state.active_diffs[diff_id] = diff_state
  M.state.current_diff = diff_state

  -- Open diff based on configuration
  if M.config.open_in_new_tab then
    M._open_diff_in_new_tab(diff_state)
  else
    M._open_diff_in_current_tab(diff_state)
  end

  -- Set up keymaps for this diff
  M._setup_diff_keymaps(diff_state)

  -- Keep terminal focus if configured
  if M.config.keep_terminal_focus then
    local terminal_win = find_zeke_terminal_window()
    if terminal_win then
      vim.api.nvim_set_current_win(terminal_win)
    end
  end

  logger.info("diff", "Created diff view: " .. diff_id)

  return diff_id
end

-- Open diff in current tab
function M._open_diff_in_current_tab(diff_state)
  local main_win = find_main_editor_window()

  if not main_win then
    -- Create new window if no suitable one exists
    vim.cmd("new")
    main_win = vim.api.nvim_get_current_win()
  end

  -- Open original file
  vim.api.nvim_set_current_win(main_win)
  vim.cmd("edit " .. vim.fn.fnameescape(diff_state.original_file))
  diff_state.original_buf = vim.api.nvim_get_current_buf()
  diff_state.original_win = main_win

  -- Create split for modified file
  if M.config.vertical_split then
    vim.cmd("vsplit " .. vim.fn.fnameescape(diff_state.modified_file))
  else
    vim.cmd("split " .. vim.fn.fnameescape(diff_state.modified_file))
  end

  diff_state.modified_buf = vim.api.nvim_get_current_buf()
  diff_state.modified_win = vim.api.nvim_get_current_win()

  -- Enable diff mode
  vim.api.nvim_win_set_option(diff_state.original_win, "diff", true)
  vim.api.nvim_win_set_option(diff_state.modified_win, "diff", true)

  -- Scroll bind
  vim.api.nvim_win_set_option(diff_state.original_win, "scrollbind", true)
  vim.api.nvim_win_set_option(diff_state.modified_win, "scrollbind", true)
end

-- Open diff in new tab
function M._open_diff_in_new_tab(diff_state)
  -- Create new tab
  vim.cmd("tabnew")
  diff_state.tab = vim.api.nvim_get_current_tabpage()

  -- Open original file
  vim.cmd("edit " .. vim.fn.fnameescape(diff_state.original_file))
  diff_state.original_buf = vim.api.nvim_get_current_buf()
  diff_state.original_win = vim.api.nvim_get_current_win()

  -- Create split for modified file
  if M.config.vertical_split then
    vim.cmd("vsplit " .. vim.fn.fnameescape(diff_state.modified_file))
  else
    vim.cmd("split " .. vim.fn.fnameescape(diff_state.modified_file))
  end

  diff_state.modified_buf = vim.api.nvim_get_current_buf()
  diff_state.modified_win = vim.api.nvim_get_current_win()

  -- Enable diff mode
  vim.api.nvim_win_set_option(diff_state.original_win, "diff", true)
  vim.api.nvim_win_set_option(diff_state.modified_win, "diff", true)

  -- Scroll bind
  vim.api.nvim_win_set_option(diff_state.original_win, "scrollbind", true)
  vim.api.nvim_win_set_option(diff_state.modified_win, "scrollbind", true)
end

-- Setup keymaps for diff operations
function M._setup_diff_keymaps(diff_state)
  local keymaps = {
    ["<CR>"] = function() M.accept_diff(diff_state.id) end,
    ["<leader>da"] = function() M.accept_diff(diff_state.id) end,
    ["<leader>dr"] = function() M.reject_diff(diff_state.id) end,
    ["<leader>dd"] = function() M.close_diff(diff_state.id) end,
    ["[c"] = function() vim.cmd("normal! [c") end,  -- Previous change
    ["]c"] = function() vim.cmd("normal! ]c") end,  -- Next change
  }

  -- Apply keymaps to both buffers
  for key, func in pairs(keymaps) do
    vim.api.nvim_buf_set_keymap(diff_state.original_buf, "n", key, "", {
      callback = func,
      noremap = true,
      silent = true,
      desc = "Diff operation"
    })

    vim.api.nvim_buf_set_keymap(diff_state.modified_buf, "n", key, "", {
      callback = func,
      noremap = true,
      silent = true,
      desc = "Diff operation"
    })
  end
end

-- Accept diff changes
function M.accept_diff(diff_id)
  local diff_state = diff_id and M.state.active_diffs[diff_id] or M.state.current_diff

  if not diff_state then
    logger.warn("diff", "No active diff to accept")
    return false
  end

  if diff_state.accepted or diff_state.rejected then
    logger.warn("diff", "Diff already processed")
    return false
  end

  -- Copy modified content to original file
  local modified_content = vim.api.nvim_buf_get_lines(diff_state.modified_buf, 0, -1, false)

  -- Write to original file
  vim.fn.writefile(modified_content, diff_state.original_file)

  diff_state.accepted = true

  logger.info("diff", "Accepted diff changes")

  -- Show stats if configured
  if M.config.show_diff_stats then
    M._show_diff_stats(diff_state)
  end

  -- Auto close if configured
  if M.config.auto_close_on_accept then
    M.close_diff(diff_state.id)
  end

  return true
end

-- Reject diff changes
function M.reject_diff(diff_id)
  local diff_state = diff_id and M.state.active_diffs[diff_id] or M.state.current_diff

  if not diff_state then
    logger.warn("diff", "No active diff to reject")
    return false
  end

  if diff_state.accepted or diff_state.rejected then
    logger.warn("diff", "Diff already processed")
    return false
  end

  diff_state.rejected = true

  logger.info("diff", "Rejected diff changes")

  -- Close diff
  M.close_diff(diff_state.id)

  return true
end

-- Close diff view
function M.close_diff(diff_id)
  local diff_state = diff_id and M.state.active_diffs[diff_id] or M.state.current_diff

  if not diff_state then
    return false
  end

  -- Close windows
  if vim.api.nvim_win_is_valid(diff_state.modified_win) then
    vim.api.nvim_win_close(diff_state.modified_win, false)
  end

  if vim.api.nvim_win_is_valid(diff_state.original_win) then
    vim.api.nvim_win_close(diff_state.original_win, false)
  end

  -- Close tab if it was created for diff
  if diff_state.tab and M.config.open_in_new_tab then
    local current_tab = vim.api.nvim_get_current_tabpage()
    if current_tab == diff_state.tab then
      vim.cmd("tabclose")
    end
  end

  -- Remove from active diffs
  M.state.active_diffs[diff_state.id] = nil

  -- Update current diff
  if M.state.current_diff == diff_state then
    M.state.current_diff = nil
  end

  logger.debug("diff", "Closed diff: " .. diff_state.id)

  return true
end

-- Accept current diff
function M.accept_current_diff()
  return M.accept_diff(nil)
end

-- Reject/deny current diff
function M.deny_current_diff()
  return M.reject_diff(nil)
end

-- Close all diff tabs
function M.close_all_diffs()
  local count = 0

  for diff_id, _ in pairs(M.state.active_diffs) do
    if M.close_diff(diff_id) then
      count = count + 1
    end
  end

  logger.info("diff", string.format("Closed %d diff(s)", count))

  return count
end

-- Show diff statistics
function M._show_diff_stats(diff_state)
  -- Get line counts
  local original_lines = vim.api.nvim_buf_line_count(diff_state.original_buf)
  local modified_lines = vim.api.nvim_buf_line_count(diff_state.modified_buf)

  local added = 0
  local removed = 0
  local modified = 0

  -- Simple line count diff (could be enhanced with actual diff algorithm)
  if modified_lines > original_lines then
    added = modified_lines - original_lines
  elseif original_lines > modified_lines then
    removed = original_lines - modified_lines
  else
    modified = original_lines
  end

  local stats = string.format(
    "Diff stats: +%d -%d ~%d lines",
    added, removed, modified
  )

  vim.notify(stats, vim.log.levels.INFO)
end

-- Get active diff count
function M.get_active_diff_count()
  local count = 0
  for _, _ in pairs(M.state.active_diffs) do
    count = count + 1
  end
  return count
end

-- Get current diff info
function M.get_current_diff_info()
  if not M.state.current_diff then
    return nil
  end

  return {
    id = M.state.current_diff.id,
    original = M.state.current_diff.original_file,
    modified = M.state.current_diff.modified_file,
    accepted = M.state.current_diff.accepted,
    rejected = M.state.current_diff.rejected,
  }
end

return M
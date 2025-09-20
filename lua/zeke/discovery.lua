local M = {}

local config = require('zeke.config')

-- Cache for discovered sessions
local session_cache = {}
local last_discovery_time = 0
local CACHE_TIMEOUT = 5000 -- 5 seconds

-- Initialize discovery system
function M.setup()
  -- Clean up stale sessions on startup
  vim.defer_fn(function()
    M.cleanup_stale_sessions()
  end, 1000)
end

-- Find active Zeke CLI session
function M.find_active_session()
  -- Check cache first
  if M.is_cache_valid() and session_cache.active then
    return session_cache.active
  end

  -- Discover sessions using Rust backend
  local ok, sessions = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.discover_sessions()
  end)

  if ok and sessions and #sessions > 0 then
    -- Return the most recent active session
    local active_session = sessions[1]
    session_cache.active = active_session
    session_cache.all = sessions
    last_discovery_time = vim.loop.hrtime()
    return active_session
  end

  return nil
end

-- Start new Zeke CLI instance
function M.start_zeke_cli(port)
  local cfg = config.get()
  port = port or cfg.zeke_cli.websocket_port

  vim.notify('Starting Zeke CLI on port ' .. port .. '...', vim.log.levels.INFO)

  local ok, session = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.start_zeke_cli(port)
  end)

  if ok and session then
    vim.notify('✅ Zeke CLI started successfully', vim.log.levels.INFO)
    -- Update cache
    session_cache.active = session
    last_discovery_time = vim.loop.hrtime()
    return session
  else
    vim.notify('❌ Failed to start Zeke CLI: ' .. tostring(session), vim.log.levels.ERROR)
    return nil
  end
end

-- Ensure there's an active connection
function M.ensure_connection()
  -- First try to find existing session
  local session = M.find_active_session()
  if session then
    return session
  end

  -- Check if auto-start is enabled
  local cfg = config.get()
  if cfg.zeke_cli.auto_start then
    return M.start_zeke_cli()
  end

  return nil
end

-- List all sessions (active and inactive)
function M.list_all_sessions()
  local ok, sessions = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.list_all_sessions()
  end)

  if ok and sessions then
    return sessions
  end

  return {}
end

-- Stop a specific session
function M.stop_session(session_id)
  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.stop_session(session_id)
  end)

  if ok and result then
    vim.notify('Stopped Zeke CLI session: ' .. session_id, vim.log.levels.INFO)
    M.invalidate_cache()
    return true
  else
    vim.notify('Failed to stop session: ' .. tostring(result), vim.log.levels.ERROR)
    return false
  end
end

-- Clean up stale sessions
function M.cleanup_stale_sessions()
  local ok, cleaned = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.cleanup_stale_sessions()
  end)

  if ok and cleaned and cleaned > 0 then
    vim.notify('Cleaned up ' .. cleaned .. ' stale Zeke CLI sessions', vim.log.levels.INFO)
  end

  M.invalidate_cache()
end

-- Show discovery status in a popup
function M.show_discovery_status()
  local sessions = M.list_all_sessions()
  local lines = {
    '🔍 Zeke CLI Discovery Status',
    '',
    '📊 Total sessions found: ' .. #sessions,
    '',
  }

  if #sessions == 0 then
    table.insert(lines, '❌ No Zeke CLI sessions found')
    table.insert(lines, '')
    table.insert(lines, '💡 Tips:')
    table.insert(lines, '  • Run :ZekeStartCLI to start a new session')
    table.insert(lines, '  • Check if Zeke CLI is installed')
    table.insert(lines, '  • Verify session directory: ' .. config.get().zeke_cli.session_dir)
  else
    table.insert(lines, '📋 Active sessions:')
    table.insert(lines, '')

    for i, session_info in ipairs(sessions) do
      local session, is_active = session_info[1], session_info[2]
      local status_icon = is_active and '🟢' or '🔴'
      local status_text = is_active and 'Active' or 'Inactive'

      table.insert(lines, string.format('  %s %s - Port %d (%s)',
        status_icon, session.session_id, session.port, status_text))

      if is_active then
        table.insert(lines, string.format('      📅 Started: %s', os.date('%Y-%m-%d %H:%M:%S', session.start_time)))
        table.insert(lines, string.format('      🆔 PID: %d', session.pid))
        table.insert(lines, string.format('      🏷️  Version: %s', session.version))
      end
      table.insert(lines, '')
    end
  end

  -- Show session directory info
  local cfg = config.get()
  table.insert(lines, '📁 Session directory: ' .. cfg.zeke_cli.session_dir)
  table.insert(lines, '⚙️  Auto-start: ' .. (cfg.zeke_cli.auto_start and 'enabled' or 'disabled'))

  M.show_popup('Zeke CLI Discovery', lines)
end

-- Show interactive session manager
function M.show_session_manager()
  local sessions = M.list_all_sessions()

  -- Create buffer and window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'zeke-sessions')

  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(30, vim.o.lines - 4)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' 🔧 Zeke CLI Session Manager ',
    title_pos = 'center',
  })

  -- Render content
  local lines = {
    '╭─────────────────────────────────────────────────────────────────────╮',
    '│                      🔧 Zeke CLI Session Manager                      │',
    '╰─────────────────────────────────────────────────────────────────────╯',
    '',
  }

  if #sessions == 0 then
    table.insert(lines, '  ❌ No sessions found')
    table.insert(lines, '')
    table.insert(lines, '  💡 Press [n] to start a new session')
  else
    table.insert(lines, '  📋 Active Sessions:')
    table.insert(lines, '')

    for i, session_info in ipairs(sessions) do
      local session, is_active = session_info[1], session_info[2]
      local status_icon = is_active and '🟢' or '🔴'

      table.insert(lines, string.format('  [%d] %s %s - Port %d',
        i, status_icon, session.session_id:sub(1, 8), session.port))
    end
  end

  table.insert(lines, '')
  table.insert(lines, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  table.insert(lines, '')
  table.insert(lines, '🎮 Controls:')
  table.insert(lines, '  [n] New Session    [d] Delete Session    [r] Refresh')
  table.insert(lines, '  [c] Cleanup Stale  [1-9] Connect to Session')
  table.insert(lines, '  [q/Esc] Close')

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Setup keymaps
  local keymaps = {
    ['n'] = function()
      vim.api.nvim_win_close(win, true)
      M.start_zeke_cli()
    end,
    ['r'] = function()
      vim.api.nvim_win_close(win, true)
      M.show_session_manager()
    end,
    ['c'] = function()
      M.cleanup_stale_sessions()
      vim.api.nvim_win_close(win, true)
      M.show_session_manager()
    end,
    ['q'] = function() vim.api.nvim_win_close(win, true) end,
    ['<Esc>'] = function() vim.api.nvim_win_close(win, true) end,
  }

  -- Add number keys for session selection
  for i = 1, math.min(9, #sessions) do
    keymaps[tostring(i)] = function()
      local session = sessions[i][1]
      vim.api.nvim_win_close(win, true)
      M.connect_to_session(session)
    end
  end

  for key, callback in pairs(keymaps) do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, '', {
      callback = callback,
      noremap = true,
      silent = true,
    })
  end
end

-- Connect to a specific session
function M.connect_to_session(session)
  local websocket = require('zeke.websocket')

  if websocket.connect(session) then
    vim.notify('Connected to Zeke CLI session: ' .. session.session_id, vim.log.levels.INFO)
    return true
  else
    vim.notify('Failed to connect to session: ' .. session.session_id, vim.log.levels.ERROR)
    return false
  end
end

-- Cache management
function M.is_cache_valid()
  local now = vim.loop.hrtime()
  return (now - last_discovery_time) < (CACHE_TIMEOUT * 1000000)  -- Convert to nanoseconds
end

function M.invalidate_cache()
  session_cache = {}
  last_discovery_time = 0
end

-- Utility functions
function M.show_popup(title, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 4, vim.o.lines - 4)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })

  -- Close on any key
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<cmd>close<cr>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<cr>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>close<cr>', { noremap = true, silent = true })
end

-- Health check for discovery system
function M.health_check()
  local cfg = config.get()
  local health = {
    session_dir_exists = vim.fn.isdirectory(cfg.zeke_cli.session_dir) == 1,
    auto_start_enabled = cfg.zeke_cli.auto_start,
    active_session = nil,
    total_sessions = 0,
  }

  local sessions = M.list_all_sessions()
  health.total_sessions = #sessions

  local active_session = M.find_active_session()
  if active_session then
    health.active_session = {
      session_id = active_session.session_id,
      port = active_session.port,
      pid = active_session.pid,
    }
  end

  return health
end

return M
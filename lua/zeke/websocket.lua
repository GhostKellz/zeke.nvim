local M = {}

local config = require('zeke.config')
local consent = require('zeke.consent')

-- WebSocket connection state
local ws_client = nil
local connection_status = 'disconnected' -- 'disconnected', 'connecting', 'connected', 'error'
local message_handlers = {}
local pending_requests = {}

-- Initialize WebSocket client
function M.setup()
  -- Register message handlers
  M.add_handler('chat_delta', M.handle_chat_delta)
  M.add_handler('action_request', M.handle_action_request)
  M.add_handler('stream_start', M.handle_stream_start)
  M.add_handler('stream_end', M.handle_stream_end)
  M.add_handler('error', M.handle_error)
end

-- Connect to Zeke CLI WebSocket server
function M.connect(session_info)
  if connection_status == 'connecting' or connection_status == 'connected' then
    return true
  end

  connection_status = 'connecting'

  -- Use Rust WebSocket client through FFI
  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.websocket_connect(session_info)
  end)

  if ok and result then
    connection_status = 'connected'
    vim.schedule(function()
      vim.notify('Connected to Zeke CLI on port ' .. session_info.port, vim.log.levels.INFO)
    end)
    return true
  else
    connection_status = 'error'
    vim.schedule(function()
      vim.notify('Failed to connect to Zeke CLI: ' .. tostring(result), vim.log.levels.ERROR)
    end)
    return false
  end
end

-- Disconnect from WebSocket server
function M.disconnect()
  if connection_status == 'connected' then
    local ok = pcall(function()
      local zeke_nvim = require('zeke_nvim')
      zeke_nvim.websocket_disconnect()
    end)

    if ok then
      connection_status = 'disconnected'
      vim.notify('Disconnected from Zeke CLI', vim.log.levels.INFO)
    end
  end
end

-- Send chat message with context
function M.send_chat(message, context)
  if not M.is_connected() then
    vim.notify('Not connected to Zeke CLI', vim.log.levels.WARN)
    return false
  end

  -- Extract current context if not provided
  if not context then
    context = M.get_current_context()
  end

  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.websocket_send_chat(message, context)
  end)

  return ok and result
end

-- Send provider switch request
function M.switch_provider(provider_name)
  if not M.is_connected() then
    vim.notify('Not connected to Zeke CLI', vim.log.levels.WARN)
    return false
  end

  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.websocket_switch_provider(provider_name)
  end)

  if ok and result then
    vim.notify('Switched to provider: ' .. provider_name, vim.log.levels.INFO)
  end

  return ok and result
end

-- Send action approval response
function M.send_action_approval(action_id, decision)
  if not M.is_connected() then
    return false
  end

  local approved = decision == consent.CONSENT_DECISIONS.ALLOW_ONCE or
                   decision == consent.CONSENT_DECISIONS.ALLOW_SESSION or
                   decision == consent.CONSENT_DECISIONS.ALLOW_PROJECT

  local session_approval = decision == consent.CONSENT_DECISIONS.ALLOW_SESSION or
                          decision == consent.CONSENT_DECISIONS.ALLOW_PROJECT

  local ok, result = pcall(function()
    local zeke_nvim = require('zeke_nvim')
    return zeke_nvim.websocket_send_action_approval(action_id, approved, session_approval)
  end)

  return ok and result
end

-- Get current editor context
function M.get_current_context()
  local context = {
    file_path = vim.api.nvim_buf_get_name(0),
    language = vim.bo.filetype,
    cursor_position = vim.api.nvim_win_get_cursor(0),
    project_root = vim.fn.getcwd(),
  }

  -- Add selection if in visual mode
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '' then
    context.selection = M.get_visual_selection()
  end

  -- Add LSP diagnostics
  context.diagnostics = M.get_diagnostics()

  -- Add git context
  context.git = M.get_git_context()

  return context
end

-- Get visual selection
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  if start_pos[2] == 0 or end_pos[2] == 0 then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  if #lines == 0 then
    return nil
  end

  -- Handle single line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  end

  return {
    text = table.concat(lines, '\n'),
    start_line = start_pos[2],
    end_line = end_pos[2],
    start_col = start_pos[3],
    end_col = end_pos[3],
  }
end

-- Get LSP diagnostics
function M.get_diagnostics()
  local diagnostics = vim.diagnostic.get(0)
  local formatted = {}

  for _, diag in ipairs(diagnostics) do
    table.insert(formatted, {
      line = diag.lnum + 1,
      column = diag.col + 1,
      severity = vim.diagnostic.severity[diag.severity],
      message = diag.message,
      source = diag.source,
    })
  end

  return formatted
end

-- Get git context
function M.get_git_context()
  local git_info = {}

  -- Get current branch
  local branch_cmd = io.popen('git branch --show-current 2>/dev/null')
  if branch_cmd then
    git_info.branch = branch_cmd:read('*l') or 'unknown'
    branch_cmd:close()
  end

  -- Get recent commits
  local log_cmd = io.popen('git log --oneline -5 2>/dev/null')
  if log_cmd then
    local commits = {}
    for line in log_cmd:lines() do
      table.insert(commits, line)
    end
    git_info.recent_commits = commits
    log_cmd:close()
  end

  -- Get staged changes
  local status_cmd = io.popen('git status --porcelain 2>/dev/null')
  if status_cmd then
    local changes = {}
    for line in status_cmd:lines() do
      table.insert(changes, line)
    end
    git_info.changes = changes
    status_cmd:close()
  end

  return git_info
end

-- Message handlers
function M.handle_chat_delta(message)
  local ui = require('zeke.ui')
  ui.append_chat_content(message.content)
end

function M.handle_action_request(message)
  local action = message.action

  -- Request consent from user
  local consent_result = consent.request_consent(action)

  -- Send approval response
  M.send_action_approval(action.id, consent_result.decision)

  -- Show user feedback
  if consent_result.decision == consent.CONSENT_DECISIONS.DENY then
    vim.notify('Action denied: ' .. action.description, vim.log.levels.WARN)
  else
    vim.notify('Action approved: ' .. action.description, vim.log.levels.INFO)
  end
end

function M.handle_stream_start(message)
  local ui = require('zeke.ui')
  ui.start_stream(message.session_id)
end

function M.handle_stream_end(message)
  local ui = require('zeke.ui')
  ui.end_stream(message.reason)
end

function M.handle_error(message)
  vim.schedule(function()
    vim.notify('Zeke CLI Error: ' .. message.message, vim.log.levels.ERROR)
  end)
end

-- Add message handler
function M.add_handler(message_type, handler)
  message_handlers[message_type] = handler
end

-- Process incoming message
function M.process_message(message)
  local handler = message_handlers[message.type]
  if handler then
    handler(message)
  else
    print('Unhandled message type: ' .. tostring(message.type))
  end
end

-- Connection status
function M.is_connected()
  return connection_status == 'connected'
end

function M.get_connection_status()
  return connection_status
end

-- Auto-reconnect logic
function M.ensure_connection()
  if M.is_connected() then
    return true
  end

  -- Try to discover and connect to Zeke CLI
  local discovery = require('zeke.discovery')
  local session = discovery.find_active_session()

  if session then
    return M.connect(session)
  else
    -- Try to start Zeke CLI if auto_start is enabled
    local cfg = config.get()
    if cfg.zeke_cli.auto_start then
      local new_session = discovery.start_zeke_cli()
      if new_session then
        return M.connect(new_session)
      end
    end
  end

  return false
end

-- Health check
function M.health_check()
  local health = {
    connected = M.is_connected(),
    status = connection_status,
  }

  if M.is_connected() then
    -- Get session info from Rust
    local ok, session_info = pcall(function()
      local zeke_nvim = require('zeke_nvim')
      return zeke_nvim.websocket_get_session_info()
    end)

    if ok and session_info then
      health.session = session_info
    end
  end

  return health
end

-- Cleanup
function M.cleanup()
  M.disconnect()
  message_handlers = {}
  pending_requests = {}
end

return M
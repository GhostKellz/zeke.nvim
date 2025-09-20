local M = {}

local api = vim.api
local config = require('zeke.config')

-- Consent decision types
local CONSENT_DECISIONS = {
  ALLOW_ONCE = 'allow_once',
  ALLOW_SESSION = 'allow_session',
  ALLOW_PROJECT = 'allow_project',
  DENY = 'deny',
}

-- Action types for different consent levels
local ACTION_TYPES = {
  READ_FILE = 'read_file',
  WRITE_FILE = 'write_file',
  EXECUTE_COMMAND = 'execute_command',
  NETWORK_REQUEST = 'network_request',
  SYSTEM_ACCESS = 'system_access',
  PROJECT_ANALYSIS = 'project_analysis',
}

-- UI state
local consent_buf = nil
local consent_win = nil
local pending_actions = {}

-- Session consent cache
local session_consents = {}
local project_consents = {}

-- Initialize consent system
function M.setup()
  -- Create autocommands for cleanup
  api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      M.cleanup()
    end,
  })
end

-- Main consent approval function
function M.request_consent(action)
  local action_id = action.id or vim.fn.sha256(vim.json.encode(action))

  -- Check if action is auto-approved based on config
  if M.is_auto_approved(action) then
    return { decision = CONSENT_DECISIONS.ALLOW_ONCE, auto_approved = true }
  end

  -- Check session/project consent cache
  local cached_decision = M.get_cached_consent(action)
  if cached_decision then
    return { decision = cached_decision, cached = true }
  end

  -- Store pending action
  pending_actions[action_id] = action

  -- Show consent UI
  local decision = M.show_consent_ui(action)

  -- Cache decision if not deny
  if decision ~= CONSENT_DECISIONS.DENY then
    M.cache_consent(action, decision)
  end

  -- Clean up
  pending_actions[action_id] = nil

  return { decision = decision, user_approved = true }
end

-- Check if action should be auto-approved
function M.is_auto_approved(action)
  local cfg = config.get()

  if not cfg.security.enable_consent then
    return true
  end

  -- Auto-approve read operations if configured
  if cfg.security.auto_approve_read and M.is_read_operation(action) then
    return true
  end

  -- Auto-approve write operations if configured (dangerous!)
  if cfg.security.auto_approve_write and M.is_write_operation(action) then
    return true
  end

  return false
end

-- Check if action is a read operation
function M.is_read_operation(action)
  local read_actions = {
    ACTION_TYPES.READ_FILE,
    ACTION_TYPES.PROJECT_ANALYSIS,
    'get_current_selection',
    'get_open_editors',
    'get_workspace_folders',
    'get_diagnostics',
  }

  return vim.tbl_contains(read_actions, action.action_type)
end

-- Check if action is a write operation
function M.is_write_operation(action)
  local write_actions = {
    ACTION_TYPES.WRITE_FILE,
    ACTION_TYPES.EXECUTE_COMMAND,
    'save_document',
    'open_diff',
    'create_file',
    'modify_file',
  }

  return vim.tbl_contains(write_actions, action.action_type)
end

-- Get cached consent decision
function M.get_cached_consent(action)
  local action_key = M.get_action_key(action)

  -- Check project-level consent
  if project_consents[action_key] then
    return CONSENT_DECISIONS.ALLOW_PROJECT
  end

  -- Check session-level consent
  if session_consents[action_key] then
    return CONSENT_DECISIONS.ALLOW_SESSION
  end

  return nil
end

-- Cache consent decision
function M.cache_consent(action, decision)
  local action_key = M.get_action_key(action)

  if decision == CONSENT_DECISIONS.ALLOW_SESSION then
    session_consents[action_key] = true
  elseif decision == CONSENT_DECISIONS.ALLOW_PROJECT then
    project_consents[action_key] = true
    -- Also persist to project file
    M.save_project_consents()
  end
end

-- Generate action key for caching
function M.get_action_key(action)
  -- Create a key based on action type and relevant parameters
  local key_parts = { action.action_type }

  if action.file_path then
    table.insert(key_parts, action.file_path)
  end

  return table.concat(key_parts, ':')
end

-- Show consent UI popup
function M.show_consent_ui(action)
  -- Create consent buffer
  consent_buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  api.nvim_buf_set_option(consent_buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(consent_buf, 'filetype', 'zeke-consent')

  -- Create consent content
  local lines = M.create_consent_content(action)
  api.nvim_buf_set_lines(consent_buf, 0, -1, false, lines)

  -- Create floating window
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 8, vim.o.lines - 4)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' GhostWarden Consent Required ',
    title_pos = 'center',
  }

  consent_win = api.nvim_open_win(consent_buf, true, win_config)

  -- Set window options
  api.nvim_win_set_option(consent_win, 'winhl', 'Normal:NormalFloat,FloatBorder:FloatBorder')

  -- Set up keymaps
  local decision = nil

  local function set_decision(d)
    decision = d
    M.close_consent_ui()
  end

  local keymaps = {
    ['1'] = function() set_decision(CONSENT_DECISIONS.ALLOW_ONCE) end,
    ['2'] = function() set_decision(CONSENT_DECISIONS.ALLOW_SESSION) end,
    ['3'] = function() set_decision(CONSENT_DECISIONS.ALLOW_PROJECT) end,
    ['d'] = function() set_decision(CONSENT_DECISIONS.DENY) end,
    ['<Esc>'] = function() set_decision(CONSENT_DECISIONS.DENY) end,
    ['q'] = function() set_decision(CONSENT_DECISIONS.DENY) end,
  }

  for key, callback in pairs(keymaps) do
    api.nvim_buf_set_keymap(consent_buf, 'n', key, '', {
      callback = callback,
      noremap = true,
      silent = true,
    })
  end

  -- Wait for user decision
  while decision == nil do
    vim.wait(50)
  end

  return decision
end

-- Create consent popup content
function M.create_consent_content(action)
  local lines = {
    '╭──────────────────────────────────────────────────────────────────────╮',
    '│                    🛡️  GhostWarden Security Alert                    │',
    '╰──────────────────────────────────────────────────────────────────────╯',
    '',
    '🤖 Zeke AI is requesting permission to perform the following action:',
    '',
  }

  -- Action description
  table.insert(lines, '📋 Action: ' .. (action.description or action.action_type))

  if action.file_path then
    table.insert(lines, '📁 File: ' .. action.file_path)
  end

  if action.changes then
    table.insert(lines, '📝 Changes: ' .. #action.changes .. ' file(s) will be modified')
  end

  -- Risk assessment
  local risk_level = M.assess_risk(action)
  local risk_icon = risk_level == 'high' and '🚨' or risk_level == 'medium' and '⚠️' or '✅'
  table.insert(lines, risk_icon .. ' Risk Level: ' .. risk_level)

  table.insert(lines, '')
  table.insert(lines, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
  table.insert(lines, '')
  table.insert(lines, '🔐 Choose your response:')
  table.insert(lines, '')
  table.insert(lines, '  [1] Allow Once      - Approve this action only')
  table.insert(lines, '  [2] Allow Session   - Approve for this session')
  table.insert(lines, '  [3] Allow Project   - Approve for this project')
  table.insert(lines, '  [d] Deny            - Block this action')
  table.insert(lines, '')
  table.insert(lines, '💡 Press ESC or q to deny')

  -- Show action details if available
  if action.changes then
    table.insert(lines, '')
    table.insert(lines, '📋 Detailed Changes:')
    for i, change in ipairs(action.changes) do
      if i <= 3 then -- Show first 3 changes
        table.insert(lines, '  • ' .. change.change_type .. ': ' .. change.file_path)
      elseif i == 4 then
        table.insert(lines, '  • ... and ' .. (#action.changes - 3) .. ' more')
        break
      end
    end
  end

  return lines
end

-- Assess risk level of an action
function M.assess_risk(action)
  -- High risk actions
  local high_risk = {
    ACTION_TYPES.EXECUTE_COMMAND,
    ACTION_TYPES.SYSTEM_ACCESS,
    'delete_file',
    'execute_terminal',
  }

  -- Medium risk actions
  local medium_risk = {
    ACTION_TYPES.WRITE_FILE,
    ACTION_TYPES.NETWORK_REQUEST,
    'modify_file',
    'save_document',
  }

  if vim.tbl_contains(high_risk, action.action_type) then
    return 'high'
  elseif vim.tbl_contains(medium_risk, action.action_type) then
    return 'medium'
  else
    return 'low'
  end
end

-- Close consent UI
function M.close_consent_ui()
  if consent_win and api.nvim_win_is_valid(consent_win) then
    api.nvim_win_close(consent_win, true)
    consent_win = nil
  end
  if consent_buf and api.nvim_buf_is_valid(consent_buf) then
    api.nvim_buf_delete(consent_buf, { force = true })
    consent_buf = nil
  end
end

-- Load project consents from file
function M.load_project_consents()
  local project_root = vim.fn.getcwd()
  local consent_file = project_root .. '/.zeke-consents.json'

  if vim.fn.filereadable(consent_file) == 1 then
    local content = vim.fn.readfile(consent_file)
    if #content > 0 then
      local ok, consents = pcall(vim.json.decode, table.concat(content, '\n'))
      if ok then
        project_consents = consents
      end
    end
  end
end

-- Save project consents to file
function M.save_project_consents()
  local project_root = vim.fn.getcwd()
  local consent_file = project_root .. '/.zeke-consents.json'

  local content = vim.json.encode(project_consents)
  vim.fn.writefile(vim.split(content, '\n'), consent_file)
end

-- Clear session consents
function M.clear_session_consents()
  session_consents = {}
end

-- Clear project consents
function M.clear_project_consents()
  project_consents = {}
  M.save_project_consents()
end

-- Get consent status for debugging
function M.get_consent_status()
  return {
    session_consents = vim.tbl_keys(session_consents),
    project_consents = vim.tbl_keys(project_consents),
    pending_actions = vim.tbl_keys(pending_actions),
  }
end

-- Cleanup function
function M.cleanup()
  M.close_consent_ui()
  pending_actions = {}
end

-- Export consent decisions for other modules
M.CONSENT_DECISIONS = CONSENT_DECISIONS
M.ACTION_TYPES = ACTION_TYPES

return M
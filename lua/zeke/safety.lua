--[[
  Safety Warnings and Confirmation System

  Features:
  - Warn before large operations
  - Confirm destructive actions
  - Rate limit tracking
  - Safety checks for AI edits
--]]

local M = {}

local api = vim.api
local logger = require('zeke.logger')
local tokens = require('zeke.tokens')
local backup = require('zeke.backup')

-- Configuration
M.config = {
  -- Token thresholds
  warn_tokens = 4000,
  critical_tokens = 8000,
  max_tokens = 16000,

  -- File size thresholds (lines)
  warn_file_size = 500,
  critical_file_size = 1000,

  -- Operation confirmations
  confirm_large_edits = true,
  confirm_destructive = true,
  auto_backup_before_edit = true,

  -- Rate limiting (requests per minute)
  rate_limit_warn = 10,
  rate_limit_critical = 20,
}

-- Rate limiting tracking
M.rate_tracker = {
  requests = {},
  window_seconds = 60,
}

---Setup safety system
---@param opts table|nil Configuration options
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  logger.info('safety', 'Safety system initialized')
end

---Check if operation is safe
---@param opts table Options {prompt, bufnr, operation_type}
---@return boolean Is safe
---@return table|nil Warnings/errors
function M.check_safety(opts)
  opts = opts or {}
  local warnings = {}
  local errors = {}

  -- Check prompt size
  if opts.prompt then
    local token_count = tokens.estimate_tokens(opts.prompt)

    if token_count >= M.config.max_tokens then
      table.insert(errors, {
        type = "prompt_too_large",
        message = string.format(
          "Prompt is too large (%d tokens). Maximum is %d tokens.",
          token_count,
          M.config.max_tokens
        ),
        severity = "critical",
      })
    elseif token_count >= M.config.critical_tokens then
      table.insert(warnings, {
        type = "prompt_large",
        message = string.format(
          "Prompt is very large (%d tokens). This may be slow and expensive.",
          token_count
        ),
        severity = "warning",
      })
    elseif token_count >= M.config.warn_tokens then
      table.insert(warnings, {
        type = "prompt_moderate",
        message = string.format(
          "Prompt is moderately large (%d tokens).",
          token_count
        ),
        severity = "info",
      })
    end
  end

  -- Check file size for edits
  if opts.bufnr and opts.operation_type == "edit" then
    local line_count = api.nvim_buf_line_count(opts.bufnr)

    if line_count >= M.config.critical_file_size then
      table.insert(warnings, {
        type = "file_large",
        message = string.format(
          "File is very large (%d lines). AI edits may be inaccurate.",
          line_count
        ),
        severity = "warning",
      })
    elseif line_count >= M.config.warn_file_size then
      table.insert(warnings, {
        type = "file_moderate",
        message = string.format(
          "File is moderately large (%d lines).",
          line_count
        ),
        severity = "info",
      })
    end
  end

  -- Check rate limiting
  local rate_check = M.check_rate_limit()
  if rate_check.exceeded then
    table.insert(warnings, {
      type = "rate_limit",
      message = string.format(
        "High request rate: %d requests in last minute.",
        rate_check.count
      ),
      severity = rate_check.count >= M.config.rate_limit_critical and "warning" or "info",
    })
  end

  -- Determine if safe
  local is_safe = #errors == 0

  if not is_safe or #warnings > 0 then
    return is_safe, {
      warnings = warnings,
      errors = errors,
      can_proceed = is_safe,
    }
  end

  return true, nil
end

---Show safety confirmation dialog
---@param safety_check table Safety check result
---@param callback function Callback (confirmed: boolean)
function M.show_safety_dialog(safety_check, callback)
  if not safety_check or (#safety_check.warnings == 0 and #safety_check.errors == 0) then
    if callback then
      callback(true)
    end
    return
  end

  local message_lines = {}

  -- Add errors
  if #safety_check.errors > 0 then
    table.insert(message_lines, "⛔ ERRORS:")
    for _, error in ipairs(safety_check.errors) do
      table.insert(message_lines, "  • " .. error.message)
    end
    table.insert(message_lines, "")
  end

  -- Add warnings
  if #safety_check.warnings > 0 then
    table.insert(message_lines, "⚠️  WARNINGS:")
    for _, warning in ipairs(safety_check.warnings) do
      local icon = warning.severity == "warning" and "⚠️ " or "ℹ️ "
      table.insert(message_lines, "  " .. icon .. warning.message)
    end
    table.insert(message_lines, "")
  end

  if safety_check.can_proceed then
    table.insert(message_lines, "Do you want to proceed?")

    vim.ui.select(
      { "Yes", "No" },
      {
        prompt = table.concat(message_lines, "\n"),
        format_item = function(item) return item end,
      },
      function(choice)
        if callback then
          callback(choice == "Yes")
        end
      end
    )
  else
    table.insert(message_lines, "❌ Cannot proceed due to errors.")
    vim.notify(table.concat(message_lines, "\n"), vim.log.levels.ERROR)

    if callback then
      callback(false)
    end
  end
end

---Confirm edit operation
---@param bufnr number Buffer to edit
---@param prompt string Prompt for AI
---@param callback function Callback (confirmed: boolean, backup: table|nil)
function M.confirm_edit(bufnr, prompt, callback)
  -- Create safety check
  local is_safe, safety_check = M.check_safety({
    prompt = prompt,
    bufnr = bufnr,
    operation_type = "edit",
  })

  -- Create backup if configured
  local backup_info = nil
  if M.config.auto_backup_before_edit then
    backup_info = backup.backup_before_edit(bufnr)
  end

  -- Show confirmation if needed
  if not is_safe or (safety_check and #safety_check.warnings > 0) then
    M.show_safety_dialog(safety_check, function(confirmed)
      if callback then
        callback(confirmed, backup_info)
      end
    end)
  else
    -- Safe, proceed
    if callback then
      callback(true, backup_info)
    end
  end
end

---Track request for rate limiting
function M.track_request()
  table.insert(M.rate_tracker.requests, os.time())

  -- Cleanup old requests
  local cutoff = os.time() - M.rate_tracker.window_seconds
  M.rate_tracker.requests = vim.tbl_filter(function(timestamp)
    return timestamp > cutoff
  end, M.rate_tracker.requests)
end

---Check rate limiting
---@return table {exceeded: boolean, count: number}
function M.check_rate_limit()
  -- Cleanup old requests
  local cutoff = os.time() - M.rate_tracker.window_seconds
  M.rate_tracker.requests = vim.tbl_filter(function(timestamp)
    return timestamp > cutoff
  end, M.rate_tracker.requests)

  local count = #M.rate_tracker.requests

  return {
    exceeded = count >= M.config.rate_limit_warn,
    count = count,
    critical = count >= M.config.rate_limit_critical,
  }
end

---Get rate limit stats
---@return table Statistics
function M.get_rate_stats()
  local check = M.check_rate_limit()

  return {
    requests_last_minute = check.count,
    rate_limit_warn = M.config.rate_limit_warn,
    rate_limit_critical = M.config.rate_limit_critical,
    is_warning = check.exceeded,
    is_critical = check.critical,
  }
end

---Confirm large context operation
---@param context_size number Size of context (tokens or lines)
---@param context_type string Type (e.g., "tokens", "lines")
---@param callback function Callback (confirmed: boolean)
function M.confirm_large_context(context_size, context_type, callback)
  local message = string.format(
    "⚠️  Large %s detected: %d %s\n\nThis operation may be slow and expensive. Continue?",
    context_type,
    context_size,
    context_type
  )

  vim.ui.select(
    { "Yes", "No" },
    {
      prompt = message,
      format_item = function(item) return item end,
    },
    function(choice)
      if callback then
        callback(choice == "Yes")
      end
    end
  )
end

---Show safety statistics
function M.show_stats()
  local rate_stats = M.get_rate_stats()

  local lines = {
    "=== Safety Statistics ===",
    "",
    string.format("Requests (last minute): %d", rate_stats.requests_last_minute),
    string.format("Rate limit warning: %d req/min", rate_stats.rate_limit_warn),
    string.format("Rate limit critical: %d req/min", rate_stats.rate_limit_critical),
    "",
    string.format("Status: %s",
      rate_stats.is_critical and "🔴 Critical" or
      rate_stats.is_warning and "🟡 Warning" or
      "🟢 Normal"
    ),
  }

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Initialize
M.setup()

return M

--[[
  Request Management System

  Features:
  - Unique request IDs
  - Request tracking and status
  - Exponential backoff retry logic
  - Request history and debugging
  - Cancellation support
--]]

local M = {}

local logger = require('zeke.logger')

-- Request states
M.State = {
  PENDING = "pending",
  IN_PROGRESS = "in_progress",
  RETRYING = "retrying",
  COMPLETED = "completed",
  FAILED = "failed",
  CANCELLED = "cancelled",
}

-- Active requests registry
M.active_requests = {}
M.request_history = {}
M.next_id = 1

---Generate unique request ID
---@return string Request ID
function M.generate_id()
  local id = string.format("req_%d_%d", M.next_id, os.time())
  M.next_id = M.next_id + 1
  return id
end

---Create new tracked request
---@param opts table Options {prompt, model, provider, max_retries, timeout}
---@return table Request object
function M.create(opts)
  opts = opts or {}

  local request = {
    id = M.generate_id(),
    prompt = opts.prompt or "",
    model = opts.model,
    provider = opts.provider,
    state = M.State.PENDING,
    created_at = os.time(),
    started_at = nil,
    completed_at = nil,
    attempts = 0,
    max_retries = opts.max_retries or 3,
    timeout = opts.timeout or 120000, -- 2 minutes default
    errors = {},
    response = nil,
    metadata = opts.metadata or {},
  }

  M.active_requests[request.id] = request
  logger.info('requests', string.format('Created request %s', request.id))

  return request
end

---Update request state
---@param request_id string Request ID
---@param state string New state
---@param data table|nil Additional data
function M.update_state(request_id, state, data)
  local request = M.active_requests[request_id]
  if not request then
    logger.warn('requests', 'Request not found: ' .. request_id)
    return
  end

  local old_state = request.state
  request.state = state

  if state == M.State.IN_PROGRESS then
    request.started_at = os.time()
    request.attempts = request.attempts + 1
  elseif state == M.State.COMPLETED then
    request.completed_at = os.time()
    if data and data.response then
      request.response = data.response
    end
  elseif state == M.State.FAILED then
    request.completed_at = os.time()
    if data and data.error then
      table.insert(request.errors, {
        message = data.error,
        timestamp = os.time(),
        attempt = request.attempts,
      })
    end
  end

  logger.debug('requests', string.format(
    'Request %s: %s -> %s (attempt %d/%d)',
    request_id,
    old_state,
    state,
    request.attempts,
    request.max_retries + 1
  ))
end

---Calculate retry delay with exponential backoff
---@param attempt number Attempt number (1-indexed)
---@param base_delay number|nil Base delay in ms (default 1000)
---@param max_delay number|nil Max delay in ms (default 32000)
---@return number Delay in milliseconds
function M.calculate_backoff(attempt, base_delay, max_delay)
  base_delay = base_delay or 1000
  max_delay = max_delay or 32000

  -- Exponential backoff: base * 2^(attempt-1)
  local delay = base_delay * math.pow(2, attempt - 1)

  -- Add jitter (±25%)
  local jitter = delay * 0.25 * (2 * math.random() - 1)
  delay = delay + jitter

  -- Cap at max_delay
  return math.min(delay, max_delay)
end

---Should retry this request?
---@param request table Request object
---@param error string Error message
---@return boolean Should retry
---@return string|nil Reason if not retrying
function M.should_retry(request, error)
  -- Check attempt limit
  if request.attempts > request.max_retries then
    return false, string.format(
      "Max retries exceeded (%d/%d)",
      request.attempts - 1,
      request.max_retries
    )
  end

  -- Check if error is retryable
  local retryable_errors = {
    "timeout",
    "connection",
    "network",
    "rate.?limit",
    "429", -- Too Many Requests
    "503", -- Service Unavailable
    "504", -- Gateway Timeout
  }

  local error_lower = error:lower()
  for _, pattern in ipairs(retryable_errors) do
    if error_lower:match(pattern) then
      return true
    end
  end

  -- Non-retryable errors
  local non_retryable = {
    "401", -- Unauthorized
    "403", -- Forbidden
    "404", -- Not Found
    "invalid.?api.?key",
    "authentication",
  }

  for _, pattern in ipairs(non_retryable) then
    if error_lower:match(pattern) then
      return false, "Non-retryable error: " .. pattern
    end
  end

  -- Default: retry
  return true
end

---Execute request with automatic retry
---@param request table Request object
---@param execute_fn function Function to execute request
---@param on_success function Success callback
---@param on_failure function Failure callback
function M.execute_with_retry(request, execute_fn, on_success, on_failure)
  local function attempt()
    M.update_state(request.id, M.State.IN_PROGRESS)

    logger.info('requests', string.format(
      'Executing request %s (attempt %d/%d)',
      request.id,
      request.attempts,
      request.max_retries + 1
    ))

    execute_fn(
      request,
      -- Success callback
      function(response)
        M.update_state(request.id, M.State.COMPLETED, { response = response })
        M.move_to_history(request.id)

        if on_success then
          on_success(response, request)
        end
      end,
      -- Error callback
      function(error)
        logger.error('requests', string.format(
          'Request %s failed (attempt %d): %s',
          request.id,
          request.attempts,
          error
        ))

        local should_retry, reason = M.should_retry(request, error)

        if should_retry then
          M.update_state(request.id, M.State.RETRYING)

          local delay = M.calculate_backoff(request.attempts)
          logger.info('requests', string.format(
            'Retrying request %s in %dms',
            request.id,
            delay
          ))

          vim.defer_fn(function()
            attempt()
          end, delay)
        else
          M.update_state(request.id, M.State.FAILED, { error = error })
          M.move_to_history(request.id)

          if on_failure then
            on_failure(error, request, reason)
          end
        end
      end
    )
  end

  -- Start first attempt
  attempt()
end

---Cancel request
---@param request_id string Request ID
---@return boolean Success
function M.cancel(request_id)
  local request = M.active_requests[request_id]
  if not request then
    return false
  end

  M.update_state(request_id, M.State.CANCELLED)
  M.move_to_history(request_id)

  logger.info('requests', 'Cancelled request: ' .. request_id)
  return true
end

---Move request to history
---@param request_id string Request ID
function M.move_to_history(request_id)
  local request = M.active_requests[request_id]
  if not request then
    return
  end

  table.insert(M.request_history, request)
  M.active_requests[request_id] = nil

  -- Keep only last 100 requests in history
  if #M.request_history > 100 then
    table.remove(M.request_history, 1)
  end
end

---Get request by ID
---@param request_id string Request ID
---@return table|nil Request object
function M.get(request_id)
  return M.active_requests[request_id] or
    vim.tbl_filter(function(r) return r.id == request_id end, M.request_history)[1]
end

---Get all active requests
---@return table List of active requests
function M.get_active()
  local active = {}
  for _, request in pairs(M.active_requests) do
    table.insert(active, request)
  end

  -- Sort by created_at
  table.sort(active, function(a, b)
    return a.created_at > b.created_at
  end)

  return active
end

---Get request statistics
---@return table Statistics
function M.get_stats()
  local stats = {
    active = 0,
    completed = 0,
    failed = 0,
    cancelled = 0,
    total_requests = M.next_id - 1,
    avg_attempts = 0,
  }

  for _, request in pairs(M.active_requests) do
    stats.active = stats.active + 1
  end

  local total_attempts = 0
  for _, request in ipairs(M.request_history) do
    if request.state == M.State.COMPLETED then
      stats.completed = stats.completed + 1
    elseif request.state == M.State.FAILED then
      stats.failed = stats.failed + 1
    elseif request.state == M.State.CANCELLED then
      stats.cancelled = stats.cancelled + 1
    end

    total_attempts = total_attempts + request.attempts
  end

  if #M.request_history > 0 then
    stats.avg_attempts = total_attempts / #M.request_history
  end

  return stats
end

---Format request for display
---@param request table Request object
---@return string Formatted request info
function M.format_request(request)
  local lines = {
    string.format("Request ID: %s", request.id),
    string.format("State: %s", request.state),
    string.format("Attempts: %d/%d", request.attempts, request.max_retries + 1),
    string.format("Model: %s", request.model or "unknown"),
    string.format("Provider: %s", request.provider or "unknown"),
    string.format("Created: %s", os.date("%Y-%m-%d %H:%M:%S", request.created_at)),
  }

  if request.started_at then
    table.insert(lines, string.format("Started: %s", os.date("%Y-%m-%d %H:%M:%S", request.started_at)))
  end

  if request.completed_at then
    table.insert(lines, string.format("Completed: %s", os.date("%Y-%m-%d %H:%M:%S", request.completed_at)))

    local duration = request.completed_at - (request.started_at or request.created_at)
    table.insert(lines, string.format("Duration: %ds", duration))
  end

  if #request.errors > 0 then
    table.insert(lines, "\nErrors:")
    for i, error in ipairs(request.errors) do
      table.insert(lines, string.format("  %d. [Attempt %d] %s", i, error.attempt, error.message))
    end
  end

  if request.prompt then
    local prompt_preview = request.prompt:sub(1, 100)
    if #request.prompt > 100 then
      prompt_preview = prompt_preview .. "..."
    end
    table.insert(lines, "\nPrompt: " .. prompt_preview)
  end

  return table.concat(lines, "\n")
end

---Show request inspector UI
function M.show_inspector()
  local active = M.get_active()
  local stats = M.get_stats()

  if #active == 0 and #M.request_history == 0 then
    vim.notify("No requests to inspect", vim.log.levels.INFO)
    return
  end

  local items = {}

  -- Add active requests
  if #active > 0 then
    table.insert(items, "=== Active Requests ===")
    for _, request in ipairs(active) do
      table.insert(items, string.format(
        "[%s] %s - %s (attempt %d)",
        request.state,
        request.id,
        request.model or "unknown",
        request.attempts
      ))
    end
    table.insert(items, "")
  end

  -- Add recent history
  if #M.request_history > 0 then
    table.insert(items, "=== Recent Requests ===")
    for i = #M.request_history, math.max(1, #M.request_history - 9), -1 do
      local request = M.request_history[i]
      local status_icon = request.state == M.State.COMPLETED and "✓" or
                         request.state == M.State.FAILED and "✗" or "○"
      table.insert(items, string.format(
        "%s [%s] %s - %s",
        status_icon,
        request.state,
        request.id,
        request.model or "unknown"
      ))
    end
  end

  -- Add stats
  table.insert(items, "")
  table.insert(items, "=== Statistics ===")
  table.insert(items, string.format("Total: %d", stats.total_requests))
  table.insert(items, string.format("Active: %d", stats.active))
  table.insert(items, string.format("Completed: %d", stats.completed))
  table.insert(items, string.format("Failed: %d", stats.failed))
  table.insert(items, string.format("Cancelled: %d", stats.cancelled))
  table.insert(items, string.format("Avg Attempts: %.2f", stats.avg_attempts))

  vim.notify(table.concat(items, "\n"), vim.log.levels.INFO)
end

return M

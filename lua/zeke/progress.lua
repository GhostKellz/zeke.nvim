--[[
  Progress Indicators

  Shows visual feedback for long-running operations:
  - Spinner animations
  - Progress messages
  - Step-by-step status
--]]

local M = {}

-- Active progress indicators
M.active = {}

-- Spinner frames
M.spinners = {
  dots = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  line = { "-", "\\", "|", "/" },
  arrows = { "←", "↖", "↑", "↗", "→", "↘", "↓", "↙" },
  box = { "◰", "◳", "◲", "◱" },
  pulse = { "◐", "◓", "◑", "◒" },
  earth = { "🌍", "🌎", "🌏" },
  moon = { "🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘" },
  robot = { "🤖", "🔧", "⚙️", "🔩", "🤖" },
}

---Start progress indicator
---@param id string Unique identifier for this progress
---@param message string Progress message
---@param opts table|nil Options {spinner, interval}
---@return string Progress ID
function M.start(id, message, opts)
  opts = opts or {}

  local spinner = opts.spinner or "dots"
  local interval = opts.interval or 100

  -- Stop existing if present
  if M.active[id] then
    M.stop(id)
  end

  local progress = {
    id = id,
    message = message,
    spinner = M.spinners[spinner] or M.spinners.dots,
    frame = 1,
    timer = nil,
    start_time = vim.loop.now(),
  }

  -- Create timer for animation
  progress.timer = vim.loop.new_timer()

  progress.timer:start(0, interval, vim.schedule_wrap(function()
    if not M.active[id] then
      return
    end

    local elapsed = math.floor((vim.loop.now() - progress.start_time) / 1000)
    local frame = progress.spinner[progress.frame]

    local status = string.format("%s %s (%ds)", frame, progress.message, elapsed)

    -- Update notification
    vim.notify(status, vim.log.levels.INFO, {
      title = "Zeke",
      replace = progress.notification_id,
      timeout = false,
    })

    -- Advance frame
    progress.frame = progress.frame % #progress.spinner + 1
  end))

  M.active[id] = progress
  return id
end

---Update progress message
---@param id string Progress ID
---@param message string New message
function M.update(id, message)
  local progress = M.active[id]
  if not progress then
    return
  end

  progress.message = message
end

---Stop progress indicator
---@param id string Progress ID
---@param final_message string|nil Final message to show
---@param success boolean|nil Success state (default: true)
function M.stop(id, final_message, success)
  local progress = M.active[id]
  if not progress then
    return
  end

  -- Stop timer
  if progress.timer then
    progress.timer:stop()
    progress.timer:close()
  end

  M.active[id] = nil

  -- Show final message if provided
  if final_message then
    local elapsed = math.floor((vim.loop.now() - progress.start_time) / 1000)
    local icon = success == false and "❌" or "✓"

    vim.notify(
      string.format("%s %s (%ds)", icon, final_message, elapsed),
      success == false and vim.log.levels.ERROR or vim.log.levels.INFO
    )
  end
end

---Create step-based progress indicator
---@param id string Progress ID
---@param steps table List of step names
---@return table Progress controller {next, complete, fail}
function M.steps(id, steps)
  local current_step = 1
  local total_steps = #steps

  local function update_message()
    if current_step <= total_steps then
      local message = string.format(
        "[%d/%d] %s",
        current_step,
        total_steps,
        steps[current_step]
      )
      M.update(id, message)
    end
  end

  M.start(id, string.format("[1/%d] %s", total_steps, steps[1]), {
    spinner = "robot",
    interval = 150,
  })

  return {
    ---Move to next step
    next = function()
      current_step = current_step + 1
      if current_step <= total_steps then
        update_message()
      end
    end,

    ---Complete all steps successfully
    complete = function(message)
      M.stop(id, message or string.format("Completed %d steps", total_steps), true)
    end,

    ---Fail with error
    fail = function(message)
      M.stop(id, message or string.format("Failed at step %d/%d", current_step, total_steps), false)
    end,

    ---Get current step info
    current = function()
      return current_step, total_steps
    end,
  }
end

---Wrap async operation with progress
---@param message string Progress message
---@param fn function Function to execute
---@param callback function|nil Callback on completion
function M.wrap(message, fn, callback)
  local id = "progress_" .. vim.loop.now()

  M.start(id, message)

  local success, result = pcall(fn)

  if success then
    M.stop(id, message .. " - Done!", true)
    if callback then
      callback(result)
    end
  else
    M.stop(id, message .. " - Failed!", false)
    vim.notify("Error: " .. tostring(result), vim.log.levels.ERROR)
  end
end

---Show simple loading message
---@param message string Message
---@return string ID for stopping
function M.loading(message)
  return M.start("loading_" .. vim.loop.now(), message, {
    spinner = "dots",
  })
end

---Stop all active progress indicators
function M.stop_all()
  for id, _ in pairs(M.active) do
    M.stop(id)
  end
end

return M

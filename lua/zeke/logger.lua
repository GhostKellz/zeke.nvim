-- Logger module for Zeke.nvim
-- Provides structured logging with levels and configurable output
local M = {}

-- Log levels
M.levels = {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
}

-- State
M.state = {
  level = M.levels.INFO,
  prefix = "[Zeke]",
  show_timestamp = false,
  file = nil,
  callbacks = {},
}

-- Setup logger configuration
function M.setup(opts)
  opts = opts or {}

  if opts.level then
    if type(opts.level) == "string" then
      M.state.level = M.levels[opts.level:upper()] or M.levels.INFO
    else
      M.state.level = opts.level
    end
  end

  if opts.prefix ~= nil then
    M.state.prefix = opts.prefix
  end

  if opts.show_timestamp ~= nil then
    M.state.show_timestamp = opts.show_timestamp
  end

  if opts.file then
    M.state.file = vim.fn.expand(opts.file)
  end

  if opts.callbacks then
    M.state.callbacks = opts.callbacks
  end
end

-- Format log message
local function format_message(level, context, message)
  local parts = {}

  if M.state.show_timestamp then
    table.insert(parts, os.date("%Y-%m-%d %H:%M:%S"))
  end

  if M.state.prefix then
    table.insert(parts, M.state.prefix)
  end

  local level_names = {
    [M.levels.DEBUG] = "DEBUG",
    [M.levels.INFO] = "INFO",
    [M.levels.WARN] = "WARN",
    [M.levels.ERROR] = "ERROR",
  }

  table.insert(parts, "[" .. level_names[level] .. "]")

  if context then
    table.insert(parts, "[" .. context .. "]")
  end

  table.insert(parts, message)

  return table.concat(parts, " ")
end

-- Write to file if configured
local function write_to_file(message)
  if not M.state.file then
    return
  end

  local file = io.open(M.state.file, "a")
  if file then
    file:write(message .. "\n")
    file:close()
  end
end

-- Core logging function
local function log(level, context, message)
  -- Check if we should log this level
  if level < M.state.level then
    return
  end

  -- Format the message
  local formatted = format_message(level, context, message)

  -- Write to file
  write_to_file(formatted)

  -- Call callbacks
  for _, callback in ipairs(M.state.callbacks) do
    local ok, err = pcall(callback, level, context, message, formatted)
    if not ok then
      vim.notify("Logger callback error: " .. err, vim.log.levels.ERROR)
    end
  end

  -- Show in Neovim
  local vim_levels = {
    [M.levels.DEBUG] = vim.log.levels.DEBUG,
    [M.levels.INFO] = vim.log.levels.INFO,
    [M.levels.WARN] = vim.log.levels.WARN,
    [M.levels.ERROR] = vim.log.levels.ERROR,
  }

  vim.notify(formatted, vim_levels[level])
end

-- Public logging methods
function M.debug(context, message)
  log(M.levels.DEBUG, context, message)
end

function M.info(context, message)
  log(M.levels.INFO, context, message)
end

function M.warn(context, message)
  log(M.levels.WARN, context, message)
end

function M.error(context, message)
  log(M.levels.ERROR, context, message)
end

-- Set log level dynamically
function M.set_level(level)
  if type(level) == "string" then
    M.state.level = M.levels[level:upper()] or M.levels.INFO
  else
    M.state.level = level
  end
end

-- Get current log level
function M.get_level()
  return M.state.level
end

-- Clear log file
function M.clear_log_file()
  if M.state.file then
    local file = io.open(M.state.file, "w")
    if file then
      file:close()
    end
  end
end

return M
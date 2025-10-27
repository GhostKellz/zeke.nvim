--[[
  CLI Wrapper for Zeke v0.3.0

  This module provides a clean interface for calling the Zeke CLI
  from Neovim. It replaces the HTTP client approach with direct
  command execution via vim.fn.system().

  Architecture: Neovim (Lua) → vim.fn.system('zeke ...') → Zeke CLI
--]]

local M = {}

-- Check if Zeke CLI is available
function M.check_installation()
  local handle = io.popen("which zeke 2>/dev/null")
  if not handle then
    return false, "Unable to check for zeke command"
  end

  local result = handle:read("*a")
  handle:close()

  if result == "" or result == nil then
    return false, "Zeke CLI not found in PATH. Install from: https://github.com/ghostkellz/zeke"
  end

  return true, result:gsub("%s+$", "")
end

-- Escape string for shell command
local function escape_shell(str)
  if not str then return "" end
  -- Replace quotes and backslashes
  return str:gsub('"', '\\"'):gsub("'", "'\\''")
end

-- Execute zeke command and return output
local function execute(cmd)
  local logger = require('zeke.logger')
  logger.debug("cli", "Executing: " .. cmd)

  local output = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    logger.error("cli", "Command failed with exit code " .. exit_code)
    logger.error("cli", "Output: " .. output)
    return nil, output
  end

  return output, nil
end

--[[
  Chat Commands
--]]

function M.chat(message)
  local escaped = escape_shell(message)
  local cmd = string.format('zeke chat "%s"', escaped)
  return execute(cmd)
end

function M.stream_chat(message, on_chunk, on_complete)
  local escaped = escape_shell(message)
  local cmd = string.format('zeke chat --stream "%s"', escaped)

  -- Use jobstart for streaming
  local chunks = {}

  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(chunks, line)
          if on_chunk then
            on_chunk(line .. "\n")  -- Add newline for proper rendering
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      local full_response = table.concat(chunks, "\n")
      if on_complete then
        on_complete(full_response, exit_code)
      end
    end,
  })

  return job_id
end

function M.cancel_stream(job_id)
  vim.fn.jobstop(job_id)
end

--[[
  Code Operations
--]]

function M.explain(code, language)
  local escaped_code = escape_shell(code)
  local cmd
  if language then
    cmd = string.format('zeke explain "%s" %s', escaped_code, language)
  else
    cmd = string.format('zeke explain "%s"', escaped_code)
  end
  return execute(cmd)
end

function M.generate(description, language)
  local escaped_desc = escape_shell(description)
  local cmd
  if language then
    cmd = string.format('zeke generate "%s" %s', escaped_desc, language)
  else
    cmd = string.format('zeke generate "%s"', escaped_desc)
  end
  return execute(cmd)
end

function M.debug_code(error_description)
  local escaped = escape_shell(error_description)
  local cmd = string.format('zeke debug "%s"', escaped)
  return execute(cmd)
end

function M.analyze(file_path, analysis_type)
  analysis_type = analysis_type or "quality"
  local cmd = string.format('zeke analyze "%s" %s', file_path, analysis_type)
  return execute(cmd)
end

--[[
  File Operations
--]]

function M.file_read(path)
  local cmd = string.format('zeke file read "%s"', path)
  return execute(cmd)
end

function M.file_write(path, content)
  local escaped_content = escape_shell(content)
  local cmd = string.format('zeke file write "%s" "%s"', path, escaped_content)
  return execute(cmd)
end

function M.file_edit(path, instruction)
  local escaped = escape_shell(instruction)
  local cmd = string.format('zeke file edit "%s" "%s"', path, escaped)
  return execute(cmd)
end

--[[
  Provider Management
--]]

function M.provider_list()
  local output, err = execute('zeke provider list')
  if not output then
    return nil, err
  end

  -- Parse provider list (format: "• provider_name (status)")
  local providers = {}
  for line in output:gmatch("[^\r\n]+") do
    local name = line:match("• (%w+)")
    if name then
      table.insert(providers, name)
    end
  end

  return providers, nil
end

function M.provider_switch(provider)
  local cmd = string.format('zeke provider switch %s', provider)
  return execute(cmd)
end

function M.provider_status()
  return execute('zeke provider status')
end

--[[
  Model Management
--]]

function M.model_list()
  return execute('zeke model list')
end

function M.model_set(model)
  local cmd = string.format('zeke model %s', model)
  return execute(cmd)
end

function M.model_current()
  return execute('zeke model')
end

--[[
  Configuration
--]]

function M.config_path()
  local home = vim.fn.expand("~")
  return home .. "/.config/zeke/zeke.toml"
end

function M.load_config()
  -- For now, we'll return default config
  -- In the future, we can parse zeke.toml or use `zeke config dump --json`
  return {
    default = {
      provider = "ollama",
      model = "qwen2.5-coder:7b",
    },
    providers = {
      ollama = { enabled = true, host = "http://localhost:11434" },
      openai = { enabled = true },
      claude = { enabled = true },
      google = { enabled = true },
      copilot = { enabled = true },
      xai = { enabled = true },
    },
    nvim = {
      enabled = true,
      auto_complete = true,
      inline_suggestions = true,
      provider_fallback = { "copilot", "ollama", "google", "claude", "openai", "xai" },
    },
  }
end

--[[
  Git Operations (if available)
--]]

function M.git_status()
  return execute('zeke git status')
end

function M.git_diff()
  return execute('zeke git diff')
end

--[[
  Health Check
--]]

function M.health_check()
  local ok, path = M.check_installation()
  if not ok then
    return {
      installed = false,
      error = path,
    }
  end

  -- Check if we can run a simple command
  local output, err = execute('zeke --version')
  if not output then
    return {
      installed = true,
      path = path,
      working = false,
      error = err,
    }
  end

  return {
    installed = true,
    path = path,
    working = true,
    version = output:match("ZEKE v([%d%.]+)") or "unknown",
  }
end

return M

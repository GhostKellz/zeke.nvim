-- Ghostlang integration for Zeke.nvim
-- Provides hooks and utilities for when Grim editor and Ghostlang become available
local M = {}

local logger = require('zeke.logger')

-- State
M.state = {
  enabled = false,
  script_engine = nil,
  grim_mode = false,  -- Whether we're running in Grim editor
  hooks = {},
}

-- Configuration
M.config = {
  auto_detect = true,
  script_dirs = { ".zeke", "scripts" },
  extensions = { ".gza", ".ghost" },
  fallback_to_lua = true,
}

-- Setup ghostlang integration
function M.setup(opts)
  opts = opts or {}

  -- Merge configuration
  for key, value in pairs(opts) do
    if M.config[key] ~= nil then
      M.config[key] = value
    end
  end

  -- Auto-detect environment
  if M.config.auto_detect then
    M._detect_environment()
  end

  logger.debug("ghostlang", "Ghostlang integration initialized")
end

-- Detect if we're running in Grim or have Ghostlang available
function M._detect_environment()
  -- Check if we're in Grim editor
  if vim.env.GRIM_MODE or vim.g.grim_editor then
    M.state.grim_mode = true
    logger.info("ghostlang", "Grim editor detected")
  end

  -- Check for ghostlang availability
  -- This would be implemented when ghostlang is ready
  local has_ghostlang = false

  if has_ghostlang then
    M.state.enabled = true
    logger.info("ghostlang", "Ghostlang script engine available")
  else
    if M.config.fallback_to_lua then
      logger.debug("ghostlang", "Ghostlang not available, using Lua fallback")
    end
  end
end

-- Register a hook for ghostlang events
function M.register_hook(event, callback)
  if not M.state.hooks[event] then
    M.state.hooks[event] = {}
  end

  table.insert(M.state.hooks[event], callback)
  logger.debug("ghostlang", "Registered hook for event: " .. event)
end

-- Fire hooks for an event
function M.fire_hooks(event, data)
  local hooks = M.state.hooks[event]
  if not hooks then
    return
  end

  for _, callback in ipairs(hooks) do
    local ok, err = pcall(callback, data)
    if not ok then
      logger.error("ghostlang", "Hook error for " .. event .. ": " .. err)
    end
  end
end

-- Execute a ghostlang script (placeholder for future implementation)
function M.execute_script(script_path, args)
  args = args or {}

  if not M.state.enabled then
    if M.config.fallback_to_lua then
      return M._execute_lua_fallback(script_path, args)
    else
      return false, "Ghostlang not available"
    end
  end

  -- This would be the actual ghostlang execution when ready
  logger.info("ghostlang", "Executing script: " .. script_path)

  -- Fire pre-execution hooks
  M.fire_hooks("script_pre_exec", {
    script = script_path,
    args = args
  })

  -- TODO: Implement actual ghostlang script execution
  local success = false
  local result = "Ghostlang execution not yet implemented"

  -- Fire post-execution hooks
  M.fire_hooks("script_post_exec", {
    script = script_path,
    args = args,
    success = success,
    result = result
  })

  return success, result
end

-- Execute Lua fallback script
function M._execute_lua_fallback(script_path, args)
  -- Convert .gza/.ghost to .lua for fallback
  local lua_script = script_path:gsub("%.gza$", ".lua"):gsub("%.ghost$", ".lua")

  if vim.fn.filereadable(lua_script) == 1 then
    logger.debug("ghostlang", "Using Lua fallback: " .. lua_script)

    local ok, result = pcall(dofile, lua_script)
    if ok then
      return true, result
    else
      return false, "Lua execution error: " .. result
    end
  else
    return false, "No Lua fallback found: " .. lua_script
  end
end

-- Find ghostlang scripts in configured directories
function M.find_scripts()
  local scripts = {}

  for _, dir in ipairs(M.config.script_dirs) do
    local full_dir = vim.fn.expand(dir)
    if vim.fn.isdirectory(full_dir) == 1 then
      for _, ext in ipairs(M.config.extensions) do
        local pattern = full_dir .. "/*" .. ext
        local files = vim.fn.glob(pattern, false, true)

        for _, file in ipairs(files) do
          table.insert(scripts, {
            path = file,
            name = vim.fn.fnamemodify(file, ":t:r"),
            extension = ext,
            directory = dir
          })
        end
      end
    end
  end

  return scripts
end

-- Run a named script
function M.run_script(script_name, args)
  local scripts = M.find_scripts()

  for _, script in ipairs(scripts) do
    if script.name == script_name then
      return M.execute_script(script.path, args)
    end
  end

  return false, "Script not found: " .. script_name
end

-- Create a new ghostlang script template
function M.create_script_template(name, script_type)
  script_type = script_type or "basic"

  local dir = M.config.script_dirs[1] or ".zeke"
  local full_dir = vim.fn.expand(dir)

  -- Create directory if it doesn't exist
  if vim.fn.isdirectory(full_dir) == 0 then
    vim.fn.mkdir(full_dir, "p")
  end

  local script_path = full_dir .. "/" .. name .. ".gza"
  local template

  if script_type == "zeke_plugin" then
    template = M._get_zeke_plugin_template(name)
  else
    template = M._get_basic_template(name)
  end

  -- Write template to file
  vim.fn.writefile(vim.split(template, "\n"), script_path)

  logger.info("ghostlang", "Created script template: " .. script_path)
  return script_path
end

-- Get basic script template
function M._get_basic_template(name)
  return string.format([[
-- %s - Ghostlang script for Zeke.nvim
-- This is a placeholder template for future Ghostlang support

function main(args)
    -- Script logic goes here
    print("Hello from %s!")

    -- Access Zeke API when available
    -- zeke.chat("Hello from ghostlang script!")

    return { success = true, message = "Script executed" }
end

-- Export main function
return { main = main }
]], name, name)
end

-- Get Zeke plugin template
function M._get_zeke_plugin_template(name)
  return string.format([[
-- %s - Zeke plugin in Ghostlang
-- Plugin template for extending Zeke functionality

local plugin = {}

-- Plugin initialization
function plugin.setup(opts)
    -- Setup plugin with options
    print("Setting up %s plugin")
end

-- Plugin commands
plugin.commands = {
    hello = function()
        print("Hello from %s plugin!")
    end
}

-- Plugin hooks
plugin.hooks = {
    on_chat = function(message)
        -- Hook into chat events
    end,

    on_file_add = function(file_path)
        -- Hook into file addition events
    end
}

return plugin
]], name, name, name)
end

-- Integration with Zeke commands
function M.setup_zeke_integration()
  -- Add ghostlang script execution to Zeke commands
  vim.api.nvim_create_user_command('ZekeScript', function(args)
    if args.args and args.args ~= '' then
      local script_name = args.args
      local success, result = M.run_script(script_name)

      if success then
        logger.info("ghostlang", "Script executed successfully: " .. script_name)
        if result then
          print(vim.inspect(result))
        end
      else
        logger.error("ghostlang", "Script execution failed: " .. result)
      end
    else
      -- List available scripts
      local scripts = M.find_scripts()
      if #scripts > 0 then
        print("Available scripts:")
        for _, script in ipairs(scripts) do
          print("  " .. script.name .. " (" .. script.directory .. ")")
        end
      else
        print("No scripts found in configured directories")
      end
    end
  end, {
    nargs = '?',
    desc = 'Execute or list Ghostlang scripts'
  })

  -- Add script creation command
  vim.api.nvim_create_user_command('ZekeNewScript', function(args)
    local name = args.args or "new_script"
    local script_path = M.create_script_template(name)
    vim.cmd("edit " .. script_path)
  end, {
    nargs = '?',
    desc = 'Create new Ghostlang script template'
  })
end

-- Check if ghostlang is available
function M.is_available()
  return M.state.enabled
end

-- Check if we're in Grim editor
function M.is_grim_mode()
  return M.state.grim_mode
end

-- Get ghostlang integration status
function M.get_status()
  return {
    enabled = M.state.enabled,
    grim_mode = M.state.grim_mode,
    config = M.config,
    hooks_count = vim.tbl_count(M.state.hooks),
    scripts_found = #M.find_scripts()
  }
end

return M
-- Lock file system for Zeke CLI discovery
-- Creates ~/.zeke/ide/[port].lock for CLI to discover running Neovim instances

local M = {}

local logger = require('zeke.logger')

M.lock_file_path = nil
M.port = 7878  -- Default Zeke HTTP API port

-- Create lock file
function M.create(port)
  port = port or M.port

  -- Create lock directory
  local lock_dir = vim.fn.expand("~/.zeke/ide")
  vim.fn.mkdir(lock_dir, "p")

  -- Lock file path
  M.lock_file_path = lock_dir .. "/" .. port .. ".lock"

  -- Lock data
  local lock_data = {
    port = port,
    pid = vim.fn.getpid(),
    protocol = "http",
    base_url = "http://localhost:" .. port,
    editor = "neovim",
    version = vim.version(),
    cwd = vim.fn.getcwd(),
    created_at = os.time(),
  }

  -- Write lock file
  local content = vim.json.encode(lock_data, { indent = 2 })
  local ok, err = pcall(vim.fn.writefile, {content}, M.lock_file_path)

  if ok then
    logger.info('lockfile', 'Created lock file: ' .. M.lock_file_path)
  else
    logger.error('lockfile', 'Failed to create lock file: ' .. tostring(err))
    return false
  end

  -- Setup cleanup on exit
  M.setup_cleanup()

  return true
end

-- Setup automatic cleanup
function M.setup_cleanup()
  -- Clean up on VimLeave
  vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
      M.cleanup()
    end,
    desc = "Cleanup Zeke lock file on exit",
  })

  logger.debug('lockfile', 'Setup cleanup autocmd')
end

-- Clean up lock file
function M.cleanup()
  if M.lock_file_path and vim.fn.filereadable(M.lock_file_path) == 1 then
    local ok, err = pcall(vim.fn.delete, M.lock_file_path)
    if ok then
      logger.info('lockfile', 'Cleaned up lock file')
    else
      logger.error('lockfile', 'Failed to cleanup lock file: ' .. tostring(err))
    end
  end
end

-- Check if lock file exists
function M.exists()
  return M.lock_file_path and vim.fn.filereadable(M.lock_file_path) == 1
end

-- Read lock file data
function M.read()
  if not M.exists() then
    return nil
  end

  local ok, content = pcall(vim.fn.readfile, M.lock_file_path)
  if not ok or not content or #content == 0 then
    return nil
  end

  local decode_ok, data = pcall(vim.json.decode, content[1])
  if decode_ok then
    return data
  end

  return nil
end

-- Update lock file (e.g., if cwd changes)
function M.update()
  if not M.exists() then
    return false
  end

  local data = M.read()
  if not data then
    return false
  end

  -- Update dynamic fields
  data.cwd = vim.fn.getcwd()
  data.updated_at = os.time()

  -- Write back
  local content = vim.json.encode(data, { indent = 2 })
  local ok, err = pcall(vim.fn.writefile, {content}, M.lock_file_path)

  if ok then
    logger.debug('lockfile', 'Updated lock file')
    return true
  else
    logger.error('lockfile', 'Failed to update lock file: ' .. tostring(err))
    return false
  end
end

return M

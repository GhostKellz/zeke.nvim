--[[
  Auto-Backup System

  Features:
  - Automatic backups before AI edits
  - Backup history and restoration
  - Cleanup old backups
  - Undo/redo support
--]]

local M = {}

local api = vim.api
local logger = require('zeke.logger')

-- Configuration
M.config = {
  enabled = true,
  backup_dir = vim.fn.stdpath('data') .. '/zeke/backups',
  max_backups_per_file = 10,
  auto_cleanup_days = 30,
}

-- Backup registry
M.backups = {}

---Initialize backup system
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  -- Create backup directory
  vim.fn.mkdir(M.config.backup_dir, 'p')

  logger.info('backup', 'Backup system initialized: ' .. M.config.backup_dir)
end

---Generate backup filename
---@param bufnr number Buffer number
---@return string Backup filename
function M.generate_backup_name(bufnr)
  local filename = api.nvim_buf_get_name(bufnr)
  local timestamp = os.date("%Y%m%d_%H%M%S")

  -- Create safe filename from original path
  local safe_name = filename:gsub("/", "_"):gsub("\\", "_"):gsub(":", "_")
  if safe_name == "" then
    safe_name = string.format("buffer_%d", bufnr)
  end

  return string.format("%s_%s.bak", safe_name, timestamp)
end

---Create backup of buffer
---@param bufnr number|nil Buffer number (default: current)
---@param reason string|nil Backup reason
---@return table|nil Backup info {path, timestamp, reason, original_file}
function M.create_backup(bufnr, reason)
  if not M.config.enabled then
    return nil
  end

  bufnr = bufnr or api.nvim_get_current_buf()
  reason = reason or "manual"

  -- Get buffer content
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  if content == "" then
    logger.debug('backup', 'Skipping backup of empty buffer')
    return nil
  end

  -- Generate backup path
  local backup_name = M.generate_backup_name(bufnr)
  local backup_path = M.config.backup_dir .. '/' .. backup_name

  -- Write backup
  local file = io.open(backup_path, 'w')
  if not file then
    logger.error('backup', 'Failed to create backup: ' .. backup_path)
    return nil
  end

  file:write(content)
  file:close()

  -- Store backup info
  local backup_info = {
    path = backup_path,
    timestamp = os.time(),
    reason = reason,
    original_file = api.nvim_buf_get_name(bufnr),
    bufnr = bufnr,
    line_count = #lines,
    size = #content,
  }

  -- Add to registry
  local original_file = backup_info.original_file
  if not M.backups[original_file] then
    M.backups[original_file] = {}
  end

  table.insert(M.backups[original_file], backup_info)

  -- Cleanup old backups
  M.cleanup_old_backups(original_file)

  logger.info('backup', string.format(
    'Created backup: %s (%d lines, reason: %s)',
    backup_name,
    #lines,
    reason
  ))

  return backup_info
end

---Create backup before AI edit
---@param bufnr number|nil Buffer number
---@return table|nil Backup info
function M.backup_before_edit(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  -- Check if buffer has unsaved changes
  if api.nvim_buf_get_option(bufnr, 'modified') then
    logger.warn('backup', 'Buffer has unsaved changes - backup may not reflect current state')
  end

  return M.create_backup(bufnr, "before_ai_edit")
end

---Restore from backup
---@param backup_path string Path to backup file
---@param bufnr number|nil Target buffer (default: current)
---@return boolean Success
function M.restore_backup(backup_path, bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  -- Read backup file
  local file = io.open(backup_path, 'r')
  if not file then
    logger.error('backup', 'Failed to open backup: ' .. backup_path)
    vim.notify('Backup file not found', vim.log.levels.ERROR)
    return false
  end

  local content = file:read('*all')
  file:close()

  -- Split into lines
  local lines = vim.split(content, '\n', { plain = true })

  -- Set buffer content
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  logger.info('backup', 'Restored from backup: ' .. backup_path)
  vim.notify('Backup restored successfully', vim.log.levels.INFO)

  return true
end

---List backups for a file
---@param filepath string|nil File path (default: current buffer)
---@return table List of backup info
function M.list_backups(filepath)
  filepath = filepath or api.nvim_buf_get_name(0)

  if not M.backups[filepath] then
    return {}
  end

  -- Sort by timestamp (newest first)
  local backups = vim.deepcopy(M.backups[filepath])
  table.sort(backups, function(a, b)
    return a.timestamp > b.timestamp
  end)

  return backups
end

---Show backup picker
---@param filepath string|nil File path (default: current buffer)
function M.show_backup_picker(filepath)
  filepath = filepath or api.nvim_buf_get_name(0)
  local backups = M.list_backups(filepath)

  if #backups == 0 then
    vim.notify('No backups found for this file', vim.log.levels.INFO)
    return
  end

  -- Format items for picker
  local items = {}
  for _, backup in ipairs(backups) do
    local date = os.date("%Y-%m-%d %H:%M:%S", backup.timestamp)
    local display = string.format(
      "%s - %s (%d lines, %s)",
      date,
      backup.reason,
      backup.line_count,
      M.format_size(backup.size)
    )

    table.insert(items, {
      display = display,
      backup = backup,
    })
  end

  -- Show picker
  vim.ui.select(items, {
    prompt = 'Select backup to restore:',
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if choice and choice.backup then
      -- Confirm restore
      local confirm = vim.fn.confirm(
        'Restore this backup? Current content will be replaced.',
        '&Yes\n&No',
        2
      )

      if confirm == 1 then
        M.restore_backup(choice.backup.path)
      end
    end
  end)
end

---Cleanup old backups for a file
---@param filepath string File path
function M.cleanup_old_backups(filepath)
  if not M.backups[filepath] then
    return
  end

  local backups = M.backups[filepath]

  -- Keep only max_backups_per_file most recent
  if #backups > M.config.max_backups_per_file then
    -- Sort by timestamp
    table.sort(backups, function(a, b)
      return a.timestamp > b.timestamp
    end)

    -- Delete old backups
    for i = M.config.max_backups_per_file + 1, #backups do
      local backup = backups[i]
      local success = os.remove(backup.path)

      if success then
        logger.debug('backup', 'Deleted old backup: ' .. backup.path)
      end

      backups[i] = nil
    end
  end

  -- Cleanup backups older than auto_cleanup_days
  local cutoff_time = os.time() - (M.config.auto_cleanup_days * 24 * 60 * 60)

  for i = #backups, 1, -1 do
    local backup = backups[i]
    if backup.timestamp < cutoff_time then
      os.remove(backup.path)
      logger.debug('backup', 'Deleted expired backup: ' .. backup.path)
      table.remove(backups, i)
    end
  end
end

---Cleanup all old backups
function M.cleanup_all_old_backups()
  local deleted = 0

  for filepath, _ in pairs(M.backups) do
    local before = #M.backups[filepath]
    M.cleanup_old_backups(filepath)
    local after = #M.backups[filepath]

    deleted = deleted + (before - after)
  end

  logger.info('backup', string.format('Cleaned up %d old backups', deleted))
  vim.notify(string.format('Cleaned up %d old backups', deleted), vim.log.levels.INFO)
end

---Format byte size
---@param bytes number Size in bytes
---@return string Formatted size
function M.format_size(bytes)
  if bytes < 1024 then
    return string.format("%d B", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.1f KB", bytes / 1024)
  else
    return string.format("%.1f MB", bytes / (1024 * 1024))
  end
end

---Get backup statistics
---@return table Statistics
function M.get_stats()
  local stats = {
    total_files = 0,
    total_backups = 0,
    total_size = 0,
    oldest_backup = nil,
    newest_backup = nil,
  }

  for filepath, backups in pairs(M.backups) do
    stats.total_files = stats.total_files + 1
    stats.total_backups = stats.total_backups + #backups

    for _, backup in ipairs(backups) do
      stats.total_size = stats.total_size + backup.size

      if not stats.oldest_backup or backup.timestamp < stats.oldest_backup.timestamp then
        stats.oldest_backup = backup
      end

      if not stats.newest_backup or backup.timestamp > stats.newest_backup.timestamp then
        stats.newest_backup = backup
      end
    end
  end

  return stats
end

---Show backup statistics
function M.show_stats()
  local stats = M.get_stats()

  local lines = {
    "=== Backup Statistics ===",
    "",
    string.format("Files with backups: %d", stats.total_files),
    string.format("Total backups: %d", stats.total_backups),
    string.format("Total size: %s", M.format_size(stats.total_size)),
    string.format("Backup directory: %s", M.config.backup_dir),
  }

  if stats.oldest_backup then
    table.insert(lines, "")
    table.insert(lines, string.format(
      "Oldest: %s",
      os.date("%Y-%m-%d %H:%M:%S", stats.oldest_backup.timestamp)
    ))
  end

  if stats.newest_backup then
    table.insert(lines, string.format(
      "Newest: %s",
      os.date("%Y-%m-%d %H:%M:%S", stats.newest_backup.timestamp)
    ))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Initialize on require
M.setup()

return M

-- File tree and plugin integrations for Zeke.nvim
-- Supports nvim-tree, neo-tree, oil.nvim, mini.files, and netrw
local M = {}

local logger = require('zeke.logger')

-- Get selected files from various tree explorers
function M.get_selected_files_from_tree()
  local current_ft = vim.bo.filetype
  local current_bufname = vim.api.nvim_buf_get_name(0)

  -- Try each integration
  if current_ft == "NvimTree" then
    return M._get_nvim_tree_selection()
  elseif current_ft == "neo-tree" or string.match(current_bufname, "neo%-tree") then
    return M._get_neo_tree_selection()
  elseif current_ft == "oil" then
    return M._get_oil_selection()
  elseif current_ft == "minifiles" or string.match(current_bufname, "minifiles://") then
    return M._get_mini_files_selection()
  elseif current_ft == "netrw" then
    return M._get_netrw_selection()
  else
    return nil, "Not in a supported file explorer"
  end
end

-- NvimTree integration
function M._get_nvim_tree_selection()
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    return nil, "nvim-tree not loaded"
  end

  local tree = api.tree
  local marks = api.marks

  -- Get marked files
  local marked_files = marks.list()
  if marked_files and #marked_files > 0 then
    local files = {}
    for _, mark in ipairs(marked_files) do
      if mark.absolute_path then
        table.insert(files, mark.absolute_path)
      end
    end
    return files, nil
  end

  -- Get file under cursor
  local node = tree.get_node_under_cursor()
  if node and node.absolute_path then
    return { node.absolute_path }, nil
  end

  return nil, "No selection in nvim-tree"
end

-- Neo-tree integration
function M._get_neo_tree_selection()
  local ok, state = pcall(require, "neo-tree.sources.manager")
  if not ok then
    return nil, "neo-tree not loaded"
  end

  -- Get the current neo-tree state
  local tree_state = state.get_state("filesystem")
  if not tree_state then
    return nil, "neo-tree filesystem state not found"
  end

  -- Get selected nodes
  local selected = {}

  -- Try to get marked nodes first
  if tree_state.marked_ids and vim.tbl_count(tree_state.marked_ids) > 0 then
    for id, _ in pairs(tree_state.marked_ids) do
      local node = tree_state.tree:get_node(id)
      if node and node.path then
        table.insert(selected, node.path)
      end
    end
  end

  -- If no marks, get node under cursor
  if #selected == 0 then
    local node = tree_state.tree:get_node()
    if node and node.path then
      table.insert(selected, node.path)
    end
  end

  if #selected > 0 then
    return selected, nil
  end

  return nil, "No selection in neo-tree"
end

-- Oil.nvim integration
function M._get_oil_selection()
  local ok, oil = pcall(require, "oil")
  if not ok then
    return nil, "oil.nvim not loaded"
  end

  -- Get current directory from oil
  local dir = oil.get_current_dir()
  if not dir then
    return nil, "Not in an oil buffer"
  end

  -- Get entry under cursor
  local entry = oil.get_cursor_entry()
  if entry then
    local full_path = dir .. entry.name
    if entry.type == "directory" then
      full_path = full_path .. "/"
    end
    return { full_path }, nil
  end

  return nil, "No selection in oil"
end

-- Mini.files integration
function M._get_mini_files_selection()
  local ok, mini_files = pcall(require, "mini.files")
  if not ok then
    return nil, "mini.files not loaded"
  end

  -- Get current entry
  local entry = mini_files.get_fs_entry()
  if entry and entry.path then
    return { entry.path }, nil
  end

  return nil, "No selection in mini.files"
end

-- Mini.files selection with range (for visual selection)
function M._get_mini_files_selection_with_range(start_line, end_line)
  local ok, mini_files = pcall(require, "mini.files")
  if not ok then
    return nil, "mini.files not loaded"
  end

  local files = {}

  -- Try to get entries in the range
  for line = start_line, end_line do
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    local entry = mini_files.get_fs_entry()
    if entry and entry.path then
      table.insert(files, entry.path)
    end
  end

  if #files > 0 then
    return files, nil
  end

  return nil, "No files in selected range"
end

-- Netrw integration
function M._get_netrw_selection()
  -- Get marked files in netrw
  local marked = vim.fn["netrw#Expose"]("marked")

  if marked and vim.tbl_count(marked) > 0 then
    local files = {}
    for file, _ in pairs(marked) do
      table.insert(files, file)
    end
    return files, nil
  end

  -- Get file under cursor
  local file = vim.fn.expand("<cfile>")
  if file and file ~= "" then
    local dir = vim.fn.expand("%:p:h")
    local full_path = dir .. "/" .. file
    return { full_path }, nil
  end

  return nil, "No selection in netrw"
end

-- Get files from visual selection in tree buffers
function M.get_files_from_visual_selection_in_tree()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" then
    return nil, "Not in visual mode"
  end

  local current_ft = vim.bo.filetype
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")

  -- Special handling for mini.files
  if current_ft == "minifiles" then
    return M._get_mini_files_selection_with_range(start_line, end_line)
  end

  -- For other file explorers, try to extract file paths from visual selection
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local files = {}

  for _, line in ipairs(lines) do
    -- Try to extract file path from line
    -- This is a simple heuristic and may need adjustment per file explorer
    local file_path = line:match("^%s*(.-)%s*$")  -- Trim whitespace

    if file_path and file_path ~= "" then
      -- Try to resolve relative paths
      if not file_path:match("^/") then
        local cwd = vim.fn.getcwd()
        file_path = cwd .. "/" .. file_path
      end

      -- Check if file exists
      if vim.fn.filereadable(file_path) == 1 or vim.fn.isdirectory(file_path) == 1 then
        table.insert(files, file_path)
      end
    end
  end

  if #files > 0 then
    return files, nil
  end

  return nil, "No valid files in visual selection"
end

-- Check if current buffer is a tree explorer
function M.is_tree_buffer()
  local current_ft = vim.bo.filetype
  local current_bufname = vim.api.nvim_buf_get_name(0)

  return current_ft == "NvimTree"
    or current_ft == "neo-tree"
    or current_ft == "oil"
    or current_ft == "minifiles"
    or current_ft == "netrw"
    or string.match(current_bufname, "neo%-tree")
    or string.match(current_bufname, "NvimTree")
    or string.match(current_bufname, "minifiles://")
end

-- Get current working directory based on context
function M.get_context_cwd()
  -- Try git root first
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null")
  if vim.v.shell_error == 0 and git_root ~= "" then
    return vim.fn.trim(git_root)
  end

  -- Try project root markers
  local markers = { ".git", ".hg", ".svn", "package.json", "Cargo.toml", "go.mod", ".project" }
  local current_dir = vim.fn.expand("%:p:h")

  while current_dir ~= "/" do
    for _, marker in ipairs(markers) do
      local marker_path = current_dir .. "/" .. marker
      if vim.fn.filereadable(marker_path) == 1 or vim.fn.isdirectory(marker_path) == 1 then
        return current_dir
      end
    end
    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end

  -- Fall back to current directory
  return vim.fn.getcwd()
end

-- Send files to Zeke
function M.send_files_to_zeke(files, opts)
  opts = opts or {}
  local terminal = require('zeke.terminal')

  if not files or #files == 0 then
    logger.warn("integrations", "No files to send")
    return 0
  end

  local success_count = 0

  for i, file in ipairs(files) do
    -- Add delay between files if specified
    if opts.delay and i > 1 then
      vim.defer_fn(function()
        terminal.send_file_to_ai(file)
      end, opts.delay * i)
    else
      terminal.send_file_to_ai(file)
    end

    success_count = success_count + 1
  end

  local msg = string.format("Added %d file(s) to Zeke context", success_count)
  logger.info("integrations", msg)

  return success_count
end

-- Setup integration commands
function M.setup()
  -- Command to add selected files from tree
  vim.api.nvim_create_user_command("ZekeTreeAdd", function()
    local files, error = M.get_selected_files_from_tree()

    if error then
      logger.error("integrations", error)
      return
    end

    if files and #files > 0 then
      M.send_files_to_zeke(files)
    else
      logger.warn("integrations", "No files selected")
    end
  end, {
    desc = "Add selected files from tree explorer to Zeke context"
  })

  logger.debug("integrations", "File tree integrations initialized")
end

return M
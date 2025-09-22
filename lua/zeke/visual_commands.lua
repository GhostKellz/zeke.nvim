-- Visual command support for Zeke.nvim
-- Handles visual mode operations and file extraction from tree views
local M = {}

local logger = require('zeke.logger')

-- Create a wrapper that handles both normal and visual mode commands
function M.create_visual_command_wrapper(normal_handler, visual_handler)
  return function(opts)
    opts = opts or {}

    -- Check if we're in visual mode or have visual data
    local mode = vim.fn.mode()
    local visual_mode = mode == "v" or mode == "V" or mode == "\22"

    if visual_mode or (opts.range and opts.range > 0) then
      -- Capture visual selection data before it's lost
      local visual_data = M.capture_visual_data()

      -- Exit visual mode
      if visual_mode then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
      end

      -- Call visual handler with captured data
      vim.schedule(function()
        visual_handler(visual_data, opts)
      end)
    else
      -- Call normal handler
      normal_handler(opts)
    end
  end
end

-- Capture visual selection data
function M.capture_visual_data()
  local mode = vim.fn.mode()

  -- Get visual marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  -- Get buffer and lines
  local bufnr = vim.api.nvim_get_current_buf()
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Ensure valid range
  if start_line <= 0 or end_line <= 0 then
    return nil
  end

  -- Get the selected lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  return {
    mode = mode,
    bufnr = bufnr,
    start_line = start_line,
    end_line = end_line,
    start_col = start_pos[3],
    end_col = end_pos[3],
    lines = lines,
    text = table.concat(lines, "\n"),
    file_path = vim.api.nvim_buf_get_name(bufnr),
    filetype = vim.bo.filetype,
  }
end

-- Extract files from visual selection in tree buffers
function M.get_files_from_visual_selection(visual_data)
  if not visual_data or not visual_data.lines then
    return nil, "No visual data available"
  end

  local files = {}
  local filetype = visual_data.filetype

  -- Handle different file explorer types
  if filetype == "NvimTree" then
    files = M._extract_nvim_tree_files(visual_data)
  elseif filetype == "neo-tree" then
    files = M._extract_neo_tree_files(visual_data)
  elseif filetype == "oil" then
    files = M._extract_oil_files(visual_data)
  elseif filetype == "minifiles" then
    files = M._extract_mini_files(visual_data)
  elseif filetype == "netrw" then
    files = M._extract_netrw_files(visual_data)
  else
    -- Generic extraction for unknown file explorers
    files = M._extract_generic_files(visual_data)
  end

  if #files > 0 then
    return files, nil
  else
    return nil, "No valid files found in visual selection"
  end
end

-- Extract files from NvimTree visual selection
function M._extract_nvim_tree_files(visual_data)
  local files = {}

  for _, line in ipairs(visual_data.lines) do
    -- NvimTree typically shows files with icons and indentation
    -- Try to extract file path from the line
    local file_path = line:match("%s*[│├└─%s]*[%S]+%s+(.+)$")

    if not file_path then
      -- Try simpler pattern
      file_path = line:match("%s*(.+)$")
    end

    if file_path and file_path ~= "" then
      -- Clean up the path
      file_path = vim.fn.trim(file_path)

      -- Try to resolve relative to current directory
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

  return files
end

-- Extract files from neo-tree visual selection
function M._extract_neo_tree_files(visual_data)
  local files = {}

  for _, line in ipairs(visual_data.lines) do
    -- Neo-tree has a specific format with icons and tree structure
    local file_path = line:match("[%s│├└─]*[%S]+%s+(.+)$")

    if not file_path then
      file_path = line:match("%s*(.+)$")
    end

    if file_path and file_path ~= "" then
      file_path = vim.fn.trim(file_path)

      if not file_path:match("^/") then
        local cwd = vim.fn.getcwd()
        file_path = cwd .. "/" .. file_path
      end

      if vim.fn.filereadable(file_path) == 1 or vim.fn.isdirectory(file_path) == 1 then
        table.insert(files, file_path)
      end
    end
  end

  return files
end

-- Extract files from oil.nvim visual selection
function M._extract_oil_files(visual_data)
  local files = {}

  -- Oil shows files in a more direct way
  local ok, oil = pcall(require, "oil")
  if ok then
    local dir = oil.get_current_dir()
    if dir then
      for _, line in ipairs(visual_data.lines) do
        local file_name = vim.fn.trim(line)
        if file_name ~= "" and not file_name:match("^%.%.") then
          local full_path = dir .. file_name
          if vim.fn.filereadable(full_path) == 1 or vim.fn.isdirectory(full_path) == 1 then
            table.insert(files, full_path)
          end
        end
      end
    end
  end

  return files
end

-- Extract files from mini.files visual selection
function M._extract_mini_files(visual_data)
  local files = {}

  local ok, mini_files = pcall(require, "mini.files")
  if ok then
    -- Mini.files has a specific way to get entries
    -- For visual selection, we need to parse the displayed lines
    for _, line in ipairs(visual_data.lines) do
      local file_path = vim.fn.trim(line)

      if file_path ~= "" then
        -- Try to get the full path
        if not file_path:match("^/") then
          local cwd = vim.fn.getcwd()
          file_path = cwd .. "/" .. file_path
        end

        if vim.fn.filereadable(file_path) == 1 or vim.fn.isdirectory(file_path) == 1 then
          table.insert(files, file_path)
        end
      end
    end
  end

  return files
end

-- Extract files from netrw visual selection
function M._extract_netrw_files(visual_data)
  local files = {}

  local dir = vim.fn.expand("%:p:h")

  for _, line in ipairs(visual_data.lines) do
    -- Skip netrw header lines
    if not line:match("^\"") and not line:match("^%.%.") then
      local file_name = vim.fn.trim(line)

      -- Remove any netrw markers
      file_name = file_name:gsub("@$", "")  -- Remove symlink marker
      file_name = file_name:gsub("/$", "")  -- Remove directory marker
      file_name = file_name:gsub("*$", "")  -- Remove executable marker

      if file_name ~= "" and file_name ~= "." and file_name ~= ".." then
        local full_path = dir .. "/" .. file_name

        if vim.fn.filereadable(full_path) == 1 or vim.fn.isdirectory(full_path) == 1 then
          table.insert(files, full_path)
        end
      end
    end
  end

  return files
end

-- Generic file extraction for unknown file explorers
function M._extract_generic_files(visual_data)
  local files = {}

  for _, line in ipairs(visual_data.lines) do
    -- Try to extract anything that looks like a file path
    local file_path = vim.fn.trim(line)

    -- Skip empty lines and common non-file patterns
    if file_path ~= "" and not file_path:match("^[#%-=]") then
      -- Try absolute path first
      if vim.fn.filereadable(file_path) == 1 or vim.fn.isdirectory(file_path) == 1 then
        table.insert(files, file_path)
      else
        -- Try relative to current directory
        local cwd = vim.fn.getcwd()
        local full_path = cwd .. "/" .. file_path

        if vim.fn.filereadable(full_path) == 1 or vim.fn.isdirectory(full_path) == 1 then
          table.insert(files, full_path)
        end
      end
    end
  end

  return files
end

-- Helper to check if we're in a file explorer
function M.is_file_explorer()
  local filetype = vim.bo.filetype
  local bufname = vim.api.nvim_buf_get_name(0)

  return filetype == "NvimTree"
    or filetype == "neo-tree"
    or filetype == "oil"
    or filetype == "minifiles"
    or filetype == "netrw"
    or string.match(bufname, "neo%-tree")
    or string.match(bufname, "NvimTree")
    or string.match(bufname, "minifiles://")
end

return M
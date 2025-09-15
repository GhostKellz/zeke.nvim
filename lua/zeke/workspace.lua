local M = {}

-- Workspace state
M.context_files = {}
M.workspace_root = nil
M.file_index = {}

-- File patterns to include/exclude
local DEFAULT_INCLUDE_PATTERNS = {
  '*.lua', '*.rs', '*.py', '*.js', '*.ts', '*.jsx', '*.tsx',
  '*.go', '*.c', '*.cpp', '*.h', '*.hpp', '*.java', '*.kt',
  '*.rb', '*.php', '*.cs', '*.swift', '*.dart', '*.scala',
  '*.sh', '*.bash', '*.zsh', '*.fish', '*.toml', '*.yaml',
  '*.yml', '*.json', '*.xml', '*.md', '*.txt', '*.cfg',
  '*.ini', '*.conf', 'Dockerfile', 'Makefile', 'CMakeLists.txt'
}

local DEFAULT_EXCLUDE_PATTERNS = {
  '*/node_modules/*', '*/.git/*', '*/target/*', '*/build/*',
  '*/dist/*', '*/.vscode/*', '*/.idea/*', '*/vendor/*',
  '*/__pycache__/*', '*.pyc', '*.class', '*.o', '*.obj',
  '*.exe', '*.dll', '*.so', '*.dylib', '*.a', '*.lib'
}

function M.setup()
  M.workspace_root = M.find_workspace_root()
  M.scan_workspace()
end

function M.find_workspace_root()
  local current_dir = vim.fn.getcwd()
  local markers = {
    '.git', '.hg', '.svn', 'Cargo.toml', 'package.json',
    'go.mod', 'pyproject.toml', 'requirements.txt', 'Gemfile',
    'pom.xml', 'build.gradle', 'CMakeLists.txt', 'Makefile'
  }

  local function has_marker(dir)
    for _, marker in ipairs(markers) do
      local path = dir .. '/' .. marker
      if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
        return true
      end
    end
    return false
  end

  local dir = current_dir
  while dir ~= '/' do
    if has_marker(dir) then
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end

  return current_dir
end

function M.scan_workspace()
  if not M.workspace_root then
    return
  end

  M.file_index = {}

  local function scan_directory(dir, relative_path)
    relative_path = relative_path or ''

    local handle = vim.loop.fs_scandir(dir)
    if not handle then
      return
    end

    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      local full_path = dir .. '/' .. name
      local rel_path = relative_path == '' and name or (relative_path .. '/' .. name)

      if type == 'directory' then
        if not M.should_exclude_path(rel_path) then
          scan_directory(full_path, rel_path)
        end
      elseif type == 'file' then
        if M.should_include_file(name) and not M.should_exclude_path(rel_path) then
          M.file_index[rel_path] = {
            full_path = full_path,
            relative_path = rel_path,
            size = vim.loop.fs_stat(full_path).size,
            mtime = vim.loop.fs_stat(full_path).mtime.sec,
          }
        end
      end

      name, type = vim.loop.fs_scandir_next(handle)
    end
  end

  scan_directory(M.workspace_root)
end

function M.should_include_file(filename)
  for _, pattern in ipairs(DEFAULT_INCLUDE_PATTERNS) do
    if vim.fn.match(filename, vim.fn.glob2regpat(pattern)) ~= -1 then
      return true
    end
  end
  return false
end

function M.should_exclude_path(path)
  for _, pattern in ipairs(DEFAULT_EXCLUDE_PATTERNS) do
    if vim.fn.match(path, vim.fn.glob2regpat(pattern)) ~= -1 then
      return true
    end
  end
  return false
end

function M.add_file_to_context(file_path)
  -- Normalize file path
  if not vim.startswith(file_path, '/') then
    file_path = M.workspace_root .. '/' .. file_path
  end

  if not vim.fn.filereadable(file_path) then
    vim.notify('File not found: ' .. file_path, vim.log.levels.ERROR)
    return
  end

  -- Check if already in context
  for _, ctx_file in ipairs(M.context_files) do
    if ctx_file.path == file_path then
      vim.notify('File already in context: ' .. vim.fn.fnamemodify(file_path, ':t'), vim.log.levels.WARN)
      return
    end
  end

  -- Read file content
  local lines = vim.fn.readfile(file_path)
  local content = table.concat(lines, '\n')

  -- Add to context
  table.insert(M.context_files, {
    path = file_path,
    relative_path = vim.fn.fnamemodify(file_path, ':~:.'),
    content = content,
    lines = #lines,
    size = #content,
    added_at = os.time(),
  })

  vim.notify('Added to context: ' .. vim.fn.fnamemodify(file_path, ':t'), vim.log.levels.INFO)
end

function M.remove_file_from_context(file_path)
  for i, ctx_file in ipairs(M.context_files) do
    if ctx_file.path == file_path or ctx_file.relative_path == file_path then
      table.remove(M.context_files, i)
      vim.notify('Removed from context: ' .. vim.fn.fnamemodify(file_path, ':t'), vim.log.levels.INFO)
      return
    end
  end

  vim.notify('File not in context: ' .. file_path, vim.log.levels.WARN)
end

function M.clear_context()
  M.context_files = {}
  vim.notify('Context cleared', vim.log.levels.INFO)
end

function M.get_context_summary()
  if #M.context_files == 0 then
    return 'No files in context'
  end

  local total_lines = 0
  local total_size = 0
  local file_list = {}

  for _, file in ipairs(M.context_files) do
    total_lines = total_lines + file.lines
    total_size = total_size + file.size
    table.insert(file_list, file.relative_path)
  end

  return string.format(
    '%d files, %d lines, %d bytes\nFiles: %s',
    #M.context_files,
    total_lines,
    total_size,
    table.concat(file_list, ', ')
  )
end

function M.build_context_prompt()
  if #M.context_files == 0 then
    return ''
  end

  local prompt = '\n\n## Context Files\n\n'

  for _, file in ipairs(M.context_files) do
    prompt = prompt .. string.format(
      '### %s\n\n```%s\n%s\n```\n\n',
      file.relative_path,
      M.get_file_language(file.path),
      file.content
    )
  end

  return prompt
end

function M.get_file_language(file_path)
  local ext = vim.fn.fnamemodify(file_path, ':e')
  local lang_map = {
    lua = 'lua', rs = 'rust', py = 'python', js = 'javascript',
    ts = 'typescript', jsx = 'jsx', tsx = 'tsx', go = 'go',
    c = 'c', cpp = 'cpp', h = 'c', hpp = 'cpp', java = 'java',
    kt = 'kotlin', rb = 'ruby', php = 'php', cs = 'csharp',
    swift = 'swift', dart = 'dart', scala = 'scala',
    sh = 'bash', bash = 'bash', zsh = 'zsh', fish = 'fish',
    toml = 'toml', yaml = 'yaml', yml = 'yaml', json = 'json',
    xml = 'xml', md = 'markdown', txt = 'text'
  }

  return lang_map[ext] or ext
end

function M.add_current_file()
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return
  end

  M.add_file_to_context(current_file)
end

function M.add_selection()
  local mode = vim.api.nvim_get_mode().mode
  if mode ~= 'v' and mode ~= 'V' and mode ~= '' then
    vim.notify('No selection active', vim.log.levels.WARN)
    return
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

  if #lines == 0 then
    return
  end

  -- Trim first and last line if needed
  if #lines == 1 then
    lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
  else
    lines[1] = lines[1]:sub(start_pos[3])
    lines[#lines] = lines[#lines]:sub(1, end_pos[3])
  end

  local content = table.concat(lines, '\n')
  local current_file = vim.api.nvim_buf_get_name(0)
  local filename = vim.fn.fnamemodify(current_file, ':t')

  -- Add as a context snippet
  table.insert(M.context_files, {
    path = current_file .. ':selection',
    relative_path = filename .. ' (selection)',
    content = content,
    lines = #lines,
    size = #content,
    added_at = os.time(),
  })

  vim.notify('Added selection to context', vim.log.levels.INFO)
end

function M.search_files(query)
  local results = {}

  for rel_path, file_info in pairs(M.file_index) do
    if rel_path:lower():find(query:lower(), 1, true) then
      table.insert(results, {
        path = file_info.full_path,
        relative_path = rel_path,
        score = 100, -- Could implement fuzzy matching score
      })
    end
  end

  table.sort(results, function(a, b) return a.score > b.score end)
  return results
end

function M.show_context_files()
  if #M.context_files == 0 then
    vim.notify('No files in context', vim.log.levels.INFO)
    return
  end

  local items = {}
  for i, file in ipairs(M.context_files) do
    table.insert(items, string.format('%d. %s (%d lines)', i, file.relative_path, file.lines))
  end

  vim.ui.select(items, {
    prompt = 'Context files (select to remove):',
  }, function(choice, idx)
    if idx then
      local file = M.context_files[idx]
      M.remove_file_from_context(file.path)
    end
  end)
end

function M.file_picker()
  local files = {}
  for rel_path, _ in pairs(M.file_index) do
    table.insert(files, rel_path)
  end

  table.sort(files)

  vim.ui.select(files, {
    prompt = 'Add file to context:',
  }, function(choice)
    if choice then
      M.add_file_to_context(M.workspace_root .. '/' .. choice)
    end
  end)
end

return M
-- Template-based prompts for common coding tasks
local M = {}

local http = require('zeke.http_client')
local tools = require('zeke.context.tools')
local logger = require('zeke.logger')

-- Prompt templates
M.templates = {
  explain = {
    description = "Explain selected code or buffer",
    build_prompt = function(code, opts)
      return string.format(
        "Explain this %s code in detail. Break down what it does, how it works, and any important concepts:\n\n```%s\n%s\n```",
        opts.language or "",
        opts.language or "",
        code
      )
    end,
  },

  fix = {
    description = "Fix code issues and bugs",
    build_prompt = function(code, opts)
      local diagnostics = tools.get_diagnostics()
      local diag_text = ""

      if #diagnostics > 0 then
        local lines = {}
        for _, d in ipairs(diagnostics) do
          table.insert(lines, string.format("- Line %d: [%s] %s", d.line, d.severity, d.message))
        end
        diag_text = "\n\n**Diagnostics**:\n" .. table.concat(lines, "\n")
      end

      return string.format(
        "Fix the issues in this code. Return the corrected version with explanations of what was wrong and how you fixed it.%s\n\n```%s\n%s\n```",
        diag_text,
        opts.language or "",
        code
      )
    end,
  },

  optimize = {
    description = "Optimize code for performance",
    build_prompt = function(code, opts)
      return string.format(
        "Optimize this code for better performance, readability, and maintainability. Explain each optimization:\n\n```%s\n%s\n```",
        opts.language or "",
        code
      )
    end,
  },

  docs = {
    description = "Add documentation comments",
    build_prompt = function(code, opts)
      return string.format(
        "Add comprehensive documentation comments to this code. Include function descriptions, parameter explanations, return values, and examples where appropriate:\n\n```%s\n%s\n```",
        opts.language or "",
        code
      )
    end,
  },

  tests = {
    description = "Generate unit tests",
    build_prompt = function(code, opts)
      return string.format(
        "Generate comprehensive unit tests for this code. Include edge cases, error cases, and normal cases:\n\n```%s\n%s\n```",
        opts.language or "",
        code
      )
    end,
  },

  commit = {
    description = "Generate commit message",
    build_prompt = function(code, opts)
      return string.format(
        "Generate a conventional commit message for these changes. Use the format: type(scope): description\n\nValid types: feat, fix, docs, style, refactor, test, chore\n\n```diff\n%s\n```",
        code
      )
    end,
  },

  refactor = {
    description = "Refactor code",
    build_prompt = function(code, opts)
      return string.format(
        "Refactor this code following best practices and design patterns. Explain the improvements and why they matter:\n\n```%s\n%s\n```",
        opts.language or "",
        code
      )
    end,
  },

  review = {
    description = "Code review",
    build_prompt = function(code, opts)
      return string.format(
        "Perform a thorough code review. Check for:\n- Bugs and potential issues\n- Code quality and style\n- Performance concerns\n- Security vulnerabilities\n- Best practices\n\n```%s\n%s\n```",
        opts.language or "",
        code
      )
    end,
  },
}

-- Execute a prompt template
function M.execute(template_name, code, opts)
  opts = opts or {}
  local utils = require('zeke.utils')

  local template = M.templates[template_name]
  if not template then
    vim.notify('Unknown template: ' .. template_name, vim.log.levels.ERROR)
    return
  end

  -- Get code if not provided
  if not code then
    if template_name == 'commit' then
      -- For commit, use staged git diff
      code = vim.fn.system("git diff --cached")
      if vim.v.shell_error ~= 0 or code == "" then
        vim.notify('No staged changes found. Stage changes with: git add <files>', vim.log.levels.WARN)
        return
      end
    else
      -- Check if called from visual mode (has range)
      if opts.range and opts.range ~= 0 then
        code = utils.get_visual_selection()
        if code == "" then
          vim.notify('No selection found', vim.log.levels.WARN)
          return
        end
        logger.info('prompts', 'Using visual selection')
      else
        -- For other templates, use current buffer
        local file = tools.get_current_file()
        if not file then
          vim.notify('No file open', vim.log.levels.WARN)
          return
        end
        code = file.content
        opts.language = file.language
      end
    end
  end

  -- Safety check: Warn if code is very large
  local token_estimate = utils.estimate_tokens(code)
  if token_estimate > 4000 then
    local formatted = utils.format_tokens(token_estimate)
    local proceed = utils.confirm(
      string.format('Large input (%s). This may be slow or expensive. Continue?', formatted),
      false
    )
    if not proceed then
      logger.info('prompts', 'User cancelled large request')
      return
    end
  end

  -- Build prompt
  local prompt = template.build_prompt(code, opts)

  logger.info('prompts', 'Executing template: ' .. template_name)

  -- Show loading notification
  local notify_id = vim.notify('Processing with ' .. template.description .. '...', vim.log.levels.INFO, {
    timeout = false,
  })

  -- Send to API
  vim.schedule(function()
    local ok, res = pcall(http.chat, prompt, {
      language = opts.language,
      intent = template_name,
    })

    -- Dismiss loading notification
    if notify_id then
      vim.notify('', vim.log.levels.INFO, { replace = notify_id, timeout = 1 })
    end

    if not ok then
      vim.notify('Failed: ' .. tostring(res), vim.log.levels.ERROR)
      return
    end

    -- Show response in floating window
    M.show_response(res, template)

    logger.info('prompts', string.format('Provider: %s, Latency: %dms', res.provider or 'unknown', res.latency_ms or 0))
  end)
end

-- Show response in floating window
function M.show_response(res, template)
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')

  -- Set content
  local lines = vim.split(res.response, '\n', { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Open window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = string.format(' %s (%s via %s) ', template.description, res.model or 'unknown', res.provider or 'unknown'),
    title_pos = 'center',
  })

  -- Set keymaps
  local opts_map = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set('n', 'q', ':close<CR>', opts_map)
  vim.keymap.set('n', '<Esc>', ':close<CR>', opts_map)

  -- Add yank keymap for easy copying
  vim.keymap.set('n', 'y', function()
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(all_lines, '\n')
    vim.fn.setreg('+', content)
    vim.notify('Response copied to clipboard', vim.log.levels.INFO)
  end, opts_map)
end

return M

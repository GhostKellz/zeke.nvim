--[[
  Interactive Help System

  Provides comprehensive help for zeke.nvim with:
  - Command reference
  - Keymap cheat sheet
  - Quick start guide
  - Feature overviews
  - Interactive navigation
--]]

local M = {}

local function create_help_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
  vim.api.nvim_buf_set_name(bufnr, 'ZekeHelp')
  return bufnr
end

local function get_help_content()
  return {
    "# 🤖 ZEKE.NVIM - Interactive Help",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## 🚀 Quick Start",
    "",
    "1. Open AI Agent:       :ZekeCode",
    "2. Select code → Edit:  :ZekeEdit",
    "3. Quick actions menu:  <leader>za",
    "4. Fix diagnostic:      <leader>zf",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## 📋 Main Commands",
    "",
    "### AI Agent Interface",
    "  :ZekeCode              - Open AI agent chat (Tab to cycle models)",
    "  :ZekeCodeClose         - Close agent interface",
    "  :ZekeCodeClear         - Clear chat history",
    "",
    "### Code Operations",
    "  :ZekeEdit              - Edit current buffer with AI",
    "  :ZekeExplain           - Explain current buffer",
    "  :ZekeChat [msg]        - Quick chat message",
    "",
    "### Code Actions (Context-Aware)",
    "  :ZekeActions           - Show actions menu",
    "  :ZekeExplainCode       - Explain selected code",
    "  :ZekeFixCode           - Fix issues in code",
    "  :ZekeRefactorCode      - Refactor selection",
    "  :ZekeGenerateTests     - Generate tests",
    "",
    "### Model Management",
    "  :ZekeModels            - Model picker",
    "  :ZekeModelNext         - Next model",
    "  :ZekeModelPrev         - Previous model",
    "  :ZekeModelInfo         - Current model info",
    "",
    "### Production Features",
    "  :ZekeRequests          - Request inspector (retry status)",
    "  :ZekeTokens            - Token usage statistics",
    "  :ZekeTokensReset       - Reset token stats",
    "  :ZekeBackups           - Backup picker (restore old versions)",
    "  :ZekeBackupStats       - Backup statistics",
    "  :ZekeBackupCleanup     - Cleanup old backups",
    "  :ZekeSafety            - Safety statistics (rate limits)",
    "",
    "### Diagnostics & LSP",
    "  :ZekeFix               - Fix diagnostic at cursor",
    "  :ZekeExplainDiagnostic - Explain diagnostic",
    "",
    "### System",
    "  :ZekeHealth            - Health check",
    "  :ZekeHelp              - This help (you're here!)",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## ⌨️  Default Keymaps",
    "",
    "### Code Actions",
    "  <leader>za             - Actions menu",
    "  <leader>ze             - Explain code",
    "  <leader>zf             - Fix code",
    "  <leader>zr             - Refactor code",
    "  <leader>zt             - Generate tests",
    "",
    "### AI Chat (in ZekeCode interface)",
    "  <CR>                   - Send message",
    "  <C-CR>                 - Send and stay in insert",
    "  <Tab>                  - Cycle to next model",
    "  <S-Tab>                - Cycle to previous model",
    "  <leader>m              - Model picker",
    "  <C-l>                  - Clear chat",
    "  <C-f>                  - File picker (insert @file:)",
    "  <Esc>                  - Close interface",
    "",
    "### Diff View (after AI edit)",
    "  [c                     - Previous hunk",
    "  ]c                     - Next hunk",
    "  <leader>dh             - Accept current hunk",
    "  <leader>dx             - Reject current hunk",
    "  <leader>ds             - Show hunk statistics",
    "  <leader>da             - Accept all changes",
    "  <leader>dr             - Reject all changes",
    "  <leader>dd             - Close diff",
    "  <CR>                   - Accept all",
    "",
    "### General AI Shortcuts",
    "  <leader>aa             - Ask AI (opens chat)",
    "  <leader>af             - AI: Fix diagnostic",
    "  <leader>ae             - AI: Edit selection",
    "  <leader>ax             - AI: Explain code",
    "  <leader>ac             - AI: Toggle chat panel",
    "  <leader>at             - AI: Toggle completions",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## 🎯 @-Mentions (Context System)",
    "",
    "Use @-mentions in prompts to include context:",
    "",
    "  @file:path/to/file     - Include specific file",
    "  @buffer                - Include current buffer",
    "  @selection             - Include visual selection",
    "  @diag                  - Include diagnostics",
    "  @git:diff              - Include git diff",
    "  @git:status            - Include git status",
    "",
    "Example: \"Fix the bug in @file:src/main.rs using @diag\"",
    "",
    "Press <C-f> in chat to open file picker for @file: mentions.",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## 🛡️  Production Features",
    "",
    "### Automatic Retry",
    "  - Failed requests automatically retry with exponential backoff",
    "  - View retry status: :ZekeRequests",
    "  - Retries: timeouts, rate limits (429, 503, 504)",
    "  - Skips: auth errors (401, 403, 404)",
    "",
    "### Token Estimation",
    "  - See token count & cost before sending",
    "  - Warnings at 4K, 8K tokens",
    "  - Blocks at 16K tokens",
    "  - Track usage: :ZekeTokens",
    "",
    "### Auto-Backup",
    "  - Automatic backup before every AI edit",
    "  - Stored: ~/.local/share/nvim/zeke/backups",
    "  - Restore: :ZekeBackups",
    "  - Auto-cleanup: 10 backups per file, 30 day retention",
    "",
    "### Safety Checks",
    "  - Rate limiting warnings (10/min warn, 20/min critical)",
    "  - File size warnings (500 lines warn, 1K critical)",
    "  - Confirmation dialogs for risky operations",
    "  - View stats: :ZekeSafety",
    "",
    "### Partial Diff Acceptance",
    "  - Accept/reject individual hunks (not all-or-nothing)",
    "  - Navigate with [c and ]c",
    "  - Accept hunk: <leader>dh",
    "  - Reject hunk: <leader>dx",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## 🎨 Statusline Integration",
    "",
    "Add zeke status to your statusline:",
    "",
    "### Standalone",
    "  vim.o.statusline = '%f %=%{v:lua.require(\"zeke.statusline\").get_statusline()}'",
    "",
    "### With Lualine",
    "  require('lualine').setup({",
    "    sections = {",
    "      lualine_x = {",
    "        require('zeke.statusline').lualine_status,",
    "        'encoding', 'filetype',",
    "      },",
    "    },",
    "  })",
    "",
    "Shows: Model | Tokens/Cost | Requests | Rate Limit",
    "Example: 🤖 claude-sonnet-4 │ 💰 $0.45 │ ⚡ in_progress │ 🟢 3/min",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## 🔧 Common Workflows",
    "",
    "### Workflow 1: Fix Bug with Context",
    "  1. Position cursor on error",
    "  2. :ZekeCode",
    "  3. Type: \"Fix this bug using @diag and @buffer\"",
    "  4. Review diff → Accept with <leader>da",
    "",
    "### Workflow 2: Refactor Function",
    "  1. Select function (visual mode)",
    "  2. <leader>zr (or :ZekeRefactorCode)",
    "  3. Review suggestions",
    "  4. Navigate hunks with ]c",
    "  5. Accept good changes: <leader>dh",
    "  6. Reject bad changes: <leader>dx",
    "",
    "### Workflow 3: Add Tests",
    "  1. Open file to test",
    "  2. <leader>zt (or :ZekeGenerateTests)",
    "  3. AI generates test file",
    "  4. Review and accept",
    "",
    "### Workflow 4: Multi-File Context",
    "  1. :ZekeCode",
    "  2. Type: \"Refactor @file:src/main.rs to use @file:src/lib.rs\"",
    "  3. AI sees both files",
    "  4. Apply changes",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## 🚨 Troubleshooting",
    "",
    "### CLI Not Found",
    "  - Run: :ZekeHealth",
    "  - Install: https://github.com/ghostkellz/zeke",
    "  - Check PATH: which zeke",
    "",
    "### Requests Failing",
    "  - Check: :ZekeRequests (see retry status)",
    "  - Verify API keys in ~/.config/zeke/zeke.toml",
    "  - Check rate limits: :ZekeSafety",
    "",
    "### Diff Not Working",
    "  - Ensure file is saved first",
    "  - Check: :set diff? (should be 'diff')",
    "  - Try closing and reopening: <leader>dd then :ZekeEdit",
    "",
    "### Backups Not Restoring",
    "  - List backups: :ZekeBackups",
    "  - Check directory: ~/.local/share/nvim/zeke/backups",
    "  - Manually restore: copy from backup directory",
    "",
    "### High Costs",
    "  - Check usage: :ZekeTokens",
    "  - Use local models: :ZekeModels → qwen2.5-coder:7b",
    "  - Monitor rate: :ZekeSafety",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## 📚 Documentation",
    "",
    "  :help zeke              - Full documentation",
    "",
    "  docs/mentions.md        - @-mention system guide",
    "  docs/code-actions.md    - Code actions reference",
    "  docs/statusline.md      - Statusline integration",
    "  docs/partial-diffs.md   - Partial diff acceptance",
    "  docs/PRODUCTION_POLISH.md - Production features overview",
    "",
    "  GitHub: https://github.com/ghostkellz/zeke.nvim",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## ⚙️  Configuration Example",
    "",
    "require('zeke').setup({",
    "  -- Enable/disable features",
    "  completion = true,",
    "  statusline = true,",
    "",
    "  -- Keymaps",
    "  keymaps = {",
    "    actions = '<leader>za',",
    "    explain = '<leader>ze',",
    "    fix = '<leader>zf',",
    "    refactor = '<leader>zr',",
    "    tests = '<leader>zt',",
    "  },",
    "",
    "  -- Production polish",
    "  backup = {",
    "    enabled = true,",
    "    max_backups_per_file = 10,",
    "  },",
    "",
    "  safety = {",
    "    rate_limit_warn = 10,",
    "    confirm_large_edits = true,",
    "  },",
    "",
    "  -- Diff",
    "  diff = {",
    "    vertical_split = true,",
    "    auto_close_on_accept = true,",
    "  },",
    "})",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "## 🎓 Tips & Best Practices",
    "",
    "1. **Use @-mentions** for better context",
    "   - Include relevant files with @file:",
    "   - Add diagnostics with @diag",
    "",
    "2. **Review before accepting**",
    "   - Navigate hunks with ]c",
    "   - Accept/reject individually",
    "   - Check token costs before sending",
    "",
    "3. **Leverage backups**",
    "   - Automatic before every edit",
    "   - Restore with :ZekeBackups",
    "   - Test changes, rollback if needed",
    "",
    "4. **Monitor costs**",
    "   - Check :ZekeTokens regularly",
    "   - Use local models for experiments",
    "   - Watch rate limits in statusline",
    "",
    "5. **Customize keymaps**",
    "   - Set your preferred bindings",
    "   - Use <leader>z prefix for consistency",
    "   - Add to which-key for discoverability",
    "",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "Press 'q' or <Esc> to close this help window",
    "",
    "For more help: :help zeke or visit https://github.com/ghostkellz/zeke.nvim",
    "",
  }
end

---Show help window
function M.show()
  local bufnr = create_help_buffer()
  local content = get_help_content()

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

  -- Calculate window size
  local width = math.min(100, vim.o.columns - 4)
  local height = math.min(50, vim.o.lines - 4)

  -- Center window
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- Open window
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    title = ' 🤖 Zeke.nvim Help ',
    title_pos = 'center',
  })

  -- Set window options
  vim.api.nvim_set_option_value('wrap', true, { win = winnr })
  vim.api.nvim_set_option_value('linebreak', true, { win = winnr })
  vim.api.nvim_set_option_value('cursorline', true, { win = winnr })

  -- Set keymaps for closing
  local close_keys = { 'q', '<Esc>' }
  for _, key in ipairs(close_keys) do
    vim.api.nvim_buf_set_keymap(bufnr, 'n', key, ':close<CR>', {
      noremap = true,
      silent = true,
      desc = 'Close help'
    })
  end

  -- Jump to Quick Start section by default
  vim.api.nvim_win_set_cursor(winnr, { 5, 0 })
end

---Show quick reference (compact version)
function M.show_quick_reference()
  local content = {
    "# Zeke.nvim Quick Reference",
    "",
    "Commands:  :ZekeCode  :ZekeEdit  :ZekeActions  :ZekeHelp",
    "Actions:   <leader>za  <leader>ze  <leader>zf  <leader>zr",
    "Diff:      [c ]c  <leader>dh  <leader>dx  <leader>da",
    "Agent:     <CR> send  <Tab> cycle  <C-f> file  <Esc> close",
    "",
    "Full help: :ZekeHelp",
  }

  vim.notify(table.concat(content, "\n"), vim.log.levels.INFO)
end

---Show section of help
---@param section string Section name
function M.show_section(section)
  local sections = {
    quickstart = { start = 5, lines = 10 },
    commands = { start = 14, lines = 40 },
    keymaps = { start = 60, lines = 30 },
    mentions = { start = 95, lines = 15 },
    production = { start = 115, lines = 30 },
    workflows = { start = 160, lines = 35 },
    troubleshooting = { start = 200, lines = 30 },
  }

  if not sections[section] then
    vim.notify("Unknown section: " .. section, vim.log.levels.WARN)
    return
  end

  M.show()

  -- Jump to section
  local sec = sections[section]
  vim.defer_fn(function()
    vim.api.nvim_win_set_cursor(0, { sec.start, 0 })
  end, 50)
end

return M

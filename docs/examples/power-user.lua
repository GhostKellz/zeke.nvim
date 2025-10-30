-- Power User Configuration
-- Full-featured setup with all bells and whistles

require('zeke').setup({
  -- Enable all features
  completion = true,
  statusline = true,

  -- Custom keymaps
  keymaps = {
    actions = '<leader>za',
    explain = '<leader>ze',
    fix = '<leader>zf',
    refactor = '<leader>zr',
    tests = '<leader>zt',
    chat_panel = '<leader>zc',
    edit = '<leader>ze',
    model_picker = '<leader>zm',
    model_next = '<Tab>',
    model_prev = '<S-Tab>',
  },

  -- Production polish - aggressive safety
  backup = {
    enabled = true,
    max_backups_per_file = 20,  -- Keep more backups
    auto_cleanup_days = 60,     -- Keep backups longer
  },

  safety = {
    confirm_large_edits = true,
    confirm_destructive = true,
    auto_backup_before_edit = true,
    rate_limit_warn = 5,        -- Warn earlier
    rate_limit_critical = 10,   -- Lower critical threshold
  },

  tokens = {
    warn_tokens = 3000,         -- More conservative
    critical_tokens = 6000,
    max_tokens = 12000,
  },

  -- Diff preferences
  diff = {
    open_in_new_tab = true,     -- Isolate diffs in tabs
    vertical_split = true,
    auto_close_on_accept = true,
    show_diff_stats = true,
  },

  -- Statusline - detailed
  statusline = {
    enabled = true,
    show_model = true,
    show_tokens = true,
    show_requests = true,
    show_rate_limit = true,
    icons = {
      model = '🤖',
      tokens = '💰',
      request = '⚡',
      rate_limit_ok = '🟢',
      rate_limit_warn = '🟡',
      rate_limit_critical = '🔴',
    },
  },

  -- Logger - verbose for debugging
  logger = {
    level = 'debug',
  },
})

-- Advanced keymaps
local keymap = vim.keymap.set

-- AI Agent
keymap('n', '<leader>aa', ':ZekeCode<CR>', { desc = 'AI Agent' })
keymap('n', '<leader>ac', ':ZekeCodeClear<CR>', { desc = 'Clear Chat' })
keymap('n', '<leader>aq', ':ZekeCodeClose<CR>', { desc = 'Close Agent' })

-- Code actions (enhanced)
keymap('n', '<leader>za', ':ZekeActions<CR>', { desc = 'Actions Menu' })
keymap('n', '<leader>ze', ':ZekeExplainCode<CR>', { desc = 'Explain' })
keymap('n', '<leader>zf', ':ZekeFixCode<CR>', { desc = 'Fix' })
keymap('n', '<leader>zr', ':ZekeRefactorCode<CR>', { desc = 'Refactor' })
keymap('n', '<leader>zt', ':ZekeGenerateTests<CR>', { desc = 'Tests' })
keymap('v', '<leader>za', ':ZekeActions<CR>', { desc = 'Actions (Selection)' })

-- Model management
keymap('n', '<leader>zm', ':ZekeModels<CR>', { desc = 'Model Picker' })
keymap('n', '<leader>zn', ':ZekeModelNext<CR>', { desc = 'Next Model' })
keymap('n', '<leader>zp', ':ZekeModelPrev<CR>', { desc = 'Prev Model' })
keymap('n', '<leader>zi', ':ZekeModelInfo<CR>', { desc = 'Model Info' })

-- Production features
keymap('n', '<leader>zb', ':ZekeBackups<CR>', { desc = 'Backups' })
keymap('n', '<leader>zs', ':ZekeSafety<CR>', { desc = 'Safety Stats' })
keymap('n', '<leader>zu', ':ZekeTokens<CR>', { desc = 'Token Usage' })
keymap('n', '<leader>zx', ':ZekeRequests<CR>', { desc = 'Request Inspector' })

-- Quick reference
keymap('n', '<leader>z?', ':ZekeHelp<CR>', { desc = 'Help' })
keymap('n', '<leader>zh', ':ZekeQuickRef<CR>', { desc = 'Quick Ref' })

-- Health check
keymap('n', '<leader>zH', ':ZekeHealth<CR>', { desc = 'Health Check' })

-- Lualine integration
require('lualine').setup({
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {
      -- Zeke status
      require('zeke.statusline').lualine_status,
      'encoding',
      'fileformat',
      'filetype'
    },
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  options = {
    theme = 'auto',
    globalstatus = true,
  },
})

-- which-key integration (optional)
local ok, wk = pcall(require, "which-key")
if ok then
  wk.register({
    z = {
      name = "AI (Zeke)",
      a = "Actions",
      e = "Explain",
      f = "Fix",
      r = "Refactor",
      t = "Tests",
      m = "Models",
      b = "Backups",
      s = "Safety",
      u = "Usage",
      x = "Requests",
      ["?"] = "Help",
    },
  }, { prefix = "<leader>" })
end

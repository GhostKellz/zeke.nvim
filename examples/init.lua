-- Example Neovim configuration for zeke.nvim
-- This file shows a complete setup with lazy.nvim

-- ============================================================================
-- Bootstrap lazy.nvim (if not installed)
-- ============================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================================
-- Plugin Setup
-- ============================================================================
require("lazy").setup({
  -- zeke.nvim - AI coding assistant
  {
    "ghostkellz/zeke.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required for HTTP client
    },
    config = function()
      require("zeke").setup({
        -- HTTP API Configuration
        http_api = {
          base_url = "http://localhost:7878", -- Zeke HTTP API URL
          timeout = 30000,                     -- Request timeout in ms
        },

        -- Default model (configured in Zeke server)
        default_model = 'smart', -- 'smart', 'qwen2.5-coder:7b', 'claude-3-5-sonnet', etc.

        -- UI settings
        auto_reload = true,

        -- Keymaps (set to false to disable)
        keymaps = {
          chat = '<leader>zc',       -- Quick chat
          edit = '<leader>ze',       -- Edit buffer
          explain = '<leader>zx',    -- Explain code
          create = '<leader>zf',     -- Create file
          analyze = '<leader>za',    -- Analyze code
          models = '<leader>zm',     -- List models
          tasks = '<leader>zt',      -- List tasks
          chat_stream = '<leader>zs', -- Streaming chat
        },

        -- Selection tracking
        track_selection = true,

        -- Logging configuration
        logger = {
          level = "INFO",                              -- DEBUG, INFO, WARN, ERROR
          file = "~/.cache/nvim/zeke.log",
          show_timestamp = true,
        },

        -- Selection tracking settings
        selection = {
          debounce_ms = 100,
          visual_demotion_delay_ms = 50,
        },

        -- Diff management
        diff = {
          keep_terminal_focus = false,  -- Stay in terminal after opening diff
          open_in_new_tab = false,      -- Open diffs in new tabs
          auto_close_on_accept = true,  -- Auto-close after accepting
          show_diff_stats = true,       -- Show diff statistics
          vertical_split = true,        -- Use vertical splits
        },

        -- Lock file for CLI discovery
        create_lockfile = true, -- Creates ~/.zeke/ide/[port].lock

        -- Ghostlang integration (FUTURE)
        ghostlang = {
          auto_detect = true,               -- Auto-detect Grim editor mode
          script_dirs = { ".zeke", "scripts" },
          fallback_to_lua = true,           -- Use Lua when Ghostlang unavailable
        },
      })
    end,
  },
})

-- ============================================================================
-- Additional Keybindings (Optional)
-- ============================================================================

-- Prompt templates
vim.keymap.set('n', '<leader>zF', ':ZekeFix<CR>', { desc = 'Fix code issues' })
vim.keymap.set('n', '<leader>zO', ':ZekeOptimize<CR>', { desc = 'Optimize code' })
vim.keymap.set('n', '<leader>zD', ':ZekeDocs<CR>', { desc = 'Add documentation' })
vim.keymap.set('n', '<leader>zT', ':ZekeTests<CR>', { desc = 'Generate tests' })
vim.keymap.set('n', '<leader>zC', ':ZekeCommit<CR>', { desc = 'Generate commit message' })
vim.keymap.set('n', '<leader>zR', ':ZekeRefactor<CR>', { desc = 'Refactor code' })
vim.keymap.set('n', '<leader>zV', ':ZekeReview<CR>', { desc = 'Code review' })

-- Chat UI
vim.keymap.set('n', '<leader>zcc', ':ZekeChatUI<CR>', { desc = 'Open chat UI' })
vim.keymap.set('n', '<leader>zct', ':ZekeToggleChat<CR>', { desc = 'Toggle chat UI' })

-- ============================================================================
-- Basic Neovim Settings (Optional - adjust to your preferences)
-- ============================================================================

-- Leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.wrap = false
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.termguicolors = true

-- ============================================================================
-- Tips and Usage Examples
-- ============================================================================

--[[

1. Start Zeke HTTP API Server (in a separate terminal):
   $ cd /path/to/zeke
   $ zeke serve

2. Basic Commands:
   :ZekeChat hello world                    -- Simple chat
   :ZekeChat #buffer explain this          -- Chat with current buffer
   :ZekeChat #selection optimize this      -- Chat with selection
   :ZekeExplain                             -- Explain current buffer
   :ZekeEdit add type hints                 -- Edit with AI
   :ZekeFix                                 -- Fix code issues
   :ZekeTests                               -- Generate tests
   :ZekeCommit                              -- Generate commit message

3. Resource Tags in Chat:
   #buffer          -- Include current buffer
   #selection       -- Include current selection
   #file:path       -- Include specific file
   #diagnostics     -- Include LSP diagnostics
   #gitdiff         -- Include staged changes
   #git             -- Include unstaged changes
   #open            -- List all open files

4. Chat UI:
   :ZekeChatUI                              -- Open chat interface
   <CR> or <C-s>                            -- Send message
   <Esc> or q                               -- Close chat
   C                                        -- Clear history
   y                                        -- Copy last response
   i                                        -- Return to input

5. Keybindings (with default leader=space):
   <space>zc        -- Chat
   <space>ze        -- Edit
   <space>zx        -- Explain
   <space>zF        -- Fix
   <space>zO        -- Optimize
   <space>zT        -- Generate tests
   <space>zcc       -- Open chat UI

6. Check Zeke Server Connection:
   $ curl http://localhost:7878/health
   Should return: {"status":"ok","version":"..."}

7. View Logs:
   :edit ~/.cache/nvim/zeke.log

8. Lock File (for CLI discovery):
   $ cat ~/.zeke/ide/7878.lock
   Shows connection info for Zeke CLI

--]]

-- Example configuration for Zeke.nvim
-- Place this in your Neovim config (init.lua or plugins/zeke.lua)

return {
  "ghostkellz/zeke.nvim",
  build = "zig build -Doptimize=ReleaseSafe",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("zeke").setup({
      -- Core settings
      binary_path = "./zig-out/bin/zeke_nvim",
      auto_reload = true,
      show_errors_as_notifications = false,

      -- Enable advanced features
      track_selection = true,

      -- API Keys (use environment variables for security)
      api_keys = {
        openai = vim.env.OPENAI_API_KEY,
        claude = vim.env.ANTHROPIC_API_KEY,
        copilot = vim.env.GITHUB_TOKEN,
      },

      -- Default provider and model
      default_provider = 'openai',
      default_model = 'gpt-4',

      -- Generation parameters
      temperature = 0.7,
      max_tokens = 2048,
      stream = false,

      -- Logging configuration
      logger = {
        level = "INFO", -- Change to "DEBUG" for troubleshooting
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
        keep_terminal_focus = false,    -- Keep focus in terminal after diff opens
        open_in_new_tab = true,         -- Open diffs in new tabs for better review
        auto_close_on_accept = true,    -- Auto-close after accepting changes
        show_diff_stats = true,         -- Show diff statistics
        vertical_split = true,          -- Use vertical splits for diffs
      },

      -- Future Ghostlang integration
      ghostlang = {
        auto_detect = true,             -- Auto-detect Grim editor mode
        script_dirs = { ".zeke", "scripts", "zeke-scripts" },
        fallback_to_lua = true,         -- Use Lua when Ghostlang unavailable
      },

      -- Keymaps
      keymaps = {
        chat = '<leader>zc',
        edit = '<leader>ze',
        explain = '<leader>zx',
        create = '<leader>zn',
        analyze = '<leader>za',
        models = '<leader>zm',
        tasks = '<leader>zt',
        chat_stream = '<leader>zs',
      },

      -- Server configuration
      server = {
        host = '127.0.0.1',
        port = 7777,
        auto_start = true,
      },
    })

    -- Optional: Set up additional keymaps for new features
    local opts = { noremap = true, silent = true }

    -- Selection and visual commands
    vim.keymap.set('v', '<leader>zs', ':ZekeSend<CR>',
      vim.tbl_extend('force', opts, { desc = 'Send visual selection to Zeke' }))

    -- File tree integration
    vim.keymap.set('n', '<leader>zf', ':ZekeTreeAdd<CR>',
      vim.tbl_extend('force', opts, { desc = 'Add tree files to Zeke context' }))

    -- Diff management
    vim.keymap.set('n', '<leader>zda', ':ZekeDiffAccept<CR>',
      vim.tbl_extend('force', opts, { desc = 'Accept diff changes' }))
    vim.keymap.set('n', '<leader>zdr', ':ZekeDiffReject<CR>',
      vim.tbl_extend('force', opts, { desc = 'Reject diff changes' }))
    vim.keymap.set('n', '<leader>zdc', ':ZekeDiffClose<CR>',
      vim.tbl_extend('force', opts, { desc = 'Close all diffs' }))

    -- Terminal control
    vim.keymap.set('n', '<leader>zt', ':ZekeTerminal<CR>',
      vim.tbl_extend('force', opts, { desc = 'Toggle Zeke terminal' }))
    vim.keymap.set('n', '<leader>zF', ':ZekeFocus<CR>',
      vim.tbl_extend('force', opts, { desc = 'Focus Zeke terminal' }))

    -- Debug and logging
    vim.keymap.set('n', '<leader>zld', function()
      vim.cmd('ZekeLogLevel DEBUG')
      vim.notify('Zeke debug logging enabled', vim.log.levels.INFO)
    end, vim.tbl_extend('force', opts, { desc = 'Enable debug logging' }))

    vim.keymap.set('n', '<leader>zli', function()
      vim.cmd('ZekeLogLevel INFO')
      vim.notify('Zeke normal logging restored', vim.log.levels.INFO)
    end, vim.tbl_extend('force', opts, { desc = 'Normal logging' }))

    -- Quick log file view
    vim.keymap.set('n', '<leader>zll', function()
      vim.cmd('tabnew ~/.cache/nvim/zeke.log')
    end, vim.tbl_extend('force', opts, { desc = 'View Zeke log file' }))
  end,
}

-- Advanced usage example:
--[[

Example workflow with new features:

1. Visual Selection:
   - Select code in visual mode
   - Press <leader>zs to send to AI
   - Chat about optimizations or explanations

2. File Tree Integration:
   - Open nvim-tree, neo-tree, oil, or mini.files
   - Select/mark multiple files
   - Use :ZekeTreeAdd to add them to context
   - Ask AI questions about the project structure

3. Diff Review:
   - Ask AI to edit a file
   - Review changes in the diff view
   - Use ]c and [c to navigate changes
   - Press <leader>zda to accept or <leader>zdr to reject

4. Debug Issues:
   - Enable debug logging: <leader>zld
   - Reproduce the issue
   - View logs: <leader>zll
   - Report issues with log context

5. Future Ghostlang:
   - :ZekeNewScript my_workflow
   - Edit the created .gza script
   - :ZekeScript my_workflow to execute

--]]
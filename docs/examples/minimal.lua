-- Minimal Configuration
-- For users who want basic AI assistance with defaults

require('zeke').setup({
  -- Use all defaults
  -- Just enable the plugin and go!
})

-- Basic keymaps
vim.keymap.set('n', '<leader>ai', ':ZekeCode<CR>', { desc = 'Open AI Agent' })
vim.keymap.set('n', '<leader>ae', ':ZekeEdit<CR>', { desc = 'AI Edit' })
vim.keymap.set('n', '<leader>ah', ':ZekeHelp<CR>', { desc = 'AI Help' })

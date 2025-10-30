-- Cost-Conscious Configuration
-- For users who want to minimize API costs

require('zeke').setup({
  -- Strict token limits
  tokens = {
    warn_tokens = 2000,        -- Warn early
    critical_tokens = 4000,    -- Be conservative
    max_tokens = 8000,         -- Hard limit
  },

  -- Aggressive safety checks
  safety = {
    confirm_large_edits = true,
    rate_limit_warn = 5,       -- Low threshold
    rate_limit_critical = 10,
  },

  -- Always show cost estimates
  statusline = {
    enabled = true,
    show_tokens = true,        -- Always visible
    show_model = true,
  },
})

-- Prefer local models by default
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    -- Try to use qwen2.5-coder:7b if available
    local models = require('zeke.models')
    models.set_model('qwen2.5-coder:7b')
  end,
})

-- Cost tracking shortcuts
vim.keymap.set('n', '<leader>$', ':ZekeTokens<CR>', { desc = 'Show Costs' })
vim.keymap.set('n', '<leader>$$', ':ZekeTokensReset<CR>', { desc = 'Reset Cost Tracking' })

-- Quick model switching for cost control
vim.keymap.set('n', '<leader>ml', function()
  require('zeke.models').set_model('qwen2.5-coder:7b')
  vim.notify("Switched to FREE local model", vim.log.levels.INFO)
end, { desc = 'Use Local (Free)' })

vim.keymap.set('n', '<leader>mc', function()
  require('zeke.models').set_model('claude-haiku-3')
  vim.notify("Switched to CHEAP cloud model", vim.log.levels.INFO)
end, { desc = 'Use Cheap Cloud' })

vim.keymap.set('n', '<leader>mq', function()
  require('zeke.models').set_model('claude-sonnet-4')
  vim.notify("Switched to QUALITY cloud model", vim.log.levels.WARN)
end, { desc = 'Use Quality (Expensive!)' })

-- Show cost warning on startup if high usage
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      local tokens = require('zeke.tokens')
      local stats = tokens.get_usage_stats()

      if stats.total_cost > 5 then
        vim.notify(
          string.format("⚠️  High token usage: $%.2f\nConsider using local models!", stats.total_cost),
          vim.log.levels.WARN
        )
      end
    end, 1000)
  end,
})

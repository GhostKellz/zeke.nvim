-- Local-Only Configuration
-- For users who want privacy and no API costs (Ollama only)

require('zeke').setup({
  -- Disable cloud-related warnings
  safety = {
    rate_limit_warn = 1000,    -- Effectively disabled for local
    rate_limit_critical = 10000,
  },

  tokens = {
    warn_tokens = 16000,       -- Local models can handle more
    critical_tokens = 32000,
    max_tokens = 64000,
  },

  -- No need for backup paranoia with local models
  backup = {
    enabled = true,
    max_backups_per_file = 5,  -- Fewer backups needed
    auto_cleanup_days = 14,    -- Cleanup sooner
  },

  -- Show model in statusline (since we'll have multiple local ones)
  statusline = {
    enabled = true,
    show_model = true,
    show_tokens = false,       -- No costs to track
    show_requests = true,
    show_rate_limit = false,   -- No rate limits locally
  },
})

-- Ensure Ollama is running
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local cli = require('zeke.cli')
    local health = cli.health_check()

    if not health.working then
      vim.notify(
        "⚠️  Zeke CLI not working!\n\n" ..
        "For local-only mode:\n" ..
        "1. Install Ollama: https://ollama.ai\n" ..
        "2. Start server: ollama serve\n" ..
        "3. Pull model: ollama pull qwen2.5-coder:7b\n\n" ..
        "Available models:\n" ..
        "  qwen2.5-coder:7b     - Fast, code-focused (4GB)\n" ..
        "  deepseek-coder-v2:16b - Better quality (10GB)\n" ..
        "  codellama:13b        - Good balance (7GB)",
        vim.log.levels.WARN
      )
    end
  end,
})

-- Local model shortcuts
local models = require('zeke.models')

vim.keymap.set('n', '<leader>m1', function()
  models.set_model('qwen2.5-coder:7b')
  vim.notify("🦙 Using Qwen2.5 Coder 7B (Fast)", vim.log.levels.INFO)
end, { desc = 'Qwen 7B (Fast)' })

vim.keymap.set('n', '<leader>m2', function()
  models.set_model('deepseek-coder-v2:16b')
  vim.notify("🦙 Using DeepSeek Coder 16B (Better)", vim.log.levels.INFO)
end, { desc = 'DeepSeek 16B (Better)' })

vim.keymap.set('n', '<leader>m3', function()
  models.set_model('codellama:13b')
  vim.notify("🦙 Using CodeLlama 13B (Balanced)", vim.log.levels.INFO)
end, { desc = 'CodeLlama 13B (Balanced)' })

-- Quick Ollama management
vim.keymap.set('n', '<leader>mo', function()
  vim.fn.system('ollama list')
  vim.cmd('terminal ollama list')
end, { desc = 'List Ollama Models' })

vim.keymap.set('n', '<leader>mp', function()
  vim.ui.input({ prompt = 'Model to pull: ' }, function(model)
    if model then
      vim.cmd(string.format('terminal ollama pull %s', model))
    end
  end)
end, { desc = 'Pull Ollama Model' })

-- Privacy notice
print("🔒 Zeke configured for LOCAL-ONLY mode (Ollama)")
print("   All AI processing happens on your machine")
print("   No data leaves your computer")
print("   Zero API costs")

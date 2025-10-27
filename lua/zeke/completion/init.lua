-- Completion module entry point
local M = {}

M.inline = require('zeke.completion.inline')

function M.setup(opts)
  opts = opts or {}

  -- Setup inline completions
  if opts.inline ~= false then
    M.inline.setup()
  end

  -- Setup keybindings if enabled
  if opts.keymaps ~= false then
    M.setup_keymaps(opts.keymaps or {})
  end
end

function M.setup_keymaps(opts)
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc, expr = false })
  end

  -- Accept suggestion with Tab (like Copilot)
  -- Use expression mapping to allow fallback
  vim.keymap.set('i', '<Tab>', function()
    if require('zeke.completion.inline').accept() then
      return ''
    else
      -- Fallback to default Tab behavior
      return '<Tab>'
    end
  end, { expr = true, silent = true, desc = 'Accept Zeke suggestion or Tab' })

  -- Dismiss with Esc or Ctrl+]
  map('i', '<C-]>', function() require('zeke.completion.inline').dismiss() end, 'Dismiss Zeke suggestion')

  -- Accept word/line
  map('i', '<C-Right>', function() require('zeke.completion.inline').accept_word() end, 'Accept next word')
  map('i', '<C-Down>', function() require('zeke.completion.inline').accept_line() end, 'Accept current line')

  -- Cycle suggestions
  map('i', '<M-]>', function() require('zeke.completion.inline').next() end, 'Next Zeke suggestion')
  map('i', '<M-[>', function() require('zeke.completion.inline').previous() end, 'Previous Zeke suggestion')

  -- Toggle completions
  map('n', '<leader>at', function() require('zeke.completion.inline').toggle() end, 'Toggle Zeke completions')
end

return M

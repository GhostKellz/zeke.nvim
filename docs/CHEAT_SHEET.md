# 🤖 Zeke.nvim Cheat Sheet

Quick reference for all commands and keymaps.

---

## 🚀 Quick Start

```vim
:ZekeCode          " Open AI agent (Tab to cycle models)
:ZekeEdit          " Edit buffer with AI
:ZekeHelp          " Interactive help
```

---

## 📋 Commands Reference

### Core AI Features
| Command | Description |
|---------|-------------|
| `:ZekeCode` | Open AI agent chat interface |
| `:ZekeCodeClose` | Close AI agent |
| `:ZekeCodeClear` | Clear chat history |
| `:ZekeEdit` | Edit current buffer with AI |
| `:ZekeExplain` | Explain current buffer |
| `:ZekeChat [msg]` | Send quick chat message |

### Code Actions (Context-Aware)
| Command | Description |
|---------|-------------|
| `:ZekeActions` | Show actions menu |
| `:ZekeExplainCode` | Explain selected code |
| `:ZekeFixCode` | Fix issues in code |
| `:ZekeRefactorCode` | Refactor selection |
| `:ZekeGenerateTests` | Generate tests |

### Model Management
| Command | Description |
|---------|-------------|
| `:ZekeModels` | Open model picker |
| `:ZekeModelNext` | Switch to next model |
| `:ZekeModelPrev` | Switch to previous model |
| `:ZekeModelInfo` | Show current model info |

### Production Features
| Command | Description |
|---------|-------------|
| `:ZekeRequests` | Request inspector (retry status) |
| `:ZekeTokens` | Token usage statistics |
| `:ZekeTokensReset` | Reset token stats |
| `:ZekeBackups` | Backup picker (restore) |
| `:ZekeBackupStats` | Backup statistics |
| `:ZekeBackupCleanup` | Cleanup old backups |
| `:ZekeSafety` | Safety statistics |

### System
| Command | Description |
|---------|-------------|
| `:ZekeHealth` | Health check |
| `:ZekeHelp` | Interactive help |
| `:ZekeQuickRef` | Quick reference |

---

## ⌨️  Default Keymaps

### Code Actions
| Key | Action |
|-----|--------|
| `<leader>za` | Actions menu |
| `<leader>ze` | Explain code |
| `<leader>zf` | Fix code |
| `<leader>zr` | Refactor code |
| `<leader>zt` | Generate tests |

### AI Agent (in ZekeCode)
| Key | Action |
|-----|--------|
| `<CR>` | Send message |
| `<C-CR>` | Send and stay in insert |
| `<Tab>` | Cycle to next model |
| `<S-Tab>` | Cycle to previous model |
| `<leader>m` | Model picker |
| `<C-l>` | Clear chat |
| `<C-f>` | File picker (@file:) |
| `<Esc>` | Close interface |

### Diff View
| Key | Action |
|-----|--------|
| `[c` | Previous hunk |
| `]c` | Next hunk |
| `<leader>dh` | Accept hunk |
| `<leader>dx` | Reject hunk |
| `<leader>ds` | Hunk stats |
| `<leader>da` | Accept all |
| `<leader>dr` | Reject all |
| `<leader>dd` | Close diff |
| `<CR>` | Accept all |

### General AI
| Key | Action |
|-----|--------|
| `<leader>aa` | Ask AI |
| `<leader>af` | Fix diagnostic |
| `<leader>ae` | Edit selection |
| `<leader>ax` | Explain code |
| `<leader>ac` | Toggle chat panel |
| `<leader>at` | Toggle completions |

---

## 🎯 @-Mentions

Include context in prompts:

```
@file:path/to/file    - Include specific file
@buffer               - Current buffer
@selection            - Visual selection
@diag                 - Diagnostics
@git:diff             - Git diff
@git:status           - Git status
```

**Example**: `"Fix bug in @file:main.rs using @diag"`

Press `<C-f>` in chat for file picker.

---

## 🔄 Common Workflows

### 1. Fix Bug
```
1. Cursor on error
2. :ZekeCode
3. "Fix this bug using @diag and @buffer"
4. Review diff → <leader>da to accept
```

### 2. Refactor Function
```
1. Select function (visual mode)
2. <leader>zr
3. Navigate hunks: ]c
4. Accept good: <leader>dh
5. Reject bad: <leader>dx
```

### 3. Generate Tests
```
1. Open file to test
2. <leader>zt
3. Review generated tests
4. Accept with <leader>da
```

### 4. Partial Diff Workflow
```
1. :ZekeEdit
2. ]c to navigate hunks
3. <leader>dh to accept good changes
4. <leader>dx to reject bad changes
5. <leader>da to accept remaining
```

---

## 🛡️  Production Features

### Request Retry
- Automatic retry with exponential backoff
- View status: `:ZekeRequests`
- Retries: timeouts, 429, 503, 504
- Skips: 401, 403, 404

### Token Tracking
- See cost before sending
- Warnings: 4K, 8K tokens
- Blocks: 16K tokens
- Check usage: `:ZekeTokens`

### Auto-Backup
- Before every AI edit
- Location: `~/.local/share/nvim/zeke/backups`
- Restore: `:ZekeBackups`
- Retention: 10 per file, 30 days

### Safety Checks
- Rate limiting: 10/min warn, 20/min critical
- File size: 500 lines warn, 1K critical
- Confirmation dialogs
- Stats: `:ZekeSafety`

---

## ⚙️  Quick Config

### Minimal
```lua
require('zeke').setup({})  -- Use defaults
```

### With Lualine
```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      require('zeke.statusline').lualine_status,
      'encoding', 'filetype',
    },
  },
})
```

### Custom Keymaps
```lua
require('zeke').setup({
  keymaps = {
    actions = '<leader>za',
    fix = '<leader>zf',
    refactor = '<leader>zr',
  },
})
```

---

## 🚨 Troubleshooting

| Issue | Solution |
|-------|----------|
| CLI not found | `:ZekeHealth`, install from github.com/ghostkellz/zeke |
| Requests failing | `:ZekeRequests` to see status, check API keys |
| High costs | `:ZekeTokens` to check, use local: `:ZekeModels` → qwen2.5-coder:7b |
| Diff not working | Ensure file is saved, try `:set diff?` |
| Backups not restoring | `:ZekeBackups`, check `~/.local/share/nvim/zeke/backups` |

---

## 💡 Tips

1. **Use @-mentions** for better context
2. **Review before accepting** - navigate hunks with `]c`
3. **Leverage backups** - restore with `:ZekeBackups`
4. **Monitor costs** - check `:ZekeTokens` regularly
5. **Try local models** - zero cost with Ollama

---

## 📊 Statusline

Shows: Model | Tokens/Cost | Requests | Rate Limit

Example: `🤖 claude-sonnet-4 │ 💰 $0.45 │ ⚡ in_progress │ 🟢 3/min`

---

## 🔗 Quick Links

- Full help: `:ZekeHelp` or `:help zeke`
- Examples: `docs/examples/*.lua`
- GitHub: https://github.com/ghostkellz/zeke.nvim
- Issues: https://github.com/ghostkellz/zeke.nvim/issues

---

## 📝 Model Quick Reference

### Cloud Models (API Required)
- `claude-sonnet-4` - Best quality, $0.003/1K in
- `claude-haiku-3` - Cheapest, $0.00025/1K in
- `gpt-4o` - OpenAI's best, $0.005/1K in
- `gpt-3.5-turbo` - Cheap OpenAI, $0.0005/1K in
- `gemini-pro` - Google, $0.00025/1K in

### Local Models (Free, Ollama)
- `qwen2.5-coder:7b` - Fast, code-focused (4GB)
- `deepseek-coder-v2:16b` - Better quality (10GB)
- `codellama:13b` - Good balance (7GB)

Switch: `:ZekeModels`

---

## 🎓 Learning Path

1. **Day 1**: Try `:ZekeCode` and chat
2. **Day 2**: Use `:ZekeEdit` with diff navigation
3. **Day 3**: Learn @-mentions for context
4. **Day 4**: Master partial diff (`<leader>dh`, `<leader>dx`)
5. **Day 5**: Customize keymaps and statusline

---

**Print this page or save as PDF for quick reference!**

For detailed documentation, run `:ZekeHelp` in Neovim.

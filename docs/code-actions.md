# Code Actions Menu

Context-aware quick actions that intelligently detect what you're working on and provide relevant AI assistance.

## Overview

The Code Actions Menu (`:ZekeActions`) analyzes your current context and offers smart actions:
- Automatically detects: visual selection, diagnostics, LSP symbols, git changes
- Context-aware prompts based on filetype and cursor position
- Works in both normal and visual mode
- Integrates with @-mention system

## Available Actions

### 🔍 Explain Code
Explain what code does with automatic context detection.

**Smart behavior:**
- With selection: Explains the selected code
- At function/method: Explains that specific function
- Otherwise: Explains entire buffer

**Command:** `:ZekeExplainCode`
**Keymap:** `<leader>ze`

---

###  🔧 Fix Issues
Fix errors, warnings, and potential problems.

**Smart behavior:**
- If diagnostics present: Focuses on fixing those specific issues
- Otherwise: Reviews code for potential improvements

**Command:** `:ZekeFixCode`
**Keymap:** `<leader>zf`

**Priority:** Higher priority when diagnostics are present

---

### ♻️ Refactor
Improve code structure and readability.

**Smart behavior:**
- With selection: Refactors selected code
- Otherwise: Suggests improvements for entire buffer

**Command:** `:ZekeRefactorCode`
**Keymap:** `<leader>zr`

---

### 🧪 Generate Tests
Generate comprehensive unit tests.

**Smart behavior:**
- With selection: Generates tests for selected code
- At function/method: Generates tests for that function
- Otherwise: Generates tests for entire buffer

**Command:** `:ZekeGenerateTests`
**Keymap:** `<leader>zt`

---

### 📝 Add Documentation
Add docstrings and comments.

**Smart behavior:**
- Adapts to your language's documentation style
- With selection: Documents selected code
- Otherwise: Documents all functions/types in buffer

---

### ⚡ Optimize Performance
Analyze and improve performance.

**Smart behavior:**
- Identifies bottlenecks
- Suggests algorithmic improvements
- Recommends better data structures

---

### 🔒 Security Review
Check for security vulnerabilities.

**Smart behavior:**
- Scans for common vulnerabilities (SQL injection, XSS, etc.)
- Checks for insecure practices
- Suggests security best practices

---

### ✨ Simplify
Make code simpler and clearer.

**Smart behavior:**
- Reduces complexity
- Improves readability
- Maintains functionality

---

### 👀 Code Review
Comprehensive code review covering:
- Code quality and style
- Potential bugs
- Performance issues
- Security concerns
- Best practices

---

### 📋 Generate Commit Message
Create detailed git commit message from changes.

**Smart behavior:**
- Analyzes `git diff`
- Only shows when in a git repository
- Follows conventional commit format

**Condition:** Only available in git repositories

---

### 🔄 Convert Code
Convert code to another language or format.

**Smart behavior:**
- Prompts for target language
- Preserves logic and comments
- Maintains equivalent functionality

---

### 💭 Custom Action
Enter a custom prompt with automatic context.

**Use case:** When you need something specific not covered by other actions

---

## Usage

### Interactive Menu

```vim
:ZekeActions
```

Or use the keymap: `<leader>za`

This opens a picker showing all available actions with descriptions.

###Direct Commands

Each action has its own command for quick access:

```vim
:ZekeExplainCode    " Explain with smart context
:ZekeFixCode        " Fix issues
:ZekeRefactorCode   " Refactor code
:ZekeGenerateTests  " Generate tests
```

### Visual Mode

All actions work in visual mode:

1. Select code in visual mode (`v`, `V`, or `<C-v>`)
2. Run `:ZekeActions` or use keymap
3. Choose action - it will automatically use your selection

### Example Workflows

**Fix diagnostics:**
```
1. See error in code
2. Press <leader>zf
3. AI analyzes error and suggests fix
```

**Generate tests:**
```
1. Write a function
2. Press <leader>zt
3. AI generates comprehensive unit tests
```

**Code review:**
```
1. Select code block (visual mode)
2. :ZekeActions
3. Choose "👀 Code Review"
4. Get detailed review with suggestions
```

**Refactor selection:**
```
1. Visual select complex code
2. Press <leader>zr
3. AI suggests cleaner implementation
```

## Context Detection

The actions menu automatically gathers:

### Selection Context
- Visual mode selection
- Line ranges
- Selected text content

### LSP Context
- Current symbol (function/method/class)
- Symbol kind (Function, Method, Class, etc.)
- Diagnostics (errors/warnings)

### File Context
- Filename and path
- Filetype
- Cursor position

### Git Context
- Whether in git repo
- Uncommitted changes
- Diff output

## Configuration

### Default Keymaps

```lua
require('zeke').setup({
  keymaps = {
    actions = '<leader>za',  -- Code actions menu
  }
})
```

### Quick Action Keymaps

The plugin also creates quick access keymaps:

| Keymap | Action | Mode |
|--------|--------|------|
| `<leader>ze` | Explain Code | n, v |
| `<leader>zf` | Fix Issues | n, v |
| `<leader>zr` | Refactor | n, v |
| `<leader>zt` | Generate Tests | n, v |

### Disable Default Keymaps

```lua
require('zeke').setup({
  keymaps = {
    enabled = false, -- Disable all default keymaps
  }
})
```

Then create your own:

```lua
vim.keymap.set({'n', 'v'}, '<C-a>', ':ZekeActions<CR>')
vim.keymap.set({'n', 'v'}, '<leader>x', ':ZekeExplainCode<CR>')
```

## Integration with Other Features

### @-Mentions

Actions automatically work with @-mentions:

```lua
-- Action generates:
"Fix these issues:

@diag

Here's the code:

@buffer"
```

### Agent Interface

Actions can:
- Open `:ZekeCode` agent if not open
- Send prompt to existing agent window
- Use CLI directly

### LSP Integration

Actions leverage LSP for:
- Symbol detection
- Diagnostic information
- Hover documentation
- Code structure understanding

## Telescope Integration

If Telescope is installed, the picker uses Telescope for:
- Fuzzy searching actions
- Better UI
- Preview (coming soon)

Otherwise falls back to `vim.ui.select`.

## Programmatic Usage

Use actions in your own scripts:

```lua
local actions = require('zeke.actions')

-- Gather context
local ctx = actions.gather_context()

-- Execute specific action
local explain_action = actions.actions[1]  -- First action
actions.execute_action(explain_action, ctx)

-- Show picker
actions.show_picker()

-- Filter actions
local filtered = actions.filter_actions(actions.actions, ctx)
```

## Adding Custom Actions

Extend the actions list:

```lua
local actions = require('zeke.actions')

table.insert(actions.actions, {
  id = "my_custom_action",
  label = "🎨 My Custom Action",
  description = "Does something custom",
  prompt = function(ctx)
    return "Do something custom with: " .. (ctx.selection_text or "@buffer")
  end,
  needs_context = true,
  condition = function(ctx)
    -- Only show in Lua files
    return ctx.filetype == "lua"
  end,
})
```

## Tips & Tricks

1. **Use in visual mode:** Select exactly what you want analyzed
2. **Combine with diagnostics:** Fix actions work best when LSP is running
3. **Git commit messages:** Use after `git add` but before `git commit`
4. **Custom prompts:** Use "💭 Custom Action" for one-off requests
5. **Symbol-aware:** Place cursor on function name for targeted actions

## Comparison to Claude Code

| Feature | Claude Code | Zeke.nvim |
|---------|-------------|-----------|
| Code actions menu | ✅ | ✅ |
| Context detection | ✅ | ✅ |
| LSP integration | ✅ | ✅ |
| Git integration | ✅ | ✅ |
| Multi-provider | ❌ | ✅ |
| Custom actions | ❌ | ✅ |
| Visual mode | ✅ | ✅ |
| Telescope picker | ❌ | ✅ |

## Troubleshooting

**Actions not showing:**
- Check if Zeke CLI is installed: `:ZekeHealth`
- Verify keymaps: `:map <leader>za`

**Context not detected:**
- Ensure LSP is attached: `:LspInfo`
- Check file is saved and has correct filetype

**Picker not opening:**
- Check for Lua errors: `:messages`
- Try with Telescope disabled

## See Also

- [@-Mentions Documentation](./mentions.md)
- [Agent Interface](./agent.md)
- [LSP Integration](./lsp.md)
- [Main README](../README.md)

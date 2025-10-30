# Partial Diff Acceptance

zeke.nvim provides granular control over AI-generated code changes with partial diff acceptance. Instead of accepting or rejecting all changes at once, you can review and apply changes hunk-by-hunk.

## Features

- **Hunk Navigation**: Jump between changes with `[c` and `]c`
- **Partial Acceptance**: Accept individual hunks with `<leader>dh`
- **Partial Rejection**: Reject individual hunks with `<leader>dx`
- **Diff Statistics**: View detailed hunk breakdown
- **Full Neovim Diff Mode**: Uses native diff highlighting and features

## Basic Usage

When zeke generates code changes, a diff view opens showing:
- **Left pane**: Original code
- **Right pane**: Modified code with AI suggestions

### Navigation

```vim
[c           " Jump to previous hunk
]c           " Jump to next hunk
<leader>ds   " Show statistics for current hunk
```

### Accepting Changes

```vim
<leader>dh   " Accept current hunk only
<leader>da   " Accept all changes
<CR>         " Accept all changes (same as <leader>da)
```

### Rejecting Changes

```vim
<leader>dx   " Reject current hunk only (keep original)
<leader>dr   " Reject all changes
```

### Closing Diff

```vim
<leader>dd   " Close diff view
```

## Workflow Example

1. **Request AI Edit**:
   ```vim
   :ZekeEdit
   ```
   Enter instruction: "Add error handling"

2. **Review Diff**:
   - Diff view opens automatically
   - Use `]c` to jump to first change

3. **Partial Accept**:
   ```vim
   ]c            " Navigate to first hunk
   <leader>dh    " Accept this hunk
   ]c            " Navigate to second hunk
   <leader>dx    " Reject this hunk (keep original)
   ]c            " Navigate to third hunk
   <leader>dh    " Accept this hunk
   ```

4. **Complete Edit**:
   ```vim
   <leader>da    " Accept remaining changes
   ```
   Or press `<leader>dd` to close without accepting.

## Hunk Types

The diff system identifies three types of hunks:

### Added Hunks
Lines that exist only in the modified version:
```diff
+ new_function() {
+   return true
+ }
```

### Deleted Hunks
Lines that exist only in the original:
```diff
- old_function() {
-   return false
- }
```

### Changed Hunks
Lines that differ between versions:
```diff
- const x = 10
+ const x = 20
```

## Statistics

### Current Hunk Stats

Show info about the hunk under cursor:
```vim
<leader>ds
```

Output:
```
Hunk: lines 45-52 (8 lines, type: changed)
```

### Full Diff Stats

View breakdown of all hunks:
```vim
:lua require('zeke.diff').show_diff_stats_detailed()
```

Output:
```
Diff Statistics:
Total hunks: 5
Added: 2
Deleted: 1
Changed: 2

Keymaps:
[c / ]c - Navigate hunks
<leader>dh - Accept current hunk
<leader>dx - Reject current hunk
<leader>da - Accept all
<leader>dr - Reject all
```

## Advanced Features

### Programmatic Access

Accept specific hunk programmatically:
```lua
local diff = require('zeke.diff')

-- Get all hunks
local hunks = diff.get_all_hunks()
print(string.format("Found %d hunks", #hunks))

-- Accept hunk
diff.accept_hunk()

-- Reject hunk
diff.reject_hunk()
```

### Auto-Backup Integration

Before applying any edits, zeke automatically creates backups:
```vim
:ZekeBackups    " View and restore backups
```

If you accept changes you regret, restore from backup:
1. `:ZekeBackups`
2. Select the backup before your edit
3. Confirm restoration

## Configuration

Configure diff behavior:
```lua
require('zeke').setup({
  diff = {
    -- Open in new tab
    open_in_new_tab = false,

    -- Vertical split (true) or horizontal (false)
    vertical_split = true,

    -- Auto-close diff after accepting all
    auto_close_on_accept = true,

    -- Show diff statistics
    show_diff_stats = true,
  },
})
```

## Tips and Best Practices

### 1. Review Before Accepting
Always review AI-generated changes carefully:
- Use `]c` to jump through hunks
- Press `<leader>ds` to see hunk details
- Check surrounding context

### 2. Accept High-Confidence Changes First
Accept obvious improvements immediately:
```vim
]c            " Jump to hunk
<leader>dh    " Accept if good
```

### 3. Reject Problematic Changes
If a hunk looks wrong:
```vim
<leader>dx    " Reject and keep original
]c            " Move to next hunk
```

### 4. Partial Acceptance Pattern
Common workflow:
1. Navigate through all hunks first (`]c` repeatedly)
2. Go back to start: `gg`
3. Accept/reject each hunk individually
4. Accept remaining with `<leader>da`

### 5. Use Diff Statistics
Before accepting all changes:
```vim
:lua require('zeke.diff').show_diff_stats_detailed()
```
Check total hunks to ensure you've reviewed everything.

### 6. Backup Safety Net
If unsure about changes:
1. Accept them (`<leader>da`)
2. Test the code
3. Restore from backup if needed (`:ZekeBackups`)

## Comparison to Other Tools

### vs. Git Hunks (vim-fugitive)
- **zeke**: AI-generated changes, not yet committed
- **fugitive**: Git staging hunks from committed changes
- Both use `[c`/`]c` navigation (familiar workflow)

### vs. GitHub Copilot
- **Copilot**: All-or-nothing acceptance
- **zeke**: Granular hunk-by-hunk control
- zeke provides more control over large AI edits

### vs. Accept All Approach
- **Accept All**: Fast but risky
- **Partial**: Slower but safer
- Use partial acceptance for critical code

## Troubleshooting

### Hunks Not Detected

If `<leader>dh` says "Cursor is not in a diff hunk":
- Ensure you're in a diff view (windows should have `diff` option)
- Navigate to a highlighted change with `]c`
- Check that diff mode is enabled: `:set diff?`

### Changes Not Applying

If accept/reject doesn't work:
- Make sure both buffers are modifiable
- Check buffer hasn't been modified outside diff view
- Try closing and reopening diff

### Lost Changes

If you accidentally reject changes:
1. Don't close the diff view
2. The modified buffer still has AI changes
3. Use undo (`u`) or copy manually from right pane

## Keymap Reference

| Key | Action |
|-----|--------|
| `[c` | Previous hunk |
| `]c` | Next hunk |
| `<leader>dh` | Accept current hunk |
| `<leader>dx` | Reject current hunk |
| `<leader>ds` | Show hunk stats |
| `<leader>da` | Accept all changes |
| `<leader>dr` | Reject all changes |
| `<leader>dd` | Close diff view |
| `<CR>` | Accept all (in diff buffer) |

## API Reference

### Functions

```lua
local diff = require('zeke.diff')

-- Accept current hunk
diff.accept_hunk(diff_id)

-- Reject current hunk
diff.reject_hunk(diff_id)

-- Show hunk statistics
diff.show_hunk_stats(diff_id)

-- Get all hunks
local hunks = diff.get_all_hunks(diff_id)

-- Show detailed diff stats
diff.show_diff_stats_detailed(diff_id)
```

### Hunk Structure

```lua
{
  start_line = 45,     -- Starting line number (1-indexed)
  end_line = 52,       -- Ending line number (inclusive)
  type = "changed",    -- "added", "deleted", or "changed"
}
```

## Examples

### Accept Only Error Handling
```lua
-- Navigate and selectively accept
vim.keymap.set('n', '<leader>ze', function()
  local diff = require('zeke.diff')
  local hunks = diff.get_all_hunks()

  for i, hunk in ipairs(hunks) do
    -- Jump to hunk
    vim.cmd(string.format('%dgg', hunk.start_line))

    -- Get hunk content
    local lines = vim.api.nvim_buf_get_lines(0, hunk.start_line - 1, hunk.end_line, false)
    local content = table.concat(lines, '\n')

    -- Accept if contains error handling keywords
    if content:match('try') or content:match('catch') or content:match('error') then
      diff.accept_hunk()
      print(string.format('Accepted hunk %d (error handling)', i))
    end
  end
end)
```

### Auto-Accept Small Changes
```lua
-- Accept hunks smaller than 5 lines
local diff = require('zeke.diff')
local hunks = diff.get_all_hunks()

for _, hunk in ipairs(hunks) do
  local size = hunk.end_line - hunk.start_line + 1
  if size <= 5 then
    vim.cmd(string.format('%dgg', hunk.start_line))
    diff.accept_hunk()
  end
end
```

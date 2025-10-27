" Example vim-plug configuration for zeke.nvim

" ============================================================================
" vim-plug setup
" ============================================================================

" Install vim-plug if not present
if empty(glob('~/.local/share/nvim/site/autoload/plug.vim'))
  silent !curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" ============================================================================
" Plugins
" ============================================================================

call plug#begin('~/.local/share/nvim/plugged')

" Required dependency
Plug 'nvim-lua/plenary.nvim'

" zeke.nvim
Plug 'ghostkellz/zeke.nvim'

call plug#end()

" ============================================================================
" zeke.nvim configuration
" ============================================================================

lua << EOF
require('zeke').setup({
  http_api = {
    base_url = "http://localhost:7878",
    timeout = 30000,
  },
  default_model = 'smart',
  keymaps = {
    chat = '<leader>zc',
    edit = '<leader>ze',
    explain = '<leader>zx',
  },
  logger = {
    level = "INFO",
  },
  create_lockfile = true,
})
EOF

" ============================================================================
" Keybindings
" ============================================================================

" Prompt templates
nnoremap <leader>zF :ZekeFix<CR>
nnoremap <leader>zO :ZekeOptimize<CR>
nnoremap <leader>zT :ZekeTests<CR>
nnoremap <leader>zC :ZekeCommit<CR>

" Chat UI
nnoremap <leader>zcc :ZekeChatUI<CR>

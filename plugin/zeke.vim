" Zeke.nvim - AI-powered Neovim plugin
" Only load once
if exists('g:loaded_zeke')
    finish
endif
let g:loaded_zeke = 1

" Ensure we're using Neovim
if !has('nvim')
    echo "Zeke.nvim requires Neovim"
    finish
endif

" Plugin initialization will be handled by Lua
" Users should call require('zeke').setup() in their config
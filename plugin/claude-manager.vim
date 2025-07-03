" claude-manager.vim
" Claude CLI Multi-Instance Manager
" License: MIT

if exists('g:loaded_claude_manager')
  finish
endif
let g:loaded_claude_manager = 1

" デフォルトコマンドの定義
command! -nargs=0 ClaudeManagerToggle lua require('claude-manager').toggle_list()
command! -nargs=0 ClaudeManagerShow lua require('claude-manager').show_list()
command! -nargs=0 ClaudeManagerHide lua require('claude-manager').hide_list()
command! -nargs=? ClaudeManagerOpen lua require('claude-manager').open_instance(<f-args>)
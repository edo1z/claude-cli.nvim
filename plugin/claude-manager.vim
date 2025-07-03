" claude-manager.vim
" Claude CLI Multi-Instance Manager
" License: MIT

if exists('g:loaded_claude_manager')
  finish
endif
let g:loaded_claude_manager = 1

" 自動セットアップ（設定がない場合はデフォルトで実行）
if !exists('g:claude_manager_no_auto_setup')
  lua require('claude-manager').setup()
endif

" デフォルトコマンドの定義
command! -nargs=0 ClaudeManagerToggle lua require('claude-manager').toggle_list()
command! -nargs=0 ClaudeManagerShow lua require('claude-manager').show_list()
command! -nargs=0 ClaudeManagerHide lua require('claude-manager').hide_list()
command! -nargs=? ClaudeManagerOpen lua require('claude-manager').open_instance(<f-args>)
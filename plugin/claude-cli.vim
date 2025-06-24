" claude-cli.nvim - Claude Code CLI integration for Neovim
" Maintainer: edo1z
" License: MIT

if exists('g:loaded_claude_cli')
  finish
endif
let g:loaded_claude_cli = 1

" コマンド定義
command! ClaudeCode lua require('claude-cli').toggle()
command! ClaudeCodeDangerous lua require('claude-cli').toggle_dangerous()
command! ClaudePrompt lua require('claude-prompt').toggle_prompt()

" ファイル変更の自動検知設定
set autoread
augroup ClaudeCliAutoReload
  autocmd!
  " フォーカスが戻った時やカーソル移動時にファイルの変更をチェック
  autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() != 'c' | checktime | endif
  " ファイルが外部で変更された時の通知
  autocmd FileChangedShellPost * echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None
augroup END

" ユーザーがsetup()を呼ばない場合のためのautocmd
augroup ClaudeCliSetup
  autocmd!
  autocmd VimEnter * ++once lua if not require('claude-cli').is_setup then require('claude-cli').setup() end
  autocmd VimEnter * ++once lua if not require('claude-prompt').is_setup then require('claude-prompt').setup() end
augroup END
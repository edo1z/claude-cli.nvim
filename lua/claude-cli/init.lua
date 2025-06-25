-- claude-cli.nvim - Claude Code CLI integration for Neovim
-- Seamlessly integrate Claude Code CLI into your Neovim workflow
-- Author: edo1z
-- License: MIT

local M = {}
local api = vim.api

-- セットアップ完了フラグ
M.is_setup = false

-- 状態管理
M.state = {
  term_buf = nil,
  term_win = nil,
  prompt_buf = nil,
  prompt_win = nil,
  term_job_id = nil,
  has_active_session = false,  -- アクティブセッションの有無
}

-- 設定
M.config = {
  keymaps = {
    toggle = "<leader>cc",         -- Claude Code表示/非表示
    toggle_dangerous = "<leader>cd", -- Claude Code表示/非表示（権限スキップ）
    continue_session = "<leader>cC",  -- セッション継続（-cオプション付き）
    continue_session_dangerous = "<leader>cD", -- セッション継続（危険モード）
    toggle_window = "<leader>ct",   -- ウィンドウの表示/非表示切り替え
    send_path = "<leader>cp",      -- ファイルパス送信
    send_error = "<leader>ce",     -- エラー送信  
    send_selection = "<leader>cs", -- 選択範囲送信
    open_prompt = "<leader>ca",    -- 依頼文作成ウィンドウ
  },
  window = {
    position = "right",  -- right, left, bottom, top
    size = 0.4,         -- ウィンドウサイズ（比率）
  },
  snippets = {
    Refactor = "このコードをリファクタリングして、より読みやすくしてください:\n",
    Explain = "このコードの動作を日本語で説明してください:\n",
    FixError = "以下のエラーを修正してください:\n",
    AddTests = "このコードに対するテストを作成してください:\n",
    Optimize = "このコードのパフォーマンスを最適化してください:\n",
  },
  dangerous_mode = false,  -- 危険モードフラグ
  continue_session = false, -- セッション継続フラグ
}

-- Claude Codeターミナルウィンドウを作成/表示
local function show_claude_terminal()
  -- 既存のウィンドウがあれば再表示
  if M.state.term_win and api.nvim_win_is_valid(M.state.term_win) then
    api.nvim_set_current_win(M.state.term_win)
    return
  end
  
  -- ウィンドウ作成
  local width = vim.o.columns
  local height = vim.o.lines
  local win_width, win_height
  
  if M.config.window.position == "right" or M.config.window.position == "left" then
    win_width = math.floor(width * M.config.window.size)
    win_height = height - 2
  else
    win_width = width
    win_height = math.floor(height * M.config.window.size)
  end
  
  -- 分割方向を決定
  local split_cmd = ""
  if M.config.window.position == "right" then
    split_cmd = "rightbelow vsplit"
  elseif M.config.window.position == "left" then
    split_cmd = "leftabove vsplit"
  elseif M.config.window.position == "bottom" then
    split_cmd = "rightbelow split"
  else
    split_cmd = "leftabove split"
  end
  
  -- 現在のウィンドウを保存
  local current_win = api.nvim_get_current_win()
  
  -- 新しいウィンドウを作成
  vim.cmd(split_cmd)
  M.state.term_win = api.nvim_get_current_win()
  
  -- バッファがなければ作成
  if not M.state.term_buf or not api.nvim_buf_is_valid(M.state.term_buf) then
    M.state.term_buf = api.nvim_create_buf(false, true)
    
    -- プロジェクトルート（初期ディレクトリ）を取得
    local project_root = vim.fn.getcwd()
    
    -- ターミナルを起動（危険モードの場合はオプション付き）
    -- 環境変数を設定してUnicode処理を改善
    -- システムのロケールを確認して適切に設定
    local system_locale = vim.fn.system("locale -a | grep -E 'ja_JP|en_US' | head -1"):gsub("\n", "")
    if system_locale == "" then
      system_locale = "C.UTF-8"  -- フォールバック
    elseif system_locale == "ja_JP.utf8" then
      system_locale = "ja_JP.UTF-8"  -- 正規化
    end
    local env_cmd = string.format("export TERM=xterm-256color && export LANG=%s && export LC_ALL=%s && ", system_locale, system_locale)
    
    -- コマンドライン構築
    local cmd_args = ""
    if M.config.dangerous_mode then
      cmd_args = cmd_args .. " --dangerously-skip-permissions"
    end
    if M.config.continue_session then
      cmd_args = cmd_args .. " -c"
    end
    
    vim.cmd('terminal ' .. env_cmd .. 'cd ' .. vim.fn.shellescape(project_root) .. ' && claude' .. cmd_args)
    M.state.term_buf = api.nvim_get_current_buf()
    M.state.term_job_id = vim.b.terminal_job_id
    
    -- バッファ設定
    vim.bo[M.state.term_buf].buflisted = false
    vim.bo[M.state.term_buf].bufhidden = 'hide'
    
    -- ターミナルウィンドウの設定
    vim.wo[M.state.term_win].wrap = false
    vim.wo[M.state.term_win].linebreak = false
    
    -- ターミナルのレンダリング設定
    -- ambiwidthはターミナルバッファごとに設定
    local term_augroup = api.nvim_create_augroup("ClaudeCLITerm", { clear = true })
    api.nvim_create_autocmd("TermOpen", {
      group = term_augroup,
      buffer = M.state.term_buf,
      callback = function()
        -- ターミナル固有の設定
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = "no"
        vim.opt_local.foldcolumn = "0"
        vim.opt_local.scrolloff = 0
        
      end
    })
  else
    -- 既存のバッファを表示
    api.nvim_win_set_buf(M.state.term_win, M.state.term_buf)
  end
  
  -- ウィンドウサイズ設定
  if M.config.window.position == "right" or M.config.window.position == "left" then
    api.nvim_win_set_width(M.state.term_win, win_width)
  else
    api.nvim_win_set_height(M.state.term_win, win_height)
  end
  
  -- ターミナルモードに入る
  vim.cmd('startinsert')
  
  -- ターミナルバッファ用のキーマッピング
  local term_opts = {noremap = true, silent = true, buffer = M.state.term_buf}
  
  -- Ctrl+hでウィンドウ移動（ターミナルモードから）
  vim.keymap.set('t', '<C-h>', '<C-\\><C-n><C-w>h', term_opts)
  vim.keymap.set('t', '<C-j>', '<C-\\><C-n><C-w>j', term_opts)
  vim.keymap.set('t', '<C-k>', '<C-\\><C-n><C-w>k', term_opts)
  vim.keymap.set('t', '<C-l>', '<C-\\><C-n><C-w>l', term_opts)
  
  -- Escでノーマルモードに戻る
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', term_opts)
  
  -- 元のウィンドウに戻る
  -- api.nvim_set_current_win(current_win)
  
  -- アクティブセッションフラグを設定
  M.state.has_active_session = true
end

-- Claude Codeターミナルを非表示
local function hide_claude_terminal()
  if M.state.term_win and api.nvim_win_is_valid(M.state.term_win) then
    api.nvim_win_close(M.state.term_win, false)
    M.state.term_win = nil
  end
end

-- トグル機能（新規セッション）
function M.toggle()
  -- アクティブなセッションがある場合は、ウィンドウトグルとして動作
  if M.state.has_active_session and M.state.term_buf and api.nvim_buf_is_valid(M.state.term_buf) then
    M.toggle_window()
    return
  end
  
  -- 通常モードの場合は危険モードとセッション継続をリセット
  M.config.dangerous_mode = false
  M.config.continue_session = false
  
  -- 既存のセッションがある場合は閉じる
  if M.state.term_win and api.nvim_win_is_valid(M.state.term_win) then
    hide_claude_terminal()
  end
  
  -- バッファをリセット（新しいセッションを開始するため）
  if M.state.term_buf and api.nvim_buf_is_valid(M.state.term_buf) then
    api.nvim_buf_delete(M.state.term_buf, {force = true})
    M.state.term_buf = nil
    M.state.term_job_id = nil
    M.state.has_active_session = false
  end
  
  show_claude_terminal()
end

-- 危険モードでトグル（新規セッション）
function M.toggle_dangerous()
  -- アクティブなセッションがある場合は、ウィンドウトグルとして動作
  if M.state.has_active_session and M.state.term_buf and api.nvim_buf_is_valid(M.state.term_buf) then
    M.toggle_window()
    return
  end
  
  -- 既存のセッションがある場合は閉じる
  if M.state.term_win and api.nvim_win_is_valid(M.state.term_win) then
    hide_claude_terminal()
  end
  
  -- バッファをリセット（新しいオプションで起動するため）
  if M.state.term_buf and api.nvim_buf_is_valid(M.state.term_buf) then
    api.nvim_buf_delete(M.state.term_buf, {force = true})
    M.state.term_buf = nil
    M.state.term_job_id = nil
    M.state.has_active_session = false
  end
  
  -- 危険モードを有効にして起動
  M.config.dangerous_mode = true
  M.config.continue_session = false
  show_claude_terminal()
end

-- セッション継続（通常モード）
function M.continue_session()
  -- セッション継続フラグを設定
  M.config.dangerous_mode = false
  M.config.continue_session = true
  
  -- 既存のセッションがある場合は閉じる
  if M.state.term_win and api.nvim_win_is_valid(M.state.term_win) then
    hide_claude_terminal()
  end
  
  -- バッファをリセット（-cオプション付きで起動するため）
  if M.state.term_buf and api.nvim_buf_is_valid(M.state.term_buf) then
    api.nvim_buf_delete(M.state.term_buf, {force = true})
    M.state.term_buf = nil
    M.state.term_job_id = nil
    M.state.has_active_session = false
  end
  
  show_claude_terminal()
end

-- セッション継続（危険モード）
function M.continue_session_dangerous()
  -- セッション継続フラグを設定
  M.config.dangerous_mode = true
  M.config.continue_session = true
  
  -- 既存のセッションがある場合は閉じる
  if M.state.term_win and api.nvim_win_is_valid(M.state.term_win) then
    hide_claude_terminal()
  end
  
  -- バッファをリセット（-cオプション付きで起動するため）
  if M.state.term_buf and api.nvim_buf_is_valid(M.state.term_buf) then
    api.nvim_buf_delete(M.state.term_buf, {force = true})
    M.state.term_buf = nil
    M.state.term_job_id = nil
    M.state.has_active_session = false
  end
  
  show_claude_terminal()
end

-- ウィンドウの表示/非表示をトグル（セッションは維持）
function M.toggle_window()
  if M.state.term_win and api.nvim_win_is_valid(M.state.term_win) then
    -- ウィンドウが表示されている場合は非表示に
    hide_claude_terminal()
  elseif M.state.has_active_session and M.state.term_buf and api.nvim_buf_is_valid(M.state.term_buf) then
    -- アクティブセッションがある場合は再表示
    show_claude_terminal()
  else
    -- セッションがない場合は通知
    vim.notify("No active Claude Code session. Use <leader>cc or <leader>cd to start a new session.", vim.log.levels.INFO)
  end
end

-- Claude Codeにテキストを送信
local function send_to_claude(text)
  -- Claude Codeターミナルが開いていることを確認
  if not M.state.term_job_id then
    show_claude_terminal()
    -- 少し待つ
    vim.defer_fn(function()
      send_to_claude(text)
    end, 500)
    return
  end
  
  -- ターミナルがインサートモードであることを確認
  if M.state.term_win and api.nvim_win_is_valid(M.state.term_win) then
    local current_win = api.nvim_get_current_win()
    if current_win ~= M.state.term_win then
      api.nvim_set_current_win(M.state.term_win)
    end
    
    -- ターミナルモードでない場合は入る
    local mode = api.nvim_get_mode().mode
    if mode ~= 't' then
      vim.cmd('startinsert')
    end
  end
  
  -- テキストを送信
  vim.fn.chansend(M.state.term_job_id, text)
end

-- ファイル情報を取得
local function get_file_context()
  local filepath = vim.fn.expand('%:p')
  local line = vim.fn.line('.')
  return string.format("%s:%d", filepath, line)
end

-- エラー情報を取得
local function get_error_info()
  -- Coc診断情報を取得
  local has_coc = vim.fn.exists('*CocAction') == 1
  if has_coc then
    local ok, diagnostics = pcall(vim.fn.CocAction, 'diagnosticList')
    if ok and diagnostics then
      local current_line = vim.fn.line('.')
      local current_file = vim.fn.expand('%:p')
      
      for _, diag in ipairs(diagnostics) do
        if diag.file == current_file and diag.lnum == current_line then
          return string.format("%s:%d [%s] %s", 
            current_file, diag.lnum, diag.severity, diag.message)
        end
      end
    end
  end
  
  -- ネイティブLSP診断を確認
  local diagnostics = vim.diagnostic.get(0, {lnum = vim.fn.line('.') - 1})
  if #diagnostics > 0 then
    local diag = diagnostics[1]
    return string.format("%s:%d [%s] %s",
      vim.fn.expand('%:p'), 
      vim.fn.line('.'), 
      vim.diagnostic.severity[diag.severity],
      diag.message)
  end
  
  return nil
end


-- セットアップ
function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})
  M.is_setup = true
  
  local keymaps = M.config.keymaps
  
  -- トグル（新規セッション）
  vim.keymap.set('n', keymaps.toggle, M.toggle, 
    {desc = 'Claude Code: New session'})
  
  -- 危険モードでトグル（新規セッション）
  if keymaps.toggle_dangerous then
    vim.keymap.set('n', keymaps.toggle_dangerous, M.toggle_dangerous, 
      {desc = 'Claude Code: New session (dangerous mode)'})
  end
  
  -- セッション継続
  if keymaps.continue_session then
    vim.keymap.set('n', keymaps.continue_session, M.continue_session,
      {desc = 'Claude Code: Continue last session'})
  end
  
  -- セッション継続（危険モード）
  if keymaps.continue_session_dangerous then
    vim.keymap.set('n', keymaps.continue_session_dangerous, M.continue_session_dangerous,
      {desc = 'Claude Code: Continue last session (dangerous mode)'})
  end
  
  -- ウィンドウトグル
  if keymaps.toggle_window then
    vim.keymap.set('n', keymaps.toggle_window, M.toggle_window,
      {desc = 'Claude Code: Toggle window visibility'})
  end
  
  -- ファイルパス送信（プロンプトウィンドウへ）
  if keymaps.send_path then
    vim.keymap.set('n', keymaps.send_path, function()
      local context = get_file_context()
      local claude_prompt = require('claude-prompt')
      claude_prompt.add_text("ファイル: " .. context .. "\n")
    end, {desc = 'Claude Code: Add file path to prompt'})
  end
  
  -- エラー情報送信（プロンプトウィンドウへ）
  if keymaps.send_error then
    vim.keymap.set('n', keymaps.send_error, function()
      local error_info = get_error_info()
      if error_info then
        local claude_prompt = require('claude-prompt')
        claude_prompt.add_text("エラー: " .. error_info .. "\n")
      else
        vim.notify("No error found at cursor position", vim.log.levels.WARN)
      end
    end, {desc = 'Claude Code: Add error info to prompt'})
  end
  
  -- 選択範囲送信（プロンプトウィンドウへ）
  if keymaps.send_selection then
    vim.keymap.set('v', keymaps.send_selection, function()
      -- ビジュアルモードを抜ける
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
      
      vim.defer_fn(function()
        local start_line = vim.fn.line("'<")
        local end_line = vim.fn.line("'>")
        local lines = api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
        
        local claude_prompt = require('claude-prompt')
        local file_context = get_file_context()
        claude_prompt.add_text("選択コード (" .. file_context .. "):\n```" .. vim.bo.filetype .. "\n" .. 
                       table.concat(lines, '\n') .. "\n```\n")
      end, 10)
    end, {desc = 'Claude Code: Add selection to prompt'})
  end
  
  if keymaps.open_prompt then
    vim.keymap.set({'n', 'v'}, keymaps.open_prompt, function()
      local claude_prompt = require('claude-prompt')
      claude_prompt.toggle_prompt()
    end, {desc = 'Claude Code: Toggle prompt window'})
  end
  
  -- 自動コマンド: ウィンドウが閉じられたときの処理
  api.nvim_create_autocmd("WinClosed", {
    callback = function(args)
      if tonumber(args.match) == M.state.term_win then
        M.state.term_win = nil
      end
    end
  })
end

return M
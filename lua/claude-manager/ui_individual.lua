---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}
local tmux = require("claude-manager.tmux")

-- 状態管理
M.state = {
  is_open = false,
  active_session = nil,
  window = nil,
  buffer = nil,
  job_id = nil,
  original_win = nil,
}

-- 個別ウィンドウを開く
---@param session_name string セッション名
function M.open(session_name)
  -- セッションの存在を確認
  if not tmux.ensure_session(session_name) then
    vim.notify("Failed to ensure session: " .. session_name, vim.log.levels.ERROR)
    return
  end
  
  -- 既に開いている場合
  if M.state.is_open then
    -- ウィンドウが無効になっている場合は閉じた状態にリセット
    if not M.state.window or not vim.api.nvim_win_is_valid(M.state.window) then
      M.state.is_open = false
      M.state.window = nil
      M.state.buffer = nil
      M.state.job_id = nil
      M.state.active_session = nil
    else
      if M.state.active_session == session_name then
        -- 同じセッションの場合はフォーカスを移動
        vim.api.nvim_set_current_win(M.state.window)
        return
      else
        -- 別のセッションの場合は切り替え
        M._switch_session(session_name)
        return
      end
    end
  end
  
  -- 元のウィンドウを記録
  M.state.original_win = vim.api.nvim_get_current_win()
  
  -- 右端に垂直分割で開く
  vim.cmd('vsplit')
  vim.cmd('wincmd L') -- 右端に移動
  
  -- ウィンドウ幅を調整（画面の40%程度）
  local width = math.floor(vim.o.columns * 0.4)
  vim.cmd(string.format('vertical resize %d', width))
  
  M.state.window = vim.api.nvim_get_current_win()
  
  -- 新しいバッファを作成
  vim.cmd('enew')
  M.state.buffer = vim.api.nvim_get_current_buf()
  
  -- ターミナルを開く
  local attach_cmd = string.format("tmux new-session -A -s %s", session_name)
  M.state.job_id = vim.fn.termopen(attach_cmd)
  
  -- バッファ設定
  vim.bo[M.state.buffer].buflisted = false
  vim.bo[M.state.buffer].bufhidden = 'hide'
  vim.api.nvim_buf_set_name(M.state.buffer, "claude_individual_" .. session_name)
  
  -- ウィンドウ設定
  vim.wo[M.state.window].number = false
  vim.wo[M.state.window].relativenumber = false
  vim.wo[M.state.window].signcolumn = "no"
  vim.wo[M.state.window].foldcolumn = "0"
  
  -- キーマッピングの設定
  M._setup_keymaps()
  
  -- ターミナルモードに入る
  vim.cmd('startinsert')
  
  M.state.is_open = true
  M.state.active_session = session_name
end

-- セッションを切り替える（内部関数）
---@param session_name string 新しいセッション名
function M._switch_session(session_name)
  if not M.state.is_open or not M.state.window then
    return
  end
  
  -- セッションの存在を確認
  if not tmux.ensure_session(session_name) then
    vim.notify("Failed to ensure session: " .. session_name, vim.log.levels.ERROR)
    return
  end
  
  -- ウィンドウが有効か確認
  if not M.state.window or not vim.api.nvim_win_is_valid(M.state.window) then
    return
  end
  
  -- 既存のバッファを削除（ウィンドウが有効なことを確認してから）
  if M.state.buffer and vim.api.nvim_buf_is_valid(M.state.buffer) then
    -- 一時的に別のバッファを設定してから削除
    vim.api.nvim_win_call(M.state.window, function()
      vim.cmd('enew')
    end)
    vim.api.nvim_buf_delete(M.state.buffer, {force = true})
  end
  
  -- ウィンドウにフォーカス
  vim.api.nvim_set_current_win(M.state.window)
  
  -- 新しいバッファを作成
  vim.cmd('enew')
  M.state.buffer = vim.api.nvim_get_current_buf()
  
  -- 新しいターミナルを開く
  local attach_cmd = string.format("tmux new-session -A -s %s", session_name)
  M.state.job_id = vim.fn.termopen(attach_cmd)
  
  -- バッファ設定
  vim.bo[M.state.buffer].buflisted = false
  vim.bo[M.state.buffer].bufhidden = 'hide'
  vim.api.nvim_buf_set_name(M.state.buffer, "claude_individual_" .. session_name)
  
  -- キーマッピングの設定
  M._setup_keymaps()
  
  -- ターミナルモードに入る
  vim.cmd('startinsert')
  
  M.state.active_session = session_name
end

-- 個別ウィンドウを閉じる
function M.close()
  if not M.state.is_open then
    return
  end
  
  -- ウィンドウを閉じる（最後のウィンドウでない場合のみ）
  if M.state.window and vim.api.nvim_win_is_valid(M.state.window) then
    -- 最後のウィンドウでないことを確認
    local win_count = #vim.api.nvim_list_wins()
    if win_count > 1 then
      vim.api.nvim_win_close(M.state.window, false)
    end
  end
  
  -- バッファを削除
  if M.state.buffer and vim.api.nvim_buf_is_valid(M.state.buffer) then
    vim.api.nvim_buf_delete(M.state.buffer, {force = true})
  end
  
  -- 元のウィンドウに戻る
  if M.state.original_win and vim.api.nvim_win_is_valid(M.state.original_win) then
    vim.api.nvim_set_current_win(M.state.original_win)
  end
  
  -- 状態をリセット
  M.state.is_open = false
  M.state.active_session = nil
  M.state.window = nil
  M.state.buffer = nil
  M.state.job_id = nil
end

-- トグル操作
---@param session_name string|nil セッション名（省略時は現在のセッションをトグル）
function M.toggle(session_name)
  if M.state.is_open then
    if session_name and M.state.active_session ~= session_name then
      -- 別のセッションを指定された場合は切り替え
      M._switch_session(session_name)
    else
      -- 同じセッションまたは指定なしの場合は閉じる
      M.close()
    end
  else
    -- 閉じている場合は開く
    if session_name then
      M.open(session_name)
    else
      vim.notify("No session specified to open", vim.log.levels.WARN)
    end
  end
end

-- 個別ウィンドウが開いているか確認
---@return boolean
function M.is_open()
  return M.state.is_open
end

-- アクティブなセッション名を取得
---@return string|nil
function M.get_active()
  return M.state.active_session
end

-- アクティブなセッションのjob IDを取得
---@return number|nil
function M.get_job_id()
  if M.state.is_open and M.state.job_id then
    return M.state.job_id
  end
  return nil
end

-- キーマッピングの設定（内部関数）
function M._setup_keymaps()
  if not M.state.buffer then
    return
  end
  
  local opts = {buffer = M.state.buffer, noremap = true, silent = true}
  
  -- ターミナルモードから抜ける
  vim.keymap.set('t', '<C-q>', '<C-\\><C-n>', opts)
  
  -- ウィンドウを閉じる
  vim.keymap.set('n', 'q', function()
    M.close()
  end, opts)
  
  -- ウィンドウ移動（ターミナルモードから）
  vim.keymap.set('t', '<C-h>', '<C-\\><C-n><C-w>h', opts)
  vim.keymap.set('t', '<C-j>', '<C-\\><C-n><C-w>j', opts)
  vim.keymap.set('t', '<C-k>', '<C-\\><C-n><C-w>k', opts)
  vim.keymap.set('t', '<C-l>', '<C-\\><C-n><C-w>l', opts)
end

return M

---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}
local tmux = require("claude-manager.tmux")

-- 状態管理
M.state = {
  is_open = false,
  original_tab = nil,
  list_tab = nil,
  windows = {},
  buffers = {},
}

-- セッション一覧（仮のデフォルト値）
local sessions = {}
for i = 1, 10 do
  table.insert(sessions, string.format("claude%d", i))
end

-- グリッドレイアウトを計算
---@param session_count number セッション数
---@return number rows 行数
---@return number cols 列数
function M.calculate_grid_layout(session_count)
  -- 正方形に近い形を目指す
  local cols = math.ceil(math.sqrt(session_count))
  local rows = math.ceil(session_count / cols)
  return rows, cols
end

-- バッファ名でバッファを検索
---@param name string バッファ名
---@return number|nil バッファ番号
function M.find_buffer_by_name(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match(name) then
        return buf
      end
    end
  end
  return nil
end

-- グリッドレイアウトでウィンドウを作成
---@param rows number 行数
---@param cols number 列数
---@return table ウィンドウIDのリスト
function M.create_grid_layout(rows, cols)
  local windows = {}
  
  -- 最初のウィンドウ（現在のウィンドウを使用）
  table.insert(windows, vim.api.nvim_get_current_win())
  
  -- 必要な数のウィンドウを作成
  for i = 2, rows * cols do
    if i <= cols then
      -- 最初の行は垂直分割
      vim.cmd('vsplit')
    else
      -- 2行目以降は適切な位置で水平分割
      local target_win_idx = ((i - 1) % cols) + 1
      vim.api.nvim_set_current_win(windows[target_win_idx])
      vim.cmd('split')
    end
    table.insert(windows, vim.api.nvim_get_current_win())
  end
  
  -- ウィンドウサイズを均等に調整
  vim.cmd('wincmd =')
  
  return windows
end

-- セッションをウィンドウに設定
---@param session_name string セッション名
---@param window_id number ウィンドウID
local function setup_session_in_window(session_name, window_id)
  local existing_buf = M.find_buffer_by_name(session_name)
  
  if existing_buf then
    -- 既存バッファを再利用
    vim.api.nvim_win_set_buf(window_id, existing_buf)
  else
    -- 新しいバッファを作成
    vim.api.nvim_win_call(window_id, function()
      vim.cmd('enew')
      
      -- tmux new-session -A でアタッチ
      local attach_cmd = string.format("tmux new-session -A -s %s", session_name)
      
      -- 自動コマンドを一時的に無効化
      local eventignore_save = vim.o.eventignore
      vim.o.eventignore = "all"
      
      local job_id = vim.fn.termopen(attach_cmd)
      
      -- 自動コマンドを復元
      vim.o.eventignore = eventignore_save
      
      -- バッファ名を設定
      local buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_name(buf, session_name)
      
      -- バッファ設定
      vim.bo[buf].buflisted = false
      vim.bo[buf].bufhidden = 'hide'
      
      -- バッファを記録
      M.state.buffers[session_name] = buf
    end)
  end
  
  -- ウィンドウ設定
  vim.wo[window_id].number = false
  vim.wo[window_id].relativenumber = false
  vim.wo[window_id].signcolumn = "no"
  vim.wo[window_id].foldcolumn = "0"
  vim.wo[window_id].statusline = session_name
end

-- 一覧画面を表示
function M.show()
  if M.state.is_open then
    return
  end
  
  -- 現在のタブを記録
  M.state.original_tab = vim.fn.tabpagenr()
  
  -- 新しいタブを作成
  vim.cmd('tabnew')
  M.state.list_tab = vim.fn.tabpagenr()
  
  -- tmuxセッションの存在を確認
  for _, session_name in ipairs(sessions) do
    tmux.ensure_session(session_name)
  end
  
  -- グリッドレイアウトを作成
  local rows, cols = M.calculate_grid_layout(#sessions)
  M.state.windows = M.create_grid_layout(rows, cols)
  
  -- 各ウィンドウにセッションを設定
  for i, session_name in ipairs(sessions) do
    if i <= #M.state.windows then
      setup_session_in_window(session_name, M.state.windows[i])
    end
  end
  
  -- 最初のウィンドウにフォーカス
  vim.api.nvim_set_current_win(M.state.windows[1])
  
  -- キーマッピングを設定
  M.setup_keymaps()
  
  M.state.is_open = true
end

-- 一覧画面を非表示
function M.hide()
  if not M.state.is_open then
    return
  end
  
  -- リストタブを閉じる
  if M.state.list_tab then
    local current_tab = vim.fn.tabpagenr()
    vim.cmd('tabclose ' .. M.state.list_tab)
    
    -- 元のタブに戻る
    if M.state.original_tab and M.state.original_tab <= vim.fn.tabpagenr("$") then
      vim.cmd('tabnext ' .. M.state.original_tab)
    end
  end
  
  M.state.is_open = false
  M.state.list_tab = nil
  M.state.windows = {}
end

-- トグル操作
function M.toggle()
  if M.state.is_open then
    M.hide()
  else
    M.show()
  end
end

-- 一覧画面が開いているか確認
---@return boolean
function M.is_open()
  return M.state.is_open
end

-- キーマッピングの設定
function M.setup_keymaps()
  -- 各ウィンドウにキーマッピングを設定
  for _, win in ipairs(M.state.windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    
    -- ターミナルモードから抜ける
    vim.keymap.set('t', '<C-q>', '<C-\\><C-n>', {buffer = buf, noremap = true, silent = true})
    
    -- 個別ウィンドウを開く
    vim.keymap.set('n', 'o', function()
      local session_name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
      -- TODO: ui_individual.open(session_name)を呼び出す
      vim.notify("Opening individual window for: " .. session_name)
    end, {buffer = buf, noremap = true, silent = true})
    
    -- 一覧画面を閉じる
    vim.keymap.set('n', 'q', function()
      M.hide()
    end, {buffer = buf, noremap = true, silent = true})
  end
end

return M

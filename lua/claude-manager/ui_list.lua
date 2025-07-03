---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}
local tmux = require("claude-manager.tmux")
local state = require("claude-manager.state")
local option_selector = require("claude-manager.option_selector")

-- 状態管理
M.state = {
  is_open = false,
  original_tab = nil,
  list_tab = nil,
  windows = {},
  buffers = {},
}

-- アクティブなインスタンス名
M.active_instance = nil

-- グリッドレイアウトを計算
---@param session_count number セッション数
---@return number rows 行数
---@return number cols 列数
function M.calculate_grid_layout(session_count)
  if session_count == 0 then
    return 1, 1  -- 空の状態でも1つのウィンドウを表示
  end
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
  
  -- インスタンス一覧を取得
  local instances = state.get_instances()
  
  if #instances == 0 then
    -- インスタンスが0の場合は空の状態を表示
    M.state.windows = { vim.api.nvim_get_current_win() }
    M.setup_empty_state(M.state.windows[1])
  else
    -- グリッドレイアウトを作成
    local rows, cols = M.calculate_grid_layout(#instances)
    M.state.windows = M.create_grid_layout(rows, cols)
    
    -- 各ウィンドウにセッションを設定
    for i, instance in ipairs(instances) do
      if i <= #M.state.windows then
        setup_session_in_window(instance.name, M.state.windows[i])
      end
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

-- 空の状態を表示
---@param window_id number ウィンドウID
function M.setup_empty_state(window_id)
  vim.api.nvim_win_call(window_id, function()
    vim.cmd('enew')
    local buf = vim.api.nvim_get_current_buf()
    
    -- バッファ設定
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].swapfile = false
    vim.bo[buf].buflisted = false
    vim.bo[buf].modifiable = true
    
    -- 空の状態のメッセージを表示
    local lines = {
      "Claude Manager - No instances",
      "",
      "Press 'a' to add a new instance",
      "Press 'A' to add with custom name",
      "Press 'q' to quit",
      "Press '?' for help"
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    
    -- ウィンドウ設定
    vim.wo[window_id].number = false
    vim.wo[window_id].relativenumber = false
    vim.wo[window_id].signcolumn = "no"
    vim.wo[window_id].statusline = "Claude Manager"
  end)
end

-- キーマッピングの設定
function M.setup_keymaps()
  -- 各ウィンドウにキーマッピングを設定
  for _, win in ipairs(M.state.windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    
    -- ターミナルモードから抜ける
    vim.keymap.set('t', '<C-q>', '<C-\\><C-n>', {buffer = buf, noremap = true, silent = true})
    
    -- 新しいインスタンスを追加（自動番号）
    vim.keymap.set('n', 'a', function()
      M.add_instance()
    end, {buffer = buf, noremap = true, silent = true})
    
    -- 新しいインスタンスを追加（カスタム名）
    vim.keymap.set('n', 'A', function()
      M.add_instance_with_name()
    end, {buffer = buf, noremap = true, silent = true})
    
    -- インスタンスを削除
    vim.keymap.set('n', 'd', function()
      M.delete_current_instance()
    end, {buffer = buf, noremap = true, silent = true})
    
    -- 個別ウィンドウを開く
    vim.keymap.set('n', 'o', function()
      local session_name = M.get_current_instance_name()
      if session_name then
        -- TODO: ui_individual.open(session_name)を呼び出す
        vim.notify("Opening individual window for: " .. session_name)
      end
    end, {buffer = buf, noremap = true, silent = true})
    
    -- インスタンスを再起動
    vim.keymap.set('n', 'r', function()
      M.restart_current_instance()
    end, {buffer = buf, noremap = true, silent = true})
    
    -- 一覧画面を閉じる
    vim.keymap.set('n', 'q', function()
      M.hide()
    end, {buffer = buf, noremap = true, silent = true})
    
    -- ヘルプを表示
    vim.keymap.set('n', '?', function()
      M.show_help()
    end, {buffer = buf, noremap = true, silent = true})
  end
end

-- 現在のインスタンス名を取得
---@return string|nil インスタンス名
function M.get_current_instance_name()
  local buf_name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  -- バッファ名からインスタンス名を抽出
  for name, _ in pairs(state.instances) do
    if buf_name:match(name) then
      return name
    end
  end
  return nil
end

-- 新しいインスタンスを追加（自動番号）
function M.add_instance()
  if state.get_instance_count() >= 30 then
    vim.notify("Maximum number of instances (30) reached", vim.log.levels.WARN)
    return
  end
  
  -- オプションを選択
  option_selector.select_by_key(function(options)
    if options == nil then
      -- キャンセルされた
      return
    end
    
    local next_num = state.get_next_available_number()
    local name = "claude" .. next_num
    
    -- インスタンスを追加
    state.add_instance({ name = name, options = options })
    
    -- tmuxセッションを作成
    tmux.create_claude_session(name, options)
    
    -- 画面を再描画
    M.refresh()
  end)
end

-- カスタム名でインスタンスを追加
function M.add_instance_with_name()
  if state.get_instance_count() >= 30 then
    vim.notify("Maximum number of instances (30) reached", vim.log.levels.WARN)
    return
  end
  
  -- 名前を入力
  vim.ui.input({
    prompt = "Enter instance name: ",
    default = "claude" .. state.get_next_available_number(),
  }, function(name)
    if not name or name == "" then
      return
    end
    
    -- 既存のインスタンス名を確認
    if state.get_instance(name) then
      vim.notify("Instance '" .. name .. "' already exists", vim.log.levels.WARN)
      return
    end
    
    -- オプションを選択
    option_selector.select_by_key(function(options)
      if options == nil then
        -- キャンセルされた
        return
      end
      
      -- インスタンスを追加
      state.add_instance({ name = name, options = options })
      
      -- tmuxセッションを作成
      tmux.create_claude_session(name, options)
      
      -- 画面を再描画
      M.refresh()
    end)
  end)
end

-- 現在のインスタンスを削除
function M.delete_current_instance()
  local name = M.get_current_instance_name()
  if not name then
    return
  end
  
  -- 確認
  vim.ui.select({"Yes", "No"}, {
    prompt = "Delete instance '" .. name .. "'?",
  }, function(choice)
    if choice == "Yes" then
      -- tmuxセッションを削除
      tmux.kill_session(name)
      
      -- 状態から削除
      state.remove_instance(name)
      
      -- 画面を再描画
      M.refresh()
    end
  end)
end

-- 現在のインスタンスを再起動
function M.restart_current_instance()
  local name = M.get_current_instance_name()
  if not name then
    return
  end
  
  local instance = state.get_instance(name)
  if instance then
    tmux.restart_session(name, instance.options)
    vim.notify("Restarted instance: " .. name)
  end
end

-- ヘルプを表示
function M.show_help()
  local help_lines = {
    "Claude Manager Help",
    "",
    "Key bindings:",
    "  a     - Add new instance (auto-numbered)",
    "  A     - Add new instance (custom name)",
    "  d     - Delete current instance",
    "  o     - Open individual window",
    "  r     - Restart current instance",
    "  q     - Quit list view",
    "  ?     - Show this help",
    "  <C-q> - Exit terminal mode",
    "",
    "Press any key to close this help"
  }
  
  vim.notify(table.concat(help_lines, "\n"), vim.log.levels.INFO)
end

-- 画面を再描画
function M.refresh()
  if not M.state.is_open then
    return
  end
  
  -- 現在のタブ番号を保存
  local current_tab = vim.fn.tabpagenr()
  
  -- 一旦閉じて再度開く
  M.hide()
  M.show()
  
  -- 元のタブに戻る（新しいlist_tabになっているはず）
  if M.state.list_tab then
    vim.cmd('tabnext ' .. M.state.list_tab)
  end
end

-- アクティブなインスタンスのjob IDを取得
---@return number|nil job ID
function M.get_active_job_id()
  if not M.active_instance then
    return nil
  end
  
  -- アクティブインスタンスのバッファを探す
  local buf = M.find_buffer_by_name(M.active_instance)
  if buf then
    return vim.b[buf].terminal_job_id
  end
  
  return nil
end

-- アクティブなインスタンスを設定
---@param name string インスタンス名
function M.set_active_instance(name)
  M.active_instance = name
end

return M

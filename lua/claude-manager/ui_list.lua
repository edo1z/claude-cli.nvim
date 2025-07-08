---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}
local tmux = require("claude-manager.tmux")
local state = require("claude-manager.state")
local option_selector = require("claude-manager.option_selector")
local ui_individual = require("claude-manager.ui_individual")

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

-- 設定
M.config = {
  active_bg_color = "#2a2a3e",  -- アクティブインスタンスの背景色
  inactive_bg_color = nil,       -- 非アクティブインスタンスの背景色（nilの場合は通常の背景色）
}

-- ハイライトグループの設定
function M.setup_highlights()
  if M.config.active_bg_color then
    vim.api.nvim_set_hl(0, 'ClaudeManagerActive', {
      bg = M.config.active_bg_color
    })
  end
  
  if M.config.inactive_bg_color then
    vim.api.nvim_set_hl(0, 'ClaudeManagerInactive', {
      bg = M.config.inactive_bg_color
    })
  end
end

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
    local new_win = vim.api.nvim_get_current_win()
    table.insert(windows, new_win)
    
    -- 新しく作成されたウィンドウに一時的なバッファを設定（後で置き換えられる）
    vim.api.nvim_win_call(new_win, function()
      vim.cmd('enew')
      local buf = vim.api.nvim_get_current_buf()
      vim.bo[buf].buftype = 'nofile'
      vim.bo[buf].buflisted = false
      vim.bo[buf].bufhidden = 'wipe'
    end)
  end
  
  -- ウィンドウサイズを均等に調整
  vim.cmd('wincmd =')
  
  return windows
end

-- セッションをウィンドウに設定
---@param session_name string セッション名
---@param window_id number ウィンドウID
local function setup_session_in_window(session_name, window_id)
  local existing_buf = M.state.buffers[session_name]
  
  if existing_buf and vim.api.nvim_buf_is_valid(existing_buf) then
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
      vim.bo[buf].bufhidden = 'hide' -- セッションは維持する必要があるのでhide
      
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
  
  -- アクティブインスタンスのハイライト設定
  if session_name == M.active_instance then
    vim.wo[window_id].winhighlight = 'Normal:ClaudeManagerActive'
  else
    if M.config.inactive_bg_color then
      vim.wo[window_id].winhighlight = 'Normal:ClaudeManagerInactive'
    end
  end
end

-- 一覧画面を表示
function M.show()
  if M.state.is_open then
    return
  end
  
  -- ハイライトグループを設定
  M.setup_highlights()
  
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
  
  -- 古いキーマッピングをクリア
  M.clear_keymaps()
  
  -- リストタブを閉じる
  if M.state.list_tab then
    -- タブが複数ある場合のみ閉じる
    if vim.fn.tabpagenr("$") > 1 then
      local current_tab = vim.fn.tabpagenr()
      
      -- 元のタブに先に戻る
      if M.state.original_tab and M.state.original_tab <= vim.fn.tabpagenr("$") 
          and M.state.original_tab ~= M.state.list_tab then
        vim.cmd('tabnext ' .. M.state.original_tab)
      end
      
      -- リストタブを閉じる
      vim.cmd('tabclose ' .. M.state.list_tab)
    else
      -- 最後のタブの場合は、ウィンドウのみを閉じる
      for _, win in pairs(M.state.windows) do
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end
    end
  end
  
  -- バッファをクリーンアップ
  for session_name, buf in pairs(M.state.buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      -- バッファを削除（ターミナルジョブが実行中の場合は強制削除）
      pcall(vim.api.nvim_buf_delete, buf, {force = true})
    end
  end
  
  M.state.is_open = false
  M.state.list_tab = nil
  M.state.windows = {}
  M.state.buffers = {}
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
    vim.bo[buf].bufhidden = 'wipe'  -- ウィンドウを離れたら削除
    vim.bo[buf].modifiable = true
    
    -- 空の状態のメッセージを表示
    local lines = {
      "Claude Manager - No instances",
      "",
      "Press 'a' to add a new instance",
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

-- 古いキーマッピングをクリア
function M.clear_keymaps()
  if M.state.buffers then
    for _, buf in pairs(M.state.buffers) do
      if vim.api.nvim_buf_is_valid(buf) then
        -- バッファの全キーマッピングをクリア
        pcall(vim.keymap.del, 't', '<C-q>', {buffer = buf})
        pcall(vim.keymap.del, 'n', 'a', {buffer = buf})
        pcall(vim.keymap.del, 'n', 'd', {buffer = buf})
        pcall(vim.keymap.del, 'n', 'o', {buffer = buf})
        pcall(vim.keymap.del, 'n', 'q', {buffer = buf})
        pcall(vim.keymap.del, 'n', '?', {buffer = buf})
      end
    end
  end
end

-- キーマッピングの設定
function M.setup_keymaps()
  -- 古いキーマッピングをクリア
  M.clear_keymaps()
  
  -- 各ウィンドウにキーマッピングを設定
  for _, win in ipairs(M.state.windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    
    -- ターミナルモードから抜ける
    vim.keymap.set('t', '<C-q>', '<C-\\><C-n>', {buffer = buf, noremap = true, silent = true})
    
    -- 新しいインスタンスを追加（自動番号）
    vim.keymap.set('n', 'a', function()
      M.add_instance()
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
  local current_buf = vim.api.nvim_get_current_buf()
  
  -- 現在のバッファが記録されているバッファリストと一致するかチェック
  for session_name, buf in pairs(M.state.buffers) do
    if buf == current_buf then
      return session_name
    end
  end
  
  -- フォールバック：バッファ名からインスタンス名を抽出
  local buf_name = vim.api.nvim_buf_get_name(current_buf)
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
    
    local pid = state.get_current_pid()
    local next_num = state.get_next_available_number()
    local name = string.format("claude_%d_%d", pid, next_num)
    
    -- インスタンスを追加
    state.add_instance({ name = name, options = options })
    
    -- tmuxセッションを作成
    tmux.create_claude_session(name, options)
    
    -- 画面を再描画
    M.refresh()
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
      -- 個別ウィンドウが開いている場合は閉じる
      if ui_individual.is_open() and ui_individual.get_active_session() == name then
        ui_individual.close()
      end
      
      -- 対応するバッファを削除
      if M.state.buffers[name] and vim.api.nvim_buf_is_valid(M.state.buffers[name]) then
        pcall(vim.api.nvim_buf_delete, M.state.buffers[name], {force = true})
        M.state.buffers[name] = nil
      end
      
      -- tmuxセッションを削除
      tmux.kill_session(name)
      
      -- 状態から削除
      state.remove_instance(name)
      
      -- インスタンスが0になった場合
      if state.get_instance_count() == 0 then
        -- タブが自動的に閉じるので、単にhideを呼び出す
        M.hide()
      else
        -- 画面を再描画
        M.refresh()
      end
    end
  end)
end


-- ヘルプを表示
function M.show_help()
  local help_lines = {
    "Claude Manager Help",
    "",
    "Key bindings:",
    "  a     - Add new instance (auto-numbered)",
    "  d     - Delete current instance",
    "  o     - Open individual window",
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

-- アクティブインスタンスのハイライトを更新
function M.update_active_highlight()
  -- アクティブ/非アクティブの識別を削除
end

-- アクティブなインスタンスを設定
---@param name string インスタンス名
function M.set_active_instance(name)
  M.active_instance = name
  M.update_active_highlight()
end

return M

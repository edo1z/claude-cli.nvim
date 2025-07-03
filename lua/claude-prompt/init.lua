-- Claude Prompt Manager
-- 依頼文作成・管理システム

local M = {}
local api = vim.api

-- セットアップ完了フラグ
M.is_setup = false

-- 状態管理
M.state = {
  -- プロンプトウィンドウ
  prompt_buf = nil,
  prompt_win = nil,
  prompt_content = {},  -- 内容を保持
  
  -- リストウィンドウ（スニペット・履歴）
  list_buf = nil,
  list_win = nil,
  list_type = nil,  -- 'snippet' or 'history'
  
  -- データ
  snippets = {},
  history = {},
  max_history = 100,
}

-- データファイルのパス
local data_dir = vim.fn.stdpath('data') .. '/claude-prompt'
local snippets_file = data_dir .. '/snippets.json'
local history_file = data_dir .. '/history.json'

-- 初期化
local function ensure_data_dir()
  if vim.fn.isdirectory(data_dir) == 0 then
    vim.fn.mkdir(data_dir, 'p')
  end
end

-- データの保存・読み込み
local function save_data(file, data)
  local json = vim.fn.json_encode(data)
  local f = io.open(file, 'w')
  if f then
    f:write(json)
    f:close()
  end
end

local function load_data(file)
  local f = io.open(file, 'r')
  if f then
    local content = f:read('*all')
    f:close()
    local ok, data = pcall(vim.fn.json_decode, content)
    if ok then
      return data
    end
  end
  return {}
end

-- プロンプトウィンドウの作成・表示
local function create_prompt_window()
  -- バッファ作成
  if not M.state.prompt_buf or not api.nvim_buf_is_valid(M.state.prompt_buf) then
    M.state.prompt_buf = api.nvim_create_buf(false, true)
    vim.bo[M.state.prompt_buf].buftype = 'nofile'
    vim.bo[M.state.prompt_buf].filetype = 'markdown'
    vim.bo[M.state.prompt_buf].modifiable = true
    
    -- 保存されていた内容を復元
    if #M.state.prompt_content > 0 then
      api.nvim_buf_set_lines(M.state.prompt_buf, 0, -1, false, M.state.prompt_content)
    end
  end
  
  -- ウィンドウサイズ（幅を50%に縮小）
  local width = math.floor(vim.o.columns * 0.5)
  local height = math.floor(vim.o.lines * 0.5)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- ウィンドウ作成
  M.state.prompt_win = api.nvim_open_win(M.state.prompt_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Claude Prompt (Ctrl+s:送信, Ctrl+l:スニペット, Ctrl+h:履歴, q:閉じる) ',
    title_pos = 'center',
  })
  
  -- キーマッピング
  local opts = {noremap = true, silent = true, buffer = M.state.prompt_buf}
  
  -- 送信
  vim.keymap.set({'n', 'i'}, '<C-s>', function()
    M.send_to_claude()
  end, opts)
  
  -- スニペット一覧
  vim.keymap.set({'n', 'i'}, '<C-l>', function()
    M.show_snippets()
  end, opts)
  
  -- 新規スニペット作成
  vim.keymap.set({'n', 'i'}, '<C-c>', function()
    M.create_snippet()
  end, opts)
  
  -- 履歴一覧
  vim.keymap.set({'n', 'i'}, '<C-h>', function()
    M.show_history()
  end, opts)
  
  -- ウィンドウを閉じる（内容は保持）
  vim.keymap.set('n', '<Esc>', function()
    M.hide_prompt()
  end, opts)
  
  -- qキーでもウィンドウを閉じる
  vim.keymap.set('n', 'q', function()
    M.hide_prompt()
  end, opts)
end

-- プロンプトウィンドウを表示
function M.show_prompt()
  if M.state.prompt_win and api.nvim_win_is_valid(M.state.prompt_win) then
    -- 既に表示されている
    api.nvim_set_current_win(M.state.prompt_win)
  else
    create_prompt_window()
  end
end

-- プロンプトウィンドウを非表示（内容保持）
function M.hide_prompt()
  if M.state.prompt_win and api.nvim_win_is_valid(M.state.prompt_win) then
    -- 内容を保存
    M.state.prompt_content = api.nvim_buf_get_lines(M.state.prompt_buf, 0, -1, false)
    -- ウィンドウを閉じる
    api.nvim_win_close(M.state.prompt_win, false)
    M.state.prompt_win = nil
  end
end

-- トグル
function M.toggle_prompt()
  if M.state.prompt_win and api.nvim_win_is_valid(M.state.prompt_win) then
    M.hide_prompt()
  else
    M.show_prompt()
  end
end

-- テキストを追加
function M.add_text(text)
  M.show_prompt()
  
  if M.state.prompt_buf and api.nvim_buf_is_valid(M.state.prompt_buf) then
    local lines = api.nvim_buf_get_lines(M.state.prompt_buf, 0, -1, false)
    
    -- 空でない場合は改行を追加
    if #lines > 0 and lines[#lines] ~= "" then
      table.insert(lines, "")
    end
    
    -- テキストを追加
    for _, line in ipairs(vim.split(text, '\n')) do
      table.insert(lines, line)
    end
    
    api.nvim_buf_set_lines(M.state.prompt_buf, 0, -1, false, lines)
    
    -- カーソルを最後に移動
    local last_line = api.nvim_buf_line_count(M.state.prompt_buf)
    api.nvim_win_set_cursor(M.state.prompt_win, {last_line, 0})
  end
end

-- Claude Codeに送信
function M.send_to_claude()
  if not M.state.prompt_buf then return end
  
  local content = table.concat(api.nvim_buf_get_lines(M.state.prompt_buf, 0, -1, false), '\n')
  
  if content ~= "" then
    -- 履歴に追加
    table.insert(M.state.history, 1, {
      content = content,
      timestamp = os.time(),
    })
    
    -- 最大件数を超えたら削除
    while #M.state.history > M.state.max_history do
      table.remove(M.state.history)
    end
    
    -- 保存
    save_data(history_file, M.state.history)
    
    -- まずclaude-managerのアクティブインスタンスを確認
    local has_manager, manager = pcall(require, 'claude-manager')
    local target_job_id = nil
    local target_win = nil
    
    if has_manager then
      target_job_id = manager.get_active_job_id()
      
      -- マネージャーのアクティブインスタンスがある場合
      if target_job_id then
        -- 個別ウィンドウが開いている場合はそちらにフォーカス
        local ui_individual = manager.ui_individual
        if ui_individual.is_open() and ui_individual.state.window and vim.api.nvim_win_is_valid(ui_individual.state.window) then
          target_win = ui_individual.state.window
        end
      end
    end
    
    -- マネージャーにアクティブインスタンスがない場合はclaude-cliにフォールバック
    if not target_job_id then
      local claude_cli = require('claude-cli')
      
      -- Claude Codeターミナルが開いていない場合は開く
      if not claude_cli.state.term_win or not api.nvim_win_is_valid(claude_cli.state.term_win) then
        claude_cli.toggle()
        -- ターミナルが起動するまで少し待つ
        vim.defer_fn(function()
          M.send_to_claude()
        end, 500)
        return
      end
      
      target_job_id = claude_cli.state.term_job_id
      target_win = claude_cli.state.term_win
    end
    
    if target_job_id then
      -- ウィンドウを非表示
      M.hide_prompt()
      
      -- ターゲットウィンドウにフォーカスを移す
      if target_win and api.nvim_win_is_valid(target_win) then
        api.nvim_set_current_win(target_win)
        -- ターミナルモードに入る
        vim.cmd('startinsert')
      end
      
      -- 送信
      vim.defer_fn(function()
        vim.fn.chansend(target_job_id, content)
      end, 300)
      
      -- バッファをクリア
      M.state.prompt_content = {}
      if M.state.prompt_buf and api.nvim_buf_is_valid(M.state.prompt_buf) then
        api.nvim_buf_set_lines(M.state.prompt_buf, 0, -1, false, {})
      end
    else
      vim.notify("Claude Code terminal not found", vim.log.levels.ERROR)
    end
  end
end

-- リストウィンドウの表示
local function show_list_window(title, items, on_select)
  -- 既存のリストウィンドウを閉じる
  if M.state.list_win and api.nvim_win_is_valid(M.state.list_win) then
    api.nvim_win_close(M.state.list_win, true)
  end
  
  -- バッファ作成
  M.state.list_buf = api.nvim_create_buf(false, true)
  vim.bo[M.state.list_buf].buftype = 'nofile'
  
  -- アイテムをフォーマット
  local lines = {}
  for i, item in ipairs(items) do
    local line
    if item.name then
      -- スニペット
      line = string.format("%d. %s", i, item.name)
    else
      -- 履歴
      local date = os.date("%Y-%m-%d %H:%M", item.timestamp)
      local preview = item.content:gsub('\n', ' '):sub(1, 50)
      line = string.format("%d. [%s] %s%s", i, date, preview, #item.content > 50 and "..." or "")
    end
    table.insert(lines, line)
  end
  
  if #lines == 0 then
    lines = {"(empty)"}
  end
  
  -- バッファに内容を設定してから読み取り専用にする
  api.nvim_buf_set_lines(M.state.list_buf, 0, -1, false, lines)
  vim.bo[M.state.list_buf].modifiable = false
  
  -- ウィンドウサイズ
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.6))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- ウィンドウ作成
  M.state.list_win = api.nvim_open_win(M.state.list_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' (j/k:選択, Enter/l:決定, d:削除, a:追加, q:キャンセル) ',
    title_pos = 'center',
  })
  
  -- キーマッピング
  local opts = {noremap = true, silent = true, buffer = M.state.list_buf}
  
  -- 選択
  vim.keymap.set('n', '<CR>', function()
    local line = api.nvim_win_get_cursor(M.state.list_win)[1]
    if items[line] then
      on_select(items[line], line)
    end
    api.nvim_win_close(M.state.list_win, true)
  end, opts)
  
  vim.keymap.set('n', 'l', function()
    local line = api.nvim_win_get_cursor(M.state.list_win)[1]
    if items[line] then
      on_select(items[line], line)
    end
    api.nvim_win_close(M.state.list_win, true)
  end, opts)
  
  -- キャンセル
  vim.keymap.set('n', 'q', function()
    api.nvim_win_close(M.state.list_win, true)
    -- プロンプトウィンドウが開いていればフォーカスを戻す
    if M.state.prompt_win and api.nvim_win_is_valid(M.state.prompt_win) then
      api.nvim_set_current_win(M.state.prompt_win)
    end
  end, opts)
  
  vim.keymap.set('n', '<Esc>', function()
    api.nvim_win_close(M.state.list_win, true)
    -- プロンプトウィンドウが開いていればフォーカスを戻す
    if M.state.prompt_win and api.nvim_win_is_valid(M.state.prompt_win) then
      api.nvim_set_current_win(M.state.prompt_win)
    end
  end, opts)
  
  -- 削除
  vim.keymap.set('n', 'd', function()
    local line = api.nvim_win_get_cursor(M.state.list_win)[1]
    if items[line] then
      table.remove(items, line)
      -- データ保存
      if M.state.list_type == 'snippet' then
        save_data(snippets_file, M.state.snippets)
      else
        save_data(history_file, M.state.history)
      end
      -- リスト更新
      api.nvim_win_close(M.state.list_win, true)
      if M.state.list_type == 'snippet' then
        M.show_snippets()
      else
        M.show_history()
      end
    end
  end, opts)
  
  -- スニペット編集（スニペットのみ）
  if M.state.list_type == 'snippet' then
    vim.keymap.set('n', 'e', function()
      local line = api.nvim_win_get_cursor(M.state.list_win)[1]
      if items[line] then
        M.edit_snippet(items[line], line)
      end
    end, opts)
  end
  
  -- 履歴をスニペットに追加（履歴のみ）
  if M.state.list_type == 'history' then
    vim.keymap.set('n', 's', function()
      local line = api.nvim_win_get_cursor(M.state.list_win)[1]
      if items[line] then
        M.history_to_snippet(items[line])
      end
    end, opts)
  end
  
  -- 新規スニペット作成（スニペットのみ）
  if M.state.list_type == 'snippet' then
    vim.keymap.set('n', 'a', function()
      -- リストウィンドウを閉じる
      api.nvim_win_close(M.state.list_win, true)
      -- スニペット作成
      M.create_snippet()
    end, opts)
  end
end

-- スニペット一覧表示
function M.show_snippets()
  M.state.list_type = 'snippet'
  show_list_window('スニペット (e:編集)', M.state.snippets, function(snippet)
    -- プロンプトウィンドウに追加
    M.add_text(snippet.content)
  end)
end

-- 履歴一覧表示
function M.show_history()
  M.state.list_type = 'history'
  show_list_window('履歴 (s:スニペット化)', M.state.history, function(history_item)
    -- プロンプトウィンドウに設定
    if M.state.prompt_buf and api.nvim_buf_is_valid(M.state.prompt_buf) then
      api.nvim_buf_set_lines(M.state.prompt_buf, 0, -1, false, vim.split(history_item.content, '\n'))
    end
  end)
end

-- スニペット作成
function M.create_snippet()
  vim.ui.input({prompt = 'スニペット名: '}, function(name)
    if name and name ~= '' then
      local content = ""
      if M.state.prompt_buf and api.nvim_buf_is_valid(M.state.prompt_buf) then
        content = table.concat(api.nvim_buf_get_lines(M.state.prompt_buf, 0, -1, false), '\n')
      end
      
      -- エディタで編集
      local buf = api.nvim_create_buf(false, true)
      vim.bo[buf].buftype = 'nofile'
      vim.bo[buf].filetype = 'markdown'
      
      api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, '\n'))
      
      local width = math.floor(vim.o.columns * 0.7)
      local height = math.floor(vim.o.lines * 0.6)
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)
      
      local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' スニペット編集: ' .. name .. ' (Ctrl+s:保存, Esc:キャンセル) ',
        title_pos = 'center',
      })
      
      -- 保存
      vim.keymap.set({'n', 'i'}, '<C-s>', function()
        local new_content = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
        table.insert(M.state.snippets, {
          name = name,
          content = new_content,
        })
        save_data(snippets_file, M.state.snippets)
        api.nvim_win_close(win, true)
        vim.notify("スニペット '" .. name .. "' を保存しました", vim.log.levels.INFO)
        
        -- スニペット一覧を再表示
        M.show_snippets()
      end, {buffer = buf})
      
      -- キャンセル
      vim.keymap.set('n', '<Esc>', function()
        api.nvim_win_close(win, true)
      end, {buffer = buf})
    end
  end)
end

-- スニペット編集
function M.edit_snippet(snippet, index)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].filetype = 'markdown'
  
  api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(snippet.content, '\n'))
  
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' スニペット編集: ' .. snippet.name .. ' (Ctrl+s:保存, Esc:キャンセル) ',
    title_pos = 'center',
  })
  
  -- 保存
  vim.keymap.set({'n', 'i'}, '<C-s>', function()
    local new_content = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
    M.state.snippets[index].content = new_content
    save_data(snippets_file, M.state.snippets)
    api.nvim_win_close(win, true)
    vim.notify("スニペット '" .. snippet.name .. "' を更新しました", vim.log.levels.INFO)
    
    -- スニペット一覧を再表示
    M.show_snippets()
  end, {buffer = buf})
  
  -- キャンセル
  vim.keymap.set('n', '<Esc>', function()
    api.nvim_win_close(win, true)
  end, {buffer = buf})
end

-- 履歴をスニペットに変換
function M.history_to_snippet(history_item)
  vim.ui.input({prompt = 'スニペット名: '}, function(name)
    if name and name ~= '' then
      table.insert(M.state.snippets, {
        name = name,
        content = history_item.content,
      })
      save_data(snippets_file, M.state.snippets)
      vim.notify("スニペット '" .. name .. "' を作成しました", vim.log.levels.INFO)
      
      -- リストウィンドウを閉じる
      if M.state.list_win and api.nvim_win_is_valid(M.state.list_win) then
        api.nvim_win_close(M.state.list_win, true)
      end
    end
  end)
end

-- セットアップ
function M.setup(opts)
  M.is_setup = true
  
  -- データディレクトリ作成
  ensure_data_dir()
  
  -- データ読み込み
  M.state.snippets = load_data(snippets_file)
  M.state.history = load_data(history_file)
  
  -- デフォルトスニペット
  if #M.state.snippets == 0 then
    M.state.snippets = {
      {name = "リファクタリング", content = "このコードをリファクタリングして、より読みやすくしてください:\n"},
      {name = "説明", content = "このコードの動作を日本語で説明してください:\n"},
      {name = "エラー修正", content = "以下のエラーを修正してください:\n"},
      {name = "テスト作成", content = "このコードに対するテストを作成してください:\n"},
      {name = "最適化", content = "このコードのパフォーマンスを最適化してください:\n"},
    }
    save_data(snippets_file, M.state.snippets)
  end
end

return M
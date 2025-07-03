---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

-- サブモジュールの読み込み
M.tmux = require("claude-manager.tmux")
M.ui_list = require("claude-manager.ui_list")
M.ui_individual = require("claude-manager.ui_individual")
M.state = require("claude-manager.state")
M.option_selector = require("claude-manager.option_selector")

-- デフォルト設定
M.config = {
  max_instances = 30,  -- 最大30インスタンス
  session_prefix = "claude",
  keymaps = {
    toggle_list = "<leader>cm",         -- マネージャー一覧の表示/非表示
    open_instance = "<leader>co",       -- 個別インスタンスを開く
  },
}

-- セットアップ状態
M.is_setup = false

-- セットアップ
---@param opts table|nil オプション設定
function M.setup(opts)
  if M.is_setup then
    return
  end
  
  -- 設定をマージ
  M.config = vim.tbl_extend('force', M.config, opts or {})
  
  -- キーマッピングの設定
  M._setup_keymaps()
  
  -- ui_listのoキーでui_individualを開くように設定
  M._setup_ui_integration()
  
  M.is_setup = true
end


-- キーマッピングの設定（内部関数）
function M._setup_keymaps()
  local keymaps = M.config.keymaps
  
  if keymaps.toggle_list then
    vim.keymap.set('n', keymaps.toggle_list, function()
      M.toggle_list()
    end, {desc = 'Claude Manager: Toggle list view'})
  end
  
  if keymaps.open_instance then
    vim.keymap.set('n', keymaps.open_instance, function()
      -- デフォルトでclaude1を開く
      M.open_instance(M.config.session_prefix .. "1")
    end, {desc = 'Claude Manager: Open instance'})
  end
end

-- UIモジュール間の連携設定（内部関数）
function M._setup_ui_integration()
  -- ui_list.luaのsetup_keymapsをオーバーライド
  local original_setup_keymaps = M.ui_list.setup_keymaps
  M.ui_list.setup_keymaps = function()
    -- 元のキーマップを設定
    original_setup_keymaps()
    
    -- 各ウィンドウにキーマッピングを追加設定
    for _, win in ipairs(M.ui_list.state.windows) do
      local buf = vim.api.nvim_win_get_buf(win)
      
      -- oキーで個別ウィンドウを開く（ui_listでもオーバーライド）
      vim.keymap.set('n', 'o', function()
        local session_name = M.ui_list.get_current_instance_name()
        if session_name then
          -- 一覧画面を閉じる
          M.ui_list.hide()
          -- 個別ウィンドウを開く
          M.ui_individual.open(session_name)
        end
      end, {buffer = buf, noremap = true, silent = true})
    end
  end
end

-- 一覧画面を表示
function M.show_list()
  if not M.is_setup then
    M.setup()
  end
  M.ui_list.show()
end

-- 一覧画面を非表示
function M.hide_list()
  M.ui_list.hide()
end

-- 一覧画面をトグル
function M.toggle_list()
  if not M.is_setup then
    M.setup()
  end
  M.ui_list.toggle()
end

-- 個別インスタンスを開く
---@param session_name string セッション名
function M.open_instance(session_name)
  if not M.is_setup then
    M.setup()
  end
  M.ui_individual.open(session_name)
end

-- アクティブなインスタンスのjob IDを取得
---@return number|nil
function M.get_active_job_id()
  -- まずリストビューのアクティブインスタンスを確認
  local list_job_id = M.ui_list.get_active_job_id()
  if list_job_id then
    return list_job_id
  end
  
  -- 次に個別ウィンドウのアクティブインスタンスを確認
  return M.ui_individual.get_job_id()
end


-- 新しいインスタンスを追加
---@param name string|nil カスタム名（省略時は自動採番）
---@param options string|nil 起動オプション
---@return string|nil 作成されたセッション名
function M.add_instance(name, options)
  if M.state.get_instance_count() >= M.config.max_instances then
    vim.notify("Maximum number of instances reached", vim.log.levels.WARN)
    return nil
  end
  
  -- 名前が指定されていない場合は自動採番
  if not name then
    local next_num = M.state.get_next_available_number()
    name = M.config.session_prefix .. next_num
  end
  
  -- インスタンスを追加
  M.state.add_instance({ name = name, options = options or "" })
  
  -- tmuxセッションを作成
  M.tmux.create_claude_session(name, options or "")
  
  return name
end

-- インスタンスを削除
---@param session_name string セッション名
---@return boolean 成功したかどうか
function M.remove_instance(session_name)
  -- tmuxセッションを削除
  local success = M.tmux.kill_session(session_name)
  
  if success then
    -- 状態から削除
    M.state.remove_instance(session_name)
  end
  
  return success
end

return M

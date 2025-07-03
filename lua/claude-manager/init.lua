---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

-- サブモジュールの読み込み
M.tmux = require("claude-manager.tmux")
M.ui_list = require("claude-manager.ui_list")
M.ui_individual = require("claude-manager.ui_individual")

-- デフォルト設定
M.config = {
  max_instances = 10,
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
  
  -- セッション名リストを更新
  M._update_session_list()
  
  -- キーマッピングの設定
  M._setup_keymaps()
  
  -- ui_listのoキーでui_individualを開くように設定
  M._setup_ui_integration()
  
  M.is_setup = true
end

-- セッション名リストを更新（内部関数）
function M._update_session_list()
  -- ui_list.luaのセッション一覧を更新
  local sessions = {}
  for i = 1, M.config.max_instances do
    table.insert(sessions, string.format("%s%d", M.config.session_prefix, i))
  end
  
  -- ui_list.luaのセッション一覧を更新する処理
  -- 現在の実装では直接更新する方法がないため、今後の改善点
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
      
      -- oキーで個別ウィンドウを開く
      vim.keymap.set('n', 'o', function()
        local session_name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
        -- 一覧画面を閉じる
        M.ui_list.hide()
        -- 個別ウィンドウを開く
        M.ui_individual.open(session_name)
      end, {buffer = buf, noremap = true, silent = true})
    end
  end
end

-- 一覧画面を表示
function M.show_list()
  if not M.is_setup then
    M.setup()
  end
  M.ensure_sessions()
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
  M.ensure_sessions()
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
  return M.ui_individual.get_job_id()
end

-- 全てのセッションが存在することを確保
function M.ensure_sessions()
  for i = 1, M.config.max_instances do
    local session_name = string.format("%s%d", M.config.session_prefix, i)
    M.tmux.ensure_session(session_name)
  end
end

-- 新しいインスタンスを追加（将来の拡張用）
---@param name string|nil カスタム名（省略時は自動採番）
---@return string|nil 作成されたセッション名
function M.add_instance(name)
  -- TODO: 実装予定
  vim.notify("add_instance is not implemented yet", vim.log.levels.WARN)
  return nil
end

-- インスタンスを削除（将来の拡張用）
---@param session_name string セッション名
---@return boolean 成功したかどうか
function M.remove_instance(session_name)
  -- TODO: 実装予定
  vim.notify("remove_instance is not implemented yet", vim.log.levels.WARN)
  return false
end

return M

---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

-- tmuxセッションの存在を確認し、必要なら作成する
---@param session_name string セッション名
---@return boolean 成功したかどうか
function M.ensure_session(session_name)
  -- セッションの存在確認
  local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
  vim.fn.system(check_cmd)
  
  if vim.v.shell_error ~= 0 then
    -- セッションが存在しない場合は作成
    local create_cmd = string.format("tmux new-session -d -s %s", session_name)
    vim.fn.system(create_cmd)
    
    if vim.v.shell_error ~= 0 then
      return false
    end
  end
  
  return true
end

-- 利用可能なclaudeセッション一覧を返す
---@return table セッション名のリスト
function M.list_sessions()
  local sessions = {}
  
  -- tmuxのセッション一覧を取得
  local list_cmd = "tmux list-sessions -F '#{session_name}' 2>/dev/null"
  local output = vim.fn.system(list_cmd)
  
  if vim.v.shell_error == 0 and output ~= "" then
    -- 各行を処理
    for line in output:gmatch("[^\r\n]+") do
      -- claudeで始まるセッションのみを抽出
      if line:match("^claude%d+$") then
        table.insert(sessions, line)
      end
    end
  end
  
  -- セッション名でソート
  table.sort(sessions, function(a, b)
    local num_a = tonumber(a:match("claude(%d+)"))
    local num_b = tonumber(b:match("claude(%d+)"))
    return num_a < num_b
  end)
  
  return sessions
end

-- セッションの状態を取得
---@param session_name string セッション名
---@return string "active" | "inactive"
function M.get_session_status(session_name)
  local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
  vim.fn.system(check_cmd)
  
  if vim.v.shell_error == 0 then
    return "active"
  else
    return "inactive"
  end
end

-- セッションを削除
---@param session_name string セッション名
---@return boolean 成功したかどうか
function M.kill_session(session_name)
  local kill_cmd = string.format("tmux kill-session -t %s 2>/dev/null", session_name)
  vim.fn.system(kill_cmd)
  
  return vim.v.shell_error == 0
end

-- ウィンドウ名を変更
---@param session_name string セッション名
---@param window_name string 新しいウィンドウ名
---@return boolean 成功したかどうか
function M.rename_window(session_name, window_name)
  local rename_cmd = string.format("tmux rename-window -t %s:0 '%s' 2>/dev/null", session_name, window_name)
  vim.fn.system(rename_cmd)
  
  return vim.v.shell_error == 0
end

-- Claude CLIを起動してセッションを作成
---@param session_name string セッション名
---@param options string 起動オプション（例: "-c --dangerously-skip-permissions"）
---@param command string|nil 実行するコマンド（テスト用、nilの場合は"claude"）
---@return boolean 成功したかどうか
function M.create_claude_session(session_name, options, command)
  -- セッションが既に存在する場合は削除
  M.kill_session(session_name)
  
  -- コマンドを構築
  local claude_cmd = command or "claude"
  if options and options ~= "" then
    claude_cmd = claude_cmd .. " " .. options
  end
  
  -- tmuxセッションを作成してClaude CLIを起動
  local create_cmd = string.format("tmux new-session -d -s %s '%s'", session_name, claude_cmd)
  vim.fn.system(create_cmd)
  
  if vim.v.shell_error ~= 0 then
    return false
  end
  
  -- ウィンドウ名を設定
  M.rename_window(session_name, "Claude CLI")
  
  return true
end

-- セッションを再起動
---@param session_name string セッション名
---@param options string 起動オプション
---@param command string|nil 実行するコマンド（テスト用）
---@return boolean 成功したかどうか
function M.restart_session(session_name, options, command)
  -- 既存のセッションを削除
  M.kill_session(session_name)
  
  -- 新しいセッションを作成
  return M.create_claude_session(session_name, options, command)
end

return M

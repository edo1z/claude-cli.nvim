---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-manager.tmux", function()
  local tmux
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-manager.tmux"] = nil
    tmux = require("claude-manager.tmux")
  end)
  
  describe("ensure_session", function()
    it("should create a new tmux session if it doesn't exist", function()
      local session_name = "test_claude_" .. os.time()
      
      -- セッションが存在しないことを確認
      local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
      vim.fn.system(check_cmd)
      assert.is_not.equals(0, vim.v.shell_error)
      
      -- セッションを作成
      local result = tmux.ensure_session(session_name)
      assert.is_true(result)
      
      -- セッションが存在することを確認
      vim.fn.system(check_cmd)
      assert.equals(0, vim.v.shell_error)
      
      -- クリーンアップ
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
    
    it("should return true if session already exists", function()
      local session_name = "test_claude_" .. os.time()
      
      -- あらかじめセッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- ensure_sessionを呼び出す
      local result = tmux.ensure_session(session_name)
      assert.is_true(result)
      
      -- セッションが存在することを確認
      local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
      vim.fn.system(check_cmd)
      assert.equals(0, vim.v.shell_error)
      
      -- クリーンアップ
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
  end)
  
  describe("list_sessions", function()
    it("should return a list of claude sessions", function()
      -- テスト用のセッションを作成
      local test_sessions = {"claude1", "claude2", "claude3"}
      for _, session in ipairs(test_sessions) do
        vim.fn.system(string.format("tmux new-session -d -s %s", session))
      end
      
      -- セッション一覧を取得
      local sessions = tmux.list_sessions()
      
      -- claude1, claude2, claude3が含まれていることを確認
      local found = {claude1 = false, claude2 = false, claude3 = false}
      for _, session in ipairs(sessions) do
        if found[session] ~= nil then
          found[session] = true
        end
      end
      
      assert.is_true(found.claude1)
      assert.is_true(found.claude2)
      assert.is_true(found.claude3)
      
      -- クリーンアップ
      for _, session in ipairs(test_sessions) do
        vim.fn.system(string.format("tmux kill-session -t %s 2>/dev/null", session))
      end
    end)
  end)
  
  describe("get_session_status", function()
    it("should return 'active' for existing session", function()
      local session_name = "test_claude_" .. os.time()
      
      -- セッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- ステータスを確認
      local status = tmux.get_session_status(session_name)
      assert.equals("active", status)
      
      -- クリーンアップ
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
    
    it("should return 'inactive' for non-existing session", function()
      local session_name = "non_existing_session_" .. os.time()
      
      -- ステータスを確認
      local status = tmux.get_session_status(session_name)
      assert.equals("inactive", status)
    end)
  end)
  
  describe("kill_session", function()
    it("should kill an existing session", function()
      local session_name = "test_claude_" .. os.time()
      
      -- セッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- セッションが存在することを確認
      local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
      vim.fn.system(check_cmd)
      assert.equals(0, vim.v.shell_error)
      
      -- セッションを削除
      local result = tmux.kill_session(session_name)
      assert.is_true(result)
      
      -- セッションが存在しないことを確認
      vim.fn.system(check_cmd)
      assert.is_not.equals(0, vim.v.shell_error)
    end)
  end)
  
  describe("rename_window", function()
    it("should rename the window in a session", function()
      local session_name = "test_claude_" .. os.time()
      local window_name = "TestWindow"
      
      -- セッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- ウィンドウ名を変更
      local result = tmux.rename_window(session_name, window_name)
      assert.is_true(result)
      
      -- ウィンドウ名を確認
      local list_cmd = string.format("tmux list-windows -t %s -F '#{window_name}'", session_name)
      local output = vim.fn.system(list_cmd)
      assert.is_not_nil(string.find(output, window_name))
      
      -- クリーンアップ
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
  end)
  
  describe("create_claude_session", function()
    it("should create session with claude command", function()
      local session_name = "test_claude_" .. os.time()
      
      -- Claude CLIセッションを作成（モックコマンドを使用）
      local result = tmux.create_claude_session(session_name, "", "echo 'Claude CLI Mock'")
      assert.is_true(result)
      
      -- セッションが存在することを確認
      local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
      vim.fn.system(check_cmd)
      assert.equals(0, vim.v.shell_error)
      
      -- クリーンアップ
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
    
    it("should create session with options", function()
      local session_name = "test_claude_" .. os.time()
      
      -- オプション付きでClaude CLIセッションを作成
      local result = tmux.create_claude_session(session_name, "-c --dangerously-skip-permissions", "echo 'Claude CLI Mock'")
      assert.is_true(result)
      
      -- セッションが存在することを確認
      local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
      vim.fn.system(check_cmd)
      assert.equals(0, vim.v.shell_error)
      
      -- クリーンアップ
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
  end)
  
  describe("restart_session", function()
    it("should restart existing session", function()
      local session_name = "test_claude_" .. os.time()
      
      -- 初期セッションを作成（bashを起動して維持）
      vim.fn.system(string.format("tmux new-session -d -s %s 'bash'", session_name))
      
      -- セッションが存在することを確認
      local check_cmd = string.format("tmux has-session -t %s 2>/dev/null", session_name)
      vim.fn.system(check_cmd)
      assert.equals(0, vim.v.shell_error)
      
      -- セッションを再起動（モックコマンドもbashで維持）
      local result = tmux.restart_session(session_name, "", "bash -c 'echo Restarted; exec bash'")
      assert.is_true(result)
      
      -- セッションがまだ存在することを確認
      vim.fn.system(check_cmd)
      assert.equals(0, vim.v.shell_error)
      
      -- クリーンアップ
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
  end)
end)
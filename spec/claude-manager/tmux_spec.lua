---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-manager.tmux", function()
  local tmux
  local state
  local original_system
  local original_notify
  local original_v
  local mock_shell_error = 0
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-manager.tmux"] = nil
    package.loaded["claude-manager.state"] = nil
    
    -- vim.fn.systemとvim.notifyをモック
    original_system = vim.fn.system
    original_notify = vim.notify
    original_v = vim.v
    
    -- vim.vをモック可能なテーブルに置き換える
    vim.v = setmetatable({}, {
      __index = function(t, k)
        if k == "shell_error" then
          return mock_shell_error
        end
        return original_v[k]
      end,
      __newindex = function(t, k, v)
        if k == "shell_error" then
          mock_shell_error = v
        else
          -- その他のキーは元のvim.vには設定しない
        end
      end
    })
    
    tmux = require("claude-manager.tmux")
    state = require("claude-manager.state")
  end)
  
  after_each(function()
    -- モックを元に戻す
    vim.fn.system = original_system
    vim.notify = original_notify
    vim.v = original_v
    mock_shell_error = 0
  end)
  
  describe("list_sessions", function()
    it("should list only current PID sessions", function()
      local current_pid = state.get_current_pid()
      
      -- tmuxの出力をモック
      vim.fn.system = function(cmd)
        if cmd:match("tmux list%-sessions") then
          vim.v.shell_error = 0
          return string.format([[claude_%d_1
claude_%d_2
claude_9999_1
claude_9999_2
other-session]], current_pid, current_pid)
        end
        vim.v.shell_error = 0
        return ""
      end
      
      local sessions = tmux.list_sessions()
      
      -- 現在のPIDのセッションのみが返される
      assert.equals(2, #sessions)
      assert.equals(string.format("claude_%d_1", current_pid), sessions[1])
      assert.equals(string.format("claude_%d_2", current_pid), sessions[2])
    end)
    
    it("should return empty list when no sessions", function()
      vim.fn.system = function(cmd)
        if cmd:match("tmux list%-sessions") then
          vim.v.shell_error = 1
          return ""
        end
        vim.v.shell_error = 0
        return ""
      end
      
      local sessions = tmux.list_sessions()
      assert.equals(0, #sessions)
    end)
    
    it("should sort sessions by number", function()
      local current_pid = state.get_current_pid()
      
      vim.fn.system = function(cmd)
        if cmd:match("tmux list%-sessions") then
          vim.v.shell_error = 0
          return string.format([[claude_%d_10
claude_%d_2
claude_%d_1]], current_pid, current_pid, current_pid)
        end
        vim.v.shell_error = 0
        return ""
      end
      
      local sessions = tmux.list_sessions()
      
      assert.equals(3, #sessions)
      assert.equals(string.format("claude_%d_1", current_pid), sessions[1])
      assert.equals(string.format("claude_%d_2", current_pid), sessions[2])
      assert.equals(string.format("claude_%d_10", current_pid), sessions[3])
    end)
  end)
  
  describe("create_claude_session", function()
    it("should not create session if it already exists", function()
      local notified = false
      local notified_msg = ""
      
      -- vim.notifyをモック
      vim.notify = function(msg, level)
        notified = true
        notified_msg = msg
      end
      
      -- 既存セッションがあるとモック
      vim.fn.system = function(cmd)
        if cmd:match("tmux has%-session") then
          vim.v.shell_error = 0  -- セッションが存在
          return ""
        end
        vim.v.shell_error = 0
        return ""
      end
      
      local success = tmux.create_claude_session("claude_12345_1", "", "claude")
      
      assert.is_false(success)
      assert.is_true(notified)
      assert.matches("already exists", notified_msg)
    end)
    
    it("should create new session when it doesn't exist", function()
      local created_session = nil
      local renamed_window = false
      
      vim.fn.system = function(cmd)
        if cmd:match("tmux has%-session") then
          vim.v.shell_error = 1  -- セッションが存在しない
          return ""
        elseif cmd:match("tmux new%-session") then
          created_session = cmd:match("-s (%S+)")
          vim.v.shell_error = 0
          return ""
        elseif cmd:match("tmux rename%-window") then
          renamed_window = true
          vim.v.shell_error = 0
          return ""
        end
        vim.v.shell_error = 0
        return ""
      end
      
      local success = tmux.create_claude_session("claude_12345_1", "-c", "claude")
      
      assert.is_true(success)
      assert.equals("claude_12345_1", created_session)
      assert.is_true(renamed_window)
    end)
  end)
  
  describe("get_session_status", function()
    it("should return active when session exists", function()
      vim.fn.system = function(cmd)
        if cmd:match("tmux has%-session") then
          vim.v.shell_error = 0
          return ""
        end
        vim.v.shell_error = 0
        return ""
      end
      
      local status = tmux.get_session_status("claude_12345_1")
      assert.equals("active", status)
    end)
    
    it("should return inactive when session doesn't exist", function()
      vim.fn.system = function(cmd)
        if cmd:match("tmux has%-session") then
          vim.v.shell_error = 1
          return ""
        end
        vim.v.shell_error = 0
        return ""
      end
      
      local status = tmux.get_session_status("claude_12345_1")
      assert.equals("inactive", status)
    end)
  end)
  
  describe("kill_session", function()
    it("should kill existing session", function()
      local killed_session = nil
      
      vim.fn.system = function(cmd)
        if cmd:match("tmux kill%-session") then
          killed_session = cmd:match("-t (%S+)")
          vim.v.shell_error = 0
          return ""
        end
        vim.v.shell_error = 0
        return ""
      end
      
      local success = tmux.kill_session("claude_12345_1")
      
      assert.is_true(success)
      assert.equals("claude_12345_1", killed_session)
    end)
    
    it("should return false when killing non-existent session", function()
      vim.fn.system = function(cmd)
        if cmd:match("tmux kill%-session") then
          vim.v.shell_error = 1
          return ""
        end
        vim.v.shell_error = 0
        return ""
      end
      
      local success = tmux.kill_session("non-existent")
      assert.is_false(success)
    end)
  end)
end)
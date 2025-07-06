---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-manager.state", function()
  local state
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-manager.state"] = nil
    package.loaded["claude-manager.tmux"] = nil
    state = require("claude-manager.state")
    state.clear_all()
  end)
  
  describe("get_current_pid", function()
    it("should return a valid process ID", function()
      local pid = state.get_current_pid()
      assert.is_number(pid)
      assert.is_true(pid > 0)
    end)
  end)
  
  describe("instance management", function()
    it("should start with empty instances", function()
      local instances = state.get_instances()
      assert.equals(0, #instances)
    end)
    
    it("should add new instance", function()
      local instance = state.add_instance({
        name = "claude_12345_1",
        options = "",
      })
      
      assert.equals("claude_12345_1", instance.name)
      assert.equals("", instance.options)
      assert.is_not_nil(instance.created_at)
      
      local instances = state.get_instances()
      assert.equals(1, #instances)
    end)
    
    it("should add instance with options", function()
      local instance = state.add_instance({
        name = "claude_12345_2",
        options = "-c --dangerously-skip-permissions",
      })
      
      assert.equals("claude_12345_2", instance.name)
      assert.equals("-c --dangerously-skip-permissions", instance.options)
    end)
    
    it("should remove instance", function()
      state.add_instance({ name = "claude_12345_1", options = "" })
      state.add_instance({ name = "claude_12345_2", options = "" })
      
      local success = state.remove_instance("claude_12345_1")
      assert.is_true(success)
      
      local instances = state.get_instances()
      assert.equals(1, #instances)
      assert.equals("claude_12345_2", instances[1].name)
    end)
    
    it("should return false when removing non-existent instance", function()
      local success = state.remove_instance("non-existent")
      assert.is_false(success)
    end)
  end)
  
  describe("instance lookup", function()
    it("should get instance by name", function()
      state.add_instance({ name = "claude_12345_1", options = "-c" })
      
      local instance = state.get_instance("claude_12345_1")
      assert.is_not_nil(instance)
      assert.equals("claude_12345_1", instance.name)
      assert.equals("-c", instance.options)
    end)
    
    it("should return nil for non-existent instance", function()
      local instance = state.get_instance("non-existent")
      assert.is_nil(instance)
    end)
  end)
  
  describe("next available number", function()
    it("should return 1 when no instances", function()
      -- tmux.list_sessionsをモック
      local tmux = require("claude-manager.tmux")
      tmux.list_sessions = function() return {} end
      
      local num = state.get_next_available_number()
      assert.equals(1, num)
    end)
    
    it("should use current PID by default", function()
      local tmux = require("claude-manager.tmux")
      tmux.list_sessions = function() return {} end
      
      local pid = state.get_current_pid()
      local prefix = string.format("claude_%d_", pid)
      
      -- 1つ目のインスタンスを追加
      state.add_instance({ name = prefix .. "1" })
      
      -- 次は2を返すべき
      local num = state.get_next_available_number()
      assert.equals(2, num)
    end)
    
    it("should skip numbers used by tmux sessions", function()
      local pid = state.get_current_pid()
      local prefix = string.format("claude_%d_", pid)
      
      -- tmuxセッションが存在する場合をモック
      local tmux = require("claude-manager.tmux")
      tmux.list_sessions = function()
        return { prefix .. "1", prefix .. "3" }
      end
      
      -- 次は2を返すべき
      local num = state.get_next_available_number()
      assert.equals(2, num)
      
      -- 2を使用
      state.add_instance({ name = prefix .. "2" })
      
      -- 次は4を返すべき
      num = state.get_next_available_number()
      assert.equals(4, num)
    end)
    
    it("should return next available number", function()
      local tmux = require("claude-manager.tmux")
      local pid = state.get_current_pid()
      local prefix = string.format("claude_%d_", pid)
      
      -- tmuxセッションをモック
      tmux.list_sessions = function()
        return { prefix .. "1", prefix .. "2" }
      end
      
      local num = state.get_next_available_number()
      assert.equals(3, num)
    end)
    
    it("should fill gaps in numbering", function()
      local tmux = require("claude-manager.tmux")
      local pid = state.get_current_pid()
      local prefix = string.format("claude_%d_", pid)
      
      -- ギャップのあるセッション
      tmux.list_sessions = function()
        return { prefix .. "1", prefix .. "3" }
      end
      
      local num = state.get_next_available_number()
      assert.equals(2, num)
    end)
    
    it("should handle non-standard names", function()
      local tmux = require("claude-manager.tmux")
      tmux.list_sessions = function() return {} end
      
      state.add_instance({ name = "my-claude", options = "" })
      state.add_instance({ name = "claude_9999_2", options = "" })
      
      local num = state.get_next_available_number()
      assert.equals(1, num)  -- 現在のPIDでclaude_PID_1は使われていない
    end)
  end)
  
  describe("instance count", function()
    it("should return correct count", function()
      assert.equals(0, state.get_instance_count())
      
      state.add_instance({ name = "claude_12345_1", options = "" })
      assert.equals(1, state.get_instance_count())
      
      state.add_instance({ name = "claude_12345_2", options = "" })
      assert.equals(2, state.get_instance_count())
      
      state.remove_instance("claude_12345_1")
      assert.equals(1, state.get_instance_count())
    end)
  end)
  
  describe("get_instances sorting", function()
    it("should sort instances by PID and number", function()
      -- 異なるPIDのインスタンスを追加
      state.add_instance({ name = "claude_1000_2" })
      state.add_instance({ name = "claude_2000_1" })
      state.add_instance({ name = "claude_1000_1" })
      state.add_instance({ name = "custom_name" })
      
      local instances = state.get_instances()
      
      -- 期待される順序：
      -- 1. claude_1000_1
      -- 2. claude_1000_2
      -- 3. claude_2000_1
      -- 4. custom_name
      assert.equals("claude_1000_1", instances[1].name)
      assert.equals("claude_1000_2", instances[2].name)
      assert.equals("claude_2000_1", instances[3].name)
      assert.equals("custom_name", instances[4].name)
    end)
  end)
  
  describe("clear all", function()
    it("should remove all instances", function()
      state.add_instance({ name = "claude_12345_1", options = "" })
      state.add_instance({ name = "claude_12345_2", options = "" })
      state.add_instance({ name = "claude_12345_3", options = "" })
      
      state.clear_all()
      
      assert.equals(0, state.get_instance_count())
      assert.equals(0, #state.get_instances())
    end)
  end)
end)
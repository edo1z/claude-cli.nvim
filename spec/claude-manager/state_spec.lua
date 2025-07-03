---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-manager.state", function()
  local state
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-manager.state"] = nil
    state = require("claude-manager.state")
  end)
  
  describe("instance management", function()
    it("should start with empty instances", function()
      local instances = state.get_instances()
      assert.equals(0, #instances)
    end)
    
    it("should add new instance", function()
      local instance = state.add_instance({
        name = "claude1",
        options = "",
      })
      
      assert.equals("claude1", instance.name)
      assert.equals("", instance.options)
      assert.is_not_nil(instance.created_at)
      
      local instances = state.get_instances()
      assert.equals(1, #instances)
    end)
    
    it("should add instance with options", function()
      local instance = state.add_instance({
        name = "claude2",
        options = "-c --dangerously-skip-permissions",
      })
      
      assert.equals("claude2", instance.name)
      assert.equals("-c --dangerously-skip-permissions", instance.options)
    end)
    
    it("should remove instance", function()
      state.add_instance({ name = "claude1", options = "" })
      state.add_instance({ name = "claude2", options = "" })
      
      local success = state.remove_instance("claude1")
      assert.is_true(success)
      
      local instances = state.get_instances()
      assert.equals(1, #instances)
      assert.equals("claude2", instances[1].name)
    end)
    
    it("should return false when removing non-existent instance", function()
      local success = state.remove_instance("non-existent")
      assert.is_false(success)
    end)
  end)
  
  describe("instance lookup", function()
    it("should get instance by name", function()
      state.add_instance({ name = "claude1", options = "-c" })
      
      local instance = state.get_instance("claude1")
      assert.is_not_nil(instance)
      assert.equals("claude1", instance.name)
      assert.equals("-c", instance.options)
    end)
    
    it("should return nil for non-existent instance", function()
      local instance = state.get_instance("non-existent")
      assert.is_nil(instance)
    end)
  end)
  
  describe("next available number", function()
    it("should return 1 when no instances", function()
      local num = state.get_next_available_number()
      assert.equals(1, num)
    end)
    
    it("should return next available number", function()
      state.add_instance({ name = "claude1", options = "" })
      state.add_instance({ name = "claude2", options = "" })
      
      local num = state.get_next_available_number()
      assert.equals(3, num)
    end)
    
    it("should fill gaps in numbering", function()
      state.add_instance({ name = "claude1", options = "" })
      state.add_instance({ name = "claude3", options = "" })
      
      local num = state.get_next_available_number()
      assert.equals(2, num)
    end)
    
    it("should handle non-standard names", function()
      state.add_instance({ name = "my-claude", options = "" })
      state.add_instance({ name = "claude2", options = "" })
      
      local num = state.get_next_available_number()
      assert.equals(1, num)  -- claude1は使われていない
    end)
  end)
  
  describe("instance count", function()
    it("should return correct count", function()
      assert.equals(0, state.get_instance_count())
      
      state.add_instance({ name = "claude1", options = "" })
      assert.equals(1, state.get_instance_count())
      
      state.add_instance({ name = "claude2", options = "" })
      assert.equals(2, state.get_instance_count())
      
      state.remove_instance("claude1")
      assert.equals(1, state.get_instance_count())
    end)
  end)
  
  describe("clear all", function()
    it("should remove all instances", function()
      state.add_instance({ name = "claude1", options = "" })
      state.add_instance({ name = "claude2", options = "" })
      state.add_instance({ name = "claude3", options = "" })
      
      state.clear_all()
      
      assert.equals(0, state.get_instance_count())
      assert.equals(0, #state.get_instances())
    end)
  end)
end)
---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-manager", function()
  local manager
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-manager"] = nil
    package.loaded["claude-manager.tmux"] = nil
    package.loaded["claude-manager.ui_list"] = nil
    package.loaded["claude-manager.ui_individual"] = nil
    package.loaded["claude-manager.state"] = nil
    manager = require("claude-manager")
  end)
  
  after_each(function()
    -- クリーンアップ
    if manager.ui_list.is_open() then
      manager.ui_list.hide()
    end
    if manager.ui_individual.is_open() then
      manager.ui_individual.close()
    end
  end)
  
  describe("setup", function()
    it("should setup with default config", function()
      manager.setup()
      
      -- デフォルト設定が適用されていることを確認
      assert.equals(30, manager.config.max_instances)
      assert.equals("claude", manager.config.session_prefix)
    end)
    
    it("should setup with custom config", function()
      manager.setup({
        max_instances = 5,
        session_prefix = "test",
      })
      
      -- カスタム設定が適用されていることを確認
      assert.equals(5, manager.config.max_instances)
      assert.equals("test", manager.config.session_prefix)
    end)
  end)
  
  describe("show_list", function()
    it("should show list view", function()
      manager.setup()
      
      assert.is_false(manager.ui_list.is_open())
      manager.show_list()
      assert.is_true(manager.ui_list.is_open())
    end)
  end)
  
  describe("toggle_list", function()
    it("should toggle list view", function()
      manager.setup()
      
      -- 初期状態では閉じている
      assert.is_false(manager.ui_list.is_open())
      
      -- トグルで開く
      manager.toggle_list()
      assert.is_true(manager.ui_list.is_open())
      
      -- もう一度トグルで閉じる
      manager.toggle_list()
      assert.is_false(manager.ui_list.is_open())
    end)
  end)
  
  describe("open_instance", function()
    it("should open individual instance", function()
      manager.setup()
      local session_name = "test_claude_" .. os.time()
      
      -- tmuxセッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- インスタンスを開く
      manager.open_instance(session_name)
      assert.is_true(manager.ui_individual.is_open())
      assert.equals(session_name, manager.ui_individual.get_active())
      
      -- クリーンアップ
      manager.ui_individual.close()
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
  end)
  
  describe("get_active_job_id", function()
    it("should return job id of active instance", function()
      manager.setup()
      local session_name = "test_claude_" .. os.time()
      
      -- tmuxセッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- インスタンスを開く
      manager.open_instance(session_name)
      
      -- job_idが取得できることを確認
      local job_id = manager.get_active_job_id()
      assert.is_not_nil(job_id)
      assert.is_number(job_id)
      
      -- クリーンアップ
      manager.ui_individual.close()
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
    
    it("should return nil when no active instance", function()
      manager.setup()
      
      local job_id = manager.get_active_job_id()
      assert.is_nil(job_id)
    end)
  end)
  
  describe("instance management", function()
    it("should add new instance", function()
      manager.setup()
      
      -- 新しいインスタンスを追加
      local name = manager.add_instance(nil, "")
      assert.is_not_nil(name)
      assert.equals("claude1", name)
      
      -- インスタンスが存在することを確認
      local instance = manager.state.get_instance(name)
      assert.is_not_nil(instance)
      assert.equals(name, instance.name)
      
      -- クリーンアップ
      manager.remove_instance(name)
    end)
    
    it("should add instance with custom name", function()
      manager.setup()
      
      local custom_name = "my-claude"
      local name = manager.add_instance(custom_name, "-c")
      assert.equals(custom_name, name)
      
      -- インスタンスが存在することを確認
      local instance = manager.state.get_instance(name)
      assert.is_not_nil(instance)
      assert.equals("-c", instance.options)
      
      -- クリーンアップ
      manager.remove_instance(name)
    end)
    
    it("should remove instance", function()
      manager.setup()
      
      -- インスタンスを追加
      local name = manager.add_instance()
      assert.is_not_nil(manager.state.get_instance(name))
      
      -- インスタンスを削除
      local success = manager.remove_instance(name)
      assert.is_true(success)
      assert.is_nil(manager.state.get_instance(name))
    end)
  end)
end)
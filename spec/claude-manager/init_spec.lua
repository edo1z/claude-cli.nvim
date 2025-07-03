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
      assert.equals(10, manager.config.max_instances)
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
  
  describe("ensure_sessions", function()
    it("should ensure all sessions exist", function()
      manager.setup({max_instances = 3})
      
      -- セッションを確保
      manager.ensure_sessions()
      
      -- セッションが存在することを確認
      local sessions = manager.tmux.list_sessions()
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
      vim.fn.system("tmux kill-session -t claude1 2>/dev/null")
      vim.fn.system("tmux kill-session -t claude2 2>/dev/null")
      vim.fn.system("tmux kill-session -t claude3 2>/dev/null")
    end)
  end)
end)
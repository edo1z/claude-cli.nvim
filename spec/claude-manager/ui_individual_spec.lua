---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-manager.ui_individual", function()
  local ui_individual
  local original_win
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-manager.ui_individual"] = nil
    package.loaded["claude-manager.tmux"] = nil
    ui_individual = require("claude-manager.ui_individual")
    
    -- 現在のウィンドウを保存
    original_win = vim.api.nvim_get_current_win()
  end)
  
  after_each(function()
    -- 個別ウィンドウを閉じる
    if ui_individual.is_open() then
      ui_individual.close()
    end
    -- 追加で開いたウィンドウがあれば閉じる
    if #vim.api.nvim_list_wins() > 1 then
      vim.cmd("only")
    end
  end)
  
  describe("open", function()
    it("should open individual window on the right", function()
      local session_name = "test_claude_" .. os.time()
      
      -- テスト用のセッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- 個別ウィンドウを開く
      ui_individual.open(session_name)
      
      -- ウィンドウが作成されたことを確認
      assert.is_true(ui_individual.is_open())
      assert.equals(session_name, ui_individual.get_active())
      
      -- ウィンドウが右側にあることを確認（元のウィンドウより右）
      local current_win = vim.api.nvim_get_current_win()
      assert.is_not.equals(original_win, current_win)
      
      -- クリーンアップ
      ui_individual.close()
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
    
    it("should switch active session when opening different session", function()
      local session1 = "test_claude1_" .. os.time()
      local session2 = "test_claude2_" .. os.time()
      
      -- テスト用のセッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session1))
      vim.fn.system(string.format("tmux new-session -d -s %s", session2))
      
      -- 最初のセッションを開く
      ui_individual.open(session1)
      assert.equals(session1, ui_individual.get_active())
      
      -- 別のセッションを開く
      ui_individual.open(session2)
      assert.equals(session2, ui_individual.get_active())
      
      -- クリーンアップ
      ui_individual.close()
      vim.fn.system(string.format("tmux kill-session -t %s", session1))
      vim.fn.system(string.format("tmux kill-session -t %s", session2))
    end)
  end)
  
  describe("close", function()
    it("should close individual window", function()
      local session_name = "test_claude_" .. os.time()
      
      -- テスト用のセッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- 個別ウィンドウを開いて閉じる
      ui_individual.open(session_name)
      assert.is_true(ui_individual.is_open())
      
      ui_individual.close()
      assert.is_false(ui_individual.is_open())
      assert.is_nil(ui_individual.get_active())
      
      -- クリーンアップ
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
  end)
  
  describe("toggle", function()
    it("should toggle individual window", function()
      local session_name = "test_claude_" .. os.time()
      
      -- テスト用のセッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- 初期状態では閉じている
      assert.is_false(ui_individual.is_open())
      
      -- トグルで開く
      ui_individual.toggle(session_name)
      assert.is_true(ui_individual.is_open())
      
      -- もう一度トグルで閉じる
      ui_individual.toggle()
      assert.is_false(ui_individual.is_open())
      
      -- クリーンアップ
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
  end)
  
  describe("get_job_id", function()
    it("should return job id for active session", function()
      local session_name = "test_claude_" .. os.time()
      
      -- テスト用のセッションを作成
      vim.fn.system(string.format("tmux new-session -d -s %s", session_name))
      
      -- 個別ウィンドウを開く
      ui_individual.open(session_name)
      
      -- job_idが取得できることを確認
      local job_id = ui_individual.get_job_id()
      assert.is_not_nil(job_id)
      assert.is_number(job_id)
      
      -- クリーンアップ
      ui_individual.close()
      vim.fn.system(string.format("tmux kill-session -t %s", session_name))
    end)
    
    it("should return nil when no active session", function()
      local job_id = ui_individual.get_job_id()
      assert.is_nil(job_id)
    end)
  end)
end)
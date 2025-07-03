---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-manager.ui_list", function()
  local ui_list
  local state
  local tmux
  local original_tab
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-manager.ui_list"] = nil
    package.loaded["claude-manager.state"] = nil
    package.loaded["claude-manager.tmux"] = nil
    
    state = require("claude-manager.state")
    tmux = require("claude-manager.tmux")
    ui_list = require("claude-manager.ui_list")
    
    -- 初期状態をクリア
    state.clear_all()
    
    -- 現在のタブを保存
    original_tab = vim.fn.tabpagenr()
  end)
  
  after_each(function()
    -- 開いたタブを全て閉じる
    vim.cmd("tabonly")
    -- 元のタブに戻る
    if original_tab and original_tab <= vim.fn.tabpagenr("$") then
      vim.cmd("tabnext " .. original_tab)
    end
  end)
  
  describe("calculate_grid_layout", function()
    it("should return 1x1 for 0 instances", function()
      local rows, cols = ui_list.calculate_grid_layout(0)
      assert.equals(1, rows)
      assert.equals(1, cols)
    end)
    
    it("should calculate grid layout for 10 sessions", function()
      local rows, cols = ui_list.calculate_grid_layout(10)
      assert.equals(3, rows)
      assert.equals(4, cols)
    end)
    
    it("should calculate grid layout for 4 sessions", function()
      local rows, cols = ui_list.calculate_grid_layout(4)
      assert.equals(2, rows)
      assert.equals(2, cols)
    end)
    
    it("should calculate grid layout for 1 session", function()
      local rows, cols = ui_list.calculate_grid_layout(1)
      assert.equals(1, rows)
      assert.equals(1, cols)
    end)
  end)
  
  describe("show/hide/toggle", function()
    it("should show empty state when no instances", function()
      local initial_tab_count = vim.fn.tabpagenr("$")
      
      ui_list.show()
      
      -- 新しいタブが作成されたことを確認
      assert.equals(initial_tab_count + 1, vim.fn.tabpagenr("$"))
      assert.is_true(ui_list.is_open())
      
      -- 空の状態が表示されていることを確認
      local buf = vim.api.nvim_win_get_buf(ui_list.state.windows[1])
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.is_true(lines[1]:match("No instances") ~= nil)
    end)
    
    it("should show instances in grid layout", function()
      -- インスタンスを追加
      state.add_instance({ name = "claude1", options = "" })
      state.add_instance({ name = "claude2", options = "" })
      
      ui_list.show()
      
      assert.is_true(ui_list.is_open())
      -- 2つのウィンドウが作成されていることを確認
      assert.equals(2, #ui_list.state.windows)
    end)
    
    it("should hide list view and return to original tab", function()
      -- 一覧画面を表示
      ui_list.show()
      local list_tab = vim.fn.tabpagenr()
      
      -- 非表示にする
      ui_list.hide()
      
      -- タブが閉じられたことを確認
      assert.is_false(ui_list.is_open())
      assert.is_not.equals(list_tab, vim.fn.tabpagenr())
    end)
    
    it("should toggle list view", function()
      -- 初期状態では閉じている
      assert.is_false(ui_list.is_open())
      
      -- トグルで開く
      ui_list.toggle()
      assert.is_true(ui_list.is_open())
      
      -- もう一度トグルで閉じる
      ui_list.toggle()
      assert.is_false(ui_list.is_open())
    end)
  end)
  
  describe("find_buffer_by_name", function()
    it("should find existing buffer by name", function()
      -- テスト用のバッファを作成
      vim.cmd("enew")
      local test_buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_name(test_buf, "test_buffer_name")
      
      -- バッファを検索
      local found_buf = ui_list.find_buffer_by_name("test_buffer_name")
      assert.equals(test_buf, found_buf)
      
      -- クリーンアップ
      vim.api.nvim_buf_delete(test_buf, {force = true})
    end)
    
    it("should return nil for non-existing buffer", function()
      local found_buf = ui_list.find_buffer_by_name("non_existing_buffer")
      assert.is_nil(found_buf)
    end)
  end)
  
  describe("create_grid_layout", function()
    it("should create window grid", function()
      ui_list.show()
      
      -- 2x2のグリッドを作成
      local windows = ui_list.create_grid_layout(2, 2)
      
      -- 4つのウィンドウが作成されたことを確認
      assert.equals(4, #windows)
      
      -- 全てのウィンドウが有効であることを確認
      for _, win in ipairs(windows) do
        assert.is_true(vim.api.nvim_win_is_valid(win))
      end
      
      ui_list.hide()
    end)
  end)
  
  describe("instance name extraction", function()
    it("should get current instance name from buffer", function()
      -- インスタンスを追加
      state.add_instance({ name = "claude1", options = "" })
      state.add_instance({ name = "claude2", options = "" })
      
      -- バッファ名をモック
      local original_get_name = vim.api.nvim_buf_get_name
      vim.api.nvim_buf_get_name = function(buf)
        return "claude2"
      end
      
      local name = ui_list.get_current_instance_name()
      assert.equals("claude2", name)
      
      -- 元に戻す
      vim.api.nvim_buf_get_name = original_get_name
    end)
  end)
  
  describe("add_instance", function()
    it("should add new instance with auto-numbered name", function()
      -- システム関数をモック
      local original_create_session = tmux.create_claude_session
      local original_refresh = ui_list.refresh
      
      local created_session = nil
      tmux.create_claude_session = function(name, options)
        created_session = { name = name, options = options }
        return true
      end
      
      ui_list.refresh = function() end
      
      -- インスタンスを追加
      ui_list.add_instance()
      
      -- 確認
      assert.equals(1, state.get_instance_count())
      local instances = state.get_instances()
      assert.equals("claude1", instances[1].name)
      assert.equals("", instances[1].options)
      
      assert.is_not_nil(created_session)
      assert.equals("claude1", created_session.name)
      assert.equals("", created_session.options)
      
      -- 元に戻す
      tmux.create_claude_session = original_create_session
      ui_list.refresh = original_refresh
    end)
  end)
  
  describe("active instance management", function()
    it("should set and get active instance", function()
      -- アクティブインスタンスを設定
      ui_list.set_active_instance("claude1")
      assert.equals("claude1", ui_list.active_instance)
      
      -- 別のインスタンスに変更
      ui_list.set_active_instance("claude2")
      assert.equals("claude2", ui_list.active_instance)
    end)
    
    it("should return nil job_id when no active instance", function()
      ui_list.active_instance = nil
      local job_id = ui_list.get_active_job_id()
      assert.is_nil(job_id)
    end)
  end)
end)
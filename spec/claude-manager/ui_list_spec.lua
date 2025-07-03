---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-manager.ui_list", function()
  local ui_list
  local original_tab
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-manager.ui_list"] = nil
    package.loaded["claude-manager.tmux"] = nil
    ui_list = require("claude-manager.ui_list")
    
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
    it("should show list view in new tab", function()
      local initial_tab_count = vim.fn.tabpagenr("$")
      
      ui_list.show()
      
      -- 新しいタブが作成されたことを確認
      assert.equals(initial_tab_count + 1, vim.fn.tabpagenr("$"))
      assert.is_true(ui_list.is_open())
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
end)
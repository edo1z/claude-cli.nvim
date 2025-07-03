---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-manager.option_selector", function()
  local option_selector
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-manager.option_selector"] = nil
    option_selector = require("claude-manager.option_selector")
  end)
  
  describe("options data", function()
    it("should have correct options", function()
      local options = option_selector.options
      
      assert.equals(5, #options)
      
      -- 各オプションの確認
      assert.equals("n", options[1].key)
      assert.equals("", options[1].value)
      
      assert.equals("c", options[2].key)
      assert.equals("-c", options[2].value)
      
      assert.equals("C", options[3].key)
      assert.equals("-c --dangerously-skip-permissions", options[3].value)
      
      assert.equals("d", options[4].key)
      assert.equals("--dangerously-skip-permissions", options[4].value)
      
      assert.equals("D", options[5].key)
      assert.equals("-c --dangerously-skip-permissions", options[5].value)
    end)
  end)
  
  describe("select_options", function()
    it("should call callback with selected option", function()
      -- vim.ui.selectをモック
      local original_select = vim.ui.select
      local selected_value = nil
      
      vim.ui.select = function(items, opts, on_choice)
        -- 2番目のオプション（-c）を選択
        on_choice(items[2], 2)
      end
      
      option_selector.select_options(function(value)
        selected_value = value
      end)
      
      assert.equals("-c", selected_value)
      
      -- 元に戻す
      vim.ui.select = original_select
    end)
    
    it("should handle cancellation", function()
      -- vim.ui.selectをモック
      local original_select = vim.ui.select
      local selected_value = "not_called"
      
      vim.ui.select = function(items, opts, on_choice)
        -- キャンセル
        on_choice(nil, nil)
      end
      
      option_selector.select_options(function(value)
        selected_value = value
      end)
      
      assert.is_nil(selected_value)
      
      -- 元に戻す
      vim.ui.select = original_select
    end)
  end)
  
  describe("select_by_key", function()
    it("should create floating window", function()
      local callback_called = false
      local callback_value = nil
      
      -- 現在のウィンドウ数を記録
      local initial_win_count = #vim.api.nvim_list_wins()
      
      option_selector.select_by_key(function(value)
        callback_called = true
        callback_value = value
      end)
      
      -- フローティングウィンドウが作成されたことを確認
      assert.equals(initial_win_count + 1, #vim.api.nvim_list_wins())
      
      -- ウィンドウを閉じる
      local wins = vim.api.nvim_list_wins()
      local float_win = wins[#wins]
      vim.api.nvim_win_close(float_win, true)
      
      -- コールバックが呼ばれたことを確認
      assert.is_true(callback_called)
    end)
  end)
end)
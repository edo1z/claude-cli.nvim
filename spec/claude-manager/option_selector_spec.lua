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
      
      assert.equals(4, #options)
      
      -- 各オプションの確認
      assert.equals("c", options[1].key)
      assert.equals("", options[1].value)
      assert.matches("Create new session", options[1].desc)
      
      assert.equals("C", options[2].key)
      assert.equals("-c", options[2].value)
      assert.matches("Continue", options[2].desc)
      
      assert.equals("d", options[3].key)
      assert.equals("--dangerously-skip-permissions", options[3].value)
      assert.matches("Dangerous", options[3].desc)
      
      assert.equals("D", options[4].key)
      assert.equals("-c --dangerously-skip-permissions", options[4].value)
      assert.matches("Continue.*Dangerous", options[4].desc)
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
      -- 現在のウィンドウ数を記録
      local initial_win_count = #vim.api.nvim_list_wins()
      
      -- select_by_keyを呼び出す
      option_selector.select_by_key(function(value)
        -- このテストではコールバックのテストは行わない
      end)
      
      -- フローティングウィンドウが作成されたことを確認
      local current_win_count = #vim.api.nvim_list_wins()
      assert.is_true(current_win_count > initial_win_count)
      
      -- 新しく作成されたウィンドウを取得して確認
      local wins = vim.api.nvim_list_wins()
      local float_win = nil
      for _, win in ipairs(wins) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= "" then  -- フローティングウィンドウの場合
          float_win = win
          break
        end
      end
      
      assert.is_not_nil(float_win)
      
      -- フローティングウィンドウが存在することを確認
      assert.is_true(vim.api.nvim_win_is_valid(float_win))
      
      -- ウィンドウを閉じる
      vim.api.nvim_win_close(float_win, true)
    end)
  end)
end)
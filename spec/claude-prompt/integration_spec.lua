---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-prompt integration with manager", function()
  local claude_prompt
  local claude_cli
  local manager
  
  before_each(function()
    -- モジュールをリロード
    package.loaded["claude-prompt"] = nil
    package.loaded["claude-cli"] = nil
    package.loaded["claude-manager"] = nil
    package.loaded["claude-manager.state"] = nil
    package.loaded["claude-manager.ui_list"] = nil
    
    claude_prompt = require("claude-prompt")
    claude_cli = require("claude-cli")
    manager = require("claude-manager")
    
    -- セットアップ
    claude_prompt.setup()
    claude_cli.setup()
    manager.setup()
  end)
  
  describe("window sizing", function()
    it("should create prompt window with appropriate width", function()
      claude_prompt.show_prompt()
      
      local prompt_win = claude_prompt.state.prompt_win
      assert.is_not_nil(prompt_win)
      assert.is_true(vim.api.nvim_win_is_valid(prompt_win))
      
      -- ウィンドウ幅を確認（50%以下であるべき）
      local win_config = vim.api.nvim_win_get_config(prompt_win)
      local expected_width = math.floor(vim.o.columns * 0.5)
      assert.is_true(win_config.width <= expected_width + 5) -- 少し余裕を持たせる
      
      claude_prompt.hide_prompt()
    end)
  end)
  
  describe("send_to_claude with manager", function()
    it("should prioritize manager active instance", function()
      -- マネージャーでインスタンスを追加
      manager.add_instance("test-claude", "")
      
      -- マネージャーのアクティブインスタンスを設定
      manager.ui_list.set_active_instance("test-claude")
      
      -- send_to_claudeをモック
      local original_chansend = vim.fn.chansend
      local sent_data = nil
      local sent_job_id = nil
      local deferred_callbacks = {}
      
      -- defer_fnをモック
      local original_defer_fn = vim.defer_fn
      vim.defer_fn = function(callback, delay)
        table.insert(deferred_callbacks, {callback = callback, delay = delay})
      end
      
      vim.fn.chansend = function(job_id, data)
        sent_job_id = job_id
        sent_data = data
        return 1
      end
      
      -- ウィンドウが有効であることをモック
      local original_nvim_win_is_valid = vim.api.nvim_win_is_valid
      vim.api.nvim_win_is_valid = function(win)
        return true
      end
      
      -- set_current_winをモック
      local original_set_current_win = vim.api.nvim_set_current_win
      vim.api.nvim_set_current_win = function() end
      
      -- スクロール関連のAPIをモック
      local original_nvim_win_get_buf = vim.api.nvim_win_get_buf
      vim.api.nvim_win_get_buf = function() return 1 end
      
      local original_nvim_buf_line_count = vim.api.nvim_buf_line_count
      vim.api.nvim_buf_line_count = function() return 100 end
      
      local original_nvim_win_set_cursor = vim.api.nvim_win_set_cursor
      vim.api.nvim_win_set_cursor = function() end
      
      -- vim.cmdをモック
      local original_cmd = vim.cmd
      vim.cmd = function() end
      
      -- プロンプトにテキストを追加
      claude_prompt.add_text("Test message")
      
      -- get_active_job_idをモック
      local original_get_active = manager.get_active_job_id
      manager.get_active_job_id = function()
        return 12345 -- モックのjob ID
      end
      
      -- 送信
      claude_prompt.send_to_claude()
      
      -- deferred callbackを実行
      for _, cb in ipairs(deferred_callbacks) do
        cb.callback()
      end
      
      -- マネージャーのインスタンスに送信されたことを確認
      assert.equals(12345, sent_job_id)
      assert.equals("Test message", vim.trim(sent_data or ""))
      
      -- クリーンアップ
      vim.fn.chansend = original_chansend
      vim.defer_fn = original_defer_fn
      vim.api.nvim_win_is_valid = original_nvim_win_is_valid
      vim.api.nvim_set_current_win = original_set_current_win
      vim.api.nvim_win_get_buf = original_nvim_win_get_buf
      vim.api.nvim_buf_line_count = original_nvim_buf_line_count
      vim.api.nvim_win_set_cursor = original_nvim_win_set_cursor
      vim.cmd = original_cmd
      manager.get_active_job_id = original_get_active
      manager.remove_instance("test-claude")
    end)
    
    it("should fall back to claude-cli when no manager instance", function()
      -- claude-cliのモックjob IDとウィンドウを設定
      claude_cli.state.term_job_id = 67890
      claude_cli.state.term_win = 200
      
      -- マネージャーのアクティブインスタンスがないことを確認
      assert.is_nil(manager.get_active_job_id())
      
      -- send_to_claudeをモック
      local original_chansend = vim.fn.chansend
      local sent_data = nil
      local sent_job_id = nil
      local deferred_callbacks = {}
      
      -- defer_fnをモック
      local original_defer_fn = vim.defer_fn
      vim.defer_fn = function(callback, delay)
        table.insert(deferred_callbacks, {callback = callback, delay = delay})
      end
      
      vim.fn.chansend = function(job_id, data)
        sent_job_id = job_id
        sent_data = data
        return 1
      end
      
      -- ウィンドウが有効であることをモック
      local original_nvim_win_is_valid = vim.api.nvim_win_is_valid
      vim.api.nvim_win_is_valid = function(win)
        return true
      end
      
      -- set_current_winをモック
      local original_set_current_win = vim.api.nvim_set_current_win
      vim.api.nvim_set_current_win = function() end
      
      -- スクロール関連のAPIをモック
      local original_nvim_win_get_buf = vim.api.nvim_win_get_buf
      vim.api.nvim_win_get_buf = function() return 1 end
      
      local original_nvim_buf_line_count = vim.api.nvim_buf_line_count
      vim.api.nvim_buf_line_count = function() return 100 end
      
      local original_nvim_win_set_cursor = vim.api.nvim_win_set_cursor
      vim.api.nvim_win_set_cursor = function() end
      
      -- vim.cmdをモック
      local original_cmd = vim.cmd
      vim.cmd = function() end
      
      -- プロンプトにテキストを追加
      claude_prompt.add_text("Fallback test")
      
      -- 送信
      claude_prompt.send_to_claude()
      
      -- deferred callbackを実行
      for _, cb in ipairs(deferred_callbacks) do
        cb.callback()
      end
      
      -- claude-cliに送信されたことを確認
      assert.equals(67890, sent_job_id)
      assert.equals("Fallback test", vim.trim(sent_data or ""))
      
      -- クリーンアップ
      vim.fn.chansend = original_chansend
      vim.defer_fn = original_defer_fn
      vim.api.nvim_win_is_valid = original_nvim_win_is_valid
      vim.api.nvim_set_current_win = original_set_current_win
      vim.api.nvim_win_get_buf = original_nvim_win_get_buf
      vim.api.nvim_buf_line_count = original_nvim_buf_line_count
      vim.api.nvim_win_set_cursor = original_nvim_win_set_cursor
      vim.cmd = original_cmd
    end)
  end)
end)
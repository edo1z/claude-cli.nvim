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
      
      vim.fn.chansend = function(job_id, data)
        sent_job_id = job_id
        sent_data = data
        return 1
      end
      
      -- プロンプトにテキストを追加
      claude_prompt.add_text("Test message")
      
      -- get_active_job_idをモック
      local original_get_active = manager.get_active_job_id
      manager.get_active_job_id = function()
        return 12345 -- モックのjob ID
      end
      
      -- 送信
      claude_prompt.send_to_claude()
      
      -- マネージャーのインスタンスに送信されたことを確認
      assert.equals(12345, sent_job_id)
      assert.equals("Test message", sent_data)
      
      -- クリーンアップ
      vim.fn.chansend = original_chansend
      manager.get_active_job_id = original_get_active
      manager.remove_instance("test-claude")
    end)
    
    it("should fall back to claude-cli when no manager instance", function()
      -- claude-cliのモックjob IDを設定
      claude_cli.state.term_job_id = 67890
      
      -- マネージャーのアクティブインスタンスがないことを確認
      assert.is_nil(manager.get_active_job_id())
      
      -- send_to_claudeをモック
      local original_chansend = vim.fn.chansend
      local sent_job_id = nil
      
      vim.fn.chansend = function(job_id, data)
        sent_job_id = job_id
        return 1
      end
      
      -- プロンプトにテキストを追加
      claude_prompt.add_text("Fallback test")
      
      -- 送信
      claude_prompt.send_to_claude()
      
      -- claude-cliに送信されたことを確認
      assert.equals(67890, sent_job_id)
      
      -- クリーンアップ
      vim.fn.chansend = original_chansend
    end)
  end)
end)
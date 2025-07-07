---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-prompt send behavior", function()
  local mock = require("luassert.mock")
  local spy = require("luassert.spy")
  local api = vim.api
  local claude_prompt
  local original_defer_fn
  local original_chansend
  local original_cmd
  local deferred_callbacks = {}
  
  before_each(function()
    -- vim.defer_fnをモック
    original_defer_fn = vim.defer_fn
    vim.defer_fn = function(callback, delay)
      table.insert(deferred_callbacks, {callback = callback, delay = delay})
    end
    
    -- vim.fn.chansendをモック
    original_chansend = vim.fn.chansend
    vim.fn.chansend = spy.new(function() end)
    
    -- vim.cmdをモック
    original_cmd = vim.cmd
    vim.cmd = spy.new(function() end)
    
    -- vim.fn.modeをモック
    vim.fn.mode = spy.new(function() return "n" end)
    
    -- スクロール関連のAPIをモック
    api.nvim_win_get_buf = spy.new(function() return 1 end)
    api.nvim_buf_line_count = spy.new(function() return 100 end)
    api.nvim_win_set_cursor = spy.new(function() end)
    
    -- モジュールをリロード
    package.loaded["claude-prompt"] = nil
    claude_prompt = require("claude-prompt")
    
    -- セットアップ
    claude_prompt.setup()
    
    -- マネージャーのモック
    package.loaded["claude-manager"] = {
      get_active_job_id = function() return 12345 end,
      ui_individual = {
        is_open = function() return true end,
        state = {
          window = 100  -- モックウィンドウID
        }
      }
    }
    
    -- claude-cliのモック
    package.loaded["claude-cli"] = {
      state = {
        term_job_id = 67890,
        term_win = 200
      },
      toggle = spy.new(function() end)
    }
    
    -- プロンプトバッファを作成
    claude_prompt.state.prompt_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(claude_prompt.state.prompt_buf, 0, -1, false, {"Test content"})
    
    -- プロンプトウィンドウをモック
    claude_prompt.state.prompt_win = 300
    api.nvim_win_is_valid = spy.new(function(win)
      return win == 100 or win == 200 or win == 300
    end)
    
    api.nvim_set_current_win = spy.new(function() end)
    api.nvim_win_close = spy.new(function() end)
    
    deferred_callbacks = {}
  end)
  
  after_each(function()
    vim.defer_fn = original_defer_fn
    vim.fn.chansend = original_chansend
    vim.cmd = original_cmd
    if claude_prompt.state.prompt_buf and api.nvim_buf_is_valid(claude_prompt.state.prompt_buf) then
      api.nvim_buf_delete(claude_prompt.state.prompt_buf, {force = true})
    end
  end)
  
  local function execute_deferred_callbacks()
    for _, cb in ipairs(deferred_callbacks) do
      cb.callback()
    end
  end
  
  describe("scrolling behavior", function()
    it("should move to terminal window and scroll to bottom before sending", function()
      -- インサートモードで実行
      vim.fn.mode = spy.new(function() return "i" end)
      
      -- 送信を実行
      claude_prompt.send_to_claude()
      
      -- ウィンドウが設定されたことを確認
      assert.spy(api.nvim_set_current_win).was_called_with(100)
      
      -- ターミナルモードに入ることを確認
      assert.spy(vim.cmd).was_called_with('startinsert')
      
      -- deferred callbackを実行
      execute_deferred_callbacks()
      
      -- スクロール処理の確認
      assert.spy(api.nvim_win_get_buf).was_called_with(100)
      assert.spy(api.nvim_buf_line_count).was_called()
      assert.spy(api.nvim_win_set_cursor).was_called_with(100, {100, 0})
      
      -- テキストが送信されたことを確認
      assert.spy(vim.fn.chansend).was_called_with(12345, "Test content")
    end)
    
    it("should handle scrolling with pcall", function()
      -- ノーマルモードで実行
      vim.fn.mode = spy.new(function() return "n" end)
      
      -- 送信を実行
      claude_prompt.send_to_claude()
      
      -- deferred callbackを実行
      execute_deferred_callbacks()
      
      -- スクロール処理がpcallで実行されることを確認
      assert.spy(api.nvim_win_set_cursor).was_called_with(100, {100, 0})
      
      -- テキストが送信されたことを確認
      assert.spy(vim.fn.chansend).was_called_with(12345, "Test content")
    end)
    
    it("should handle terminal mode", function()
      -- ターミナルモードで実行
      vim.fn.mode = spy.new(function() return "t" end)
      
      -- 送信を実行
      claude_prompt.send_to_claude()
      
      -- deferred callbackを実行
      execute_deferred_callbacks()
      
      -- ターミナルモードでもstartinsertが呼ばれることを確認
      assert.spy(vim.cmd).was_called_with('startinsert')
      
      -- テキストが送信されたことを確認
      assert.spy(vim.fn.chansend).was_called_with(12345, "Test content")
    end)
  end)
  
  describe("window validation", function()
    it("should handle invalid window gracefully", function()
      -- ウィンドウを無効にする
      api.nvim_win_is_valid = spy.new(function(win)
        return win == 300  -- プロンプトウィンドウのみ有効
      end)
      
      -- 送信を実行
      claude_prompt.send_to_claude()
      
      -- deferred callbackを実行
      execute_deferred_callbacks()
      
      -- ウィンドウ関連の操作が行われていないことを確認
      assert.spy(api.nvim_set_current_win).was_not_called_with(100)
      
      -- それでもテキストは送信されることを確認
      assert.spy(vim.fn.chansend).was_called_with(12345, "Test content")
    end)
  end)
end)
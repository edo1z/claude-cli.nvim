---@diagnostic disable-next-line: undefined-global
local vim = vim

describe("claude-cli keymap integration", function()
  local mock = require("luassert.mock")
  local spy = require("luassert.spy")
  local claude_cli
  local claude_manager
  local original_keymap_set
  local captured_keymaps = {}
  
  before_each(function()
    -- vim.keymap.setをモック
    original_keymap_set = vim.keymap.set
    vim.keymap.set = function(mode, lhs, rhs, opts)
      captured_keymaps[lhs] = {
        mode = mode,
        rhs = rhs,
        opts = opts
      }
    end
    
    -- モジュールをリロード
    package.loaded["claude-cli"] = nil
    package.loaded["claude-manager"] = nil
    package.loaded["claude-manager.state"] = nil
    package.loaded["claude-manager.tmux"] = nil
    
    claude_cli = require("claude-cli")
    claude_manager = require("claude-manager")
    
    -- マネージャーのモック設定
    claude_manager.add_instance = spy.new(function(name, options)
      return "claude_test_123"
    end)
    claude_manager.open_instance = spy.new(function(session_name) end)
    
    -- tmuxモジュールのモック
    local tmux_mock = {
      create_claude_session = spy.new(function() return true end),
      kill_session = spy.new(function() return true end),
      get_sessions = spy.new(function() return {} end),
    }
    claude_manager.tmux = tmux_mock
    
    -- stateモジュールのモック
    local state_mock = {
      get_instance_count = spy.new(function() return 0 end),
      get_current_pid = spy.new(function() return 12345 end),
      get_next_available_number = spy.new(function() return 1 end),
      add_instance = spy.new(function() end),
      remove_instance = spy.new(function() end),
    }
    claude_manager.state = state_mock
    
    -- セットアップ
    claude_cli.setup()
    claude_manager.setup()
  end)
  
  after_each(function()
    vim.keymap.set = original_keymap_set
    captured_keymaps = {}
  end)
  
  describe("keymaps create manager instances", function()
    it("<leader>cc creates new instance with default options", function()
      local keymap = captured_keymaps["<leader>cc"]
      assert.is_not_nil(keymap)
      assert.equals("n", keymap.mode)
      assert.equals("Claude Code: New session", keymap.opts.desc)
      
      -- キーマップの関数を実行
      keymap.rhs()
      
      -- マネージャーのadd_instanceが正しく呼ばれたか確認
      assert.spy(claude_manager.add_instance).was_called_with(nil, "")
      assert.spy(claude_manager.open_instance).was_called_with("claude_test_123")
    end)
    
    it("<leader>cd creates new instance with dangerous mode", function()
      local keymap = captured_keymaps["<leader>cd"]
      assert.is_not_nil(keymap)
      assert.equals("n", keymap.mode)
      assert.equals("Claude Code: New session (dangerous mode)", keymap.opts.desc)
      
      -- キーマップの関数を実行
      keymap.rhs()
      
      -- マネージャーのadd_instanceが正しく呼ばれたか確認
      assert.spy(claude_manager.add_instance).was_called_with(nil, "--dangerously-skip-permissions")
      assert.spy(claude_manager.open_instance).was_called_with("claude_test_123")
    end)
    
    it("<leader>cC creates new instance with continue option", function()
      local keymap = captured_keymaps["<leader>cC"]
      assert.is_not_nil(keymap)
      assert.equals("n", keymap.mode)
      assert.equals("Claude Code: Continue last session", keymap.opts.desc)
      
      -- キーマップの関数を実行
      keymap.rhs()
      
      -- マネージャーのadd_instanceが正しく呼ばれたか確認
      assert.spy(claude_manager.add_instance).was_called_with(nil, "-c")
      assert.spy(claude_manager.open_instance).was_called_with("claude_test_123")
    end)
    
    it("<leader>cD creates new instance with continue and dangerous mode", function()
      local keymap = captured_keymaps["<leader>cD"]
      assert.is_not_nil(keymap)
      assert.equals("n", keymap.mode)
      assert.equals("Claude Code: Continue last session (dangerous mode)", keymap.opts.desc)
      
      -- キーマップの関数を実行
      keymap.rhs()
      
      -- マネージャーのadd_instanceが正しく呼ばれたか確認
      assert.spy(claude_manager.add_instance).was_called_with(nil, "-c --dangerously-skip-permissions")
      assert.spy(claude_manager.open_instance).was_called_with("claude_test_123")
    end)
  end)
  
  describe("manager keymaps work correctly", function()
    it("<leader>cm toggles the manager list", function()
      local keymap = captured_keymaps["<leader>cm"]
      assert.is_not_nil(keymap)
      assert.equals("n", keymap.mode)
      assert.equals("Claude Manager: Toggle list view", keymap.opts.desc)
    end)
  end)
end)
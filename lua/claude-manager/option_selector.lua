---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

-- 利用可能なオプション
M.options = {
  { key = "n", value = "", desc = "No options (default)" },
  { key = "c", value = "-c", desc = "Continue session" },
  { key = "C", value = "-c --dangerously-skip-permissions", desc = "Continue session (dangerous)" },
  { key = "d", value = "--dangerously-skip-permissions", desc = "Dangerous mode" },
  { key = "D", value = "-c --dangerously-skip-permissions", desc = "Continue + Dangerous" },
}

-- オプション選択ダイアログを表示
---@param callback function(string) 選択されたオプションを受け取るコールバック
function M.select_options(callback)
  -- オプションの表示用リストを作成
  local items = {}
  for _, opt in ipairs(M.options) do
    table.insert(items, string.format("[%s] %s", opt.key, opt.desc))
  end
  
  -- vim.ui.selectを使用して選択
  vim.ui.select(items, {
    prompt = "Select Claude CLI options:",
  }, function(choice, idx)
    if choice and idx then
      callback(M.options[idx].value)
    else
      -- キャンセルされた場合
      callback(nil)
    end
  end)
end

-- キー入力でオプションを選択
---@param callback function(string) 選択されたオプションを受け取るコールバック
function M.select_by_key(callback)
  -- フローティングウィンドウを作成
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- オプション表示用のテキストを作成
  local lines = {
    "Select Claude CLI options:",
    "",
  }
  for _, opt in ipairs(M.options) do
    table.insert(lines, string.format("  [%s] %s", opt.key, opt.desc))
  end
  table.insert(lines, "")
  table.insert(lines, "Press a key to select, or <Esc> to cancel")
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  
  -- ウィンドウサイズを計算
  local width = 50
  local height = #lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- フローティングウィンドウを作成
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })
  
  -- キーマッピングを設定
  local function close_and_select(option_value)
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    callback(option_value)
  end
  
  -- 各オプションのキーマッピング
  for _, opt in ipairs(M.options) do
    vim.keymap.set('n', opt.key, function()
      close_and_select(opt.value)
    end, { buffer = buf, noremap = true, silent = true })
  end
  
  -- Escでキャンセル
  vim.keymap.set('n', '<Esc>', function()
    close_and_select(nil)
  end, { buffer = buf, noremap = true, silent = true })
  
  -- qでもキャンセル
  vim.keymap.set('n', 'q', function()
    close_and_select(nil)
  end, { buffer = buf, noremap = true, silent = true })
end

return M
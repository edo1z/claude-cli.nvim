---@diagnostic disable-next-line: undefined-global
local vim = vim

local M = {}

-- インスタンス情報を格納
-- key: インスタンス名, value: インスタンス情報
M.instances = {}

-- インスタンスを追加
---@param config table { name: string, options: string }
---@return table インスタンス情報
function M.add_instance(config)
  local instance = {
    name = config.name,
    options = config.options or "",
    created_at = os.time(),
  }
  
  M.instances[config.name] = instance
  return instance
end

-- インスタンスを削除
---@param name string インスタンス名
---@return boolean 成功したかどうか
function M.remove_instance(name)
  if M.instances[name] then
    M.instances[name] = nil
    return true
  end
  return false
end

-- インスタンスを取得
---@param name string インスタンス名
---@return table|nil インスタンス情報
function M.get_instance(name)
  return M.instances[name]
end

-- 全インスタンスを取得
---@return table インスタンスのリスト
function M.get_instances()
  local instances = {}
  for _, instance in pairs(M.instances) do
    table.insert(instances, instance)
  end
  
  -- 名前でソート
  table.sort(instances, function(a, b)
    -- claudeN形式の場合は番号でソート
    local num_a = a.name:match("^claude(%d+)$")
    local num_b = b.name:match("^claude(%d+)$")
    
    if num_a and num_b then
      return tonumber(num_a) < tonumber(num_b)
    elseif num_a then
      return true  -- claude番号付きを先に
    elseif num_b then
      return false
    else
      return a.name < b.name  -- その他は名前順
    end
  end)
  
  return instances
end

-- インスタンス数を取得
---@return number インスタンス数
function M.get_instance_count()
  local count = 0
  for _ in pairs(M.instances) do
    count = count + 1
  end
  return count
end

-- 次に使用可能な番号を取得
---@return number 次の番号
function M.get_next_available_number()
  -- 使用中の番号を収集
  local used_numbers = {}
  for name, _ in pairs(M.instances) do
    local num = name:match("^claude(%d+)$")
    if num then
      used_numbers[tonumber(num)] = true
    end
  end
  
  -- 1から順に空いている番号を探す
  for i = 1, 30 do
    if not used_numbers[i] then
      return i
    end
  end
  
  -- 30個まで使用中の場合（通常はここには来ない）
  return 31
end

-- 全インスタンスをクリア
function M.clear_all()
  M.instances = {}
end

return M

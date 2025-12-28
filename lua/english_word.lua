-- lua/wordpicker.lua
local M = {}

-- デフォルト設定
local defaults = {
  path = nil,         -- 英単語ファイルへのパス（必須）
  n = 5,              -- 何行ピックするか
  letter_num = 25,    -- 英単語をこの幅までスペース埋めして揃える
}

local config = vim.deepcopy(defaults)

-- -------------------------
-- 補助：スペース埋め
-- -------------------------
local function space_num(moji)
  local s = ""
  local pad = config.letter_num - vim.fn.strchars(moji)
  if pad < 0 then pad = 0 end
  for _ = 1, pad do
    s = s .. " "
  end
  return moji .. s
end

-- -------------------------
-- 補助：ファイルから n 行ランダム抽出 → 整形して文字列に
-- -------------------------
local function pick_lines(path, n)
  n = n or config.n or 5
  if not path or path == "" then
    return nil, "path が未設定です (setup{ path=... } が必要)"
  end

  local ok, raw = pcall(vim.fn.readfile, path)
  if not ok or type(raw) ~= "table" then
    return nil, ("ファイルを読めません: %s"):format(path)
  end

  -- 最初の空白行までスキップ → 以降で「:」を含む行だけ候補にする
  local started = false
  local candidates = {}

  for _, line in ipairs(raw) do
    if not started then
      if line:match("^%s*$") then
        started = true
      end
    else
      local s = line:gsub("^%s+", ""):gsub("%s+$", "")
      if s ~= "" and s:find(":", 1, true) then
        table.insert(candidates, s)
      end
    end
  end

  if #candidates == 0 then
    return nil, "候補行がありません（空白行の後に `en: ja` 形式の行が必要）"
  end

  -- シャッフル（Fisher–Yates）
  -- NOTE: hrtime で seed を作る（LuaJIT/Neovim では十分実用）
  local seed = vim.uv and vim.uv.hrtime() or vim.loop.hrtime()
  math.randomseed(seed)
  for i = #candidates, 2, -1 do
    local j = math.random(i)
    candidates[i], candidates[j] = candidates[j], candidates[i]
  end

  local take = math.min(n, #candidates)
  local out2 = {}

  for i = 1, take do
    local line = candidates[i]
    local en, ja = line:match("^(.-)%s*:%s*(.-)%s*$")
    if en and ja then
      table.insert(out2, string.format("%s%s", space_num(en), ja))
    end
  end

  return table.concat(out2, "\n")
end

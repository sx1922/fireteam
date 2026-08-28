-- test/smoke_test.lua
-- FIRETEAM 冒烟测试：数据完整性 + 纯函数断言（标准 Lua 5.1 直跑，GMod 全局打桩）。
-- 用法：lua5.1 test/smoke_test.lua <仓库根目录>
-- CI（.github/workflows/ci.yml）与本地均以此为准。

local root = (arg and arg[1] and arg[1]:gsub("[\\/]$", "")) or ".."
local function packPath(pack, file)
    return root .. "/setting_packs/" .. pack .. "/" .. file
end

-- ─────────────────────────────────────
-- GMod 全局打桩（最小集）
-- ─────────────────────────────────────
_G.Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
_G.istable = function(t) return type(t) == "table" end
_G.isstring = function(s) return type(s) == "string" end
math.Clamp = function(n, lo, hi) return math.min(math.max(n, lo), hi) end
math.Round = function(n) return math.floor(n + 0.5) end
table.Copy = function(t)
    if not istable(t) then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = istable(v) and table.Copy(v) or v end
    return out
end

HITGROUP_GENERIC, HITGROUP_HEAD, HITGROUP_CHEST, HITGROUP_STOMACH = 0, 1, 2, 3
HITGROUP_LEFTARM, HITGROUP_RIGHTARM, HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG = 4, 5, 6, 7

local pass, fail = 0, 0
local function ok(cond, msg)
    if cond then pass = pass + 1 else fail = fail + 1; print("[FAIL] " .. msg) end
end

-- ─────────────────────────────────────
-- 1. 设定包数据完整性
-- ─────────────────────────────────────
for _, pack in ipairs({ "coldwar", "_template" }) do
    local factions = dofile(packPath(pack, "factions.lua"))
    ok(istable(factions) and next(factions), pack .. "/factions 可加载且非空")

    local classes = dofile(packPath(pack, "classes.lua"))
    ok(istable(classes) and next(classes), pack .. "/classes 可加载且非空")

    local items = dofile(packPath(pack, "items.lua")).items
    ok(istable(items) and items.bandage, pack .. "/items 含 bandage")

    local vp = dofile(packPath(pack, "voice_presets.lua"))
    ok(istable(vp.channels) and vp.channels["local"] and vp.channels["local"].kind == "local",
        pack .. "/voice_presets 含 local 频道（kind=local）")
    ok(vp.channels.command and vp.channels.command.kind == "command",
        pack .. "/voice_presets command kind")

    local rules = dofile(packPath(pack, "map_rules.lua"))
    -- vitals 覆盖块可选（不声明时走 config 兜底）；声明了则必须是表
    ok(rules.vitals == nil or istable(rules.vitals), pack .. "/map_rules vitals 块类型")
end

-- coldwar 双剧本 PvE 方向
local cwRules = dofile(packPath("coldwar", "map_rules.lua"))
local scenarios = cwRules.rounds.scenarios
ok(cwRules.rounds.default_scenario == "fulda_gap", "coldwar default_scenario")
for _, sid in ipairs({ "fulda_gap", "berlin" }) do
    local pve = scenarios[sid] and scenarios[sid].pve
    ok(istable(pve) and #pve.player_factions > 0 and #pve.ai_factions > 0,
        "coldwar/" .. sid .. " pve 块完整")
    ok(pve.ai_behavior == "advance" or pve.ai_behavior == "defend",
        "coldwar/" .. sid .. " ai_behavior 枚举")
    local pset = {}
    for _, f in ipairs(pve.player_factions) do pset[f] = true end
    for _, f in ipairs(pve.ai_factions) do
        ok(not pset[f], sid .. " 玩家/AI 阵营不重叠")
    end
end

-- ─────────────────────────────────────
-- 2. locale 双语键集一致
-- ─────────────────────────────────────
local en = dofile(root .. "/gamemodes/fireteam/gamemode/locale/en.lua")
local zh = dofile(root .. "/gamemodes/fireteam/gamemode/locale/zh-cn.lua")
local missE, missZ = {}, {}
for k in pairs(en) do if zh[k] == nil then missZ[#missZ + 1] = k end end
for k in pairs(zh) do if en[k] == nil then missE[#missE + 1] = k end end
ok(#missZ == 0, "zh 缺键: " .. table.concat(missZ, ","))
ok(#missE == 0, "en 缺键: " .. table.concat(missE, ","))

-- ─────────────────────────────────────
-- 3. 网格背包纯函数（sh_inventory）
-- ─────────────────────────────────────
Fireteam = {
    Config  = { Register = function() end, Get = function() return nil end },
    Setting = { GetData = function() return nil end },
    Log     = { Info = function() end, Warn = function() end },
}
dofile(root .. "/gamemodes/fireteam/gamemode/modules/inventory/sh_inventory.lua")
local I = Fireteam.Inventory

ok(I.GRID_W == 10 and I.GRID_H == 6, "网格 10x6")
local cells = { { id = "a", x = 2, y = 2, w = 2, h = 1 } }
ok(I.CanPlaceCells(cells, 0, 0, 2, 2) == true, "网格：空位可放")
ok(I.CanPlaceCells(cells, 3, 2, 1, 1) == false, "网格：重叠拒绝")
ok(I.CanPlaceCells(cells, 10, 0, 1, 1) == false, "网格：越界拒绝")
ok(I.CanPlaceCells(cells, 2, 2, 1, 1, 1) == true, "网格：ignoreIndex 自身")
local fx, fy = I.FindFreeSpot(cells, 10, 6)
ok(fx == nil, "网格：满格需求放不下")

-- ─────────────────────────────────────
-- 4. 分部位健康纯函数（sh_vitals）
-- ─────────────────────────────────────
dofile(root .. "/gamemodes/fireteam/gamemode/modules/vitals/sh_vitals.lua")
local V = Fireteam.Vitals

ok(V.HitgroupToPart(HITGROUP_HEAD) == "head", "部位：HEAD→head")
ok(V.HitgroupToPart(HITGROUP_GENERIC) == "thorax", "部位：GENERIC→thorax")
local limbs = V.DefaultLimbs()
ok(V.ApplyPartDamage(limbs, "head", 99) == true, "部位：头打黑致死")
limbs = V.DefaultLimbs()
limbs.r_arm = 0
ok(V.ApplyPartDamage(limbs, "r_arm", 20) == false and limbs.thorax == 65,
    "部位：黑肢伤害转移胸腔")

-- ─────────────────────────────────────
print(string.format("== 冒烟测试: %d 通过, %d 失败 ==", pass, fail))
if fail > 0 then os.exit(1) end

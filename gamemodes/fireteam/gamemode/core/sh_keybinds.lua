-- core/sh_keybinds.lua
-- FIRETEAM Keybind Layer
-- 键位不硬编码物理键码：一律「引擎 hook / 按键钩子 + concommand」，玩家可自由重绑。
--
-- 引擎限制：Garry's Mod 禁止 Lua 调用 bind/unbind（RunConsoleCommand: Command is
-- blocked!），因此 B/C 级默认键位不走 bind 写入，改由客户端 PlayerButtonDown/
-- PlayerButtonUp 钩子直接分发。玩家手动在控制台 bind 到 ft_* 命令仍然有效
-- （concommand 层保留），且优先于钩子默认动作。
--
-- 接管分级（worklog 041 决策）：
--   A 级 引擎 hook 接管 —— 零改玩家配置，玩家重绑对应 bind 后自动跟随
--        ScoreboardShow → 背包（吃掉原版计分板，名单页在背包内）
--        ShowHelp/ShowTeam/ShowSpare1/ShowSpare2 (F1..F4) → 主菜单/小队/职业/指挥视图
--        SpawnMenuOpen / ContextMenuOpen → 禁用（战术模式不造物）
--        PlayerNoClip → 服务端拒绝非管理员
--   B 级 按键钩子强制接管 —— vanilla 行为在本模式下已死（7/8/9/0 武器槽位恒空）；
--        引擎默认 slot7..slot0 bind 仍在（无副作用），如需完全接管可手动
--        bind 7 ft_item_slot1 等
--   C 级 按键钩子空闲键投放 —— m/n/h/CapsLock/g/i；玩家已占用（绑了非 ft 命令）
--        的键自动让位
--   D 级 绝不触碰 —— WASD/Space/Shift/Ctrl/Alt/E/R/F/Y/U/`/Esc/鼠标/vanilla 说话键
--
-- cvar ft_binds_applied 保留用于首次进服提示一次（历史上是 bind 应用标记）。

if not Fireteam then Fireteam = {} end
Fireteam.Keybinds = Fireteam.Keybinds or {}

-- ═══════════════════════════════════════
-- 推荐键位表（B/C 级；A 级不在此表内——它们不占 bind）
-- ═══════════════════════════════════════
Fireteam.Keybinds.DEFAULTS = {
    -- B 级：强制接管（vanilla 功能已死）
    { key = "7", cmd = "ft_item_slot1", tier = "B" },
    { key = "8", cmd = "ft_item_slot2", tier = "B" },
    { key = "9", cmd = "ft_item_slot3", tier = "B" },
    { key = "0", cmd = "ft_item_slot4", tier = "B" },

    -- C 级：空闲键投放
    { key = "m",        cmd = "ft_map",           tier = "C" },
    { key = "n",        cmd = "ft_marker",        tier = "C" },
    { key = "h",        cmd = "ft_hud_squad",     tier = "C" },
    { key = "capslock", cmd = "ft_command",       tier = "C" },
    { key = "g",        cmd = "+ft_voice_squad",  tier = "C" },
    { key = "i",        cmd = "ft_backpack",      tier = "C" },
}

--- D 级保护名单：任何情况下不写入这些键（即便推荐表被第三方改坏）
local PROTECTED = {
    w = true, a = true, s = true, d = true,
    space = true, shift = true, ctrl = true, alt = true,
    e = true, r = true, f = true, y = true, u = true,
    escape = true, ["`"] = true, enter = true,
    mouse1 = true, mouse2 = true, mouse3 = true, mouse4 = true, mouse5 = true,
    mwheelup = true, mwheeldown = true,
}

if CLIENT then

local BACKUP_FILE = "fireteam/binds_backup.txt" -- bind 时代遗留，Restore 时清理

CreateClientConVar("ft_binds_applied", "0", true, false,
    "FIRETEAM 默认键位提示是否已展示过（0 时首次进服提示一次）")

-- ─────────────────────────────────────
-- 键名 → 按键码
-- ─────────────────────────────────────

local KEY_CODES = {}
--- 特殊键兜底：部分键名 input.GetKeyCode 不识别，直接查 KEY_* 全局
local KEY_FALLBACK = {
    capslock = KEY_CAPSLOCK or KEY_CAPSLOCKTOGGLE,
}

local function KeyCodeOf(key)
    local cached = KEY_CODES[key]
    if cached ~= nil then return cached end
    local code = KEY_FALLBACK[string.lower(key)]
    if code == nil and input.GetKeyCode then
        code = input.GetKeyCode(key)
    end
    if code then KEY_CODES[key] = code end
    return code
end

--- 命令 → 默认键名（供 UI 键位提示在玩家未绑定时回退显示）
function Fireteam.Keybinds.DefaultKeyFor(cmd)
    local bare = cmd
    local c1 = string.sub(bare, 1, 1)
    if c1 == "+" or c1 == "-" then bare = string.sub(bare, 2) end
    for _, e in ipairs(Fireteam.Keybinds.DEFAULTS) do
        if e.cmd == cmd or e.cmd == c1 .. bare then return e.key end
    end
    return nil
end

-- ─────────────────────────────────────
-- 应用 / 还原命令（bind 时代遗留接口，现为提示 + 清理）
-- ─────────────────────────────────────

function Fireteam.Keybinds.Apply(silent)
    -- 引擎禁止 Lua 写 bind，默认键位由 PlayerButtonDown 钩子分发，无需写入玩家配置
    for _, e in ipairs(Fireteam.Keybinds.DEFAULTS) do
        if PROTECTED[string.lower(e.key)] then
            Fireteam.Log.Warn("键位", "推荐表包含受保护按键（请修正 DEFAULTS）: " .. e.key)
        end
    end

    RunConsoleCommand("ft_binds_applied", "1")
    if not silent then
        Fireteam.Log.Info("键位", "✓ 默认键位由按键钩子接管 " .. #Fireteam.Keybinds.DEFAULTS
            .. " 项（不修改玩家绑定，可在 GMod 设置 → 键盘 自由改键）")
    end
    return #Fireteam.Keybinds.DEFAULTS
end

function Fireteam.Keybinds.Restore()
    -- 历史遗留：bind 接管时代用于还原被覆盖的原生绑定。
    -- 现在从不写入玩家绑定，无需还原；仅清理旧版备份文件。
    if file.Exists(BACKUP_FILE, "DATA") then
        file.Delete(BACKUP_FILE)
        Fireteam.Log.Info("键位", "已清理旧版键位备份 " .. BACKUP_FILE)
    end
    Fireteam.Log.Info("键位", "默认键位由按键钩子接管，未修改过玩家绑定，无需还原")
    return false
end

--- 当前键位总览（F10 键位页与控制台共用）
function Fireteam.Keybinds.Describe()
    local out = {}
    for _, e in ipairs(Fireteam.Keybinds.DEFAULTS) do
        out[#out + 1] = {
            key      = e.key,
            cmd      = e.cmd,
            tier     = e.tier,
            boundNow = input.LookupBinding(e.cmd) or e.key,
        }
    end
    return out
end

concommand.Add("ft_binds_apply", function() Fireteam.Keybinds.Apply(false) end)
concommand.Add("ft_binds_restore", function() Fireteam.Keybinds.Restore() end)
concommand.Add("ft_binds_list", function()
    Fireteam.Log.Info("键位", "── FIRETEAM 键位 ──")
    for _, e in ipairs(Fireteam.Keybinds.Describe()) do
        Fireteam.Log.Info("键位", string.format("  %-10s %-22s 当前绑定: %s",
            e.cmd, "[" .. e.tier .. "级 推荐 " .. e.key .. "]",
            e.boundNow ~= "" and e.boundNow or "(无)"))
    end
    Fireteam.Log.Info("键位", "F1 主菜单 / F2 小队 / F3 职业 / F4 指挥视图 / Tab 背包"
        .. " 走引擎绑定，重绑后自动跟随")
end)

-- 首次进服提示一次（幂等；ft_binds_applied 已置 1 的玩家不再提示）
hook.Add("InitPostEntity", "Fireteam.Keybinds.FirstRun", function()
    timer.Simple(2, function()
        if GetConVar("ft_binds_applied"):GetInt() == 0 then
            Fireteam.Keybinds.Apply(false)
            chat.AddText(Color(255, 200, 80), "[FIRETEAM] ", color_white,
                "默认键位 m/n/h/CapsLock/g/i 与 7/8/9/0 已生效。如需完全接管 7-0 物品栏，"
                .. "可在控制台输入 bind 7 ft_item_slot1（以此类推）手动绑定。")
        end
    end)
end)

-- ═══════════════════════════════════════
-- 功能命令（全部惰性解析：本文件在 shared.lua 内早于各模块加载）
-- 面板类命令统一走各模块的 Toggle 语义，热键按第二次即关闭。
-- ═══════════════════════════════════════

--- 输入框聚焦时吞掉命令（按键钩子同样遵守此守卫）
local function Guard()
    return not Fireteam.UI or Fireteam.UI.CanTogglePanel()
end

--- 命令注册表：concommand 与按键钩子共用同一份动作体
local ACTIONS = {}

local function Cmd(name, fn)
    ACTIONS[name] = fn
    concommand.Add(name, function()
        if not Guard() then return end
        local ok, err = pcall(fn)
        if not ok then
            Fireteam.Log.Error("键位", "命令 " .. name .. " 执行失败: " .. tostring(err))
        end
    end)
end

Cmd("ft_menu", function()
    if Fireteam.MainMenu and Fireteam.MainMenu.Toggle then Fireteam.MainMenu.Toggle() end
end)
Cmd("ft_squad", function()
    if Fireteam.Squad and Fireteam.Squad.OpenPanel then Fireteam.Squad.OpenPanel() end
end)
Cmd("ft_class", function()
    if Fireteam.Class and Fireteam.Class.OpenSelectPanel then Fireteam.Class.OpenSelectPanel() end
end)
Cmd("ft_map", function()
    if Fireteam.TacMap and Fireteam.TacMap.Toggle then Fireteam.TacMap.Toggle() end
end)
Cmd("ft_command", function()
    if Fireteam.TacMap and Fireteam.TacMap.ToggleCommandView then
        Fireteam.TacMap.ToggleCommandView()
    end
end)
Cmd("ft_backpack", function()
    if Fireteam.Inventory and Fireteam.Inventory.ToggleBackpack then
        Fireteam.Inventory.ToggleBackpack()
    end
end)
Cmd("ft_marker", function()
    if Fireteam.Marker and Fireteam.Marker.PlaceAtCrosshair then
        Fireteam.Marker.PlaceAtCrosshair()
    end
end)
Cmd("ft_hud_squad", function()
    if Fireteam.Squad and Fireteam.Squad.ToggleHUD then Fireteam.Squad.ToggleHUD() end
end)
Cmd("ft_admin", function()
    if Fireteam.Admin and Fireteam.Admin.Toggle then Fireteam.Admin.Toggle() end
end)
Cmd("ft_packeditor", function()
    if Fireteam.PackEditor and Fireteam.PackEditor.Toggle then Fireteam.PackEditor.Toggle() end
end)

for slot = 1, 4 do
    Cmd("ft_item_slot" .. slot, function()
        if Fireteam.Inventory and Fireteam.Inventory.UseHotbar then
            Fireteam.Inventory.UseHotbar(slot)
        end
    end)
end

-- 按住说话（Squad 式）：+ 切频道并代发 +voicerecord，- 停止并回退
local VOICE_KINDS = { "local", "squad", "command" }
for _, kind in ipairs(VOICE_KINDS) do
    concommand.Add("+ft_voice_" .. kind, function()
        if Fireteam.Voice and Fireteam.Voice.BeginTalk then Fireteam.Voice.BeginTalk(kind) end
    end)
    concommand.Add("-ft_voice_" .. kind, function()
        if Fireteam.Voice and Fireteam.Voice.EndTalk then Fireteam.Voice.EndTalk(kind) end
    end)
end

-- ═══════════════════════════════════════
-- A 级：引擎面板 hook 接管（玩家重绑对应 bind 后自动跟随）
-- ═══════════════════════════════════════

-- Tab（+showscores）→ 背包；名单页在背包面板内，替代原版计分板
hook.Add("ScoreboardShow", "Fireteam.Keybinds.Scoreboard", function()
    if Fireteam.Inventory and Fireteam.Inventory.ToggleBackpack then
        Fireteam.Inventory.ToggleBackpack()
    end
    return false
end)

hook.Add("ShowHelp", "Fireteam.Keybinds.ShowHelp", function()
    if Fireteam.MainMenu and Fireteam.MainMenu.Toggle then Fireteam.MainMenu.Toggle() end
    return false
end)

hook.Add("ShowTeam", "Fireteam.Keybinds.ShowTeam", function()
    if Fireteam.Squad and Fireteam.Squad.OpenPanel then Fireteam.Squad.OpenPanel() end
    return false
end)

hook.Add("ShowSpare1", "Fireteam.Keybinds.ShowSpare1", function()
    if Fireteam.Class and Fireteam.Class.OpenSelectPanel then Fireteam.Class.OpenSelectPanel() end
    return false
end)

hook.Add("ShowSpare2", "Fireteam.Keybinds.ShowSpare2", function()
    if Fireteam.TacMap and Fireteam.TacMap.ToggleCommandView then
        Fireteam.TacMap.ToggleCommandView()
    end
    return false
end)

-- ═══════════════════════════════════════
-- B/C 级：PlayerButtonDown 钩子分发（引擎禁止 Lua 写 bind，改用按键钩子）
-- ═══════════════════════════════════════

--- 是否允许钩子分发默认动作（否则交给玩家自己的 bind / 让位）
local function ShouldDispatch(e)
    local code = KeyCodeOf(e.key)
    if not code then return true end -- 键名映射失败时兜底分发
    local bound = input.LookupKeyBinding(code)
    if not bound or bound == "" then return true end

    -- 玩家已有绑定：剥离 +/- 前缀后判断归属
    local cmd = bound
    local c1 = string.sub(cmd, 1, 1)
    if c1 == "+" or c1 == "-" then cmd = string.sub(cmd, 2) end

    if string.find(cmd, "^ft_") then
        return false -- 绑的是 FIRETEAM 命令：交给玩家 bind 执行，避免双触发
    end
    if e.tier == "C" then
        return false -- C 级空闲键：尊重玩家占用，让位
    end
    return true -- B 级：vanilla 槽位在本模式已死，强制接管
end

--- 执行动作体（与 concommand 同源；语音键需要按下/松开两态）
local function RunAction(cmd, pressed)
    if string.sub(cmd, 1, 1) == "+" then
        local kind = string.match(cmd, "^%+ft_voice_(%w+)$")
        if kind and Fireteam.Voice then
            if pressed and Fireteam.Voice.BeginTalk then
                Fireteam.Voice.BeginTalk(kind)
            elseif not pressed and Fireteam.Voice.EndTalk then
                Fireteam.Voice.EndTalk(kind)
            end
        end
        return
    end

    local fn = ACTIONS[cmd]
    if not fn then return end
    if not Guard() then return end
    local ok, err = pcall(fn)
    if not ok then
        Fireteam.Log.Error("键位", "热键 " .. cmd .. " 执行失败: " .. tostring(err))
    end
end

hook.Add("PlayerButtonDown", "Fireteam.Keybinds.HotkeyDown", function(ply, button)
    if ply ~= LocalPlayer() then return end
    for _, e in ipairs(Fireteam.Keybinds.DEFAULTS) do
        if KeyCodeOf(e.key) == button then
            if ShouldDispatch(e) then
                RunAction(e.cmd, true)
            end
            return
        end
    end
end)

hook.Add("PlayerButtonUp", "Fireteam.Keybinds.HotkeyUp", function(ply, button)
    if ply ~= LocalPlayer() then return end
    for _, e in ipairs(Fireteam.Keybinds.DEFAULTS) do
        if KeyCodeOf(e.key) == button then
            if string.sub(e.cmd, 1, 1) == "+" then
                RunAction(e.cmd, false)
            end
            return
        end
    end
end)

end -- CLIENT

-- ═══════════════════════════════════════
-- A 级：沙盒功能禁用（战术模式不造物 / 不穿墙）
-- ═══════════════════════════════════════
hook.Add("SpawnMenuOpen", "Fireteam.Keybinds.BlockSpawnMenu", function()
    return false
end)

hook.Add("ContextMenuOpen", "Fireteam.Keybinds.BlockContextMenu", function()
    return false
end)

if SERVER then
    hook.Add("PlayerNoClip", "Fireteam.Keybinds.BlockNoClip", function(ply)
        if IsValid(ply) and ply:IsAdmin() then return end
        return false
    end)
end

Fireteam.Log.Info("键位", "✓ 键位层已加载")

-- core/sh_keybinds.lua
-- FIRETEAM Keybind Layer
-- 键位不硬编码物理键码：一律「引擎 hook + concommand」，玩家可自由重绑。
--
-- 接管分级（worklog 041 决策）：
--   A 级 引擎 hook 接管 —— 零改玩家配置，玩家重绑对应 bind 后自动跟随
--        ScoreboardShow → 背包（吃掉原版计分板，名单页在背包内）
--        ShowHelp/ShowTeam/ShowSpare1/ShowSpare2 (F1..F4) → 主菜单/小队/职业/指挥视图
--        SpawnMenuOpen / ContextMenuOpen → 禁用（战术模式不造物）
--        PlayerNoClip → 服务端拒绝非管理员
--   B 级 强制 bind 接管 —— vanilla 行为在本模式下已死（7/8/9/0 武器槽位恒空）
--   C 级 空闲键投放 —— m/n/h/CapsLock/g/i
--   D 级 绝不触碰 —— WASD/Space/Shift/Ctrl/Alt/E/R/F/Y/U/`/Esc/鼠标/vanilla 说话键
--
-- ft_binds_apply 会先把被覆盖键的原绑定备份到 data/fireteam/binds_backup.txt，
-- ft_binds_restore 可完整还原。cvar ft_binds_applied 保证只自动应用一次。

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

local BACKUP_DIR  = "fireteam"
local BACKUP_FILE = "fireteam/binds_backup.txt"

CreateClientConVar("ft_binds_applied", "0", true, false,
    "FIRETEAM 推荐键位是否已应用过（0 时首次进服自动应用一次）")

-- ─────────────────────────────────────
-- 备份 / 还原
-- ─────────────────────────────────────

--- 读取某键当前绑定的命令；未绑定返回 ""
local function CurrentBind(key)
    local code = input.GetKeyCode and input.GetKeyCode(key) or nil
    if not code then return "" end
    local bound = input.LookupKeyBinding(code)
    return bound or ""
end

local function ReadBackup()
    if not file.Exists(BACKUP_FILE, "DATA") then return nil end
    local raw = file.Read(BACKUP_FILE, "DATA")
    if not raw or raw == "" then return nil end
    local out = {}
    for line in string.gmatch(raw, "[^\r\n]+") do
        local key, cmd = string.match(line, "^([^\t]+)\t(.*)$")
        if key then out[#out + 1] = { key = key, cmd = cmd } end
    end
    return out
end

--- 首次覆盖前把原绑定落盘（已存在备份则不覆盖，避免二次应用把 FIRETEAM 命令写进备份）
local function WriteBackupOnce(entries)
    if file.Exists(BACKUP_FILE, "DATA") then return false end
    if not file.IsDir(BACKUP_DIR, "DATA") then file.CreateDir(BACKUP_DIR) end

    local lines = {}
    for _, e in ipairs(entries) do
        lines[#lines + 1] = e.key .. "\t" .. CurrentBind(e.key)
    end
    file.Write(BACKUP_FILE, table.concat(lines, "\n"))
    return true
end

-- ─────────────────────────────────────
-- 应用 / 还原命令
-- ─────────────────────────────────────

function Fireteam.Keybinds.Apply(silent)
    local plan = {}
    for _, e in ipairs(Fireteam.Keybinds.DEFAULTS) do
        if PROTECTED[string.lower(e.key)] then
            Fireteam.Log.Warn("键位", "跳过受保护按键: " .. e.key)
        else
            plan[#plan + 1] = e
        end
    end

    local backedUp = WriteBackupOnce(plan)

    for _, e in ipairs(plan) do
        local before = CurrentBind(e.key)
        RunConsoleCommand("bind", e.key, e.cmd)
        if not silent then
            local from = (before ~= "" and before) or "(未绑定)"
            Fireteam.Log.Info("键位", string.format("%s: %s → %s [%s级]",
                e.key, from, e.cmd, e.tier))
        end
    end

    RunConsoleCommand("ft_binds_applied", "1")
    if not silent then
        Fireteam.Log.Info("键位", "✓ 已应用推荐键位 " .. #plan .. " 项"
            .. (backedUp and "（原绑定已备份，ft_binds_restore 可还原）" or ""))
    end
    return #plan
end

function Fireteam.Keybinds.Restore()
    local entries = ReadBackup()
    if not entries then
        Fireteam.Log.Warn("键位", "没有可还原的备份（尚未应用过推荐键位）")
        return false
    end

    for _, e in ipairs(entries) do
        if e.cmd ~= "" then
            RunConsoleCommand("bind", e.key, e.cmd)
            Fireteam.Log.Info("键位", "还原 " .. e.key .. " → " .. e.cmd)
        else
            RunConsoleCommand("unbind", e.key)
            Fireteam.Log.Info("键位", "解绑 " .. e.key .. "（原本未绑定）")
        end
    end

    file.Delete(BACKUP_FILE)
    RunConsoleCommand("ft_binds_applied", "0")
    Fireteam.Log.Info("键位", "✓ 已还原原始键位 " .. #entries .. " 项")
    return true
end

--- 当前键位总览（F10 键位页与控制台共用）
function Fireteam.Keybinds.Describe()
    local out = {}
    for _, e in ipairs(Fireteam.Keybinds.DEFAULTS) do
        out[#out + 1] = {
            key      = e.key,
            cmd      = e.cmd,
            tier     = e.tier,
            boundNow = input.LookupBinding(e.cmd) or "",
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

-- 首次进服自动应用一次（幂等；玩家 ft_binds_restore 后不会再自动应用）
hook.Add("InitPostEntity", "Fireteam.Keybinds.FirstRun", function()
    timer.Simple(2, function()
        if GetConVar("ft_binds_applied"):GetInt() == 0 then
            Fireteam.Keybinds.Apply(false)
        end
    end)
end)

-- ═══════════════════════════════════════
-- 功能命令（全部惰性解析：本文件在 shared.lua 内早于各模块加载）
-- 面板类命令统一走各模块的 Toggle 语义，热键按第二次即关闭。
-- ═══════════════════════════════════════

--- 输入框聚焦时吞掉命令（bind 在文本框聚焦时通常不触发，此处为双保险）
local function Guard()
    return not Fireteam.UI or Fireteam.UI.CanTogglePanel()
end

local function Cmd(name, fn)
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
end)

hook.Add("ShowTeam", "Fireteam.Keybinds.ShowTeam", function()
    if Fireteam.Squad and Fireteam.Squad.OpenPanel then Fireteam.Squad.OpenPanel() end
end)

hook.Add("ShowSpare1", "Fireteam.Keybinds.ShowSpare1", function()
    if Fireteam.Class and Fireteam.Class.OpenSelectPanel then Fireteam.Class.OpenSelectPanel() end
end)

hook.Add("ShowSpare2", "Fireteam.Keybinds.ShowSpare2", function()
    if Fireteam.TacMap and Fireteam.TacMap.ToggleCommandView then
        Fireteam.TacMap.ToggleCommandView()
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

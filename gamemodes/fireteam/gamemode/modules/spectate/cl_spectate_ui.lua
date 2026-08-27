-- modules/spectate/cl_spectate_ui.lua
-- FIRETEAM Observer Mode - Client HUD
-- 观战覆盖层（目标名/视角模式/操作提示）；左键换目标、右键切视角。

local kit = Fireteam.UI
local L = function(key, ...)
    return Fireteam.Locale and Fireteam.Locale.Get(key, ...) or key
end

-- OBS_MODE_* 枚举在个别环境下就绪较晚（曾触发 table index is nil），
-- 改为首次使用时惰性构建，且逐项守卫缺枚举的场景
local MODE_LABEL
local function ModeLabel(mode)
    MODE_LABEL = MODE_LABEL or {}
    if next(MODE_LABEL) == nil then
        if OBS_MODE_IN_EYE then MODE_LABEL[OBS_MODE_IN_EYE] = "spec_mode_eye" end
        if OBS_MODE_CHASE then MODE_LABEL[OBS_MODE_CHASE] = "spec_mode_chase" end
        if OBS_MODE_ROAM then MODE_LABEL[OBS_MODE_ROAM] = "spec_mode_roam" end
    end
    return MODE_LABEL[mode]
end

-- ═══════════════════════════════════════
-- 覆盖层
-- ═══════════════════════════════════════
hook.Add("HUDPaint", "Fireteam.Spectate.Overlay", function()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    if me:Alive() or me:GetObserverMode() == OBS_MODE_NONE then return end
    if not Fireteam.Config.Get("spectate.enabled") then return end

    local scale = ScrH() / 1080
    local w = math.Round(340 * scale)
    local h = math.Round(84 * scale)
    local x = ScrW() / 2 - w / 2
    local y = ScrH() - h - math.Round(48 * scale)

    kit.DrawPanel(x, y, w, h, { fillAlpha = 200 })

    -- 标题：观战中
    draw.SimpleText(L("spec_overlay"), kit.Font("medium"),
        x + w / 2, y + 18 * scale,
        kit.Color("warning"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- 目标名 + 视角模式
    local target = me:GetObserverTarget()
    local name = IsValid(target) and target:Nick() or "—"
    local modeKey = ModeLabel(me:GetObserverMode())

    draw.SimpleText(L("spec_target", name), kit.Font("body"),
        x + w / 2, y + 42 * scale,
        kit.Color("text"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if modeKey then
        draw.SimpleText(L(modeKey), kit.Font("small"),
            x + w / 2, y + 62 * scale,
            kit.Color("primary"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- 操作提示（底部细条）
    draw.SimpleText(L("spec_hint"), kit.Font("small"),
        x + w / 2, y + h - 10 * scale,
        kit.Color("text_muted"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- 屏幕边缘暗角强化"旁观感"（复用 UI Kit 程序化暗角）
    kit.DrawVignette(0.35)
end)

-- ═══════════════════════════════════════
-- 输入：鼠标键控制（仅观战状态生效）
-- ═══════════════════════════════════════
hook.Add("PlayerButtonDown", "Fireteam.Spectate.Input", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if not Fireteam.Config.Get("spectate.enabled") then return end
    if not Fireteam.UI.CanTogglePanel() then return end
    if ply:Alive() or ply:GetObserverMode() == OBS_MODE_NONE then return end

    if button == MOUSE_LEFT then
        Fireteam.Net.SendToServer(Fireteam.NET.SPECTATE_CONTROL, "next")
    elseif button == MOUSE_RIGHT then
        Fireteam.Net.SendToServer(Fireteam.NET.SPECTATE_CONTROL, "mode")
    elseif button == MOUSE_MIDDLE then
        Fireteam.Net.SendToServer(Fireteam.NET.SPECTATE_CONTROL, "prev")
    end
end)

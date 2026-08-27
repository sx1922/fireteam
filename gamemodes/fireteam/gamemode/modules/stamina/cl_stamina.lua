-- modules/stamina/cl_stamina.lua
-- FIRETEAM Stamina System - Client
-- 底部体力条（并入体征快照的 stam/stamMax 字段）+ 力竭开火视角抖动。

if not Fireteam then Fireteam = {} end
Fireteam.Stamina = Fireteam.Stamina or {}

local kit = Fireteam.UI

--- 本地玩家体力条目 { value, max } 或 nil
function Fireteam.Stamina.GetSelf()
    local lp = LocalPlayer()
    if not IsValid(lp) then return nil end
    local entry = Fireteam.Vitals and Fireteam.Vitals.Client and Fireteam.Vitals.Client[lp:EntIndex()]
    if not (istable(entry) and entry.stamMax and entry.stamMax > 0) then return nil end
    return { value = tonumber(entry.stam) or 0, max = tonumber(entry.stamMax) or 100 }
end

-- ─────────────────────────────────────
-- HUD：底部居中细条，满值隐藏；力竭转警告色
-- ─────────────────────────────────────
hook.Add("HUDPaint", "Fireteam.Stamina.HUD", function()
    if Fireteam.Config.Get("stamina.enabled") == false then return end
    local self_ = Fireteam.Stamina.GetSelf()
    if not self_ or self_.value >= self_.max - 0.5 then return end

    local elem = kit.GetElement("stamina")
    local bw = math.Round(300 * (ScrW() / 1920))
    local x, y = kit.ResolveAnchor(elem.position or "bottom_center", bw, 7)
    y = y - 40   -- 抬升避开消耗品芯片行

    local exhausted = self_.value / self_.max
        <= (tonumber(Fireteam.Config.Get("stamina.exhausted_frac")) or 0.15)
    kit.DrawProgressBar(x, y, bw, 7, self_.value / math.max(self_.max, 1),
        exhausted and "warning" or "primary")
end)

-- ─────────────────────────────────────
-- 力竭开火视角抖动（仅视觉；不改动弹道）
-- ─────────────────────────────────────
hook.Add("CalcView", "Fireteam.Stamina.LowStaminaKick", function(lp, origin, angles, fov)
    if Fireteam.Config.Get("stamina.enabled") == false then return end
    if not IsValid(lp) or not lp:Alive() then return end
    if not lp:KeyDown(IN_ATTACK) then return end

    local self_ = Fireteam.Stamina.GetSelf()
    if not self_ then return end
    local frac = self_.value / math.max(self_.max, 1)
    if frac > 0.35 then return end

    -- 体力越低抖得越明显（上限 ±0.5°）
    local amp = 0.5 * (1 - frac / 0.35)
    local view = {}
    view.origin   = origin
    view.angles   = angles + Angle((math.random() - 0.5) * amp,
                                   (math.random() - 0.5) * amp, 0)
    view.fov      = fov
    view.drawviewer = true
    return view
end)

Fireteam.Log.Info("Stamina", "✓ 客户端 HUD 已加载")

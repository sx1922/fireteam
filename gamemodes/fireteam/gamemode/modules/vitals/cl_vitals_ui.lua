-- modules/vitals/cl_vitals_ui.lua
-- FIRETEAM Vitals HUD
-- 倒地全屏遮罩（计时/稳定/被救读条）、出血警示、倒地队友距离列表、救援读条。
-- 全部经 Fireteam.UI 语义取色，无硬编码颜色。

if not Fireteam then Fireteam = {} end
Fireteam.Vitals = Fireteam.Vitals or {}

local kit = Fireteam.UI

hook.Add("HUDPaint", "Fireteam.Vitals.HUD", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local self_ = Fireteam.Vitals.GetSelf()

    -- ═══ 自身倒地遮罩 ═══
    if IsValid(lp) and lp:Alive() and self_ and self_.state == "downed" then
        kit.DrawVignette(0.85)

        local sw, sh = ScrW(), ScrH()
        local panelW, panelH = math.Round(420 * (sw / 1920)), math.Round(120 * (sh / 1080))
        local x, y = sw / 2 - panelW / 2, sh * 0.68

        kit.DrawPanel(x, y, panelW, panelH, { fillAlpha = 200 })

        draw.SimpleText(Fireteam.Locale.Get("vitals_downed_self"),
            kit.Font("large"), x + panelW / 2, y + 26,
            kit.Color("danger"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- 失血过世倒计时（稳定后重置满）
        local remain = Fireteam.Vitals.SelfRemain()
        if remain then
            local total = tonumber(Fireteam.Vitals.GetParam("bleedout_time")) or 60
            kit.DrawProgressBar(x + panelW * 0.15, y + 62,
                panelW * 0.7, 8, remain / math.max(total, 1), "warning")
            draw.SimpleText(string.format("%ds", math.ceil(remain)),
                kit.Font("body"), x + panelW / 2, y + 88,
                kit.ColorA("warning", 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        if self_.stabilized then
            draw.SimpleText(Fireteam.Locale.Get("vitals_stabilized_tag"),
                kit.Font("small"), x + panelW / 2, y + panelH - 12,
                kit.Color("success"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- 被救援读条
        for _, entry in pairs(Fireteam.Vitals.Client) do
            if entry.reviving and entry.reviving.tgtIdx == lp:EntIndex() then
                local total2 = tonumber(entry.reviving.kind == "revive"
                    and Fireteam.Vitals.GetParam("revive_time")
                    or Fireteam.Vitals.GetParam("stabilize_time")) or 3
                local frac = 1 - math.Clamp((entry.reviving.ends - CurTime()) / math.max(total2, 0.1), 0, 1)
                kit.DrawProgressBar(sw / 2 - panelW * 0.3, y - 24,
                    panelW * 0.6, 10, frac, "success")
                draw.SimpleText(Fireteam.Locale.Get("vitals_being_revived"),
                    kit.Font("small"), sw / 2, y - 32,
                    kit.Color("success"), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            end
        end
    end

    -- ═══ 出血警示（正常状态）═══
    if IsValid(lp) and lp:Alive() and self_
        and self_.state == "normal" and (tonumber(self_.bleed) or 0) > 0 then
        draw.SimpleText(string.format(
            Fireteam.Locale.Get("vitals_bleeding"), tonumber(self_.bleed)),
            kit.Font("medium"),
            ScrW() / 2, ScrH() * 0.72,
            kit.ColorA("danger", 220 * kit.EffectsAlpha()),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ═══ 部位状态指示（塔科夫式：黑肢/骨折时显示；elements.limbs 锚点）═══
    if IsValid(lp) and lp:Alive() and self_ and istable(self_.limbs)
        and self_.state == "normal" then
        local L = Fireteam.Locale.Get
        local badParts = {}
        for _, part in ipairs(Fireteam.Vitals.LIMB_ORDER or {}) do
            local hp = tonumber(self_.limbs[part]) or 0
            local fractured = istable(self_.fractures) and self_.fractures[part] == true
            if hp <= 0 and part ~= "thorax" and part ~= "head" then
                badParts[#badParts + 1] = L("vitals_limb_" .. part) .. " "
                    .. L(fractured and "vitals_limb_black_fractured" or "vitals_limb_black")
            elseif fractured then
                badParts[#badParts + 1] = L("vitals_limb_" .. part) .. " "
                    .. L("vitals_limb_fractured")
            end
        end

        if #badParts > 0 then
            local elem = kit.GetElement("limbs")
            local lx, ly = kit.ResolveAnchor(elem.position or "left",
                160, #badParts * 20 + 24)
            local painMasked = self_.pain and true or false
            for i, text in ipairs(badParts) do
                draw.SimpleText(text, kit.Font("small"), lx, ly + (i - 1) * 20,
                    kit.ColorA("danger", (painMasked and 100 or 230) * kit.EffectsAlpha()),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            if painMasked then
                draw.SimpleText(Fireteam.Locale.Get("vitals_painkiller_active"),
                    kit.Font("small"), lx, ly + #badParts * 20,
                    kit.ColorA("success", 200 * kit.EffectsAlpha()),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end

    -- ═══ 救援读条（施救者视角）═══
    if IsValid(lp) and lp:Alive() then
        for _, entry in pairs(Fireteam.Vitals.Client) do
            if entry.reviving and entry.idx == lp:EntIndex() then
                local tgt = Entity(entry.reviving.tgtIdx)
                local label = string.format(Fireteam.Locale.Get(
                    entry.reviving.kind == "revive" and "vitals_reviving" or "vitals_stabilizing"),
                    IsValid(tgt) and tgt:Nick() or "?")
                local total = tonumber(entry.reviving.kind == "revive"
                    and Fireteam.Vitals.GetParam("revive_time")
                    or Fireteam.Vitals.GetParam("stabilize_time")) or 3
                local frac = 1 - math.Clamp((entry.reviving.ends - CurTime()) / math.max(total, 0.1), 0, 1)

                local barW = math.Round(320 * (ScrW() / 1920))
                local bx, by = ScrW() / 2 - barW / 2, ScrH() * 0.6
                draw.SimpleText(label, kit.Font("body"), ScrW() / 2, by - 16,
                    kit.Color("text"), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                kit.DrawProgressBar(bx, by, barW, 10, frac, "primary")
            end
        end
    end

    -- ═══ 倒地队友列表（右上，含距离）═══
    local lines = {}
    local myPos = IsValid(lp) and lp:GetPos() or nil
    for _, entry in pairs(Fireteam.Vitals.Client) do
        if entry.state == "downed" and myPos and entry.idx ~= lp:EntIndex() then
            local mate = Entity(entry.idx)
            if IsValid(mate) then
                local dist = math.floor(myPos:Distance(Vector(entry.pos.x, entry.pos.y, entry.pos.z)) / 40)
                lines[#lines + 1] = {
                    text = string.format(Fireteam.Locale.Get("vitals_teammate_downed_hud"),
                        mate:Nick(), dist),
                    stabilized = entry.stabilized,
                }
            end
        end
    end
    table.sort(lines, function(a, b) return a.text < b.text end)

    local listY = ScrH() * 0.3
    for i, line in ipairs(lines) do
        if i > 5 then break end
        draw.SimpleText(line.text, kit.Font("small"),
            ScrW() - kit.MARGIN, listY + (i - 1) * 20,
            kit.ColorA(line.stabilized and "success" or "danger", 230),
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end)

print("[FIRETEAM:Vitals] ✓ 客户端 HUD 已加载")

-- modules/mainmenu/cl_mainmenu.lua
-- FIRETEAM Main Menu (ESC)
-- 拦截引擎菜单：PreRender 轮询 gui.IsGameUIVisible → gui.HideGameUI 隐藏引擎菜单，
-- 弹出自定义主菜单（社区成熟做法）；已打开时 ESC = 关闭。F4 为等效备用入口。

if not Fireteam then Fireteam = {} end
Fireteam.MainMenu = Fireteam.MainMenu or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

local menuPanel = nil

local STATE_LABEL = {
    warmup       = "round_warmup",
    briefing     = "round_briefing",
    active       = "round_active",
    ended        = "round_ended",
    intermission = "round_intermission",
}

local function FormatTime(secs)
    secs = math.max(0, math.floor(secs))
    return string.format("%02d:%02d", math.floor(secs / 60), secs % 60)
end

--- 入口按钮：点击执行动作并关闭主菜单
local function AddEntryButton(parent, label, fn)
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(40)
    btn:Dock(TOP)
    btn:DockMargin(0, 0, 0, 8)
    btn:SetText(label)
    kit.StyleButton(btn, { style = "ghost" })
    btn.DoClick = function()
        if IsValid(menuPanel) then menuPanel:Remove() end
        fn()
    end
    return btn
end

function Fireteam.MainMenu.Open()
    if IsValid(menuPanel) then return end

    local W, H = math.Round(560 * (ScrW() / 1920)), math.Round(560 * (ScrH() / 1080))
    menuPanel = kit.CreateFrame("FIRETEAM", W, H, {
        blur = true,
        hints = { L("ui_hint_esc_close") }
    })

    local wrap = vgui.Create("DPanel", menuPanel)
    wrap:Dock(FILL)
    wrap:DockPadding(16, menuPanel.ftContentTop + 6, 16, menuPanel.ftContentBottom + 8)
    wrap.Paint = nil

    -- ─── 战局状态区 ───
    local status = vgui.Create("DPanel", wrap)
    status:Dock(TOP)
    status:SetTall(84)
    status.Paint = function(s, w, h)
        kit.DrawPanel(0, 0, w, h, { fillAlpha = 150, borderColor = false })

        local c = Fireteam.Rounds and Fireteam.Rounds.Client or nil
        local line1 = L("ui_mm_status_idle")
        local line2 = ""

        if c and c.state and c.state ~= "idle" then
            local scn = Fireteam.Rounds.GetScenarioName()
            local stateText = L(STATE_LABEL[c.state] or c.state)
            line1 = scn and (scn .. " · " .. stateText) or stateText
            if c.round > 0 then line1 = line1 .. " · #" .. c.round end

            local remain = FormatTime(math.max(0, c.endTime - CurTime()))
            line2 = remain
            -- 模式与战役进度
            if c.mode then
                line2 = line2 .. " · " .. L("admin_round_mode", string.upper(c.mode))
                if c.mode == "pve" and istable(c.campaign) and c.campaign.total then
                    line2 = line2 .. " · "
                        .. L("admin_round_campaign", c.campaign.stage or 1, c.campaign.total)
                end
            end
        end

        draw.SimpleText(line1, kit.Font("medium"), 12, 16,
            kit.Color("text"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(line2, kit.Font("small"), 12, 46,
            kit.Color("text_muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local spacer = vgui.Create("DPanel", wrap)
    spacer:Dock(TOP)
    spacer:SetTall(12)
    spacer.Paint = nil

    -- ─── 功能入口 ───
    AddEntryButton(wrap, L("ui_mm_squad") .. "  (F7)", function()
        Fireteam.Squad.OpenPanel()
    end)
    AddEntryButton(wrap, L("ui_mm_class") .. "  (F8)", function()
        Fireteam.Class.OpenSelectPanel()
    end)
    AddEntryButton(wrap, L("ui_mm_backpack") .. "  (Tab)", function()
        Fireteam.Inventory.ToggleBackpack()
    end)
    AddEntryButton(wrap, L("ui_mm_tacmap") .. "  (M)", function()
        Fireteam.TacMap.Toggle()
    end)
    AddEntryButton(wrap, L("ui_mm_command") .. "  (CapsLock)", function()
        Fireteam.TacMap.ToggleCommandView()
    end)

    -- 管理员入口（非管理员打开会被服务端拒绝）
    local adminBtn = vgui.Create("DButton", wrap)
    adminBtn:SetTall(40)
    adminBtn:Dock(TOP)
    adminBtn:DockMargin(0, 0, 0, 8)
    adminBtn:SetText(L("ui_mm_admin") .. "  (F10)")
    kit.StyleButton(adminBtn, { style = "danger" })
    adminBtn.DoClick = function()
        if IsValid(menuPanel) then menuPanel:Remove() end
        Fireteam.Admin.Open()
    end
end

function Fireteam.MainMenu.Close()
    if IsValid(menuPanel) then menuPanel:Remove() end
end

-- ─────────────────────────────────────
-- ESC 拦截：引擎菜单弹出即隐藏并接管
-- （已打开时 ESC = 关闭；F4 等效入口）
-- ─────────────────────────────────────
hook.Add("PreRender", "Fireteam.MainMenu.Intercept", function()
    if gui.IsGameUIVisible() then
        gui.HideGameUI()
        if IsValid(menuPanel) then
            Fireteam.MainMenu.Close()
        else
            Fireteam.MainMenu.Open()
        end
    end
end)

hook.Add("PlayerButtonDown", "Fireteam.MainMenu.F4Key", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button ~= KEY_F4 then return end
    if not kit.CanTogglePanel() then return end
    if IsValid(menuPanel) then
        Fireteam.MainMenu.Close()
    else
        Fireteam.MainMenu.Open()
    end
end)

print("[FIRETEAM:MainMenu] ✓ ESC menu loaded")

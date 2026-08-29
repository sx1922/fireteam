-- modules/mainmenu/cl_mainmenu.lua
-- FIRETEAM Main Menu (ESC) — Cold War Military Style
-- 左屏贴边面板：图标卡片按钮 + 右侧信息区
-- 拦截引擎菜单：PreRender 轮询 gui.IsGameUIVisible → gui.HideGameUI 隐藏引擎菜单，
-- 弹出自定义主菜单（社区成熟做法）；已打开时 ESC = 关闭。F4 为等效备用入口。

if not Fireteam then Fireteam = {} end
Fireteam.MainMenu = Fireteam.MainMenu or {}

local kit = Fireteam.UI
local L = Fireteam.Locale.Get

local menuPanel = nil

-- 贴图路径前缀：VTF 存放在 coldwar_content/06_实用脚本/materials/ 下
local TEX = "fireteam/ui/coldwar/"

-- 预加载图标材质
local ICONS = {
    squad    = Material(TEX .. "icon-squad"),
    class    = Material(TEX .. "icon-class"),
    backpack = Material(TEX .. "icon-backpack"),
    map      = Material(TEX .. "icon-tacmap"),
    command  = Material(TEX .. "icon-commander"),
}

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

--- 查找按键绑定提示（玩家未绑定时回退到默认键位）
local function KeyHint(cmd, engineHint)
    local bound = input.LookupBinding(cmd)
    if bound and bound ~= "" then return string.upper(bound) end
    if engineHint then return engineHint end
    if Fireteam.Keybinds and Fireteam.Keybinds.DefaultKeyFor then
        local def = Fireteam.Keybinds.DefaultKeyFor(cmd)
        if def then return string.upper(def) end
    end
    return ""
end

--- 卡片按钮工厂：图标 + 标题 + 描述 + 快捷键
local function AddCardButton(parent, iconMat, label, desc, keyStr, fn, btnStyle)
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(52)
    btn:Dock(TOP)
    btn:DockMargin(0, 0, 0, 6)
    btn:SetText("")
    kit.StyleCardButton(btn, {
        icon = iconMat,
        label = label,
        desc = desc,
        keyHint = keyStr,
        style = btnStyle or "ghost",
    })
    btn.DoClick = function()
        if IsValid(menuPanel) then menuPanel:Remove() end
        fn()
    end
    return btn
end

function Fireteam.MainMenu.Open()
    if IsValid(menuPanel) then return end

    local scale = ScrW() / 1920
    local panelW = math.Round(360 * scale)
    local panelH = ScrH()

    -- 左屏贴边面板
    menuPanel = vgui.Create("DFrame")
    menuPanel:SetSize(panelW, panelH)
    menuPanel:SetPos(0, 0)
    menuPanel:SetTitle("")
    menuPanel:SetDraggable(false)
    menuPanel:ShowCloseButton(false)
    menuPanel:MakePopup()

    local hintBarH = 28

    menuPanel.Paint = function(s, pw, ph)
        -- 模糊衬底
        local blurMat = Material("pp/blurscreen")
        surface.SetMaterial(blurMat)
        surface.SetDrawColor(255, 255, 255, 255)
        for i = 1, 3 do
            blurMat:SetFloat("$blur", (i / 3) * 5)
            blurMat:Recompute()
            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
        end

        -- 面板底色：橄榄军绿
        surface.SetDrawColor(kit.ColorA("background", 235))
        surface.DrawRect(0, 0, pw, ph)

        -- 右侧边框线
        surface.SetDrawColor(kit.ColorA("primary", 200))
        surface.DrawRect(pw - 1, 0, 1, ph)

        -- 右侧投影渐变
        surface.SetDrawColor(kit.ColorA("background", 180))
        surface.DrawRect(pw, 0, 12, ph)

        -- 标题区
        local titleY = 24
        draw.SimpleText("FIRETEAM", kit.Font("title"), 20, titleY,
            kit.Color("text"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("COLD WAR", kit.Font("small"), 20, titleY + 22,
            kit.ColorA("text_muted", 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- 分隔线
        kit.DrawStencilDivider(16, titleY + 44, pw - 32)

        -- 底部提示条
        surface.SetDrawColor(kit.ColorA("border", 140))
        surface.DrawRect(0, ph - hintBarH, pw, 1)
        draw.SimpleText(L("ui_hint_esc_close"), kit.Font("small"),
            pw / 2, ph - hintBarH / 2,
            kit.Color("text_muted"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ─── 内容容器 ───
    local wrap = vgui.Create("DPanel", menuPanel)
    wrap:Dock(FILL)
    wrap:DockMargin(0, 80, 0, hintBarH + 8)
    wrap.Paint = nil

    -- 按钮区标题
    local sectionLabel = vgui.Create("DLabel", wrap)
    sectionLabel:Dock(TOP)
    sectionLabel:DockMargin(20, 0, 0, 8)
    sectionLabel:SetText("作战菜单")
    sectionLabel:SetFont(kit.Font("small"))
    sectionLabel:SetTextColor(kit.ColorA("text_muted", 200))
    sectionLabel:SizeToContents()

    -- ─── 卡片按钮列表 ───
    local btnSquad = AddCardButton(wrap, ICONS.squad,
        L("ui_mm_squad"), L("ui_mm_squad_desc"), KeyHint("ft_squad", "F2"),
        function() Fireteam.Squad.OpenPanel() end)

    local btnClass = AddCardButton(wrap, ICONS.class,
        L("ui_mm_class"), L("ui_mm_class_desc"), KeyHint("ft_class", "F3"),
        function() Fireteam.Class.OpenSelectPanel() end)

    local btnBackpack = AddCardButton(wrap, ICONS.backpack,
        L("ui_mm_backpack"), L("ui_mm_backpack_desc"), KeyHint("ft_backpack", "Tab"),
        function() Fireteam.Inventory.ToggleBackpack() end)

    local btnMap = AddCardButton(wrap, ICONS.map,
        L("ui_mm_tacmap"), L("ui_mm_tacmap_desc"), KeyHint("ft_map", "M"),
        function() Fireteam.TacMap.Toggle() end)

    local btnCommand = AddCardButton(wrap, ICONS.command,
        L("ui_mm_command"), L("ui_mm_command_desc"), KeyHint("ft_command", "F4"),
        function() Fireteam.TacMap.ToggleCommandView() end)

    -- 弹簧：把管理面板推到底部
    local spacer = vgui.Create("DPanel", wrap)
    spacer:Dock(FILL)
    spacer.Paint = nil

    -- 管理面板入口（danger 样式）
    local adminBtn = AddCardButton(wrap, nil,
        L("ui_mm_admin"), L("ui_mm_admin_desc"), KeyHint("ft_admin", "F10"),
        function() Fireteam.Admin.Toggle() end, "danger")
end

function Fireteam.MainMenu.Close()
    if IsValid(menuPanel) then menuPanel:Remove() end
end

--- 面板开关由 core/sh_keybinds.lua 统一分配
--- （引擎 ShowHelp=F1 / 命令 ft_menu）。
function Fireteam.MainMenu.Toggle()
    if IsValid(menuPanel) then
        Fireteam.MainMenu.Close()
    else
        Fireteam.MainMenu.Open()
    end
end

Fireteam.Log.Info("MainMenu", "✓ 主菜单已加载")

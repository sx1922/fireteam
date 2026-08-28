-- core/sh_ui_kit.lua
-- FIRETEAM UI Kit
-- 主题驱动的设计系统基座：字体阶梯、统一取色、绘制原语、主题化面板壳层、屏幕特效。
-- 规则：模块内禁止硬编码 Color()，一律通过 Fireteam.UI.Color(语义名) 取色。

if not Fireteam then Fireteam = {} end
Fireteam.UI = Fireteam.UI or {}

local kit = Fireteam.UI

-- ═══════════════════════════════════════
-- 默认调色板（主题缺键时的兜底，保证任意设定包可用）
-- ═══════════════════════════════════════
local DEFAULT_PALETTE = {
    primary        = Color(51, 255, 51),
    secondary      = Color(26, 140, 26),
    background     = Color(10, 10, 10),
    surface        = Color(16, 24, 16),
    border         = Color(40, 70, 40),
    text           = Color(208, 255, 208),
    text_muted     = Color(111, 160, 111),
    accent         = Color(57, 255, 106),
    success        = Color(51, 255, 51),
    warning        = Color(255, 204, 0),
    danger         = Color(255, 51, 51),
    info           = Color(100, 180, 255),
    squad_ally     = Color(102, 255, 102),
    squad_leader   = Color(255, 255, 51),
    marker_waypoint  = Color(51, 255, 136),
    marker_enemy     = Color(255, 51, 51),
    marker_objective = Color(255, 204, 0),
    marker_danger    = Color(255, 102, 0),
    marker_rally     = Color(100, 180, 255),
    marker_medical   = Color(255, 102, 153)
}

-- ═══════════════════════════════════════
-- 取色（唯一入口）
-- ═══════════════════════════════════════
local colorCache = {}

--- 按语义名取主题色；主题未定义时回退默认调色板
function kit.Color(name)
    local hit = colorCache[name]
    if hit then return hit end

    local theme = Fireteam.HUD and Fireteam.HUD.GetTheme and Fireteam.HUD.GetTheme()
    local hex = theme and theme.palette and theme.palette[name]
    local col
    if hex then
        col = Fireteam.HUD.ParseColor(hex)
    else
        col = DEFAULT_PALETTE[name] or Color(255, 255, 255)
    end

    colorCache[name] = col
    return col
end

--- 带自定义透明度的语义色
function kit.ColorA(name, alpha)
    local c = kit.Color(name)
    return Color(c.r, c.g, c.b, alpha)
end

-- 缓存失效（主题切换时由 sh_hud 调用）
function kit.InvalidateCache()
    colorCache = {}
    kit.BuildFonts()
end

hook.Add(Fireteam.HOOKS.UI_THEME_INVALIDATED, "Fireteam.UI.Invalidate", function()
    kit.InvalidateCache()
end)

-- ═══════════════════════════════════════
-- 字体系统
-- 由主题 font.primary / size_base 生成字号阶梯；
-- 字体名含主题 ID，切主题自动重建不串味。
-- ═══════════════════════════════════════
local FONT_LADDER = {
    small  = 0.75,
    body   = 1.0,
    medium = 1.2,
    large  = 1.45,
    title  = 1.8
}

local currentFontSet = nil

if CLIENT then
    function kit.BuildFonts()
        local theme = Fireteam.HUD and Fireteam.HUD.GetTheme and Fireteam.HUD.GetTheme()
        if not theme then return end

        local fontDef = theme.font or {}
        local faceName = fontDef.primary or "Tahoma"
        local baseSize = tonumber(fontDef.size_base) or 16
        -- 分辨率缩放：以 1080p 为基准
        local scale = math.Clamp(ScrH() / 1080, 0.75, 2)
        local themeId = tostring(theme.theme_id or "default")

        local set = {}
        for stepName, mult in pairs(FONT_LADDER) do
            local fontName = "FT." .. themeId .. "." .. stepName
            surface.CreateFont(fontName, {
                font      = faceName,
                size      = math.Round(baseSize * mult * scale),
                weight    = stepName == "title" and 700 or 400,
                antialias = true,
                extended  = true
            })
            set[stepName] = fontName
        end

        -- 数字/等宽场景用 fallback 面孔
        local monoName = "FT." .. themeId .. ".num"
        surface.CreateFont(monoName, {
            font      = fontDef.fallback or "Courier New",
            size      = math.Round(baseSize * 1.45 * scale),
            weight    = 700,
            antialias = true
        })
        set.num = monoName

        currentFontSet = set
    end

    --- 取字体名；懒建保证首次调用时主题已就绪
    function kit.Font(stepName)
        if not currentFontSet then kit.BuildFonts() end
        return (currentFontSet and currentFontSet[stepName]) or "DermaDefault"
    end

    hook.Add("OnScreenSizeChanged", "Fireteam.UI.RebuildFonts", function()
        currentFontSet = nil
        kit.InvalidateCache()
    end)
else
    -- 服务端占位（保持 API 双端可调用）
    function kit.BuildFonts() end
    function kit.Font(stepName) return "DermaDefault" end
end

-- ═══════════════════════════════════════
-- 布局常量与锚点
-- ═══════════════════════════════════════
kit.MARGIN = 16

if CLIENT then
    --- 解析 elements.*.position 命名锚点 → 屏幕坐标（返回元素的左上角）
    --- @param position string  top_left/top_center/top_right/left/right/bottom_left/bottom_center/bottom_right
    --- @param w number 元素宽
    --- @param h number 元素高
    function kit.ResolveAnchor(position, w, h)
        local sw, sh = ScrW(), ScrH()
        local m = kit.MARGIN
        position = position or "top_left"

        local x, y = m, m
        if position:find("center") then
            x = sw / 2 - w / 2
        elseif position:find("right") then
            x = sw - w - m
        elseif position == "left" then
            x = m
        end
        if position:find("^bottom") then
            y = sh - h - m
        elseif position == "left" or position == "right" then
            y = sh * 0.3
        end
        return math.Round(x), math.Round(y)
    end

    --- 读取主题元素定义
    function kit.GetElement(name)
        local theme = Fireteam.HUD and Fireteam.HUD.GetTheme and Fireteam.HUD.GetTheme()
        return theme and theme.elements and theme.elements[name] or {}
    end
end

-- ═══════════════════════════════════════
-- 绘制原语（仅客户端）
-- ═══════════════════════════════════════
if CLIENT then
    --- 主题面板底板：圆角填充 + 可选描边
    function kit.DrawPanel(x, y, w, h, opts)
        opts = opts or {}
        local radius = opts.radius or 0
        local fillAlpha = opts.fillAlpha or 200
        draw.RoundedBox(radius, x, y, w, h, kit.ColorA(opts.fill or "surface", fillAlpha))
        if opts.borderColor ~= false then
            draw.RoundedBox(radius, x, y, w, h, kit.ColorA(opts.borderColor or "border", opts.borderAlpha or 160))
            -- 描边只留外框：内部再盖一层填充
            draw.RoundedBox(radius, x + 1, y + 1, w - 2, h - 2, kit.ColorA(opts.fill or "surface", fillAlpha))
        end
    end

    --- 标题条：在面板顶部绘制标题文字与分隔线，返回内容区起始 y
    function kit.DrawHeader(x, y, w, title)
        local headerH = math.Round(28 * (ScrH() / 1080))
        surface.SetDrawColor(kit.ColorA("border", 200))
        surface.DrawRect(x, y, w, headerH)
        draw.SimpleText(title or "", kit.Font("medium"),
            x + 10, y + headerH / 2, kit.Color("text"),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(kit.ColorA("primary", 220))
        surface.DrawRect(x, y + headerH - 2, w, 2)
        return y + headerH + 8
    end

    --- 分隔线
    function kit.DrawDivider(x, y, w)
        surface.SetDrawColor(kit.ColorA("border", 180))
        surface.DrawRect(x, y, w, 1)
    end

    --- DButton 主题化（Paint 覆写 + 悬停渐变）
    --- @param btn Panel 目标按钮
    --- @param opts { style="primary"|"ghost"|"danger", font="body", textColor=语义名 }
    function kit.StyleButton(btn, opts)
        opts = opts or {}
        local style = opts.style or "primary"

        btn:SetText("")
        btn.Paint = function(s, w, h)
            s.ftHoverLerp = Lerp(FrameTime() * 12, s.ftHoverLerp or 0, s:IsHovered() and 1 or 0)
            s.ftDownLerp = Lerp(FrameTime() * 15, s.ftDownLerp or 0, s:IsDown() and 1 or 0)

            local accent = kit.Color(style == "danger" and "danger" or "primary")
            local hover = s.ftHoverLerp
            local down = s.ftDownLerp

            if style == "ghost" then
                draw.RoundedBox(0, 0, 0, w, h, Color(accent.r, accent.g, accent.b, 18 + hover * 40))
                surface.SetDrawColor(Color(accent.r, accent.g, accent.b, 90 + hover * 120))
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            else
                draw.RoundedBox(0, 0, 0, w, h, Color(accent.r, accent.g, accent.b, 40 + hover * 60 - down * 30))
                surface.SetDrawColor(Color(accent.r, accent.g, accent.b, 140 + hover * 100))
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end

            local label = s:GetText()
            if label and label ~= "" then
                draw.SimpleText(label, kit.Font(opts.font or "body"), w / 2, h / 2,
                    kit.ColorA(opts.textColor or "text", 235 - down * 60),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        return btn
    end

    --- 主题化 DLabel
    function kit.StyleLabel(label, opts)
        opts = opts or {}
        label:SetFont(kit.Font(opts.font or "body"))
        label:SetTextColor(kit.Color(opts.color or "text"))
        label:SetWrap(opts.wrap or false)
        if opts.autoHeight and label.SizeToContentsY then
            label:SizeToContentsY()
        end
        return label
    end

    --- 键盘焦点守卫：仅当**文本输入控件**持有焦点时拦截热键（防打字/输入法组合期误触）。
    --- ⚠ 不能简单判 `vgui.GetKeyboardFocus() == nil`：CreateFrame 无条件 MakePopup，
    --- 面板本体也持有键盘焦点，那样写会让任意面板一开就锁死全部热键（历史 P0，worklog 041）。
    function kit.CanTogglePanel()
        local focus = vgui.GetKeyboardFocus()
        if not IsValid(focus) then return true end

        -- 鸭子类型：TextEntry 家族同时具备这三个方法，DFrame/DPanel 不具备
        if focus.GetText and focus.SetText and focus.IsEditing then return false end

        -- 类名兜底（个别派生控件可能改写方法表）
        local cls = focus.GetClassName and focus:GetClassName() or ""
        if cls == "DTextEntry" or cls == "TextEntry" or cls == "RichText" then
            return false
        end
        return true
    end

    --- 主题化 DTextEntry 工厂：统一字体/配色/聚焦描边（中文输入请走系统输入法）
    --- @param parent Panel 容器
    --- @param opts { tall=number, font="body" }
    function kit.CreateEntry(parent, opts)
        opts = opts or {}
        local entry = vgui.Create("DTextEntry", parent)
        entry:SetTall(opts.tall or 30)
        entry:SetFont(kit.Font(opts.font or "body"))
        entry.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, kit.ColorA("background", 220))
            local border = s.HasFocus and "primary" or "border"
            surface.SetDrawColor(kit.ColorA(border, s.HasFocus and 220 or 170))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            local ph = s.GetPlaceholderText and s:GetPlaceholderText() or nil
            if ph and ph ~= "" and s:GetText() == "" then
                draw.SimpleText(ph, kit.Font(opts.font or "body"), 8, h / 2,
                    kit.ColorA("text_muted", 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            s:DrawTextEntryText(kit.Color("text"), kit.ColorA("primary", 120), kit.Color("primary"))
        end
        return entry
    end

    --- 进度条（0~1）
    function kit.DrawProgressBar(x, y, w, h, frac, colorName)
        frac = math.Clamp(frac or 0, 0, 1)
        draw.RoundedBox(0, x, y, w, h, kit.ColorA("background", 200))
        if frac > 0 then
            draw.RoundedBox(0, x, y, math.max(w * frac, 2), h, kit.ColorA(colorName or "primary", 230))
        end
        surface.SetDrawColor(kit.ColorA("border", 200))
        surface.DrawOutlinedRect(x, y, w, h, 1)
    end

    -- ─────────────────────────────────────
    -- 冷战军事风格组件
    -- 直角面板、卡片按钮、图标材质管理
    -- ─────────────────────────────────────

    --- 材质缓存：按路径懒加载 VTF 贴图
    local matCache = {}
    function kit.Material(path)
        local m = matCache[path]
        if m then return m end
        m = Material(path)
        matCache[path] = m
        return m
    end

    --- 绘制贴图图标（自动居中缩放）
    --- @param mat Material 材质
    --- @param x number 左上角 x
    --- @param y number 左上角 y
    --- @param size number 宽高（正方形）
    --- @param color table|nil 着色（缺省用 text 色）
    function kit.DrawIcon(mat, x, y, size, color)
        if not mat or mat:IsError() then return end
        local c = color or kit.Color("text")
        surface.SetMaterial(mat)
        surface.SetDrawColor(c.r, c.g, c.b, c.a or 255)
        surface.DrawTexturedRect(x, y, size, size)
    end

    --- 冷战直角面板（无圆角，薄边框）
    function kit.DrawSharpPanel(x, y, w, h, opts)
        opts = opts or {}
        local fillAlpha = opts.fillAlpha or 180
        surface.SetDrawColor(kit.ColorA(opts.fill or "surface", fillAlpha))
        surface.DrawRect(x, y, w, h)
        if opts.borderColor ~= false then
            surface.SetDrawColor(kit.ColorA(opts.borderColor or "border", opts.borderAlpha or 200))
            surface.DrawOutlinedRect(x, y, w, h, 1)
        end
    end

    --- 卡片按钮：图标 + 标题 + 描述 + 快捷键
    --- 替换 StyleButton 用于 ESC 菜单等功能入口
    --- @param btn Panel DButton
    --- @param opts { icon=Material, label=string, desc=string, keyHint=string, style="ghost"|"primary"|"danger" }
    function kit.StyleCardButton(btn, opts)
        opts = opts or {}
        local style = opts.style or "ghost"

        btn:SetText("")
        btn.Paint = function(s, w, h)
            s.ftHoverLerp = Lerp(FrameTime() * 12, s.ftHoverLerp or 0, s:IsHovered() and 1 or 0)
            s.ftDownLerp = Lerp(FrameTime() * 15, s.ftDownLerp or 0, s:IsDown() and 1 or 0)

            local hover = s.ftHoverLerp
            local down = s.ftDownLerp
            local colName = (style == "danger" and "danger") or (style == "primary" and "primary") or "primary"
            local accent = kit.Color(colName)

            -- 底色填充
            local fillA = 12 + hover * 30 - down * 20
            surface.SetDrawColor(Color(accent.r, accent.g, accent.b, fillA))
            surface.DrawRect(0, 0, w, h)

            -- 左侧高亮条（hover 时渐现）
            local barW = 3 + hover * 2
            surface.SetDrawColor(Color(accent.r, accent.g, accent.b, 80 + hover * 175))
            surface.DrawRect(0, 0, barW, h)

            -- 边框
            surface.SetDrawColor(Color(accent.r, accent.g, accent.b, 60 + hover * 80))
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            -- 图标
            local iconX = 14
            local iconSize = math.min(h - 12, 32)
            local iconY = (h - iconSize) / 2
            if opts.icon and not opts.icon:IsError() then
                surface.SetMaterial(opts.icon)
                local icCol = kit.ColorA("text", 200 + hover * 55)
                surface.SetDrawColor(icCol.r, icCol.g, icCol.b, icCol.a)
                surface.DrawTexturedRect(iconX, iconY, iconSize, iconSize)
            end

            -- 标题
            local textX = opts.icon and (iconX + iconSize + 12) or 14
            if opts.label then
                draw.SimpleText(opts.label, kit.Font("body"), textX, h / 2 - 7,
                    kit.ColorA("text", 235 - down * 60),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            -- 描述（小字）
            if opts.desc then
                draw.SimpleText(opts.desc, kit.Font("small"), textX, h / 2 + 9,
                    kit.ColorA("text_muted", 200),
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            -- 快捷键标签（右侧）
            if opts.keyHint and opts.keyHint ~= "" then
                local kw = 40
                local kx = w - kw - 10
                surface.SetDrawColor(kit.ColorA("border", 120 + hover * 80))
                surface.DrawOutlinedRect(kx, h / 2 - 9, kw, 18, 1)
                draw.SimpleText(opts.keyHint, kit.Font("small"), kx + kw / 2, h / 2,
                    kit.ColorA("text_muted", 200 + hover * 55),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        return btn
    end

    --- 绘制角标装饰（L形边角框）
    function kit.DrawCornerBracket(x, y, size, corner, color)
        corner = corner or "tl"
        color = color or "primary"
        local c = kit.ColorA(color, 150)
        local len = size or 12
        surface.SetDrawColor(c)
        if corner == "tl" then
            surface.DrawRect(x, y, len, 1)
            surface.DrawRect(x, y, 1, len)
        elseif corner == "tr" then
            surface.DrawRect(x + 1, y, len, 1)
            surface.DrawRect(x + len, y, 1, len)
        elseif corner == "bl" then
            surface.DrawRect(x, y + len, len, 1)
            surface.DrawRect(x, y + 1, 1, len)
        elseif corner == "br" then
            surface.DrawRect(x + 1, y + len, len, 1)
            surface.DrawRect(x + len, y + 1, 1, len)
        end
    end

    --- 冷战风格分隔线（中央菱形 + 渐隐线）
    function kit.DrawStencilDivider(x, y, w, color)
        color = color or "border"
        local c = kit.ColorA(color, 180)
        surface.SetDrawColor(c)
        -- 左半线
        surface.DrawRect(x, y, w / 2 - 6, 1)
        -- 右半线
        surface.DrawRect(x + w / 2 + 6, y, w / 2 - 6, 1)
        -- 中央菱形
        local cx, cy = x + w / 2, y
        draw.NoTexture()
        surface.SetDrawColor(kit.ColorA(color, 220))
        surface.DrawPoly({
            { x = cx,     y = cy - 3 },
            { x = cx + 4, y = cy },
            { x = cx,     y = cy + 3 },
            { x = cx - 4, y = cy },
        })
    end

    -- ─────────────────────────────────────
    -- 面板壳层 CreateFrame
    -- 主题背景 + 自绘标题条 + 底部按键提示条，
    -- 替换裸 DFrame 的 Windows 默认灰皮肤。
    -- ─────────────────────────────────────
    local blurMat = Material("pp/blurscreen")

    --- 全屏模糊衬底（在 Frame.Paint 内调用）
    function kit.DrawBlur(panel, layers)
        layers = layers or 3
        local x, y = panel:LocalToScreen(0, 0)
        surface.SetMaterial(blurMat)
        surface.SetDrawColor(255, 255, 255)
        for i = 1, layers do
            blurMat:SetFloat("$blur", (i / layers) * 6)
            blurMat:Recompute()
            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
        end
        draw.RoundedBox(0, 0, 0, panel:GetWide(), panel:GetTall(), kit.ColorA("background", 170))
    end

    --- 创建主题化窗口
    --- @return Panel frame
    --- opts { blur=bool, hints={"F7 关闭", ...}, draggable=bool }
    function kit.CreateFrame(title, w, h, opts)
        opts = opts or {}
        local frame = vgui.Create("DFrame")
        frame:SetSize(w, h)
        frame:Center()
        frame:SetTitle("")
        frame:SetDraggable(opts.draggable ~= false)
        frame:ShowCloseButton(true)
        frame:MakePopup()

        if frame.btnClose then
            frame.btnClose.Paint = function(s, cw, ch)
                draw.SimpleText("✕", kit.Font("body"), cw / 2, ch / 2,
                    s:IsHovered() and kit.Color("danger") or kit.Color("text_muted"),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            frame.btnClose:SetText("")
        end

        local hintBarH = opts.hints and 24 or 0

        frame.Paint = function(s, pw, ph)
            if opts.blur then
                kit.DrawBlur(s)
            else
                draw.RoundedBox(0, 0, 0, pw, ph, kit.ColorA("background", 225))
            end

            draw.RoundedBox(0, 0, 0, pw, ph, kit.ColorA("surface", 210))
            surface.SetDrawColor(kit.ColorA("border", 220))
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)

            -- 标题条
            surface.SetDrawColor(kit.ColorA("border", 160))
            surface.DrawRect(0, 0, pw, 32)
            draw.SimpleText(title or "", kit.Font("large"), 12, 16,
                kit.Color("text"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(kit.ColorA("primary", 200))
            surface.DrawRect(0, 31, pw, 1)

            -- 底部按键提示条
            if opts.hints then
                surface.SetDrawColor(kit.ColorA("border", 140))
                surface.DrawRect(0, ph - hintBarH, pw, 1)
                local text = table.concat(opts.hints, "    ")
                draw.SimpleText(text, kit.Font("small"), pw - 10, ph - hintBarH / 2,
                    kit.Color("text_muted"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        -- 内容区起点让开标题条与提示条
        frame.ftContentTop = 40
        frame.ftContentBottom = hintBarH
        return frame
    end

    -- ─────────────────────────────────────
    -- 屏幕特效
    -- ─────────────────────────────────────
    local grainMat = Material("effects/tvscreen_noise002a")
    local vignetteMats = {
        up = Material("vgui/gradient-u"),
        down = Material("vgui/gradient-d"),
        left = Material("vgui/gradient-l"),
        right = Material("vgui/gradient-r")
    }

    --- 扫描线（区域可选，缺省全屏）
    function kit.DrawScanlines(alpha)
        alpha = alpha or 15
        surface.SetDrawColor(0, 0, 0, alpha)
        for y = 0, ScrH(), 4 do
            surface.DrawRect(0, y, ScrW(), 1)
        end
    end

    --- 程序化暗角：四边渐变叠加（零素材依赖）
    function kit.DrawVignette(strength01)
        strength01 = strength01 or 0
        if strength01 <= 0 then return end
        local a = strength01 * 255
        local edgeW = math.Round(ScrW() * 0.35)
        local edgeH = math.Round(ScrH() * 0.35)
        surface.SetDrawColor(0, 0, 0, a)
        surface.SetMaterial(vignetteMats.down)
        surface.DrawTexturedRect(0, 0, ScrW(), edgeH)          -- 上缘向下渐隐
        surface.SetMaterial(vignetteMats.up)
        surface.DrawTexturedRect(0, ScrH() - edgeH, ScrW(), edgeH)
        surface.SetMaterial(vignetteMats.right)
        surface.DrawTexturedRect(0, 0, edgeW, ScrH())
        surface.SetMaterial(vignetteMats.left)
        surface.DrawTexturedRect(ScrW() - edgeW, 0, edgeW, ScrH())
    end

    --- 噪点颗粒
    function kit.DrawGrain(strength01)
        if not strength01 or strength01 <= 0 then return end
        grainMat = grainMat or Material("effects/tvscreen_noise002a")
        if grainMat:IsError() then return end
        local ox = math.random(0, 512)
        local oy = math.random(0, 512)
        surface.SetDrawColor(255, 255, 255, strength01 * 40)
        surface.SetMaterial(grainMat)
        for gx = -ox % 512 - 512, ScrW(), 512 do
            for gy = -oy % 512 - 512, ScrH(), 512 do
                surface.DrawTexturedRect(gx, gy, 512, 512)
            end
        end
    end

    --- CRT 闪烁抖动系数（effects.flicker 开启时 0.82~1 抖动）
    function kit.EffectsAlpha()
        local theme = Fireteam.HUD and Fireteam.HUD.GetTheme and Fireteam.HUD.GetTheme()
        if not (theme and theme.effects and theme.effects.flicker) then return 1 end
        local t = CurTime()
        -- 低频呼吸 + 高频细抖
        local breath = 0.93 + 0.05 * math.sin(t * 7.3)
        local jitter = (math.sin(t * 61.7) > 0.96) and -0.08 or 0
        return breath + jitter
    end
end

Fireteam.Log.Info("UI", "✓ UI Kit 就绪")

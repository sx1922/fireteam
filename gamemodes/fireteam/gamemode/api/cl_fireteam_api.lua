-- gamemode/api/cl_fireteam_api.lua
-- FIRETEAM Public API — Client Surface
-- 面向第三方 addon 的客户端只读接口（本地玩家视角的缓存快照 + 主题取色）。
-- 返回值一律是副本或不可变量，避免外部 addon 改坏内部缓存。
--
-- 加载时机：cl_init.lua 在模块全量加载之后 include 本文件，
-- 但实现仍走惰性解析，防止个别模块被服务器禁用时报错。

if not CLIENT then return end

local function Reg(name, fn, desc, args, returns)
    if not (Fireteam.API and Fireteam.API.Register) then return end
    Fireteam.API.Register("Fireteam.API." .. name, fn, desc, args, returns)
end

-- ─────────────────────────────────────
-- 本地小队 / 体征
-- ─────────────────────────────────────

Reg("GetLocalSquad", function()
    if not (Fireteam.Squad and Fireteam.Squad.GetMySquad) then return nil end
    return Fireteam.Squad.GetMySquad()
end, "Local player's squad snapshot (from the latest SQUAD_UPDATE)",
    {}, { { type = "table|nil" } })

Reg("GetLocalVitals", function()
    if not (Fireteam.Vitals and Fireteam.Vitals.GetSelf) then return nil end
    local self_ = Fireteam.Vitals.GetSelf()
    if not istable(self_) then return nil end

    local out = { state = self_.state, bleed = self_.bleed,
                  stabilized = self_.stabilized, pain = self_.pain }
    if istable(self_.limbs) then
        out.limbs = {}
        for part, hp in pairs(self_.limbs) do out.limbs[part] = hp end
    end
    if istable(self_.fractures) then
        out.fractures = {}
        for part in pairs(self_.fractures) do out.fractures[part] = true end
    end
    return out
end, "Local player's vitals snapshot copy (state / bleed / limbs / fractures)",
    {}, { { type = "table|nil" } })

-- ─────────────────────────────────────
-- 本地背包
-- ─────────────────────────────────────

Reg("GetLocalInventory", function()
    local counts = Fireteam.Inventory and Fireteam.Inventory.ClientCounts or nil
    if not istable(counts) then return {} end
    local out = {}
    for itemId, count in pairs(counts) do out[itemId] = count end
    return out
end, "Copy of the local item counts table { itemId = count }",
    {}, { { type = "table" } })

Reg("GetLocalInventoryCells", function()
    local cells = Fireteam.Inventory and Fireteam.Inventory.ClientCells or nil
    if not istable(cells) then return {} end
    local out = {}
    for i, c in ipairs(cells) do
        out[i] = { id = c.id, x = c.x, y = c.y, w = c.w, h = c.h }
    end
    return out
end, "Copy of the local grid layout array { {id,x,y,w,h}, ... }",
    {}, { { type = "table" } })

-- ─────────────────────────────────────
-- 回合快照
-- ─────────────────────────────────────

Reg("GetRoundSnapshot", function()
    local c = Fireteam.Rounds and Fireteam.Rounds.Client or nil
    if not istable(c) then return nil end
    return {
        state    = c.state,
        round    = c.round,
        endTime  = c.endTime,
        mode     = c.mode,
        winner   = c.winner,
        campaign = istable(c.campaign)
            and { stage = c.campaign.stage, total = c.campaign.total } or nil,
    }
end, "Copy of the client round snapshot (state / countdown / mode / campaign stage)",
    {}, { { type = "table|nil" } })

-- ─────────────────────────────────────
-- 主题取色（供第三方 UI 融入当前 HUD 皮肤）
-- ─────────────────────────────────────

Reg("GetThemeColor", function(semanticName)
    if not (Fireteam.UI and Fireteam.UI.Color) then return Color(255, 255, 255) end
    local c = Fireteam.UI.Color(semanticName)
    return Color(c.r, c.g, c.b, c.a or 255)
end, "Resolve a semantic palette color from the active HUD theme (copy)",
    { { name = "semanticName", type = "string", desc = "primary/text/danger/squad_ally/..." } },
    { { type = "Color" } })

Reg("GetThemeFont", function(step)
    if not (Fireteam.UI and Fireteam.UI.Font) then return "DermaDefault" end
    return Fireteam.UI.Font(step or "body")
end, "Resolve a theme font name by step: small/body/medium/large/title/num",
    { { name = "step", type = "string|nil", desc = "default 'body'" } },
    { { type = "string" } })

Fireteam.Log.Info("API", "✓ 客户端 API 表面已注册")

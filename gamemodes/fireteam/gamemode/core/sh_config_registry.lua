-- core/sh_config_registry.lua
-- FIRETEAM Configuration Registry: register, validate, get, set, sync

if not Fireteam then Fireteam = {} end
Fireteam.Config = Fireteam.Config or {}

local registry = {}   -- { key = { default, value, type, min, max, desc, silent } }

-- ─────────────────────────────────────
-- 注册一个配置项
-- ─────────────────────────────────────
--- @param key string       点分路径 "voice.model"
--- @param default any      默认值
--- @param opts table       { type="string"|"number"|"boolean"|"table", min, max, desc, options }
function Fireteam.Config.Register(key, default, opts)
    opts = opts or {}
    registry[key] = {
        default = default,
        value   = default,
        type    = opts.type or type(default),
        min     = opts.min,
        max     = opts.max,
        desc    = opts.desc or "",
        options = opts.options,   -- 枚举可选值列表
        silent  = false
    }
end

-- ─────────────────────────────────────
-- 获取配置值
-- ─────────────────────────────────────
function Fireteam.Config.Get(key)
    local entry = registry[key]
    if not entry then
        ErrorNoHalt("[FIRETEAM:Config] Get unknown key: " .. tostring(key) .. "\n")
        return nil
    end
    return entry.value
end

-- ─────────────────────────────────────
-- 设置配置值（带校验）
-- ─────────────────────────────────────
--- @param key string
--- @param value any
--- @param opts table  { silent = bool }  为 true 时不触发 Hook / 不广播
--- @return boolean success
function Fireteam.Config.Set(key, value, opts)
    opts = opts or {}
    local entry = registry[key]
    if not entry then
        Fireteam.Log.Warn("配置", "写入未知配置项: " .. tostring(key))
        return false
    end

    -- 类型校验
    if entry.type and type(value) ~= entry.type then
        Fireteam.Log.Warn("配置", "类型不匹配 '" .. key
            .. "': 期望 " .. entry.type .. "，实际 " .. type(value))
        return false
    end

    -- 数值范围校验
    if entry.type == "number" then
        if entry.min and value < entry.min then value = entry.min end
        if entry.max and value > entry.max then value = entry.max end
    end

    -- 枚举校验
    if entry.options and not table.HasValue(entry.options, value) then
        Fireteam.Log.Warn("配置", "非法枚举值 '" .. key
            .. "': " .. tostring(value))
        return false
    end

    local old = entry.value
    entry.value = value

    if not opts.silent then
        hook.Run(Fireteam.HOOKS.CONFIG_CHANGED, key, old, value)
        -- 服务端广播给客户端（WriteType 自带类型标识，客户端用 ReadType 还原）
        if SERVER then
            net.Start(Fireteam.NET.CONFIG_SYNC)
                net.WriteString(key)
                net.WriteType(value)
            net.Broadcast()
        end
    end

    return true
end

-- ─────────────────────────────────────
-- 重置为默认值
-- ─────────────────────────────────────
function Fireteam.Config.Reset(key)
    local entry = registry[key]
    if entry then
        Fireteam.Config.Set(key, entry.default)
    end
end

-- ─────────────────────────────────────
-- 获取所有已注册键（调试用）
-- ─────────────────────────────────────
function Fireteam.Config.GetAll()
    local out = {}
    for k, v in pairs(registry) do
        out[k] = v.value
    end
    return out
end

--- 全量元数据（管理面板用）：{ key = {value, default, type, min, max, desc, options} }
function Fireteam.Config.DescribeAll()
    local out = {}
    for k, e in pairs(registry) do
        out[k] = {
            value   = e.value,
            default = e.default,
            type    = e.type,
            min     = e.min,
            max     = e.max,
            desc    = e.desc,
            options = e.options,
        }
    end
    return out
end

-- ─────────────────────────────────────
-- 默认配置注册
-- ─────────────────────────────────────
local function RegisterDefaults()
    -- 语音
    Fireteam.Config.Register("voice.model", Fireteam.VOICE_MODEL.ANALOG_RADIO, {
        type = "string",
        options = { "analog_radio", "digital", "direct", "field_phone" },
        desc = "Communication model"
    })
    Fireteam.Config.Register("voice.distance_max", 800, {
        type = "number", min = 100, max = 5000,
        desc = "Max voice range (units)"
    })
    Fireteam.Config.Register("voice.interference", true, {
        type = "boolean",
        desc = "Enable terrain/radio interference"
    })

    -- HUD
    Fireteam.Config.Register("hud.theme", "crt_green", {
        type = "string",
        options = { "crt_green", "monochrome_amber", "paper_map", "modern_digital", "minimal" },
        desc = "Active HUD theme"
    })

    -- 弹道
    Fireteam.Config.Register("ballistics.bullet_drop", true, {
        type = "boolean",
        desc = "Enable bullet drop simulation"
    })
    Fireteam.Config.Register("ballistics.suppression_mult", 1.0, {
        type = "number", min = 0.5, max = 3.0,
        desc = "Suppression effect multiplier"
    })

    -- 标记
    Fireteam.Config.Register("marker.style", "chalk", {
        type = "string",
        options = { "chalk", "digital", "flag", "laser" },
        desc = "Marker visual style"
    })
    Fireteam.Config.Register("marker.max_per_player", 3, {
        type = "number", min = 1, max = 10,
        desc = "Max simultaneous markers per player"
    })

    -- 小队
    Fireteam.Config.Register("squad.max_size", 6, {
        type = "number", min = 2, max = 12,
        desc = "Maximum squad size"
    })
    Fireteam.Config.Register("squad.friendly_fire", false, {
        type = "boolean",
        desc = "Allow friendly fire"
    })
end

RegisterDefaults()

-- ─────────────────────────────────────
-- 客户端：接收服务端配置同步
-- （服务端权威，直接写入本地注册表并触发本地 hook 供 UI 响应）
-- ─────────────────────────────────────
if CLIENT then
    net.Receive(Fireteam.NET.CONFIG_SYNC, function()
        local key = net.ReadString()
        local value = net.ReadType()
        local entry = registry[key]
        if not entry then return end
        local old = entry.value
        entry.value = value
        hook.Run(Fireteam.HOOKS.CONFIG_CHANGED, key, old, value)
    end)
end

Fireteam.Log.Info("配置", "✓ 配置注册表就绪 (" .. table.Count(registry) .. " 项)")

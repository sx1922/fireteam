-- core/sh_logger.lua
-- FIRETEAM 统一日志系统（必须最先加载，自持命名空间初始化）
--
-- 输出格式: [FIRETEAM][级别][模块] 消息
-- 级别: INFO(白) WARN(黄) ERROR(红) DEBUG(青, 受 ft_debug 门控)
-- 所有消息均为 UTF-8 中文；客户端控制台/聊天可直接显示，
-- Windows 独服控制台如乱码请执行 chcp 65001 或使用 -condebug

Fireteam = Fireteam or {}
Fireteam.Log = Fireteam.Log or {}

local PREFIX_COLOR  = Color(51, 255, 51)    -- [FIRETEAM] 绿
local MODULE_COLOR  = Color(160, 160, 160)  -- 模块名 灰
local LEVEL_COLORS  = {
    info  = Color(220, 220, 220),
    warn  = Color(255, 200, 50),
    error = Color(255, 80, 80),
    debug = Color(80, 220, 255)
}
local MSG_COLORS = {
    info  = Color(230, 230, 230),
    warn  = Color(255, 230, 160),
    error = Color(255, 150, 150),
    debug = Color(170, 235, 250)
}
local LEVEL_TAGS = { info = "INFO", warn = "警告", error = "错误", debug = "调试" }

local function DebugEnabled()
    local cv = GetConVar("ft_debug")
    return (cv ~= nil and cv:GetBool()) or false
end

local function Emit(level, module, msg)
    local tag   = LEVEL_TAGS[level] or level:upper()
    local pCol  = PREFIX_COLOR
    local lCol  = LEVEL_COLORS[level]
    local mCol  = MSG_COLORS[level]

    MsgC(
        pCol, "[FIRETEAM]",
        MODULE_COLOR, "[" .. tostring(module) .. "]",
        lCol, "[" .. tag .. "] ",
        mCol, tostring(msg) .. "\n"
    )
end

-- 常规信息（始终输出）
function Fireteam.Log.Info(module, msg)
    Emit("info", module, msg)
end

-- 警告（始终输出，黄色）
function Fireteam.Log.Warn(module, msg)
    Emit("warn", module, msg)
end

-- 错误（始终输出，红色）
function Fireteam.Log.Error(module, msg)
    Emit("error", module, msg)
end

-- 调试信息（仅 ft_debug=1 时输出）
function Fireteam.Log.Debug(module, msg)
    if not DebugEnabled() then return end
    Emit("debug", module, msg)
end

-- 详细调试（仅 ft_debug=2 时输出）
function Fireteam.Log.Trace(module, msg)
    local cv = GetConVar("ft_debug")
    if not (cv and cv:GetInt() and cv:GetInt() >= 2) then return end
    Emit("debug", module, msg)
end

Fireteam.Log.Info("日志", "✓ 日志系统就绪")

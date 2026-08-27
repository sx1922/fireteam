-- core/sh_net_protocol.lua
-- FIRETEAM Unified Networking Protocol

if not Fireteam then Fireteam = {} end
Fireteam.Net = Fireteam.Net or {}

-- ─────────────────────────────────────
-- 注册网络消息
-- ─────────────────────────────────────
local registeredMessages = {}

function Fireteam.Net.Register(messageId)
    if registeredMessages[messageId] then return end
    util.AddNetworkString(messageId)
    registeredMessages[messageId] = true
end

-- 服务端注册所有消息
if SERVER then
    for _, msgId in pairs(Fireteam.NET) do
        Fireteam.Net.Register(msgId)
    end
    Fireteam.Log.Info("网络", "✓ 网络协议: 已注册 " .. table.Count(registeredMessages) .. " 条消息")
end

-- ─────────────────────────────────────
-- 发送工具函数
-- varargs 用显式计数打包（ipairs 遍历 {...} 遇首个 nil 即停，
-- 会静默吞掉其后的全部参数）；序列化统一走 WriteValue，
-- 不支持的类型在发送端立即 error，而不是到接收端才错位暴露。
-- ─────────────────────────────────────

--- 打包变长参数：n 记录真实个数（含内部 nil 槽位）
local function PackArgs(...)
    return { n = select("#", ...), ... }
end

local function StartAndWrite(messageId, args)
    net.Start(messageId)
    for i = 1, args.n do
        Fireteam.Net.WriteValue(args[i])
    end
end

--- 发送给所有玩家
function Fireteam.Net.SendToAll(messageId, ...)
    if not SERVER then return end
    local args = PackArgs(...)
    StartAndWrite(messageId, args)
    net.Broadcast()
end

--- 发送给单个玩家
function Fireteam.Net.SendToPlayer(ply, messageId, ...)
    if not SERVER then return end
    if not IsValid(ply) then return end
    local args = PackArgs(...)
    StartAndWrite(messageId, args)
    net.Send(ply)
end

--- 发送给指定玩家列表
function Fireteam.Net.SendToPlayers(plys, messageId, ...)
    if not SERVER then return end
    local args = PackArgs(...)
    StartAndWrite(messageId, args)
    net.Send(plys)
end

--- 客户端发送给服务端
function Fireteam.Net.SendToServer(messageId, ...)
    if SERVER then return end
    local args = PackArgs(...)
    StartAndWrite(messageId, args)
    net.SendToServer()
end

-- ─────────────────────────────────────
-- 定型序列化 WriteValue（无类型标签）
-- 现网 wire format 是"读写两端按固定顺序、固定类型手工对齐"：
-- 所有存量消息的读端都是裸 ReadString/ReadTable…。
-- 因此这里绝不能增删已支持类型的字节布局。
-- Vector/Angle/Color/nil 在无标签流里无法表达——与其静默降级成
-- tostring 字符串造成读端不可逆错位，不如发送端立即 error。
-- 需要传这些类型时改用下方自描述的 WriteAny / ReadAny 对。
-- ─────────────────────────────────────
local UNSUPPORTED_HINT = " 不支持经 Fireteam.Net.WriteValue 发送（定型协议无类型标签），" ..
    "请使用自描述的 Fireteam.Net.WriteAny / ReadAny。"

function Fireteam.Net.WriteValue(value)
    local t = type(value)
    if t == "string" then
        net.WriteString(value)
    elseif t == "number" then
        net.WriteDouble(value)
    elseif t == "boolean" then
        net.WriteBool(value)
    elseif t == "table" then
        net.WriteTable(value)
    elseif t == "Player" then
        net.WritePlayer(value)
    elseif t == "Entity" then
        net.WriteEntity(value)
    else
        error(t .. UNSUPPORTED_HINT)
    end
end

-- ─────────────────────────────────────
-- 自描述序列化 WriteAny / ReadAny
-- 1 字节类型标签 + 载荷，读写完全对称；读端无需预知写入顺序，
-- 循环调 ReadAny 即可逐个还原。适用于新消息与异构参数；
-- 存量消息继续走 WriteValue 以保持字节级兼容。
-- 注意：Player 归入 Entity 标签（ReadEntity 对玩家实体同样成立）。
-- ─────────────────────────────────────
local TAG_NIL    = 0
local TAG_BOOL   = 1
local TAG_NUMBER = 2
local TAG_STRING = 3
local TAG_TABLE  = 4
local TAG_VECTOR = 5
local TAG_ANGLE  = 6
local TAG_COLOR  = 7
local TAG_ENTITY = 8

function Fireteam.Net.WriteAny(value)
    local t = type(value)
    if value == nil then
        net.WriteUInt(TAG_NIL, 8)
    elseif t == "boolean" then
        net.WriteUInt(TAG_BOOL, 8)
        net.WriteBool(value)
    elseif t == "number" then
        net.WriteUInt(TAG_NUMBER, 8)
        net.WriteDouble(value)
    elseif t == "string" then
        net.WriteUInt(TAG_STRING, 8)
        net.WriteString(value)
    elseif t == "Vector" then
        net.WriteUInt(TAG_VECTOR, 8)
        net.WriteVector(value)
    elseif t == "Angle" then
        net.WriteUInt(TAG_ANGLE, 8)
        net.WriteAngle(value)
    elseif t == "Player" or t == "Entity" then
        net.WriteUInt(TAG_ENTITY, 8)
        net.WriteEntity(value)
    elseif t == "table" and iscolor(value) then
        net.WriteUInt(TAG_COLOR, 8)
        net.WriteUInt(value.r or 0, 8)
        net.WriteUInt(value.g or 0, 8)
        net.WriteUInt(value.b or 0, 8)
        net.WriteUInt(value.a or 255, 8)
    elseif t == "table" then
        net.WriteUInt(TAG_TABLE, 8)
        net.WriteTable(value)
    else
        error(t .. UNSUPPORTED_HINT)
    end
end

--- 与 WriteAny 严格对称：按流中的类型标签还原值
function Fireteam.Net.ReadAny()
    local tag = net.ReadUInt(8)
    if tag == TAG_NIL then
        return nil
    elseif tag == TAG_BOOL then
        return net.ReadBool()
    elseif tag == TAG_NUMBER then
        return net.ReadDouble()
    elseif tag == TAG_STRING then
        return net.ReadString()
    elseif tag == TAG_VECTOR then
        return net.ReadVector()
    elseif tag == TAG_ANGLE then
        return net.ReadAngle()
    elseif tag == TAG_ENTITY then
        return net.ReadEntity()
    elseif tag == TAG_COLOR then
        return Color(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8))
    elseif tag == TAG_TABLE then
        return net.ReadTable()
    end
    error("Fireteam.Net.ReadAny: 流中遇到未知类型标签 " .. tostring(tag) .. "（读写两端版本不一致？）")
end

-- ─────────────────────────────────────
-- 接收工具
-- ─────────────────────────────────────
function Fireteam.Net.Receive(messageId, callback)
    net.Receive(messageId, callback)
end

Fireteam.Log.Info("网络", "✓ 网络协议模块已加载")

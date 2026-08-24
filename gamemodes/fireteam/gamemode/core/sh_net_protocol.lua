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
-- ─────────────────────────────────────

--- 发送给所有玩家
function Fireteam.Net.SendToAll(messageId, ...)
    if not SERVER then return end
    net.Start(messageId)
    local args = { ... }
    for _, v in ipairs(args) do
        Fireteam.Net.WriteValue(v)
    end
    net.Broadcast()
end

--- 发送给单个玩家
function Fireteam.Net.SendToPlayer(ply, messageId, ...)
    if not SERVER then return end
    if not IsValid(ply) then return end
    net.Start(messageId)
    local args = { ... }
    for _, v in ipairs(args) do
        Fireteam.Net.WriteValue(v)
    end
    net.Send(ply)
end

--- 发送给指定玩家列表
function Fireteam.Net.SendToPlayers(plys, messageId, ...)
    if not SERVER then return end
    net.Start(messageId)
    local args = { ... }
    for _, v in ipairs(args) do
        Fireteam.Net.WriteValue(v)
    end
    net.Send(plys)
end

--- 客户端发送给服务端
function Fireteam.Net.SendToServer(messageId, ...)
    if SERVER then return end
    net.Start(messageId)
    local args = { ... }
    for _, v in ipairs(args) do
        Fireteam.Net.WriteValue(v)
    end
    net.SendToServer()
end

-- ─────────────────────────────────────
-- 智能序列化（自动判断类型写入）
-- ─────────────────────────────────────
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
        net.WriteString(tostring(value))
    end
end

function Fireteam.Net.ReadValue(typeHint)
    if typeHint == "string" then return net.ReadString()
    elseif typeHint == "number" then return net.ReadDouble()
    elseif typeHint == "boolean" then return net.ReadBool()
    elseif typeHint == "table" then return net.ReadTable()
    elseif typeHint == "Player" then return net.ReadPlayer()
    elseif typeHint == "Entity" then return net.ReadEntity()
    else return net.ReadString()
    end
end

-- ─────────────────────────────────────
-- 接收工具
-- ─────────────────────────────────────
function Fireteam.Net.Receive(messageId, callback)
    net.Receive(messageId, callback)
end

Fireteam.Log.Info("网络", "✓ 网络协议模块已加载")

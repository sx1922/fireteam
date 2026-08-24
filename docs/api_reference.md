# FIRETEAM API Reference

> 本文档由 `sh_api_registry.lua` 动态生成，请勿手动编辑。
>
> 生成时间: 2026-08-24 | 设定包: coldwar

## 概述

FIRETEAM 通过 `Fireteam.API` 命名空间向第三方 addon 开放功能。所有公开接口在运行时由注册表收集并挂载到 `Fireteam.API.<Module>.<Function>`，同时支持通过 `fireteam.RequestAPI` 网络消息按需查询。

## 命名空间结构

```
Fireteam
├── API                     -- 公开接口根命名空间（自动生成）
│   ├── Squad               -- 小队操作
│   ├── Class               -- 职业系统
│   ├── Marker              -- 战术标记
│   ├── Ballistics          -- 弹道计算
│   └── Suppression         -- 压制系统
├── Config                  -- 配置注册表 (sh_config_registry)
├── WeaponInterface         -- 武器接口 (sh_weapon_interface)
├── VehicleInterface        -- 载具接口 (sh_vehicle_interface)
├── Setting                 -- 设定包管理 (sv_setting_loader / 客户端只读快照)
└── HUD                     -- HUD 工具 (sh_hud, 仅客户端绘制相关)
```

## Squad（小队）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `Create(ply, name)` | Player, string | bool, string | 创建小队 |
| `Disband(squadId)` | string | bool | 解散小队（仅队长）|
| `Join(ply, squadId)` | Player, string | bool, string | 加入小队 |
| `Leave(ply)` | Player | bool | 离开小队 |
| `GetMembers(squadId)` | string | table | 成员快照列表 |
| `IsLeader(ply)` | Player | bool | 是否队长 |

## Class（职业）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `GetAll()` | - | table | 当前设定包全部职业定义 |
| `Get(classId)` | string | table \| nil | 单个职业定义 |
| `Select(ply, classId)` | Player, string | bool, string | 选择职业并发放装备 |

## Marker（标记）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `Place(ply, markerType, pos)` | Player, string, Vector | bool | 放置标记（服务端校验距离/数量）|
| `Remove(markerId)` | string | bool | 移除标记 |
| `GetVisible(ply)` | Player | table | 该玩家可见的标记列表 |

## Ballistics（弹道，Shared）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `CalcDrop(muzzleVel, distance)` | number, number | number | 子弹下坠量 (units) |
| `CalcFlightTime(muzzleVel, distance)` | number, number | number | 飞行时间 (s) |
| `CalcDamage(baseDamage, distance, effectiveRange)` | number×3 | number | 距离衰减后的伤害 |

## Suppression（压制）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `Add(ply, amount)` | Player, number | - | 增加压制值 0~1（仅服务端）|
| `GetLevel(value)` | number | number | 压制值 → 等级 0-4 |

## WeaponInterface / VehicleInterface

第三方武器/载具基座适配器（ARC9、TFA、LVS、Simfphys）通过以下调用注册数据：

```lua
Fireteam.WeaponInterface.Register({
    base = "weapon_class",
    displayName = "...", tags = {...}, category = Fireteam.WEAPON_CATEGORY.RIFLE,
    suppression = 0.3, effectiveRange = 12000, fireModes = {"semi","auto"},
    opticType = "iron", weight = 3.5, noiseLevel = 0.7,
    magazineSize = 30, damage = 25
})

Fireteam.VehicleInterface.Register({
    base = "sent_class",
    displayName = "...", category = Fireteam.VEHICLE_CATEGORY.LIGHT,
    tags = {...}, maxSpeed = 800, health = 100,
    fuelCapacity = 100, crewCapacity = 4, armorLevel = 1
})
```

发现时机：监听 `Fireteam.HOOKS.WEAPON_DISCOVER` / `VEHICLE_DISCOVER` gamemode 钩子。

## Config 注册表

```lua
Fireteam.Config.Get(key)            -- 读取，如 "ballistics.bullet_drop"
Fireteam.Config.Set(key, value)     -- 写入（服务端）
Fireteam.Config.RegisterDefault(key, value)
```

## 网络消息一览

| 消息名 | 方向 | 内容 |
|---|---|---|
| `FT_SettingChanged` | S→C | packId, packName |
| `FT_HUDTheme` | S→C | theme JSON |
| `FT_SuppressionUpdate` | S→C | float 压制值 |
| `FT_SquadSync` | S→C | 全量小队快照 |
| `FT_MarkerSync` | S→C | 标记增删改 |
| `FT_ClassSelect` | C→S | classId |
| `fireteam.RequestAPI` | C→S | 模块名查询 |

## 扩展指南

新增模块时：

1. 在 `gamemodes/fireteam/gamemode/modules/<name>/` 建立 `sh_/sv_/cl_` 三件套（模块加载器自动发现）；
2. 共享常量与纯函数放 `sh_`；需要暴露给第三方的函数在文件末尾挂载到 `Fireteam.API.<Module>`；
3. 自定义网络消息必须在文件加载期 `util.AddNetworkString`；
4. 客户端读取设定包数据一律走网络同步或 `Fireteam.HUD.GetTheme()` 这类带客户端路径回退的封装，禁止直接读 `Setting.Discovered`。

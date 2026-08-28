# FIRETEAM API Reference

> 与实际代码同步（2026-08-28 重写）。来源：`core/sh_api_registry.lua` + `api/{sh,sv,cl}_fireteam_api.lua`。
> **注意：本文件为手动维护，改 API 时必须同步更新。** 自动生成功能见「A 节」。

## 0. 三层暴露面

FIRETEAM 对外接口分三层，第三方 addon 按需使用：

```text
层1  Fireteam.API.*                 自动注册表 + 惰性解析（缺失模块返回 nil/false，不报错）
层2  Fireteam.<模块>.*              各模块公开函数（建议只读；可写的见 sv API）
层3  Fireteam.HOOKS.*               30+ 事件钩子，hook.Add 消费
```

**约定**：`api/*.lua` 里所有 `Fireteam.API.*` 实现都是**惰性解析**——调用时才查
`Fireteam.<模块>`，模块未加载/被禁用时静默返回 nil/false，绝不抛错。客户端 `sv_`
接口只读并返回副本，避免外部改坏内部缓存。

---

## A. 自动文档生成（防脱节）

`docs/api_reference.md` 已改为手动维护。但 `sh_api_registry.lua` 的注册表（含
`desc/args/returns`）才是权威来源。若想彻底防止脱节，可加一个脚本从注册表生成文档：

```lua
-- 服务端控制台：打印所有已注册的 Fireteam.API.* 签名
concommand.Add("ft_api_docs", function()
    for name, meta in pairs(Fireteam.API.GetRegistry()) do
        print(name .. " | " .. meta.desc)
        for _, a in ipairs(meta.args or {}) do
            print("   arg: " .. (a.name or "?") .. ":" .. (a.type or "?") .. " - " .. (a.desc or ""))
        end
        for _, r in ipairs(meta.returns or {}) do
            print("   ret: " .. (r.type or "?") .. " - " .. (r.desc or ""))
        end
    end
end)
```

---

## B. 命名空间树（实际）

```text
Fireteam
├── API                      ← 见 C-F 节（按所在 realm 分类）
│   ├── (sh)                 GetFaction/GetRoundMode/GetScenario/...
│   ├── (sv)                 SetRoundMode/SetScenario/AdvanceRound/EndRound/GiveItem/...
│   └── (cl)                 GetLocalSquad/GetLocalVitals/GetThemeColor/...
├── Config                   ← G1
├── Locale                   ← G2
├── Setting                  ← G3
├── Voice                    ← G4
├── Squad                    ← G5
├── Commander                ← G6
├── Marker                   ← G7
├── Vitals                   ← G8
├── Rounds                   ← G9
├── Inventory                ← G10
├── WeaponInterface          ← G11
├── VehicleInterface         ← G12
└── HOOKS                    ← H
```

---

## C. 共享（sh）API —— 查询接口

这些在 `api/sh_fireteam_api.lua` + `core/sh_api_registry.lua` 注册。**两端可用**。

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `GetSquad(ply)` | Player | table\|nil | 玩家当前小队 |
| `GetSquadMembers(squadId)` | number | table (Player[]) | 小队全部成员 |
| `GetClass(ply)` | Player | string\|nil | 玩家职业 id |
| `GetFaction(ply)` | Player | string\|nil | 阵营 id（无小队 nil） |
| `GetRoundMode()` | - | string | `"pvp"`\|`"pve"` |
| `GetScenario(id)` | string\|nil | table\|nil | nil=当前生效剧本 |
| `GetScenarioList()` | - | table\|nil | 当前设定包剧本表 |
| `GetChannelKind(id)` | string | string\|nil | local/squad/command/all |
| `GetChannelDef(id)` | string | table\|nil | 频道定义 |
| `GetCommander(factionId)` | string | Player\|nil | 服务端权威 / 客户端广播缓存 |
| `IsCommander(ply)` | Player | boolean | 是否现任指挥官 |
| `GetItemDef(itemId)` | string | table\|nil | 物品定义 |
| `GetItemSize(itemDef)` | table | number, number | 背包占格宽高（默认 1,1） |
| `GetWeaponData(entity)` | Entity | table\|nil | FTWeaponData |
| `GetVehicleData(entity)` | Entity | table\|nil | FTVehicleData |
| `HitgroupToLimb(hitgroup)` | number | string\|nil | 命中组→肢体 id |
| `GetLimbMaxHealth()` | - | table\|nil | { 肢体 = 上限 HP } |

**直调别名**（只读）：`Fireteam.Squad.GetPlayerSquad(ply)` / `GetAll()` / `GetById(id)` /
`GetByFaction(fid)`；`Fireteam.Rounds.GetScenario(id)` / `ResolveScenario()` /
`GetTimings()` / `GetPackConfig()` / `IsEnabled()`。

---

## D. 服务端（sv）API —— 可写接口

`api/sv_fireteam_api.lua`。**无管理员校验**——调用方是服务端 Lua，已在信任边界内。
面向玩家的入口（concommand / net 消息）各模块自带 AdminAllowed 校验。

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `SetRoundMode(mode)` | string | boolean | 切换 pvp/pve，下回合生效 |
| `SetScenario(scenarioId)` | string | boolean | 选剧本，下回合简报生效 (""=默认) |
| `AdvanceRound()` | - | boolean | 立即推进回合状态机 |
| `EndRound(winner)` | string\|nil | boolean | 强制结算，见 G9 AdminEnd 校验 |
| `GiveItem(ply, itemId, count)` | Player,string,number\|nil | number | 实际发放数（网格空间截断） |
| `TakeItem(ply, itemId, count)` | Player,string,number\|nil | number | 实际移除数 |
| `GetItemCount(ply, itemId)` | Player,string | number | 当前持有数 |
| `IsDowned(ply)` | Player | boolean | 是否倒地 |
| `ResetVitals(ply)` | Player | boolean | 重置体征记录 |
| `RelinquishCommand(ply)` | Player | boolean | 让出指挥席位 |
| `AssignClass(ply, classId)` | Player,string | boolean | 分配职业（触发 CLASS_ASSIGNED） |

**直调别名**（可写）：`Fireteam.Squad.Create(ply,name,faction)` / `Join(ply,squadId)` /
`Leave(ply)` / `Disband(squadId)` / `Kick(leader,target)` / `SetLocked` / `SetReady`；
`Fireteam.Commander.Volunteer(ply)` / `Vote(ply,targetIdx)` / `Relinquish(ply)`；
`Fireteam.Setting.Activate(packId)`；`Fireteam.Voice.SetChannel(ply,channelId)`。

---

## E. 客户端（cl）API —— 只读快照

`api/cl_fireteam_api.lua`。返回副本或不可变值。

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `GetLocalSquad()` | - | table\|nil | 本地小队快照 |
| `GetLocalVitals()` | - | table\|nil | { state,bleed,stabilized,pain,limbs,fractures } |
| `GetLocalInventory()` | - | table | { itemId = count } 副本 |
| `GetLocalInventoryCells()` | - | table | { {id,x,y,w,h}, ... } 副本 |
| `GetRoundSnapshot()` | - | table\|nil | { state,round,endTime,mode,winner,campaign } |
| `GetThemeColor(semanticName)` | string | Color | 主题语义色副本 |
| `GetThemeFont(step)` | string\|nil | string | 主题字体名（默认 "body"） |

---

## F. 剧本 / 目标类型扩展 API（直调 `Fireteam.Rounds.*`）

设定包数据**只读**；第三方自定义走运行时叠加层。解析按
`基础(自定义 > 设定包 > 隐式单剧本) ← 扩展层` 合成新表，`ClearScenarioExtensions` 一键还原。

### F1. 剧本级（改运行时扩展层，不动设定包文件）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `RegisterScenario(id, data)` | string, table | boolean | 注册/替换完整剧本；**data 由框架引用，注册后勿原地改** |
| `UnregisterScenario(id)` | string | boolean | 移除自定义剧本 |
| `AddScenarioObjective(scenarioId, objectiveDef)` | string, table | boolean | 追加目标模板（type 须已注册） |
| `RemoveScenarioObjective(scenarioId, objectiveName)` | string, string | boolean | 按 name 剔除目标 |
| `AddScenarioSpawn(scenarioId, factionId, spawnEntry)` | string, string, table | boolean | 给阵营追加出生点 |
| `SetScenarioTimings(scenarioId, timings)` | string, table | boolean | 浅合并覆盖节奏参数 |
| `OverrideScenarioVitals(scenarioId, params)` | string, table | boolean | 覆盖体征（三级解析最上层） |
| `SetScenarioPvE(scenarioId, pve)` | string, table | boolean | 覆盖 PvE 战役配置 |
| `ClearScenarioExtensions()` | - | - | 清空全部自定义与扩展 |

上述函数通过 `Fireteam.API.*` 也暴露（见 `sh_api_registry.lua`），签名一致。

### F2. 自定义目标类型（核心扩展点）

```lua
Fireteam.Rounds.RegisterObjective("my_mode", {
    label       = "objective_my_mode",        -- locale key
    onStart     = function(ctx) ... end,        -- 可选，初始化 ctx.data
    think       = function(ctx, dt) ... end,    -- 服务端逐帧，必需
    isComplete  = function(ctx) return done, winnerFaction end,  -- 必需
    getProgress = function(ctx) return 0..1 end,-- HUD 进度条
    describe    = function(ctx) return {...} end, -- 客户端渲染参数
})
```

内置 4 类：`hold_zone`（占区）、`eliminate`（歼灭）、`destroy_entity`（摧毁实体）、
`extract`（撤离），定义在 `sh_rounds.lua` 末尾。

---

## G. 各模块公开函数速查（直调 `Fireteam.<模块>.*`）

### G1 Config — `core/sh_config_registry.lua`
| 函数 | 说明 |
|---|---|
| `Register(key, default, opts)` | 注册配置项 `{ type,min,max,desc,options }` |
| `Get(key)` | 读取，未知 key 返回 nil+warn |
| `Set(key, value, opts)` | 校验后写入，触发 CONFIG_CHANGED，`opts.silent` 静默 |
| `Reset(key)` | 重置为默认值 |
| `SyncAllTo(ply)` | 单玩家全量同步（服务端） |
| `GetAll()` / `DescribeAll()` | 调试全量 / 管理面板元数据 |

### G2 Locale — `core/sh_locale.lua`
| 函数 | 说明 |
|---|---|
| `Get(key, ...)` | 解析字符串（游戏→包→en 回退），带参则 format |
| `LoadPack(pathPrefix, realm)` | 注入设定包词条 `<pack>/locale/<lang>.lua` |
| `SetLanguage(lang)` | 切换语言，重载 base+pack 词条 |
| `GetLanguage()` | 当前语言码 |
| `ClearPack()` | 清空 pack 词条 |

### G3 Setting — `sv_setting_loader.lua`
| 函数 | 说明 |
|---|---|
| `Discover()` | 扫描 builtin/gamemode/addon 包目录 |
| `Activate(packId)` | 校验+热切换设定包，应用覆盖/注入词条/广播 |
| `GetData(fileName)` | 当前设定包数据文件（服务端+客户端，SafeName 防穿越） |
| `GetActiveId()` / `SendStateTo(ply)` | 当前包 / 单发同步 |

### G4 Voice — `sh_voice.lua` + `sv_voice.lua`
| 函数 | 说明 |
|---|---|
| `GetChannel(channelId)` | 频道定义（设定包优先，内置 local 回退） |
| `GetChannelKind(channelId)` | local/squad/command/all |
| `SetChannel(ply, channelId)` | 校验准入后切换（服务端） |
| `GetPlayerChannel(ply)` / `GetModel()` / `GetPresets()` | 查询 |

### G5 Squad — `sv_squad.lua` 写 + `sh/cl` 读
`Create / Join / Leave / Disband / Kick / SetLocked / SetReady`（写）；`GetAll / GetById /
GetByFaction / GetPlayerSquad / GetPlayerRole / AreInSameSquad / GetMemberCount / IsFull`（读）；
客户端缓存 `GetCachedSquads / GetMySquad / IsMySquadLeader`。

### G6 Commander — `sv_commander.lua` + `cl_commander.lua`
`Volunteer(ply)` / `Vote(ply,targetIdx)` / `Relinquish(ply)`（写）；`GetFactionCommander(faction)`
/ `IsFactionCommander(ply)`（服务端权威）；客户端缓存 `GetClientState / GetCachedFactionCommander /
GetElectionSecondsLeft`。注：无 `Start`，选举入口是 `Volunteer`（自动触发）。

### G7 Marker — `sv_marker.lua` + `sh_marker.lua`
`Add(ply, pos, type, label, opts)`（opts.factionWide=true 限指挥官阵营广播）/ `Remove(ply, markerId)`
（owner/队长/指挥官分权）；`GetAll / GetBySquad / GetByFaction / SyncToSquad / SyncToFaction`；
`GetTypeColor(markerType)` 共享。

### G8 Vitals — `sv_vitals.lua` + `sh_vitals.lua`
`GetParam(name)`（三级解析）/ `GetState(ply)` / `IsDowned(ply)` / `RecalcSpeed(ply)` /
`Reset(ply)` / `BroadcastAll` / `IsEnabled()`；共享纯函数 `ScaleHitgroupDamage / AddBleedStack /
BleedTickDamage / ResolveRescueKind / DefaultLimbs / HitgroupToPart / ApplyPartDamage`。

### G9 Rounds — `sh_rounds.lua` + `sv_rounds.lua`
`GetState()` / `RegisterObjective` / `RegisterScenario`（见 F）/ `ResolveScenario` /
`GetScenario(id)` / `GetObjectiveTemplates()` / `GetPackConfig()` / `GetTimings()` /
`IsEnabled()` / `GetPlayerFaction` / `GetActiveFactions` / `GetEntityFaction` /
`GetScenarioSpawns(fid)` / `ResolvePos(spec)`；服务端 `SendSnapshotTo / AdminAdvance /
AdminEnd(winner) / IsRespawnBlocked / GetModeInfo / GetObjectivePos`。

### G10 Inventory — `sv_inventory.lua` + `sh_inventory.lua`
`RegisterUseHandler(category, fn)`（关键扩展：医疗品/弹药等使用效果挂接）/ `Add(ply,itemId,delta)`
/ `GrantForSlot(ply,slotName,factionId)` / `Get / GetAll / Consume / Reset / TryUse /
RegisterItem / GetItemDef / GetAllItemDefs / ResolveSlotItems / BuildLoadoutPlan / ApplyDelta /
GetItemSize / CanPlaceCells / FindFreeSpot`。

### G11/G12 WeaponInterface / VehicleInterface
`Register(data)`（由适配器调用，校验 base 后入缓存）/ `Get(className)` / `GetAll()` /
`FilterByTags(required, banned)` / `FilterByCategory` / `FilterByRole`（载具）；`RunDiscovery()`
清空后 `hook.Run(HOOKS.WEAPON_DISCOVER / VEHICLE_DISCOVER, cache)`。

---

## H. HOOKS 命名空间（`Fireteam.HOOKS.*`，定义于 `core/sh_constants.lua`）

第三方用 `hook.Add(Fireteam.HOOKS.X, "MyAddon.Tag", fn)` 消费。常用：

| Hook | 回调参数 | 说明 |
|---|---|---|
| `Weapon.Discover` / `Vehicle.Discover` | cache 表 | 适配器注册点（见 G11/G12） |
| `Class.Assigned` | ply, classId | 职业分配完成 |
| `Rounds.StateChanged` | old, new, round | 回合状态切换 |
| `Rounds.Ended` | winner, reason, scores | 回合结算 |
| `Rounds.ScenarioChanged` | newScenarioId | 剧本切换（下回合生效） |
| `Vitals.StateChanged` | ply, old, new | normal/downed/dead |
| `Commander.Changed` | faction, newCmd\|nil | 指挥官就任/腾位 |
| `Vote.Started/Passed/Failed` | 见 vote 模块 | 投票生命周期 |
| `Squad.PlayerJoined/Left` | ply, squad | 小队成员变动 |
| `Marker.Added` | marker | 新标记 |
| `Config.Changed` | key, old, new | 配置变更 |
| `Locale.Changed` | lang | 语言切换 |
| `Inventory.ItemUsed` | ply, itemId | 消耗品使用成功 |
| `Voice.ChannelChanged` | ply, channelId | 语音频道切换 |
| `Seats.Entered/Left` | ply, vehicle | 进出载具 |
| `PvE.BotKilled` | bot, attacker | AI 阵亡归功 |
| `AI.Deployed` | bot | AI 部署完成 |

完整列表见 `core/sh_constants.lua` 的 `Fireteam.HOOKS` 表。

---

## I. 网络消息（`Fireteam.NET.*`）

`core/sh_constants.lua` 的 `Fireteam.NET` 表。新增自定义消息必须在此登记并
`util.AddNetworkString`。常用：

| 常量 | 方向 | 内容 |
|---|---|---|
| `CONFIG_SYNC` | S→C | 配置同步 |
| `SETTING_CHANGED` | S→C | packId, packName |
| `HUD_THEME` | S→C | 主题 ID |
| `ROUNDS_STATE` | S→C | 回合快照 |
| `SQUAD_UPDATE` | S→C | 小队全量快照 |
| `COMMANDER_UPDATE` | S→C | 指挥官+选举态 |
| `VOTE_START/UPDATE/RESULT` | S→C | 投票开始/票数/结果 |
| `INVENTORY_SYNC` | S→C | 背包快照 |
| `VITALS_UPDATE` | S→C | 体征快照 |
| `CLIENT_READY` | C→S | 客户端加载完成 |
| `CLASS_ASSIGN` | C→S↔ | 职业分配 |
| `MARKER_PLACE/REMOVE` | C→S | 标记放/删 |
| `SQUAD_CREATE/JOIN/LEAVE/READY/KICK/LOCK` | C→S | 小队操作 |
| `COMMANDER_ACTION` | C→S | 志愿/投票/让位 |
| `VOTE_CAST` | C→S | 投票 |
| `ITEM_USE/MOVE/DROP` | C→S | 背包操作 |
| `ADMIN_ACTION` | C→S | 管理面板 |

---

## J. 扩展指南（新增自定义内容）

### J1. 新武器/载具适配器
```lua
-- 守卫：基座不存在即返回
if not MYBASE then return end

hook.Add(Fireteam.HOOKS.WEAPON_DISCOVER, "MyAddon.WeaponAdapter", function(cache)
    for _, swep in ipairs(weapons.GetList()) do
        if swep.MYBASE then
            Fireteam.WeaponInterface.Register({
                base = swep.ClassName, displayName = swep.PrintName,
                tags = { "nato", "coldwar_west", "rifle" },
                category = Fireteam.WEAPON_CATEGORY.RIFLE,
            })
        end
    end
end)
```
载具同理用 `VEHICLE_DISCOVER` + `Fireteam.VehicleInterface.Register`。注意 `RunDiscovery`
会先清空缓存再跑钩子，监听器须每次重枚举并注册。

### J2. 自定义消耗品用途
```lua
Fireteam.Inventory.RegisterUseHandler(Fireteam.INVENTORY_CATEGORY.CONSUMABLE,
    function(ply, itemId, itemDef)
        if itemId ~= "my_item" then return false end
        -- ... 返回 true 表示已消费
        return true
    end)
```

### J3. 新模块
在 `modules/<name>/` 建立 `sh_/sv_/cl_` 三件套（模块加载器自动发现）；共享常量放 `sh_`；
暴露给第三方的函数挂到 `Fireteam.API.<Module>` 或直接 `Fireteam.<Module>`；自定义网络消息
文件加载期 `util.AddNetworkString`；客户端读设定包数据走网络同步或
`Fireteam.HUD.GetTheme()` 这类带客户端路径回退的封装，禁止直接读 `Setting.Discovered`。

---

## K. 重要既有约定 / 陷阱

- **API 名与直调名的差异**：`docs` 旧版记载的 `Fireteam.API.Squad.Create` /
  `Marker.Place` / `Class.Select` / `Config.RegisterDefault` **已不存在**。现为
  `Fireteam.Squad.Create(ply,name,faction)` / `Marker.Add(...)` / `API.AssignClass` /
  `Config.Register(key,default,opts)`。按本文档为准。
- **`RegisterObjective` 不走 Fireteam.API 表**：直接在 `Fireteam.Rounds.RegisterObjective(id,def)`。
- **客户端禁读 `Setting.Discovered`**：必须走网络同步或带客户端回退路径的封装。
- **`Squad.members` 的 key 是 Player**，不是 id 索引数组；查询用 `GetSquadMembers(squadId)`。
- **API 无管理员校验**：面玩家的入口在校验，服务端直调 API 信任调用方。

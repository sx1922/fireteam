# FIRETEAM 设定包模板（自制模式指南）

复制本目录开始做你自己的模式：

```bash
cp -r setting_packs/_template setting_packs/my_setting
# 编辑 pack.json 的 id/name，再按下面契约填各数据文件
# 服务器执行 ft_setting_pack my_setting（支持运行时热切换）
```

调试利器：**F9 设定包编辑器**（可视化改本包全部数据并导出 JSON）、F10 配置页、`ft_debug 1` 日志。

## 文件一览

| 文件 | 作用 | 必填 |
|---|---|---|
| pack.json | 元数据（id/name/era/推荐插件/配置覆盖） | ✅ |
| factions.lua | 阵营定义 | ✅ |
| classes.lua | 职业 + 装备槽位 + 属性 | ✅ |
| weapons.lua | 武器池规则（Tag 过滤） | ✅ |
| items.lua | 物品/消耗品定义 | ⚠️ 可选 |
| vehicles.lua | 载具规则 | ⚠️ 可选 |
| voice_presets.lua | 语音频道结构 | ⚠️ 可选 |
| hud_theme.json | HUD/UI 主题（换包即换皮） | ⚠️ 可选 |
| map_rules.lua | 地图规则 + 回合任务 + 剧本 + PvE + 体征参数 | ⚠️ 可选 |

> JSON 文件不支持注释，所有字段说明见本文档对应章节。

## 核心原则：Tag 驱动

**永远不要写死武器类名**。武器/载具通过 Tag 匹配（ARC9/TFA 等工坊武器的标签）：

```
职业 loadout 声明 tags → WeaponInterface.FilterByTags 在已发现武器里筛选 → 随机 Give 一把
                                                    ↓ 无命中
                                     回落 Inventory.GrantForSlot 发该槽位物品
```

- 标签全部小写英文+下划线；建议 `你的包名_武器类型` 双标签（如 `my_era assault_rifle`）
- 阵营 `allowed_tags` / `banned_tags` 必须互斥
- 工坊武器打什么标签：装上后游戏内查看，或查该武器 addon 的说明

## factions.lua — 阵营

```lua
faction_alpha = {
    name / name_zh,              -- 显示名（中文客户端用 name_zh）
    icon,                        -- 徽章路径 materials/fireteam/factions/xxx.png（512² PNG）
    color = Color(r,g,b),        -- 阵营色：左上战局块比分色点 / 结算屏高亮
    allowed_tags / banned_tags,  -- 装备准入（互斥！）
    voice_pack,                  -- 语音目录（预留）
    default_squad_size,          -- 默认小队上限
    command_structure,           -- "flat" | "squad_leader" | "commissar" | "officer"（指挥链风格）
    lore / lore_zh,              -- 可选：阵营背景设定（coldwar 包示例）
}
```

## classes.lua — 职业

```lua
rifleman_alpha = {
    name / name_zh, icon,
    faction = "faction_alpha",   -- 必须是 factions.lua 里的 key
    loadout = {
        primary   = { tags = {...}, count = 1 },       -- 槽名任意；武器 Tag 匹配优先
        secondary = { tags = {...}, count = 1, optional = true },
        grenade   = { tags = {...}, count = 2 },       -- 无武器命中 → 按 items.lua 的 slots 发物品
    },
    stats = {
        speed_mult = 1.0,        -- 移速倍率（200/400 基准；经 vitals.RecalcSpeed 收口）
        armor = 1,               -- 0~3：护甲值 = ×25，最大生命 = 100 + ×10
        stamina = 100,           -- 体力上限（冲刺消耗/力竭）
        radio_access = true,     -- 预留：电台准入
        radio_channels = { "squad", "command" },  -- 预留：可收频道
    },
    abilities = { "mark_target", "call_medical", "issue_orders" },  -- 展示用能力标签
}
```

职业 id 命名建议 `角色_国家/阵营`（如 `squad_leader_usa`）——**语音频道 access 权限按职业 id 列表校验**。

## weapons.lua / vehicles.lua — 池规则

- `global_filter`：全包硬过滤（时代标签 + 禁用标签）
- `pools.<faction>`：按阵营的准入 tags 与数量上限
- `restrictions`：附件/弹药限制

## items.lua — 物品（网格背包）

```lua
bandage = {
    name / name_zh,
    category = "consumable",   -- consumable 读完条生效（效果由模块 RegisterUseHandler 注册；
                               --   vitals 已注册 bandage/splint/analgesic/medkit 医疗效果）
                               -- throwable 投掷物（需 throw 表，框架内置抛掷）
                               -- deployable 放置物（resupply 注册弹药盒）
    slots = { "medical" },     -- 可服务的职业槽位（classes.lua loadout 的键）
    factions = {...},          -- 可选：仅列出的阵营可获得
    max_carry = 6,             -- 持有上限
    amount_per_slot = 4,       -- 该槽位发放数量
    use_time = 2.5,            -- 使用读条秒数
    size = { w = 2, h = 1 },   -- 背包网格占格（缺省 1×1；10×6 网格）
    icon = "fireteam/items/xxx.png",  -- 预留：物品图标
}
```

## voice_presets.lua — 语音频道

```lua
channels = {
    ["local"] = {              -- 地区频道：距离内所有人可听（3D 人声）
        name / name_zh, kind = "local", range = 800, access = "all" },
    squad =    { kind = "squad",   range = 500 },  -- 仅本小队
    command =  { kind = "command", range = 2000,   -- 同阵营；access = 职业id列表（队长/通讯员）
                 access = { "squad_leader_usa", ... } },
    emergency ={ kind = "all",     range = 1000, access = "all" },  -- 全服
},
```

- `kind` 四值决定收听分流：`local` 距离人声 / `squad` 小队网 / `command` 指挥网 / `all` 全服；
  旧包不写 kind 时按频道 id 推断（向后兼容）
- 切换键默认 V/B/G（`voice.key_local/squad/command` 可改）；range ≤ 0 视为不限距
- 不声明 `["local"]` 时框架内置兜底

## hud_theme.json — 主题（换包即换皮）

- `palette`：20 个语义色（面板/文字/阵营/标记六类），UI 全部经语义名取色
- `font`：主字体 + 等宽 fallback + 基准字号
- `effects`：scanlines / flicker / vignette / grain（CRT 特效开关与强度）
- `elements`：HUD 元素锚点，`position` 可选
  `top_left / top_center / top_right / left / right / bottom_left / bottom_center / bottom_right`
  - `compass` bearing tape 罗盘（默认 bottom_center）
  - `round_info` 左上战局状态块
  - `squad_status` 左下小队栏（bottom_left 时自动堆叠在血量块上方）
  - `health` 自身血量（贴底）/ `ammo` 右下弹药 / `consumables` 消耗品行
  - `stamina` 体力条 / `radio_indicator` 电台面板（主题未定义则不渲染）
  - `limbs` 黑肢/骨折指示 / `map` 战术地图 style+open_key

## map_rules.lua — 地图规则 / 回合 / 剧本 / PvE / 体征

文件内注释已最全，要点：

- `rounds.enabled` + 目标四类型 `hold_zone / destroy_entity / extract / eliminate`
- **多剧本**：`scenarios` 表 + `default_scenario`；`ft_scenario <id>` 或 F10 切换，下一回合生效
- **PvE 战役**：剧本内 `pve` 表（player_factions / ai_factions / ai_behavior=advance|defend /
  bots_per_faction）；管理员 `ft_mode pve` 切换，目标逐关推进
- **体征参数**：剧本 `vitals` 表 > 包级 `map_rules.vitals` > config 三级解析，可覆盖
  `enabled / head_mult / max_bleed_stacks / bleedout_time / revive_time / limbs_enabled /
  fracture_chance / painkiller_time / leg_speed_mult ...`（全表见 F10 配置页搜索 vitals）
- 出生点 `spawns.<faction>`：绝对坐标或 `{ anchor="map_center", offset={x,y,z} }`

## 图标资源约定

| 资源 | 路径（相对 `content/materials/`） | 规格 |
|---|---|---|
| 阵营徽章 | `fireteam/factions/<id>_badge.png` | 512² 透明 PNG |
| 职业图标 | `fireteam/classes/<角色>.png`（华约式换色加 `_e`） | 128–256 |
| 物品图标 | `fireteam/items/<itemId>.png`（预留） | 128 |
| 包封面 | pack.json `icon` 字段 `materials/fireteam/packs/xxx.png` | 256² |

图标缺失时 UI 自动回退文字显示，不阻塞使用。

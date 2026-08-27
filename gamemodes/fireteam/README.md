# FIRETEAM — Garry's Mod 战术小队框架

<p align="center">
  <strong>模块化 · 设定包驱动 · 多基座适配</strong><br>
  一个不绑定具体游戏循环的战术小队底层框架
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.1.0--alpha-orange" alt="version">
  <img src="https://img.shields.io/badge/GMod-250814%2B-blue" alt="gmod">
  <img src="https://img.shields.io/badge/Lua-5.1-green" alt="lua">
  <img src="https://img.shields.io/badge/status-alpha-yellow" alt="status">
</p>

## 目录

- [概述](#概述)
- [核心理念](#核心理念)
- [功能模块](#功能模块)
- [架构总览](#架构总览)
- [安装部署](#安装部署)
- [快速开始](#快速开始)
- [设定包系统](#设定包系统)
- [适配器支持](#适配器支持)
- [按键操作](#按键操作)
- [配置项一览](#配置项一览)
- [目录结构](#目录结构)
- [开发路线](#开发路线)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

## 概述

FIRETEAM 是一个 Garry's Mod 战术小队游戏模式框架。它提供：

- 🎯 **小队管理** — 创建、加入、解散、角色分配
- 🪖 **职业系统** — 基于 Tag 的装备匹配，不写死武器类名
- 🗺️ **标记系统** — 路点、敌人、目标点标记与同步
- 📻 **语音通讯** — 频道制语音，支持干扰/距离衰减
- ⏱️ **回合制引擎** — 状态机 + 目标接口（占区/摧毁/撤离/歼灭）+ 计分，支持多剧本切换
- 🛰️ **战术地图** — M 键程序化"纸质图纸"地图，与标记系统联动
- 🤖 **AI 队友** — NextBot 跟随/驻守/自主交战，响应路点指令与回合补位
- 👻 **观察者模式** — 阵亡后旁观队友（第一/第三/自由视角），回合制联动
- 🎨 **HUD 主题** — 可配置的界面风格（CRT / 纸质 / 现代）
- 💥 **弹道模拟** — 子弹下坠、伤害衰减
- 😰 **压制系统** — 屏幕模糊、准星扩散、视觉震动
- 🔌 **适配器层** — 自动识别 ARC9 / TFA / LVS / Simfphys
- 🧰 **运维工具** — F10 管理面板 + F9 可视化设定包编辑器

> ⚠️ FIRETEAM 是**框架**，不是完整游戏模式。它提供战术小队的基础设施，
> 具体的玩法循环（夺旗、攻防、合作 PvE）由上层逻辑或设定包定义。

## 核心理念

| 原则 | 说明 |
| --- | --- |
| Tag 驱动 | 武器/载具通过标签匹配，不硬编码类名 |
| 设定包隔离 | 所有数据（阵营/职业/武器池）封装在设定包中，热切换 |
| 模块即插即用 | 每个功能独立目录，`sh_`/`sv_`/`cl_` 三件套自动加载 |
| 适配器模式 | 第三方武器/载具基座通过适配器桥接，框架不依赖任何特定 addon |
| 零配置可用 | 默认 coldwar 设定包开箱即跑 |

## 功能模块

| 模块 | 路径 | 说明 |
| --- | --- | --- |
| Squad | `modules/squad/` | 小队 CRUD、队长转移、就绪状态 |
| Class | `modules/class/` | 职业分配、属性应用、装备加载 |
| Marker | `modules/marker/` | 标记放置/移除/过期、3D 渲染 |
| Voice | `modules/voice/` | 频道切换、距离/权限拦截 |
| Rounds | `modules/rounds/` | 回合状态机、目标类型（占区/摧毁/撤离/歼灭）、计分、多剧本解析 |
| TacMap | `modules/tacmap/` | M 键战术地图、世界坐标投影、点击放置路点 |
| Spectate | `modules/spectate/` | 阵亡旁观队友（第一/第三/自由视角）、回合联动 |
| Seats | `modules/seats/` | 载具座位职业门槛、上车提示、车载电台 |
| AI | `modules/ai/` | NextBot AI 队友：跟随/驻守/交战、回合补位 |
| PvE | `modules/pve/` | PvE 战役模式：AI 敌军阵营生成、推进/驻防行为、战役关卡机 |
| Admin | `modules/admin/` | F10 管理面板：配置 / 回合控制 / 玩家总览 / 设定包切换 / 冷战情景预设工具 |
| PackEditor | `modules/packeditor/` | F9 设定包可视化编辑（schema 表单）、JSON 导出 |
| HUD | `modules/hud/` | 准星、弹药、生命、指南针、特效 |
| Ballistics | `modules/ballistics/` | 子弹下坠、伤害衰减 |
| Suppression | `modules/suppression/` | 压制值累积/衰减、视觉效果 |
| Inventory | `modules/inventory/` | 消耗品栏：物品定义数据驱动、职业槽位统一解析（武器优先→物品回落）、手雷投掷物、HUD 芯片栏 |
| Vitals | `modules/vitals/` | 健康与医疗：部位倍率伤害、出血累积、倒地濒死（稳定/复活/补刀）、体征 HUD |
| Stamina | `modules/stamina/` | 体力：职业上限冲刺消耗/滞回力竭、移速惩罚、低体力开火抖动 |
| Resupply | `modules/resupply/` | 弹药与补给：备弹池补满、可放置弹药盒（N 次使用）、尸体搜刮 |
| MainMenu | `modules/mainmenu/` | ESC 主菜单：引擎菜单接管、战局状态、各面板聚合入口 |
| Adapters | `modules/adapters/` | ARC9 / TFA / LVS / Simfphys 桥接 |

## 架构总览

```
┌─────────────────────────────────────────────────┐
│                  游戏逻辑层                       │
│         (玩法循环 / 任务 / 胜负判定)              │
├─────────────────────────────────────────────────┤
│              FIRETEAM 框架核心                    │
│  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────────┐  │
│  │ Squad │ │ Class │ │Marker │ │   Voice   │  │
│  └───┬───┘ └───┬───┘ └───┬───┘ └─────┬─────┘  │
│      │         │         │           │         │
│  ┌───┴─────────┴─────────┴───────────┴─────┐  │
│  │         Config / Net / API Registry      │  │
│  └───────────────────┬─────────────────────┘  │
│                      │                         │
│  ┌───────────────────┴─────────────────────┐  │
│  │     Weapon Interface / Vehicle Interface │  │
│  └───────────────────┬─────────────────────┘  │
├──────────────────────┼─────────────────────────┤
│              适配器层 (Adapters)                 │
│   ARC9 │ TFA │ LVS │ Simfphys │ 自定义...      │
├─────────────────────────────────────────────────┤
│              设定包 (Setting Packs)              │
│   coldwar │ _template │ 自定义...               │
└─────────────────────────────────────────────────┘
```

## 安装部署

### 方式一：直接放入（推荐开发期）

```
garrysmod/
├── gamemodes/
│   └── fireteam/          ← 整个目录放这里
│       ├── fireteam.txt
│       ├── gamemode/
│       └── setting_packs/
```

### 方式二：Addon 打包（推荐分发）

使用 gmad 工具打包。**必须在 `gamemodes/` 目录执行并带 `-folder fireteam`**，
让 GMA 内保留 `gamemodes/fireteam/` 路径前缀——gamemode 的模块/语言/主题加载器
按该前缀做 file.Find，从 fireteam 目录内部打包会导致运行时找不到文件：

```bash
cd garrysmod/gamemodes
gmad create -folder fireteam -name "FIRETEAM" -out "fireteam.gma"
```

### 验证

启动 GMod → 新建游戏 → 模式列表中出现 "FIRETEAM" → 选择进入。

控制台应依次输出：

```
[FIRETEAM] ✓ Shared environment initialized
[FIRETEAM] ✓ Constants loaded (v0.1.0-alpha)
[FIRETEAM] ✓ Config registry ready (12 keys)
[FIRETEAM] ✓ Module loader ready
[FIRETEAM] ✓ Setting loader ready
[FIRETEAM] Discovered 8 module(s)
[FIRETEAM] ✓ Setting pack active: Iron Curtain Germany (v1.2.0)
[FIRETEAM] ✓ Bootstrap complete
```

## 快速开始

服务端控制台：

```bash
# 切换设定包
ft_setting_pack coldwar

# 开启调试日志（0=关 1=基础 2=详细）
ft_debug 1

# 回合控制（管理员）
ft_round_next          # 进入下一阶段
ft_round_end [阵营|draw]  # 结束回合，缺省按比分结算

# 剧本切换（下一回合简报生效，不打断进行中的回合）
ft_scenario            # 列出当前设定包的可用剧本
ft_scenario berlin     # 切换到指定剧本（也可在 F10 配置页修改 rounds.scenario）

# 模式切换（PvP 对战 / PvE 战役，下一回合生效）
ft_mode                # 查看当前模式与用法
ft_mode pve            # 切到 PvE 战役；ft_mode pvp 切回 PvP

# AI 队友
ft_ai_add [数量]        # 部署 AI 队友（需在小队中）
ft_ai_remove           # 回收全部 AI 队友
ft_ai_stance follow|hold  # 切换跟随/驻守姿态
ft_ai_fill [人数]       # （管理员）全体小队补位
```

游戏内操作：

1. 按 **F7** 打开小队面板 → 创建或加入小队
2. 按 **F8** 选择职业 → 自动分配装备
3. 按 **F6** 在准星位置放置标记（路点/集合点会指挥 AI 队友机动）
4. 按 **M** 打开战术地图；按 **F10** 管理员面板；按 **F9** 设定包编辑器（管理员）
5. 语音默认走小队频道，无需额外操作

## 设定包系统

设定包是 FIRETEAM 的数据层，定义了"玩什么"。

### 结构

```
setting_packs/your_pack/
├── pack.json          # 元数据（必须）
├── factions.lua       # 阵营定义
├── classes.lua        # 职业 + 装备槽位
├── weapons.lua        # 武器池规则
├── vehicles.lua       # 载具规则（可选）
├── voice_presets.lua  # 通讯频道（可选）
├── hud_theme.json     # UI 主题（可选）
└── map_rules.lua      # 地图规则（可选）
```

### 内置设定包

| ID | 名称 | 时代 | 通讯模型 |
| --- | --- | --- | --- |
| coldwar | Iron Curtain Germany | 1968–1985 | 模拟电台 |
| _template | 空白模板 | — | — |

coldwar 包内置 8 个现实国家阵营：北约的美国/英国/西德/法国，华约的苏联/东德/波兰/捷克斯洛伐克。各国独立职业表（华约含政委）、武器与载具池、按语言区分的语音包和侧翼出生带，每国 `lore` 字段记录其在想定中的历史角色。

内置两个可切换剧本（`ft_scenario <id>` 或 F10 管理面板切换，下一回合简报生效）：

- **fulda_gap 富尔达缺口**（默认）——北约西翼防御带对华约东翼突击轴的全线会战。目标轮转：阿尔法点哨所占区 → 巴特黑斯费尔德中继站摧毁 → 金齐希河谷撤离 → 福格尔斯贝格背水一战。
- **berlin 西柏林之战**——美英法三国守军紧凑中央防区，西德远郊解围，苏军/东德东弧主攻、波/捷第二梯队。城市攻坚节奏更快（简报 8s / 回合 7min）。目标轮转：查理检查站突破 → 瘫痪守军通讯 → 滕珀尔霍夫空运撤出 → 驻军最后抵抗。

两个剧本均内置 PvE 战役配置（剧本内 `pve` 表）：管理员 `ft_mode pve` 切换后，玩家方执攻/守一侧，其余阵营由 AI NextBot 驱动——富尔达缺口为北约守方对抗华约四国推进，西柏林为苏/东德攻方对抗三国驻军固防。PvE 下目标按表顺序逐关推进（过关进下一关、失败重试本关、通关后回到第 1 关），进度显示在 F10 回合页。

旧版平铺 `objectives`/`spawns` 结构仍受支持：不声明 `scenarios` 表时作为隐式单剧本照常运行。

### 自定义设定包

```bash
# 复制模板
cp -r setting_packs/_template setting_packs/my_setting

# 编辑 pack.json 中的 id 和 name
# 编辑各数据文件

# 服务器执行
ft_setting_pack my_setting
```

### 热切换

设定包支持运行时切换，无需重启服务器：

```bash
ft_setting_pack another_pack
```

切换时自动触发 `Fireteam.Setting.Unload` → `Fireteam.Setting.Loaded` 钩子。

## 适配器支持

| 基座 | 适配器文件 | 检测方式 |
| --- | --- | --- |
| ARC9 | `sv_arc9_adapter.lua` | `if ARC9 then` |
| TFA Base | `sv_tfa_adapter.lua` | `if TFA then` |
| LVS | `sv_lvs_adapter.lua` | `if LVS then` |
| Simfphys | `sv_simfphys_adapter.lua` | `if simfphys then` |

适配器在对应基座不存在时静默跳过，不会报错。

### 编写自定义适配器

```lua
-- modules/adapters/sv_mybase_adapter.lua
hook.Add(Fireteam.HOOKS.WEAPON_DISCOVER, "FIRETEAM.MyBaseAdapter", function()
    for className, data in pairs(myBaseWeaponList) do
        Fireteam.WeaponInterface.Register({
            base        = className,
            displayName = data.Name,
            tags        = { "my_base", "nato", "assault_rifle" },
            category    = Fireteam.WEAPON_CATEGORY.RIFLE,
            -- ...
        })
    end
end)
```

## 按键操作

| 按键 | 功能 |
| --- | --- |
| ESC / F4 | 主菜单（战局状态 + 各面板入口） |
| F6 | 在准星位置放置标记 |
| F7 | 打开小队管理面板 |
| F8 | 打开职业选择面板 |
| H | 显示/隐藏左下角小队栏（仅影响自己） |
| V / B / G | 切换语音频道：地区（近距人声）/ 小队 / 指挥 |
| Tab | 打开网格背包（默认计分板已让位） |
| 7/8/9/0 | 使用快捷栏绑定物品 |
| M | 打开战术地图 |
| CapsLock | 全屏指挥视图（大地图 + 队伍情况） |
| F9 | 设定包编辑器（管理员） |
| F10 | 管理面板：配置 / 回合控制 / 玩家总览 / 设定包切换（管理员） |

## 主菜单与指挥视图

- **ESC 主菜单**：拦截引擎菜单（`gui.IsGameUIVisible` + `gui.HideGameUI`），弹出 FIRETEAM 主面板——当前剧本/模式/回合状态 + 小队、职业、背包、地图、指挥视图、管理面板入口。F4 等效。单人模式下 ESC 的引擎暂停语义被接管，游戏不会暂停。
- **CapsLock 指挥视图**（模仿《战术小队》队伍界面）：全屏左右分栏——左侧大地图（复用战术地图投影，含队友朝向/名字、小队标记、回合目标圈，可点击放路点），右侧队伍情况栏（成员存活/血量条/职业/倒地红显/队长菱形）。

## 语音频道（战术小队式三频道）

| 频道 | 切换键 | 收听范围 |
| --- | --- | --- |
| 地区 Local | V | 距离内所有人（3D 人声，`voice.distance_max`） |
| 小队 Squad | B | 仅本小队成员，频道 range 内 |
| 指挥 Command | G | 同阵营全部成员（需职业权限：队长/通讯员/政委） |

说话者名牌显示在屏幕左侧（喇叭图标按频道着色：地区白 / 小队绿 / 指挥黄），结束后 2 秒淡出；左下电台指示器显示当前频道名。频道结构由设定包 `voice_presets.lua` 的 `channels` 声明（`kind = local|squad|command|all`），切换键经 `voice.key_local / voice.key_squad / voice.key_command` 配置改绑——若与引擎默认语音键（设置 → 键盘 → 语音）冲突，改绑其一即可。

## 配置项一览

| 键名 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `voice.model` | string | `analog_radio` | 通讯模型 |
| `voice.distance_max` | number | `800` | 最大语音距离 |
| `voice.interference` | boolean | `true` | 地形干扰 |
| `hud.theme` | string | `crt_green` | HUD 主题 |
| `ballistics.bullet_drop` | boolean | `true` | 子弹下坠 |
| `ballistics.suppression_mult` | number | `1.0` | 压制倍率 |
| `marker.style` | string | `chalk` | 标记样式 |
| `marker.max_per_player` | number | `3` | 每人最大标记数 |
| `squad.max_size` | number | `6` | 小队上限 |
| `squad.friendly_fire` | boolean | `false` | 友军伤害 |
| `rounds.enabled` | boolean | `true` | 回合系统总开关（仍需设定包提供任务数据） |
| `rounds.scenario` | string | `""` | 剧本选择（空 = 按设定包 default_scenario；下一回合简报生效） |
| `rounds.mode` | string | `pvp` | 对战模式：`pvp` 玩家对战 / `pve` PvE 战役（F10 下拉或 ft_mode） |
| `pve.bots_per_faction` | number | `4` | PvE 每 AI 阵营 bot 数 |
| `pve.max_bots` | number | `24` | PvE 场上 AI bot 总数上限 |
| `tacmap.enabled` | boolean | `true` | 战术地图（M 键） |
| `tacmap.grid_step` | number | `1024` | 地图网格步长（世界单位） |
| `tacmap.allow_click_place` | boolean | `true` | 点击地图放置路点 |
| `seats.enabled` | boolean | `true` | 载具座位职业门槛与交互提示 |
| `seats.prompt_distance` | number | `160` | 上车提示触发距离 |
| `spectate.enabled` | boolean | `true` | 死亡后旁观队友 |
| `ai.enabled` | boolean | `true` | AI 队友总开关 |
| `ai.max_per_player` | number | `2` | 每名玩家 AI 队友上限 |
| `ai.autofill_size` | number | `0` | 回合开始自动补位目标人数（0=关闭） |
| `packeditor.enabled` | boolean | `true` | F9 设定包编辑器开关 |
| `hud.squad_panel` | boolean | `true` | 左下小队栏总开关（玩家还可用 H 键本地切换） |
| `hud.show_fps` | boolean | `false` | 左上角 FPS 计数 |
| `voice.ambience` | boolean | `true` | 电台氛围音（咔嗒/静噪） |
| `voice.key_local` | string | `V` | 地区频道切换键 |
| `voice.key_squad` | string | `B` | 小队频道切换键 |
| `voice.key_command` | string | `G` | 指挥频道切换键 |
| `vitals.limbs_enabled` | boolean | `true` | 塔科夫式七部位血量模型 |
| `vitals.fracture_chance` | number | `0.25` | 腿部受击骨折概率（打黑必骨折） |
| `vitals.painkiller_time` | number | `60` | 止痛药持续秒数（屏蔽腿瘸/臂晃） |
| `vitals.medkit_heal_frac` | number | `0.5` | 医疗包恢复部位血量比例 |
| `vitals.enabled` | boolean | `true` | 倒地/出血系统总开关（false = 原版即死） |
| `vitals.bleedout_time` | number | `60` | 倒地失血时限（秒） |
| `vitals.revive_time` | number | `7` | 医疗兵复活读条（消耗 medkit） |
| `vitals.finish_damage` | number | `25` | 补刀倒地单位所需单次伤害 |

## HUD 布局（战术小队风格）

HUD 元素位置全部由设定包 `hud_theme.json` 的 `elements.*.position` 锚点驱动，换包即换皮：

```
┌ 左上：战局状态块          底部中央：bearing tape 罗盘
│  剧本·状态·回合号         N ··· 030 ··· E ···（15° 刻度数字）
│  倒计时+阵营比分色点       087°（中央白框高亮当前角度）
│  目标 + 进度条            ▲队友 ◆路点 □目标 方位投影
│
│ 左下：小队栏              右下：弹药（大号弹匣数/备弹/武器名）
│  (2) 队名
│  ● ◆ 张三  ▓▓▓▓
│  ●    李四  ▓▓░░
│ HP ▓▓▓▓▓░░（血量贴底）
```

小队栏显示小队编号徽章、存活状态点、队长菱形标与各成员血量条；按 **H** 可本地隐藏。准星扩散响应移动（蹲姿收敛）与压制。

## 网格背包（塔科夫式）

**Tab** 开合背包面板（默认计分板已让位）：

- 右侧 **10×6 网格**：物品按占格渲染（`items.lua` 的 `size={w,h}`，缺省 1×1——医疗包 2×1、弹药盒 2×2），**拖拽换位**（服务端碰撞校验，非法落点回弹）、拖出面板无效；**双击使用**、**右键菜单**（使用 / 丢弃一件 / 绑定快捷栏）
- 左侧：当前武器列表 + **七部位健康检查**（血量条 + 骨折标记，与 P6a 联动）
- 底部/屏幕快捷栏 **4 槽**：右键物品绑定后按 **7/8/9/0** 直接使用；背包满时新物品自动截断发放
- 丢弃为直接销毁（落地拾取实体列后续）

## 分部位健康（塔科夫式）

七部位独立血量：头部 35 / 胸腔 85 / 腹部 70 / 双臂 60 / 双腿 65（`hud_theme` 无关，数值经 `vitals.*` 配置或设定包 `vitals` 块覆盖）：

- 已打黑部位的伤害**整笔转移胸腔**；头部或胸腔打黑 = 立即死亡（不走倒地）
- 腹部打黑 = 出血拉满持续掉血；腿部打黑必骨折、受击有概率骨折 → 移速大幅下降（单腿 ×0.55 / 双腿 ×0.35）
- 手臂打黑 → 开火扩散增大（准星晃动）；**止痛药**限时屏蔽腿瘸与臂晃
- 医疗品真实生效：**绷带**止血、**夹板**修骨折并恢复黑腿部分血量、**止痛药**镇痛、**医疗包**全体位恢复 + 清出血
- 屏幕左侧显示黑肢/骨折状态（止痛药生效中会有绿色提示）；速度结算由 class/stamina/vitals 三模块统一收口，互不覆盖

## 中文输入说明

- 所有文本框（F7 小队命名 / F10 配置编辑 / F9 设定包编辑器）均为引擎原生 DTextEntry，Windows 下直接使用系统输入法，游戏内显示候选菜单。
- 输入框持有键盘焦点时，F6–F10 / M / H 等面板热键自动失效，打中文不会误触开关面板。
- 引擎候选窗定位与渲染属 GMod 本体；Windows 11 候选窗截断问题官方已于 2025-09 修复并进入 dev beta 分支，正式版跟进后自动获益（纯 Lua 无法移动引擎候选窗）。

## 目录结构

```
gamemodes/fireteam/
├── fireteam.txt                    # Gamemode 声明
├── gamemode/
│   ├── init.lua                    # 服务端入口
│   ├── cl_init.lua                 # 客户端入口
│   ├── shared.lua                  # 共享入口
│   ├── core/
│   │   ├── sh_constants.lua        # 全局常量 / 枚举
│   │   ├── sh_config_registry.lua  # 配置注册 / 校验
│   │   ├── sh_api_registry.lua     # 公开 API 注册
│   │   ├── sh_net_protocol.lua     # 网络协议
│   │   ├── sh_weapon_interface.lua # 武器抽象层
│   │   ├── sh_vehicle_interface.lua# 载具抽象层
│   │   ├── sv_module_loader.lua    # 模块加载器
│   │   └── sv_setting_loader.lua   # 设定包加载器
│   ├── modules/
│   │   ├── squad/                  # 小队
│   │   ├── class/                  # 职业
│   │   ├── marker/                 # 标记
│   │   ├── voice/                  # 语音
│   │   ├── rounds/                 # 回合制（含多剧本）
│   │   ├── tacmap/                 # 战术地图
│   │   ├── spectate/               # 观察者模式
│   │   ├── seats/                  # 载具座位
│   │   ├── ai/                     # AI 队友
│   │   ├── pve/                    # PvE 战役模式
│   │   ├── inventory/              # 物品 / 网格背包 / 快捷栏
│   │   ├── vitals/                 # 分部位健康 / 倒地复活
│   │   ├── stamina/                # 体力
│   │   ├── resupply/               # 弹药与补给
│   │   ├── mainmenu/               # ESC 主菜单
│   │   ├── admin/                  # F10 管理面板
│   │   ├── packeditor/             # F9 设定包编辑器
│   │   ├── hud/                    # HUD
│   │   ├── ballistics/             # 弹道
│   │   ├── suppression/            # 压制
│   │   └── adapters/               # 基座适配器
│   ├── api/                        # 公开 API 文档目录
│   └── locale/
│       ├── en.lua                  # English
│       └── zh-CN.lua               # 简体中文
├── setting_packs/
│   ├── _template/                  # 空白模板
│   └── coldwar/                    # 冷战默认包
└── docs/
    └── api_reference.md            # API 参考文档
```

## 开发路线

### ✅ 已完成 (v0.1.0-alpha)

- [x] 项目骨架（18 目录 / 66 文件）
- [x] 全局表 / 常量 / 枚举
- [x] 模块加载器 + 设定包加载器
- [x] 配置注册 / API 注册 / 网络协议
- [x] 武器 / 载具抽象接口
- [x] 小队 / 职业 / 标记 / 语音模块
- [x] HUD 渲染（准星/弹药/生命/指南针）
- [x] 弹道计算 + 压制系统
- [x] ARC9 / TFA / LVS / Simfphys 适配器
- [x] 冷战设定包 + 模板包
- [x] 多语言（en / zh-CN）
- [x] API 文档

### ✅ 近期迭代 (v0.2.x)

- [x] 战术地图（M 键，标记同步到地图）
- [x] 回合制 / 任务生成框架
- [x] 胜负判定引擎
- [x] 观察者模式（死亡旁观队友，第一/第三/自由视角，回合制联动）
- [x] 语音电台氛围音（通话咔嗒 / 静噪底声 / 干扰衰减，原始语音流受引擎边界不可截获）
- [x] 载具座位交互（E 键提示 / 职业门槛座位 / 车载电台）
- [x] 管理面板（F10，配置 / 回合控制 / 玩家总览 / 设定包切换）
- [x] 多剧本支持（scenarios 声明式切换，coldwar 内置富尔达缺口 / 西柏林双剧本）
- [x] PvE 战役模式（管理员 PVP/PVE 切换、AI 敌军阵营推进/驻防、逐关战役进度）
- [x] 背包/消耗品系统（P5a：设定包 items.lua 数据驱动、grenade/medical/ammo_belt 槽位真实化、手雷投掷实体、ft_item_<id> 快捷键、主题化消耗品栏）
- [x] 健康与医疗系统（P5b：头/胸/腹/四肢部位倍率、命中出血累积、Squad 式倒地濒死——队友按 E 稳定、医疗兵持医疗包读条复活、足量补刀终结，真死才计分；参数进 map_rules.vitals 三级解析）
- [x] 体力系统（P5c：职业 stats.stamina 上限、冲刺消耗/滞回力竭、力竭禁冲刺+移速惩罚+开火视角抖动，数值并入体征快照）
- [x] 弹药与补给（P5d：loadout 备弹池补满、弹药盒可放置实体（N 次补给后消失）、尸体按 E 搜刮部分备弹/消耗品）
- [x] 战术小队风格 HUD 布局（bearing tape 罗盘 / 左下小队栏 / 左上战局块，锚点数据驱动，H 键开关）
- [x] 中文输入适配（面板热键焦点守卫 + 统一主题输入框）
- [x] 语音三频道（战术小队式：地区近距人声 / 小队网 / 指挥网，V/B/G 切换、频道色说话者名牌）
- [x] 塔科夫式分部位健康（七部位独立血量：黑部位伤害转移胸腔、头/胸黑即死、胃黑大出血、腿黑/骨折减速、臂黑开火晃动；绷带/夹板/止痛药/医疗包真实生效；class/stamina/vitals 速度统一收口）
- [x] 塔科夫式网格背包（Tab 开合、10×6 网格拖拽/服务端碰撞校验、物品占格 size、双击使用/右键丢弃、4 槽快捷栏 7/8/9/0、背包满截断发放、面板内嵌七部位健康页）
- [x] ESC 主菜单（引擎菜单接管，聚合各面板入口与战局状态）+ CapsLock 全屏指挥视图（大地图 + 队伍情况栏）
- [ ] 设定包 Workshop 分发格式

### 💭 远期愿景 (v1.0)

- [x] 可视化设定包编辑器（接口级：F9 面板，schema 表单编辑主题/回合参数，导出 JSON 设定包）
- [x] AI 小队成员（接口级：NextBot 队友部署/跟随/驻守、路点指令挂接标记系统、回合补位框架）
- [ ] 多小队联合作战（排级）
- [ ] 回放 / 录像系统
- [ ] 官方战役设定包（越战 / 海湾 / 现代）

## 剧本扩展 API

第三方插件（`lua/autorun` 脚本、其他 addon）可在**不改设定包文件**的前提下新增或定制剧本。全部为运行时叠加层：解析按「基础（自定义注册 > 设定包 > 隐式单剧本）← 扩展层」合成，重载设定包即还原。

```lua
-- 注册一个全新剧本（id 与内置冲突时覆盖内置），结构同 map_rules.scenarios 条目
Fireteam.API.RegisterScenario("night_raid", {
    name = "Night Raid", name_zh = "夜袭",
    objectives = { { name = "Radar", name_zh = "摧毁雷达", type = "destroy_entity", ... } },
    spawns = { usa = { { pos = { anchor = "map_center", offset = { x = -1200, y = 0, z = 0 } } } } },
    timings = { round_time = 300 },
    pve = { player_factions = { "usa" }, ai_factions = { "ussr" }, ai_behavior = "defend" },
})

-- 或在扩展层定制既有剧本（以富尔达缺口为例）
Fireteam.API.AddScenarioObjective("fulda_gap", { name = "Depot", type = "hold_zone", ... })
Fireteam.API.RemoveScenarioObjective("fulda_gap", "Kinzig Extraction")  -- 按 objective.name
Fireteam.API.AddScenarioSpawn("fulda_gap", "usa", { pos = { anchor = "map_center", offset = { x = -1500, y = 200, z = 0 } } })
Fireteam.API.SetScenarioTimings("fulda_gap", { briefing = 5 })
Fireteam.API.OverrideScenarioVitals("fulda_gap", { bleedout_time = 30 })   -- vitals 三级解析最上层
Fireteam.API.SetScenarioPvE("berlin", { ai_behavior = "advance" })

-- 查询与还原
Fireteam.Rounds.GetScenario("fulda_gap")     -- 合成结果（含扩展层）
Fireteam.Rounds.ResolveScenario()            -- 当前生效剧本
hook.Add("Fireteam.Rounds.ScenarioChanged", "myaddon", function(newId) end)
Fireteam.API.ClearScenarioExtensions()       -- 清空全部运行时定制
```

切换仍走 `ft_scenario <id>` / F10 面板（自定义剧本会出现在列表中），改动在下一回合简报生效。

## 贡献指南

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/your-feature`
3. 遵循命名规范：
   - 共享文件：`sh_模块名.lua`
   - 服务端：`sv_模块名.lua`
   - 客户端：`cl_模块名.lua`
4. 所有新增 API 必须在 `sh_api_registry.lua` 中注册
5. 提交 Pull Request

### 代码规范

- 缩进：4 空格
- 全局表：`Fireteam.模块.函数名`
- Hook 前缀：`Fireteam.模块.事件`
- 网络消息：`FT_` 前缀
- 注释语言：中文或英文均可

## 许可证

MIT License — 详见 [LICENSE](LICENSE) 文件。

## 致谢

- Garry Newman & Facepunch Studios — Garry's Mod
- ARC9 团队 — 武器基座
- TFA Base 团队 — 武器基座
- LVS / Simfphys 团队 — 载具基座
- 所有参与测试和反馈的社区成员

<p align="center">
  <sub>FIRETEAM v0.1.0-alpha · Built for Garry's Mod · 2026</sub>
</p>

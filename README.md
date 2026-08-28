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
- [阵营指挥官](#阵营指挥官)
- [语音频道](#语音频道战术小队式三频道按住说话)
- [配置项一览](#配置项一览)
- [HUD 布局](#hud-布局战术小队风格)
- [网格背包](#网格背包塔科夫式)
- [分部位健康](#分部位健康塔科夫式)
- [目录结构](#目录结构)
- [开发路线](#开发路线)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

## English

FIRETEAM is a modular Garry's Mod tactical fireteam framework. It separates
gameplay code from data-driven setting packs and bridges optional weapon and
vehicle bases through adapters. The repository ships with the **Iron Curtain
Germany** Cold War pack and a blank `_template` pack.

### Architecture

- **Core:** configuration, networking, API registry, localization, module and
  setting-pack loaders, weapon/vehicle abstraction.
- **Modules:** squad, class/loadout, rounds, PvP/PvE, AI teammates, inventory,
  vitals, stamina, voice, commander, HUD and tactical map.
- **Adapters:** ARC9, TFA, CW 2.0, LVS and Simfphys; missing bases are skipped.
- **Setting packs:** factions, classes, scenarios, weapon pools, items, HUD
  themes and localized text are isolated per pack and can be hot-switched.

### Installation and validation

Copy the repository's `gamemodes/fireteam` directory into
`garrysmod/gamemodes/`, or build a GMA from the `garrysmod/gamemodes` folder:

```bash
gmad create -folder fireteam -name "FIRETEAM" -out "fireteam.gma"
```

Start GMod, select **FIRETEAM**, and verify the server log reports successful
module loading, setting-pack activation and weapon discovery. The repository
smoke test can be run with Lua 5.1:

```bash
lua5.1 test/smoke_test.lua .
```

Static tests do not replace an in-server acceptance test. After installing the
optional weapon bases, test class loadouts, PvP/PvE transitions, AI spawning,
hot-swapping setting packs, keybinds and HUD rendering on a live GMod server.

### Current status

The project is alpha software. The core framework, Cold War scenarios,
transaction-safe setting-pack activation, deterministic client/server module
loading, inventory and weapon filtering are implemented. Replay/recording and
additional official campaigns remain future work.

## 代码审查结果（2026-08-28） / Code Review Results (2026-08-28)

本轮按 [代码审查计划](docs/CODE_REVIEW_PLAN.md) 执行了静态架构与生命周期审查，结论如下：

### 已确认并修复 / Confirmed and Fixed

- **P1 设定包热切换半初始化**：激活流程已改为先加载并校验核心数据，失败时保留旧包状态。
- **P1 客户端加载顺序不确定**：客户端现在复用模块优先级和字母序排序，与服务端一致。
- **P2 API 接受无效剧本**：`SetScenario` 现在会拒绝当前设定包不存在的剧本 ID。
- **P2 核心数据缺失静默通过**：支持 `required_data`，默认校验 `factions/classes/map_rules`。

### 当前待跟踪 / Open Follow-ups

- **P2 fallback 清单重复维护**：服务端和客户端各自维护模块 fallback 列表，新增模块存在漂移风险；后续应提取共享 manifest。
- **P2 运行时覆盖不足**：静态测试无法验证 GMod 网络、HUD、第三方基座和实体生命周期；需要按计划完成真实服务器验收。

验证证据：Lua 5.1 冒烟测试 36/36 通过，修改文件语法检查通过，`git diff --check` 通过。上述静态结果不等同于 GMod 运行时发布就绪。

The review followed the [Code Review Plan](docs/CODE_REVIEW_PLAN.md). Setting-pack activation is transactional, client/server module ordering is deterministic, invalid scenario API requests are rejected, and required pack data is validated. Remaining P2 work is consolidating fallback manifests; live GMod acceptance is still required for networking, HUD, third-party bases, and entity lifecycles.

### 深审进展（未完） / Deep Review In Progress

本轮深审尚未结束，新增确认的待修复风险：

- **P1 目标数据契约不足**：设定包目前只校验 `map_rules` 是表，未逐项校验 objective 的 `type`、处理函数和必需参数；异常目标可能在 ACTIVE Think 阶段触发 nil 调用。需要增加加载期 schema 校验和安全跳过策略。
- **P2 网络入口缺少统一限流层**：`ITEM_MOVE`、`ITEM_USE`、标记和部分管理请求分别自行校验，但没有统一的 per-player 频率门控；恶意或误触发的高频请求可能造成快照广播和服务器开销。需要统一 RateLimiter 或消息级限流声明。
- **P2 fallback manifest 仍重复维护**：服务端与客户端清单尚未合并为共享 manifest。

因此，本 README 记录的是阶段性审查结果，不代表代码已经完成全部审查或达到运行时发布标准。

The deep review is still in progress. Newly confirmed open risks are incomplete objective-data schema validation, the absence of a shared per-player network rate-limit layer, and duplicated client/server fallback manifests. This is a staged review report, not a claim of runtime release readiness.

## 概述

FIRETEAM 是一个 Garry's Mod 战术小队游戏模式框架。它提供：

- 🎯 **小队管理** — 创建、加入、解散、角色分配、锁队/踢人/就绪
- 🪖 **职业系统** — 基于 Tag 的装备匹配，不写死武器类名
- 🗺️ **标记系统** — 路点、敌人、目标点标记与同步，指挥官可下阵营级标记
- 📻 **语音通讯** — 三频道（地区/小队/指挥）+ 应急，按频道语义分流收听
- ⭐ **阵营指挥官** — 志愿就任 / 竞选投票 / 重选挑战，指挥频道准入与全阵营态势视图
- ⏱️ **回合制引擎** — 状态机 + 目标接口（占区/摧毁/撤离/歼灭）+ 计分，支持多剧本切换
- 🎖️ **PvP / PvE** — 管理员切换模式，PvE 生成 AI 敌军阵营并逐关推进战役
- 🗺️ **战术地图** — M 键程序化"纸质图纸"地图 + CapsLock 全屏指挥视图
- 🎒 **网格背包** — Tab 开合 10×6 拖拽背包、物品占格、4 槽快捷栏
- 🩹 **分部位健康** — 七部位独立血量、骨折/黑肢/止痛药、倒地濒死与医疗品
- 🏃 **体力与补给** — 冲刺力竭、备弹池、弹药盒、尸体搜刮
- 🤖 **AI 队友** — NextBot 跟随/驻守/自主交战，响应路点指令与回合补位
- 👻 **观察者模式** — 阵亡后旁观队友（第一/第三/自由视角），回合制联动
- 🎨 **HUD 主题** — 战术小队式布局，锚点与配色全由设定包主题驱动
- 💥 **弹道模拟** — 子弹下坠、伤害衰减
- 😰 **压制系统** — 屏幕模糊、准星扩散、视觉震动
- 🔌 **适配器层** — 自动识别 ARC9 / TFA / CW 2.0 / LVS / Simfphys
- 🌐 **多语言** — 9 种语言，跟随 `gmod_language` 自动切换，设定包可注入专属词条
- 🧰 **运维工具** — 管理面板（ft_admin）+ 可视化设定包编辑器（ft_packeditor）

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
| Voice | `modules/voice/` | 三频道语音（地区/小队/指挥 + 应急）、按频道 kind 分流收听、职业与指挥官准入、电台氛围音 |
| Rounds | `modules/rounds/` | 回合状态机、目标类型（占区/摧毁/撤离/歼灭）、计分、多剧本解析 |
| TacMap | `modules/tacmap/` | M 键战术地图、世界坐标投影、点击放置路点 |
| Spectate | `modules/spectate/` | 阵亡旁观队友（第一/第三/自由视角）、回合联动 |
| Seats | `modules/seats/` | 载具座位职业门槛、上车提示、车载电台 |
| AI | `modules/ai/` | NextBot AI 队友：跟随/驻守/交战、回合补位 |
| PvE | `modules/pve/` | PvE 战役模式：AI 敌军阵营生成、推进/驻防行为、战役关卡机 |
| Commander | `modules/commander/` | 阵营指挥官选举（志愿就任 / 竞选投票 / 重选挑战）、指挥语音频道准入、阵营级标记广播、断线自动腾位 |
| Admin | `modules/admin/` | 管理面板（`ft_admin`）：配置 / 回合控制 / 玩家总览 / 设定包切换 / 冷战情景预设工具 |
| PackEditor | `modules/packeditor/` | F9 设定包可视化编辑（schema 表单）、JSON 导出 |
| HUD | `modules/hud/` | 准星、弹药、生命、指南针、特效 |
| Ballistics | `modules/ballistics/` | 子弹下坠、伤害衰减 |
| Suppression | `modules/suppression/` | 压制值累积/衰减、视觉效果 |
| Inventory | `modules/inventory/` | 网格背包（Tab 面板 10×6 拖拽 + 服务端碰撞校验）、物品占格、4 槽快捷栏、手雷投掷物、消耗品芯片栏；物品定义与职业槽位解析全数据驱动 |
| Vitals | `modules/vitals/` | 分部位健康：七部位独立血量（黑部位伤害转移胸腔 / 头胸黑即死）、骨折与止痛药、出血累积、倒地濒死（稳定/复活/补刀）、医疗品效果、移速统一收口 |
| Stamina | `modules/stamina/` | 体力：职业上限冲刺消耗/滞回力竭、移速惩罚、低体力开火抖动 |
| Resupply | `modules/resupply/` | 弹药与补给：备弹池补满、可放置弹药盒（N 次使用）、尸体搜刮 |
| MainMenu | `modules/mainmenu/` | ESC 主菜单：引擎菜单接管、战局状态、各面板聚合入口 |
| Adapters | `modules/adapters/` | ARC9 / TFA / CW 2.0 / LVS / Simfphys 桥接（引导期全量执行，基座缺失自跳过） |

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

**GMA 白名单三条硬约束**（违反会导致打包失败或文件被静默丢弃）：

| 约束 | 后果 | 应对 |
| --- | --- | --- |
| 0 字节文件 | gmad **中止整包**（`Failed to create the addon`） | 删除或填充空文件 |
| 文件名含大写字母 | 该文件被**静默跳过**，包内缺失 | 文件名一律全小写 |
| `.json` 不在白名单 | 该文件被静默跳过 | 元数据与主题改用 `pack.lua` / `hud_theme.lua` |

打包前自查：

```bash
find . -type f -size 0                  # 应为空
find . -type f -name "*[A-Z]*"          # 应为空（addon.json 除外，它不进 GMA 内容层）
```

设定包若随 addon 分发，放到 `lua/fireteam_setting_packs/<包名>/`（该路径在白名单内，
且被加载器以 realm=LUA 扫描）。

### 验证

启动 GMod → 新建游戏 → 模式列表中出现 "FIRETEAM" → 选择进入。

> **模式列表里看不到？** 检查 `fireteam.txt` —— 该文件是**引擎读的 gamemode 声明**，
> 字段集与 `addon.json` 完全不同，必须包含 `"menusystem" "1"`（决定是否出现在
> 主菜单模式列表，`base` 模式没有它所以不可见）与 `"base" "base"`（派生基座）。
> `type` / `icon` / `description` / `author_name` / `tags` 是 addon.json 的字段，
> 写进 `.txt` 无效。`"category"` 需为合法值（`pvp` / `pve` / `rp` / `other` 等），
> 可对照 `garrysmod/gamemodes/sandbox/sandbox.txt` 与 `terrortown/terrortown.txt`。
>
> 本框架当前声明：
> ```
> "fireteam"
> {
> 	"base"		"base"
> 	"title"		"FIRETEAM"
> 	"category"	"pvp"
> 	"maps"		""
> 	"menusystem"	"1"
> }
> ```

控制台应依次输出：

```
[FIRETEAM] ✓ 共享环境已初始化
[FIRETEAM] ✓ 常量已加载 (v0.1.0-alpha)
[FIRETEAM] ✓ 多语言系统就绪 (zh-CN, N 条词条)
[FIRETEAM] ✓ 模块加载器就绪
[FIRETEAM] 发现 21 个模块
[FIRETEAM] 模块加载: 21 成功, 0 失败
[FIRETEAM] ✓ 已执行 5 个基座适配器
[FIRETEAM] ✓ 武器发现完成: 共注册 N 把武器
[FIRETEAM] ✓ 已激活: Iron Curtain Germany (v1.2.0)
[FIRETEAM] ✓ 引导流程完成
```

> 「武器发现完成」若显示注册 0 把，说明没装匹配当前设定包标签的武器 addon——
> 框架仍可运行，但职业发不出主武器。装 ARC9 / TFA / CW 2.0 冷战枪包即可。

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
├── pack.lua             # 元数据（必须；pack.json 亦可，见下方双格式说明）
├── factions.lua         # 阵营定义
├── classes.lua          # 职业 + 装备槽位
├── weapons.lua          # 武器池规则
├── items.lua            # 物品 / 消耗品（可选）
├── vehicles.lua         # 载具规则（可选）
├── voice_presets.lua    # 通讯频道（可选）
├── hud_theme.lua        # UI 主题（可选；hud_theme.json 亦可）
├── map_rules.lua        # 地图规则 + 回合 + 剧本 + PvE + 体征（可选）
├── player_models.lua    # 阵营玩家模型映射（可选）
├── weapon_overrides.lua # 单件武器标签/分类覆盖（可选）
├── vehicle_overrides.lua# 单辆载具覆盖（可选）
└── locale/              # 设定包专属词条（可选）
    ├── en.lua
    └── zh-cn.lua
```

**元数据与主题双格式**：加载器优先读 `pack.lua` / `hud_theme.lua`，缺失时回退
`pack.json` / `hud_theme.json`。**GMA 白名单不含 `.json`**，所以要发布到创意工坊的包
必须提供 `.lua` 版本；磁盘部署与第三方既有包继续用 `.json` 也能跑。

**发现路径**（三处按序扫描）：`setting_packs/`（仓库内置）、
`gamemodes/fireteam/setting_packs/`（部署后同级）、
`lua/fireteam_setting_packs/`（Addon/GMA 分发，realm=LUA）。

### 内置设定包

| ID | 名称 | 时代 | 通讯模型 |
| --- | --- | --- | --- |
| coldwar | Iron Curtain Germany | 1968–1985 | 模拟电台 |
| _template | 空白模板 | — | — |

coldwar 包内置 8 个现实国家阵营：北约的美国/英国/西德/法国，华约的苏联/东德/波兰/捷克斯洛伐克。各国独立职业表（华约含政委）、武器与载具池、按语言区分的语音包和侧翼出生带，每国 `lore` 字段记录其在想定中的历史角色。

内置两个可切换剧本（`ft_scenario <id>` 或管理面板切换，下一回合简报生效）：

- **fulda_gap 富尔达缺口**（默认）——北约西翼防御带对华约东翼突击轴的全线会战。目标轮转：阿尔法点哨所占区 → 巴特黑斯费尔德中继站摧毁 → 金齐希河谷撤离 → 福格尔斯贝格背水一战。
- **berlin 西柏林之战**——美英法三国守军紧凑中央防区，西德远郊解围，苏军/东德东弧主攻、波/捷第二梯队。城市攻坚节奏更快（简报 8s / 回合 7min）。目标轮转：查理检查站突破 → 瘫痪守军通讯 → 滕珀尔霍夫空运撤出 → 驻军最后抵抗。

两个剧本均内置 PvE 战役配置（剧本内 `pve` 表）：管理员 `ft_mode pve` 切换后，玩家方执攻/守一侧，其余阵营由 AI NextBot 驱动——富尔达缺口为北约守方对抗华约四国推进，西柏林为苏/东德攻方对抗三国驻军固防。PvE 下目标按表顺序逐关推进（过关进下一关、失败重试本关、通关后回到第 1 关），进度显示在 F10 回合页。

旧版平铺 `objectives`/`spawns` 结构仍受支持：不声明 `scenarios` 表时作为隐式单剧本照常运行。

### 自定义设定包

```bash
# 复制模板
cp -r setting_packs/_template setting_packs/my_setting

# 编辑 pack.lua 中的 id 和 name
# 编辑各数据文件（字段契约见 setting_packs/_template/README.md）

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
| CW 2.0 | `sv_cw2_adapter.lua` | `if CustomizableWeaponry then` |
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

**键位不硬编码物理键码**：一律走「引擎 hook + `ft_*` 命令」，玩家可任意重绑，
并可用 `ft_binds_restore` 一键还原原始绑定。

### A 级｜引擎入口（重绑对应 bind 后自动跟随）

| 默认键 | 引擎 hook | FIRETEAM 功能 |
| --- | --- | --- |
| F1 | `ShowHelp` | 主菜单（战局状态 + 各面板入口） |
| F2 | `ShowTeam` | 小队管理面板 |
| F3 | `ShowSpare1` | 职业选择 |
| F4 | `ShowSpare2` | 全屏指挥视图 |
| Tab | `ScoreboardShow` | 网格背包（**名单页在面板内**，替代原版计分板） |

### B/C 级｜命令 + 推荐键（`ft_binds_apply` 应用，可自由重绑）

| 推荐键 | 命令 | 功能 | 级别 |
| --- | --- | --- | --- |
| 7 / 8 / 9 / 0 | `ft_item_slot1..4` | 快捷栏使用物品 | B（接管 slot7–slot0，固定 loadout 下这些槽位恒空） |
| M | `ft_map` | 战术地图 | C |
| N | `ft_marker` | 在准星位置放置标记 | C |
| H | `ft_hud_squad` | 显示/隐藏左下小队栏（仅自己） | C |
| CapsLock | `ft_command` | 全屏指挥视图 | C |
| G | `+ft_voice_squad` | **按住**用小队频道说话 | C |
| I | `ft_backpack` | 背包备用入口 | C |
| — | `ft_admin` | 管理面板（管理员） | 需自绑 |
| — | `ft_packeditor` | 设定包编辑器（管理员） | 需自绑 |
| — | `ft_menu` | 主菜单（等同 F1） | 需自绑 |
| — | `+ft_voice_local` / `+ft_voice_command` | 按住用地区 / 指挥频道说话 | 需自绑 |

### D 级｜永不触碰

WASD、Space、Shift、Ctrl、Alt、`E` 使用、`R` 换弹、`F` 手电、`Y`/`U` 聊天、
`` ` `` 控制台、`Esc`、全部鼠标键（含 vanilla 的 `+voicerecord` 绑定）。
即使推荐表被第三方改坏，写入前也会被保护名单拦下。

### 键位管理命令

```bash
ft_binds_apply     # 应用推荐键位（首次进服自动执行一次）
ft_binds_restore   # 从 data/fireteam/binds_backup.txt 完整还原原始绑定
ft_binds_list      # 列出所有 FIRETEAM 命令与当前实际绑定
```

**沙盒功能禁用**：`SpawnMenuOpen` / `ContextMenuOpen` 返回 false（Q/C 菜单不再弹出），
`PlayerNoClip` 对非管理员返回 false——战术模式不造物、不穿墙。

## 主菜单与指挥视图

- **主菜单（F1 / `ft_menu`）**：当前剧本/模式/回合状态 + 小队、职业、背包、地图、指挥视图、管理面板入口。按钮上的按键提示由 `input.LookupBinding` 反查，玩家重绑后自动跟随。
  **ESC 保持引擎原生行为**（改设置、断开连接照常可用）。
- **指挥视图（F4 / CapsLock / `ft_command`）**（模仿《战术小队》队伍界面）：全屏左右分栏——左侧大地图（复用战术地图投影，含队友朝向/名字、小队标记、回合目标圈，可点击放路点），右侧队伍情况栏（成员存活/血量条/职业/倒地红显/队长菱形）。

## 阵营指挥官

每个阵营一个指挥官席位，入口在**小队面板**（F2 / `ft_squad`）：

- **志愿就任**：席位空缺时，任意小队长可直接接任
- **竞选投票**：多人同时申请则进入限时投票，同阵营成员投票决出
- **重选挑战**：已有指挥官时，其他小队长可发起挑战重选
- **权限**：指挥频道（`+ft_voice_command`）发言准入自动放行；可下发**阵营级地图标记**（全阵营可见，非仅本小队）
- **断线自动腾位**：指挥官掉线或离开阵营即释放席位

指挥官的阵营级标记与全阵营态势在**指挥视图**（F4 / CapsLock）中汇总显示。

## 语音频道（战术小队式三频道·按住说话）

| 频道 | 命令（按住） | 推荐键 | 收听范围 |
| --- | --- | --- | --- |
| 地区 Local | `+ft_voice_local` | 需自绑 | 距离内所有人（3D 人声，`voice.distance_max`） |
| 小队 Squad | `+ft_voice_squad` | G | 仅本小队成员，频道 range 内 |
| 指挥 Command | `+ft_voice_command` | 需自绑 | 同阵营全部成员（需职业权限：队长/通讯员/政委，或本阵营指挥官） |

**按住语义**（与《战术小队》一致）：按下 → 切到该频道并代发 `+voicerecord`；
松开 → 停止录音并回退原频道。**不占用 vanilla 的说话键**，你原本的
`+voicerecord` 绑定照常可用（走当前频道）。绑定示例：

```bash
bind g "+ft_voice_squad"
bind mouse5 "+ft_voice_command"
```

说话者名牌显示在屏幕左侧（喇叭图标按频道着色：地区白 / 小队绿 / 指挥黄），结束后 2 秒淡出；
左下电台指示器显示当前频道名。频道结构由设定包 `voice_presets.lua` 的 `channels` 声明
（`kind = local|squad|command|all`）。

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
| `vitals.limbs_enabled` | boolean | `true` | 塔科夫式七部位血量模型 |
| `vitals.fracture_chance` | number | `0.25` | 腿部受击骨折概率（打黑必骨折） |
| `vitals.painkiller_time` | number | `60` | 止痛药持续秒数（屏蔽腿瘸/臂晃） |
| `vitals.medkit_heal_frac` | number | `0.5` | 医疗包恢复部位血量比例 |
| `vitals.enabled` | boolean | `true` | 倒地/出血系统总开关（false = 原版即死） |
| `vitals.bleedout_time` | number | `60` | 倒地失血时限（秒） |
| `vitals.revive_time` | number | `7` | 医疗兵复活读条（消耗 medkit） |
| `vitals.finish_damage` | number | `25` | 补刀倒地单位所需单次伤害 |
| `vitals.head_mult` | number | `2.5` | 头部伤害倍率 |
| `vitals.chest_mult` | number | `1.0` | 胸部伤害倍率 |
| `vitals.stomach_mult` | number | `0.85` | 腹部伤害倍率 |
| `vitals.limb_mult` | number | `0.6` | 四肢伤害倍率 |
| `vitals.max_bleed_stacks` | number | `5` | 出血层数上限 |
| `vitals.bleed_dps_per_stack` | number | `1.2` | 每层出血每秒掉血 |
| `vitals.stabilize_time` | number | `3.5` | 队友按 E 稳定读条秒数 |
| `vitals.revive_health_frac` | number | `0.4` | 复活后恢复生命比例 |
| `vitals.downed_speed` | number | `40` | 倒地匍匐移速 |
| `vitals.leg_speed_mult` | number | `0.55` | 单腿黑/骨折移速倍率 |
| `vitals.both_legs_speed_mult` | number | `0.35` | 双腿黑/骨折移速倍率 |
| `ai.health` | number | `100` | AI 队友生命值 |
| `ai.acquire_range` | number | `1200` | AI 索敌距离 |
| `ai.attack_damage` | number | `8` | AI 单次射击伤害 |
| `ai.follow_distance` | number | `150` | AI 跟随保持距离 |
| `stamina.enabled` | boolean | `true` | 体力系统总开关 |
| `stamina.default_max` | number | `100` | 体力上限兜底（职业 stats.stamina 优先） |
| `stamina.drain_per_sec` | number | `9` | 冲刺每秒消耗 |
| `stamina.regen_per_sec` | number | `12` | 停跑后每秒回复 |
| `stamina.regen_delay` | number | `1.5` | 停跑到开始回复的延迟秒数 |
| `stamina.exhausted_frac` | number | `0.15` | 进入力竭的体力比例 |
| `stamina.recover_frac` | number | `0.4` | 解除力竭所需回复比例 |
| `stamina.low_speed_mult` | number | `0.7` | 力竭时移速倍率 |
| `resupply.reserve_primary` | number | `240` | 主武器备弹池 |
| `resupply.reserve_secondary` | number | `64` | 副武器备弹池 |
| `resupply.crate_uses` | number | `4` | 弹药盒可补给次数 |
| `resupply.loot_enabled` | boolean | `true` | 尸体搜刮开关 |
| `resupply.loot_frac` | number | `0.5` | 尸体可搜刮比例 |

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

- 所有文本框（小队命名 / 配置编辑 / 设定包编辑器）均为引擎原生 DTextEntry，Windows 下直接使用系统输入法，游戏内显示候选菜单。
- 输入框持有焦点时面板热键自动失效，打中文不会误触开关面板。判定只针对文本输入控件本身——早期版本误判「任何面板持有键盘焦点」，导致面板一开全部热键锁死（已修）。
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
│   │   ├── sh_ui_kit.lua           # UI 设计系统（取色/字体/绘制原语/窗口壳层）
│   │   ├── sh_keybinds.lua         # 键位层（引擎 hook + ft_* 命令 + 分级接管）
│   │   ├── sh_locale.lua           # 多语言
│   │   ├── cl_setting_data.lua     # 客户端设定包数据桥接
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
│   │   ├── commander/              # 阵营指挥官（选举 / 指挥频道 / 阵营标记）
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
│   ├── api/                        # 公开 API 表面（sh/sv/cl 三层，第三方 addon 入口）
│   └── locale/
│       ├── en.lua                  # English（兜底）
│       ├── zh-cn.lua               # 简体中文
│       ├── zh-hant.lua             # 繁體中文
│       ├── ru.lua  es.lua  fr.lua  # 俄 / 西 / 法
│       └── de.lua  ja.lua  ko.lua  # 德 / 日 / 韩
├── setting_packs/
│   ├── _template/                  # 空白模板（含自制模式指南 README）
│   └── coldwar/                    # 冷战默认包
└── docs/
    └── api_reference.md            # API 参考文档
```

> `locale/` 文件名一律全小写：GMA 白名单拒收含大写字母的文件名（打包时被静默丢弃），
> 对外语言标识仍是 BCP 47 的 `zh-CN` / `zh-Hant`，由 `sh_locale.lua` 转换。

## 开发路线

### ✅ 已完成 (v0.1.0-alpha)

- [x] 项目骨架（21 模块 / 120+ 文件）
- [x] 全局表 / 常量 / 枚举
- [x] 模块加载器 + 设定包加载器
- [x] 配置注册 / API 注册 / 网络协议
- [x] 武器 / 载具抽象接口
- [x] 小队 / 职业 / 标记 / 语音模块
- [x] HUD 渲染（准星/弹药/生命/指南针）
- [x] 弹道计算 + 压制系统
- [x] ARC9 / TFA / CW 2.0 / LVS / Simfphys 适配器
- [x] 冷战设定包 + 模板包
- [x] 多语言（9 种：en / zh-CN / zh-Hant / ru / es / fr / de / ja / ko）
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
- [x] 设定包 Workshop 分发格式（`pack.lua` / `hud_theme.lua` 双格式、`lua/fireteam_setting_packs/` 发现路径、GMA 白名单自查）

### 💭 远期愿景 (v1.0)

- [x] 可视化设定包编辑器（接口级：F9 面板，schema 表单编辑主题/回合参数，导出 JSON 设定包）
- [x] AI 小队成员（接口级：NextBot 队友部署/跟随/驻守、路点指令挂接标记系统、回合补位框架）
- [x] 多小队联合作战（排级）：阵营指挥官选举（志愿就任 / 竞选投票 / 重选挑战）、指挥语音频道准入、阵营级地图标记、全阵营态势指挥视图、锁队/踢人/就绪建队增强
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

### 硬规范（踩过坑，别再犯）

1. **模块文件名必须严格 `sh_/sv_/cl_<目录名>.lua`**
   加载器只按目录名拼文件名查找。`modules/packeditor/` 下写成 `sh_pack_editor.lua`
   会让整个模块在两端静默不加载（配置键也不注册），F9 面板因此长期是死键。
2. **禁止模块子文件手动 include**
   子文件不会被 `AddCSLuaFile` 下发，且 `include()` 基准目录在 GMA 挂载下会解析失败，
   双端都加载不到还静默跳过。需要拆分时并入主文件，或另建符合命名约定的模块目录。
3. **键位不得硬编码物理键码**
   一律走 `core/sh_keybinds.lua` 的引擎 hook 或 `ft_*` 命令，并遵守 D 级保护名单。
   直接监听 `PlayerButtonDown` 会与玩家个人绑定冲突（曾撞上 quickload / toggleconsole / noclip）。
4. **手写 net 协议不得依赖表构造式求值顺序**
   `{ a = net.ReadUInt(8), b = net.ReadString() }` 的字段求值顺序 Lua 未定义，
   会与写序错位。一律先逐字段读入 local 再组表。
5. **一个 net 消息只能有一个 `net.Receive`**
   后注册会覆盖前者。跨文件共享同一消息时，由单一接收器写入共享状态，其他方读状态。

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

# FIRETEAM — Garry's Mod 战术小队框架

<p align="center">
  <strong>模块化 · 设定包驱动 · 多基座适配</strong><br>
  一个不绑定具体游戏循环的战术小队底层框架
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.1.0--alpha-orange" alt="version">
  <img src="https://img.shields.io/badge/GMod-250814%2B-blue" alt="gmod">
  <img src="https://img.shields.io/badge/Lua-5.1-green" alt="lua">
  <img src="https://img.shields.io/badge/status-skeleton--complete-yellow" alt="status">
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
- 🎨 **HUD 主题** — 可配置的界面风格（CRT / 纸质 / 现代）
- 💥 **弹道模拟** — 子弹下坠、伤害衰减
- 😰 **压制系统** — 屏幕模糊、准星扩散、视觉震动
- 🔌 **适配器层** — 自动识别 ARC9 / TFA / LVS / Simfphys

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
| HUD | `modules/hud/` | 准星、弹药、生命、指南针、特效 |
| Ballistics | `modules/ballistics/` | 子弹下坠、伤害衰减 |
| Suppression | `modules/suppression/` | 压制值累积/衰减、视觉效果 |
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

使用 gmad 工具打包：

```bash
cd garrysmod/gamemodes/fireteam
gmad create -name "FIRETEAM" -out "fireteam.gma"
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
[FIRETEAM] ✓ Setting pack active: Iron Curtain Edge (v1.0.0)
[FIRETEAM] ✓ Bootstrap complete
```

## 快速开始

服务端控制台：

```bash
# 切换设定包
ft_setting_pack coldwar

# 开启调试日志（0=关 1=基础 2=详细）
ft_debug 1
```

游戏内操作：

1. 按 **F7** 打开小队面板 → 创建或加入小队
2. 按 **F8** 选择职业 → 自动分配装备
3. 按 **F6** 在准星位置放置标记
4. 语音默认走小队频道，无需额外操作

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
| coldwar | Iron Curtain Edge | 1968–1985 | 模拟电台 |
| _template | 空白模板 | — | — |

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
| F6 | 在准星位置放置标记 |
| F7 | 打开小队管理面板 |
| F8 | 打开职业选择面板 |
| M | 打开战术地图 |

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

### 🔜 计划中 (v0.2.0)

- [x] 战术地图（M 键，标记同步到地图）
- [ ] 回合制 / 任务生成框架
- [ ] 胜负判定引擎
- [ ] 观察者 / 旁观者模式
- [ ] 语音实际音频播放（替代文字频道）
- [ ] 载具座位交互
- [ ] 设定包 Workshop 分发格式
- [ ] 管理面板（F10）

### 💭 远期愿景 (v1.0)

- [ ] 可视化设定包编辑器（浏览器面板）
- [ ] AI 小队成员
- [ ] 多小队联合作战（排级）
- [ ] 回放 / 录像系统
- [ ] 官方战役设定包（越战 / 海湾 / 现代）

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

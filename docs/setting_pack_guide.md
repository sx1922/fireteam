# FIRETEAM 设定包与资源拆分规范 / Setting Pack and Packaging Guide

## 1. 设定包结构 / Pack Structure

`pack.lua` 为元数据入口；`factions.lua`、`classes.lua`、`map_rules.lua` 是默认核心数据，缺失或类型错误时不得激活。可选文件包括 `items.lua`、`vehicles.lua`、`weapons.lua`、主题、模型映射、覆盖表和 locale。

`required_data` 可在 `pack.lua` 中显式声明；未声明时按核心三文件处理。

## 2. 数据契约 / Data Contract

- `factions` 中的 ID 必须唯一，职业 faction 必须引用已存在阵营。
- `classes.loadout` 的武器标签必须能匹配适配器标签或物品槽位。
- `map_rules.rounds.scenarios` 的 objective 必须声明有效 `type`，并满足该目标类型所需参数。
- `pve.player_factions` 与 `ai_factions` 不得重叠；模式切换必须有合法回退。
- `config_overrides` 只能写入已注册配置，并通过类型、枚举和范围校验。

## 3. GMod 资源拆分 / GMod Resource Splitting

- 资源包按独立 addon/GMA 拆分，不使用无法独立挂载的压缩分卷。
- 每个包保持完整的 GMod 相对路径（`models/`、`materials/`、`sound/` 等）。
- 同一模型族的 `.mdl`、`.vvd`、`.vtx`、`.phy` 及其材质依赖必须放在同一包。
- **`01_武器与依赖` 保持一个整体包，不拆分。** 武器代码、模型、材质、音效和依赖必须一起发布，避免基座资源缺失或覆盖顺序错误。
- 超过平台单包限制的其他资源目录，按完整资源族拆成多个独立包，并通过 Workshop Collection 组合。
- `00_游戏模式` 保持独立且完整；不得把核心 gamemode 文件拆到资源包中。

## 4. 发布检查 / Release Checks

- 检查 0 字节文件、大写路径、GMA 白名单和相对路径。
- 校验每个包的大小、文件数、依赖说明和安装顺序。
- 服务器启动后确认设定包发现、模块加载、适配器发现和资源挂载日志。
- 文档中的包列表必须与实际目录和 Workshop 发布物一致。

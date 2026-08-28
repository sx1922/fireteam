# FIRETEAM 模块开发规范 / Module Development Guide

## 1. 文件与加载 / Files and Loading

- 每个模块目录使用 `sh_<dir>.lua`、`sv_<dir>.lua`、`cl_<dir>.lua` 或 `cl_<dir>_ui.lua`。
- 不在模块子文件中手动 `include`；由加载器统一发现、下发和执行。
- 共享代码不得直接访问客户端/服务端专属 API，使用 `if SERVER` / `if CLIENT` 守卫。
- 新模块必须同时更新共享 fallback manifest（若该机制尚未迁移完成），并在 worklog 记录。

## 2. 依赖边界 / Dependency Boundaries

- Core 只依赖 GMod API 和共享基础表，不依赖具体玩法模块。
- 模块之间通过公开函数、Hook 或网络协议协作，不读取其他模块私有表。
- 所有可选依赖必须使用存在性检查，并提供安全降级路径。
- 初始化阶段不得假设玩家、地图实体、第三方基座或设定包已经可用。

## 3. Hook、计时器与生命周期 / Hooks, Timers, Lifecycle

- Hook 名称使用 `Fireteam.<Module>.<Event>` 前缀，避免覆盖其他插件。
- Timer 名称必须带模块前缀；模块停止、设定包卸载和玩家断线时清理对应 timer。
- `PlayerSpawn`、`PlayerDisconnected`、`SETTING_LOADED` 等事件处理必须幂等。
- 延迟回调中再次检查 `IsValid(entity/player)`、当前回合状态和设定包 ID。
- 任何状态机转移都必须定义重复调用和失败回退行为。

## 4. 网络与输入 / Networking and Input

- 每个网络消息只能有一个 `net.Receive`，字段读取顺序必须与发送顺序完全一致。
- 服务端永远不信任客户端的实体、阵营、坐标、数量、字符串和动作类型。
- 字符串、数组长度、坐标范围、实体有效性和权限必须在服务端校验。
- 高频消息必须使用统一 per-player 限流；拒绝请求不得改变权威状态。
- 输入使用 `ft_*` 命令或引擎 Hook；不得硬编码物理键码，不得覆盖 D 级保护键。

## 5. 数据与错误处理 / Data and Errors

- 设定包数据必须在激活前校验类型、必需字段、枚举值和引用关系。
- 新增字段提供默认值或明确版本迁移策略；缺失核心数据必须拒绝激活。
- 失败路径必须返回明确的 `false/nil/0`，并写入日志；禁止静默吞错。
- 不在网络回调中抛出未捕获异常；使用边界检查和 `pcall` 隔离第三方数据。

## 6. 测试与交付 / Testing and Delivery

- P0/P1 修复必须增加自动回归断言或可重复的 GMod 验收步骤。
- 提交前运行 smoke test、Lua 语法检查、`git diff --check`。
- 影响 `coldwar_content` 的文件必须同步部署镜像并校验 SHA-256。
- 每次行为修复写入 `worklog/`，包括未完成的运行时验证。
- 提交信息遵循 `docs/GIT_CONVENTIONS.md`，使用中英文 subject/body；不添加额外署名 footer。

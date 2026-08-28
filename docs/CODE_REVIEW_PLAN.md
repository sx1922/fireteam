# FIRETEAM 代码审查计划 / Code Review Plan

版本：1.0 · 日期：2026-08-28

## 1. 目标 / Objectives

建立可重复的审查流程，优先发现会导致服务器崩溃、状态不同步、装备丢失、回合卡死或权限绕过的问题。

Establish a repeatable review process that prioritizes crashes, state desynchronization, lost loadouts, stuck rounds, and authorization bypasses.

## 2. 审查范围 / Scope

1. 核心层：模块加载器、设定包加载器、配置注册、网络协议、API、日志和抽象接口。
2. 游戏循环：回合状态机、PvP/PvE 切换、剧本解析、胜负结算、重生和热切换。
3. 玩家系统：小队、职业、武器/物品发放、背包、生命、体力、语音、载具座位。
4. AI 与实体：AI 队友生命周期、目标选择、生成/回收、手雷和补给实体。
5. 客户端：HUD、输入绑定、面板、快照接收、断线重连和 UI 状态恢复。
6. 设定包与部署：数据契约、必需文件、适配器兼容性、GMA 路径和部署镜像。

Core, lifecycle, player systems, AI/entities, client UI/input, setting packs, adapters, and packaging are all in scope.

## 3. 风险优先级 / Severity

- **P0 阻断**：服务器启动失败、远程代码/权限绕过、网络协议错位、数据破坏。
- **P1 严重**：回合无法推进、热切换半初始化、玩家无法获得核心装备、PvE/PvP 状态错误。
- **P2 一般**：单模块功能失效、HUD/输入不同步、错误恢复不足、性能退化。
- **P3 轻微**：日志、文档、可维护性和非关键 UI 问题。

P0/P1 findings must be fixed or explicitly accepted before release; P2/P3 findings require tracking.

## 4. 分阶段流程 / Review Phases

### 阶段 A：基线与变更范围 / Baseline

- 检查 `git status`、最近提交、worklog 和未跟踪文件。
- 确认主仓库与 `coldwar_content` 部署镜像的同步范围。
- 读取 README、API 文档、设定包模板和提交规范。

### 阶段 B：静态架构审查 / Static Architecture Review

- 绘制服务端/客户端模块加载图和依赖关系。
- 检查模块优先级、fallback 清单、重复注册和循环依赖。
- 审查设定包激活的事务性、失败回滚和必需数据校验。
- 检查所有公共 API 的参数验证、返回值和权限边界。

### 阶段 C：核心逻辑审查 / Core Logic Review

- 用状态表检查 `idle → warmup → briefing → active → ended → intermission` 的每条转移。
- 检查重复事件、定时器、断线、死亡、重生和热切换期间的幂等性。
- 对 PvP/PvE 分别检查阵营资格、AI 生成/回收、胜负和计分。
- 检查武器标签、时代过滤、职业槽位、Give 失败和物品回退路径。

### 阶段 D：网络与输入审查 / Network and Input Review

- 对每个 `net.Start`/`net.Receive` 建立字段顺序和消息所有权清单。
- 检查长度限制、实体有效性、字符串截断、频率限制和服务端权威校验。
- 检查按键绑定备份/恢复、输入焦点守卫、重绑兼容和默认键保护。
- 检查客户端晚加入、重连和快照补发是否完整。

### 阶段 E：测试与运行时验收 / Testing and Runtime Acceptance

- Lua 5.1 语法检查（对 GMod 扩展语法使用规范化临时副本）。
- `test/smoke_test.lua` 必须全绿。
- `git diff --check` 必须通过。
- GMod 服务器验收：启动、加入/重连、职业发枪、背包、PvP、PvE、AI、回合推进、设定包热切换、HUD 和按键。
- 记录静态验证与运行时验证，不把静态通过表述为运行时通过。

### 阶段 F：修复与交付 / Fix and Delivery

- 每个修复写入 `worklog/`，包含发现、影响、修复、验证和未验证边界。
- 只提交用户范围内的文件，保留原有未跟踪文件。
- 同步所有部署镜像文件并校验 SHA-256。
- 使用 Conventional Commit，中英文 subject/body，附 `AI-Assisted: true`。
- 推送前复查提交差异、测试结果和工作区状态。

## 5. 审查清单 / Checklist

- [ ] 模块加载顺序在服务端和客户端一致
- [ ] 设定包失败时旧状态保持可用
- [ ] 核心数据文件和字段契约已验证
- [ ] 所有网络入口均有服务端校验和限流
- [ ] 回合状态转移不会重复触发或卡死
- [ ] PvP/PvE 阵营和 AI 生命周期正确
- [ ] 职业槽位有可用武器/物品，失败可报告
- [ ] 重生、死亡、断线、重连路径幂等
- [ ] HUD/输入/快照在晚加入和重连后恢复
- [ ] 静态测试、差异检查和运行时验收结果已记录
- [ ] worklog、镜像同步和双语提交信息齐全

## 6. 输出格式 / Review Output

每轮审查输出：

1. 按 P0–P3 排序的问题列表，附绝对路径和行号。
2. 复现条件、影响范围、根因和建议修复方案。
3. 已修复项、测试命令及结果。
4. 尚未验证的 GMod 运行时场景和下一步验收建议。

Each review must report findings by severity, evidence, root cause, fixes, test results, and remaining runtime validation gaps.

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
- 使用 Conventional Commit，并采用中英文 subject/body。
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

## 7. 模块依赖矩阵 / Module Dependency Matrix

| 层级 | 允许依赖 | 重点检查 |
| --- | --- | --- |
| Core | GMod API、基础共享表 | 不依赖具体玩法模块，不在加载阶段访问玩家状态 |
| API | Core、模块公开接口 | 惰性解析、参数验证、稳定返回值 |
| Setting | Core、数据文件 | 数据契约、版本、必需文件、失败回滚 |
| Gameplay | Core、Setting、其他模块公开 API | 不直接修改别模块私有状态 |
| Adapter | Weapon/Vehicle Interface、第三方基座 | 基座缺失安全跳过、重复发现幂等 |
| Client UI | Shared API、客户端快照 | 晚加入、重连、实体失效和主题切换 |

依赖方向应保持由上到下，禁止 Core 反向依赖 Gameplay；跨模块调用必须经过公开函数或 Hook。

Dependencies should flow downward. Core must not depend on gameplay modules, and cross-module calls must use public functions or hooks rather than private state.

## 8. 专项审查场景 / Scenario-Based Reviews

### 启动与加载 / Startup

- 无第三方武器/载具基座时启动。
- GMA 挂载、磁盘部署、Addon 部署三种路径。
- 一个共享模块或客户端 UI 文件编译失败时的隔离行为。
- 客户端先于服务端广播或晚于服务端广播加入。

### 回合与模式 / Rounds and Modes

- 连续完成多轮，确认计时器、目标和分数清理。
- PvP ↔ PvE 切换，确认 AI、阵营资格和玩家状态清理。
- 回合中途断线、重连、死亡、重生和管理员强制结束。
- 无有效剧本、单阵营、无玩家或无 AI 阵营的边界输入。

### 装备与背包 / Loadout and Inventory

- 职业分配、重复分配、重生重发和换职业冷却。
- 武器过滤、覆盖标签、时代限制、候选为空和 `Give` 失败。
- 背包满格、快捷栏绑定物品消失、物品使用被拒绝。
- 弹药盒、手雷、尸体搜刮实体的生成、使用次数和回收。

### 网络与安全 / Networking and Security

- 重放、连发、超长字符串、无效实体、错误阵营和越权请求。
- 每条网络消息的唯一接收器、字段顺序和版本兼容。
- 服务端拒绝后客户端忙碌状态、UI 状态和缓存是否恢复。

## 9. 回归策略 / Regression Strategy

每个 P0/P1 修复必须增加至少一个可自动执行的回归断言；无法在标准 Lua 环境模拟的逻辑，应增加纯函数边界并在 GMod 验收表中补充场景。

Every P0/P1 fix must add at least one automated regression assertion. Logic that cannot be simulated in plain Lua should expose a pure-function boundary and receive a documented GMod acceptance case.

回归检查顺序：

1. 相关纯函数/数据测试。
2. 全量 smoke test。
3. Lua 语法检查和 `git diff --check`。
4. 部署镜像差异与哈希检查。
5. GMod 专项验收。

## 10. 缺陷记录模板 / Finding Template

```text
标题 / Title:
级别 / Severity: P0 | P1 | P2 | P3
文件与行号 / File and line:
触发条件 / Trigger:
实际结果 / Actual result:
预期结果 / Expected result:
影响范围 / Impact:
根因 / Root cause:
修复方案 / Fix:
验证命令与结果 / Verification:
未验证边界 / Runtime gaps:
```

## 11. 发布门禁 / Release Gates

- P0 = 0，P1 无未批准项。
- smoke test 全部通过，语法检查和差异检查通过。
- 主仓库与部署镜像的受影响文件一致。
- worklog 包含本轮发现、修复和验证证据。
- README、API 文档和设定包契约与实现一致。
- 至少完成一次真实 GMod 服务器验收；若环境不可用，必须明确标记为未验证，不得宣称发布就绪。

Release is blocked by any unresolved P0 or unapproved P1 finding, missing evidence, or undocumented runtime gaps.

## 12. 审查节奏 / Review Cadence

- 每次功能提交：执行变更范围审查和相关回归测试。
- 每次回合/PvE/PvP/网络协议变更：执行完整专项场景审查。
- 每次设定包或适配器变更：执行数据契约、标签过滤和部署镜像检查。
- 每个版本发布前：执行完整清单、运行时验收和文档一致性检查。

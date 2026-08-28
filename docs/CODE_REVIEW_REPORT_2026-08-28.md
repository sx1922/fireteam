# FIRETEAM 代码审查报告 / Code Review Report

日期 / Date：2026-08-28  
计划 / Plan：[CODE_REVIEW_PLAN.md](CODE_REVIEW_PLAN.md)

## 审查范围 / Scope

本轮执行静态架构、模块生命周期、回合状态机、PvP/PvE、武器装备、网络入口和部署一致性审查。GMod 运行时验收尚未完成。

This review covered static architecture, module lifecycle, round state machine, PvP/PvE, loadouts, network entry points, and deployment consistency. Live GMod acceptance is still pending.

## 已修复 / Fixed

- **P1** 设定包热切换半初始化：改为先加载并校验，失败时保留旧状态。
- **P1** 客户端模块加载顺序不确定：复用服务端优先级和字母序。
- **P2** `SetScenario` 接受无效剧本：API 现在拒绝不存在的剧本 ID。
- **P2** 核心数据缺失静默通过：支持 `required_data`，默认校验 `factions/classes/map_rules`。

## 未修复风险 / Open Risks

- **P1 目标数据契约不足**：只校验 `map_rules` 为表，objective 的 `type`、处理函数和参数未完全做加载期 schema 校验，异常数据可能在 ACTIVE 阶段触发 nil 调用。
- **P2 网络入口缺少统一限流**：物品、标记和管理请求各自校验，没有统一 per-player 频率门控，可能造成高频请求和快照广播开销。
- **P2 fallback manifest 重复维护**：服务端和客户端各维护一份模块清单，存在部署漂移风险。

## 验证证据 / Evidence

- Lua 5.1 smoke test：36/36 通过。
- 修改文件 Lua 语法检查：通过。
- `git diff --check`：通过。
- 部署镜像受影响核心文件：已同步并校验。

## 结论 / Conclusion

本报告是阶段性审查结果，不代表运行时发布就绪。下一轮应优先修复 objective schema 校验和统一限流层，然后在真实 GMod 服务器验证启动、热切换、回合推进、PvP/PvE、装备、HUD、按键和第三方基座。

This is an interim review report, not a runtime release sign-off. The next pass should prioritize objective schema validation and a shared rate-limit layer, followed by live-server acceptance of startup, hot-switching, rounds, PvP/PvE, loadouts, HUD, keybinds, and third-party bases.

## 本轮追加审查 / Additional Findings

- **P1 设定包事务边界仍不完整**：`Activate()` 在数据校验后执行 locale 注入与配置覆盖；若这些步骤抛错，旧包已被卸载而新包尚未提交，仍可能形成半切换状态。需要把 locale/config 应用纳入统一事务，或在异常时恢复旧数据与 locale。
- **P2 目标运行时契约未固化**：`BuildObjectiveContext()` 的返回值在 ACTIVE Think 中被直接调用，设定包 objective 的字段校验尚未覆盖 `type`、`think`、`isComplete` 和参数引用。
- **P2 网络限流仍分散**：当前消息入口虽有参数校验，但尚无统一的 token bucket/per-player 限流接口。

These findings remain open; no runtime release approval is implied.

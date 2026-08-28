# 045 · 游戏循环、PvE/PvP 资格与按键修复

日期：2026-08-28

## 修复清单

### ① PvE 阵营资格

PvE 创建或加入小队时只允许当前剧本 `player_factions`，AI 控制阵营不能被真人占用。

### ② PvE→PvP 清理

模式切换离开 PvE 时立即移除 AI roster 并停止推进定时器，避免 PvP 回合残留敌方 AI。

### ③ 无效战役关卡保护

PvE 进入简报时自动跳过未注册目标类型的关卡，避免 `stage` 永久卡死。

### ④ 回合与按键状态

单阵营 PvP 跳过时清空目标上下文；F1-F4 接管 hook 返回阻止值，防止原版面板与 FIRETEAM 面板同时打开。

## 验证

- `test/smoke_test.lua`：36 项通过。
- `git diff --check`：通过。
- AI 清理、阵营限制和引擎按键 hook 仍需 GMod 运行时验收。

-- modules/admin/sh_admin.lua
-- FIRETEAM Admin Panel - Shared（模块入口）
-- F10 管理面板：配置编辑（直连 Config 注册表）、回合控制、设定包切换、玩家总览。

if not Fireteam then Fireteam = {} end
Fireteam.Admin = Fireteam.Admin or {}

--- 动作白名单（sv 侧逐条校验）
Fireteam.Admin.ACTIONS = {
    set_config   = true,
    reset_config = true,
    switch_pack  = true,
    round_next   = true,
    round_end    = true,
    refresh      = true,
}

print("[FIRETEAM:Admin] ✓ 共享定义已加载")

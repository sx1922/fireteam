-- modules/pve/sh_pve.lua
-- FIRETEAM PvE 战役 - Shared
-- 模式开关是 rounds.mode（rounds 模块注册，options 枚举驱动 F10 下拉框）；
-- 本模块只注册 AI 生成规模的运行时参数。战役内容（哪些阵营由 AI 扮演、
-- 攻防方向、每关目标）全部来自设定包 map_rules.rounds 的 pve 配置块。

if not Fireteam then Fireteam = {} end
Fireteam.PvE = Fireteam.PvE or {}

Fireteam.Config.Register("pve.bots_per_faction", 4, {
    type = "number",
    min  = 0,
    max  = 12,
    desc = "Default AI bots per AI faction (pack can override)"
})

Fireteam.Config.Register("pve.max_bots", 24, {
    type = "number",
    min  = 0,
    max  = 64,
    desc = "Hard cap on total PvE bots"
})

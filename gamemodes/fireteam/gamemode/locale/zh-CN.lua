-- gamemode/locale/zh-CN.lua
-- FIRETEAM 简体中文本地化

return {
    -- 小队
    squad_created          = "小队已创建",
    squad_disbanded        = "小队已解散",
    squad_joined           = "你已加入小队",
    squad_left             = "你已离开小队",
    squad_full             = "小队已满员",
    squad_not_found        = "未找到该小队",
    already_in_squad       = "你已经在小队中",
    not_in_squad           = "你不在任何小队中",
    leader_promoted        = "%s 已成为队长",
    member_kicked          = "%s 已被踢出小队",
    not_leader             = "只有队长才能执行此操作",

    -- 职业
    class_selected         = "职业已选择: %s",
    class_locked           = "该职业已锁定",
    class_limit_reached    = "该职业名额已满",
    loadout_given          = "装备已发放",

    -- 标记
    marker_placed          = "标记已放置",
    marker_removed         = "标记已移除",
    marker_limit_reached   = "标记数量已达上限",
    too_far_from_marker    = "距离标记过远",

    -- 载具
    vehicle_locked         = "载具锁定 - 非本队成员",
    vehicle_no_seat        = "没有空余座位",
    vehicle_destroyed      = "载具已被摧毁",

    -- 压制
    suppressed_light       = "受到压制",
    suppressed_heavy       = "猛烈火力",
    suppressed_pinned      = "被火力压制",

    -- 系统
    setting_pack_loaded    = "设定包已加载: %s",
    setting_pack_failed    = "设定包加载失败: %s",
    hud_theme_updated      = "HUD 主题已更新",

    -- UI 面板
    ui_squad_title         = "FIRETEAM — 小队管理",
    ui_class_title         = "FIRETEAM — 选择职业",
    ui_current_squad       = "当前小队: %s [%s]",
    ui_member_count        = "%d 名成员",
    ui_leave_squad         = "离开小队",
    ui_squad_name          = "小队名称:",
    ui_squad_name_placeholder = "输入小队名称...",
    ui_select_faction      = "阵营:",
    ui_create_squad        = "创建小队",
    ui_available_squads    = "可用小队",
    ui_join_squad_first    = "请先加入小队再选择职业。",
    ui_abilities           = "能力: %s",
    ui_current             = "当前",
    ui_hint_esc_close      = "按 ESC 关闭",

    -- 战术地图
    ui_tacmap_title        = "FIRETEAM — 战术地图",
    ui_hint_m_close        = "按 M 关闭地图",
    ui_hint_click_place    = "左键点击放置路点",
    ui_tacmap_scale        = "每格 %d 米",
    marker_need_squad      = "加入小队后才能放置标记。",

    -- 回合系统
    round_warmup           = "热身阶段",
    round_briefing         = "任务简报",
    round_active           = "任务进行中",
    round_ended            = "回合结束",
    round_intermission     = "幕间休整",
    round_victory          = "胜利",
    round_defeat           = "失败",
    round_draw             = "平局",
    round_next_in          = "下一回合 %d 秒后开始",
    objective_hold_zone    = "占领并守住区域",
    objective_eliminate    = "歼灭敌方力量",
    objective_destroy      = "摧毁目标",
    objective_extract      = "前往区域撤离",
    objective_unknown      = "未知目标",

    -- 语音氛围
    voice_status_idle      = "待机",
    voice_status_tx        = "发送中",
    voice_status_rx        = "接收中 ×%d",

    -- 载具座位
    seat_locked_class      = "该座位需要职业: %s",
    seat_enter_hint        = "上车 %s（%d/%d）",
    seat_exit_hint         = "按 E 下车",
    seat_radio_hint        = "车载电台可用频道: %s",
    seat_generic_name      = "载具",
    seat_role_driver       = "驾驶员",
    seat_role_gunner       = "炮手",
    seat_role_commander    = "车长",
    seat_role_passenger    = "乘员"
}

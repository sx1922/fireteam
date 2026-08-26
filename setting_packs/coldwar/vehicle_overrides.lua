-- setting_packs/coldwar/vehicle_overrides.lua
-- 载具标签覆盖配置：手工指定无法从文件名推断的车型标签
-- 返回 { [className] = {tags={...}, category=..., role=...} }

return {
    -- LVS Mi-8：类名与显示名均可能不含完整国家信息，明确标为华约空中运输。
    ["sw_mi8"] = {
        tags = { "lvs", "coldwar", "warsaw_pact", "coldwar_east", "air", "helicopter", "transport" },
        role = "air"
    },

    -- LVS UH-60：明确标为北约空中运输。
    ["sw_uh60"] = {
        tags = { "lvs", "coldwar", "nato", "coldwar_west", "air", "helicopter", "transport" },
        role = "air"
    },

    -- LFS UAZ-469 暂不列入：当前 gamemode 没有 LFS 适配器，避免产生死配置。
}

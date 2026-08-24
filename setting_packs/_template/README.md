# FIRETEAM Setting Pack Template

## 使用方法
1. 复制本目录为 `setting_packs/你的设定名/`
2. 编辑 `pack.json` 中的 `id`、`name`、`era`
3. 编辑各数据文件填入你的内容
4. 服务器设置 `ft_setting_pack 你的设定名`

## 文件说明

| 文件 | 作用 | 必填 |
|---|---|---|
| pack.json | 元数据 | ✅ |
| factions.lua | 阵营 | ✅ |
| classes.lua | 职业 | ✅ |
| weapons.lua | 武器池规则 | ✅ |
| vehicles.lua | 载具规则 | ⚠️ 可选 |
| voice_presets.lua | 通讯 | ⚠️ 可选 |
| hud_theme.json | UI 主题 | ⚠️ 可选 |
| map_rules.lua | 地图规则 | ⚠️ 可选 |

## 关键原则
- **不要写死武器类名，用 Tag 引用**
- 所有标签使用小写英文 + 下划线
- 每个阵营的 `allowed_tags` 和 `banned_tags` 必须互斥

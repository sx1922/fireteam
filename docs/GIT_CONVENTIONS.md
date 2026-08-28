# FIRETEAM Git Commit Message 规范

用于统一 AI 辅助开发时的提交格式，保证 GitHub 历史可读、可自动生成 CHANGELOG。

## 格式总览

```
<type>(<scope>): <subject>

[body]

[footer]
```

- **第一行**：必填，≤72 字符
- **空行**：第一行与 body 之间必须有空行
- **body**：可选，解释「为什么」而非「做了什么」
- **footer**：可选，关联 issue / BREAKING CHANGE / Co-authored-by

## Type 枚举（固定，不可自创）

| Type    | 含义                                | 触发 CHANGELOG 分类 |
|---------|-------------------------------------|---------------------|
| feat    | 新功能/新模块/新设定包字段          | Added               |
| fix     | Bug 修复                            | Fixed               |
| refactor| 重构（不改行为）                    | Changed             |
| perf    | 性能优化                            | Changed             |
| style   | 代码格式/空白/分号（不影响逻辑）    | —                   |
| docs    | 文档变更                            | —                   |
| test    | 测试增删改                          | —                   |
| build   | 构建系统/CI/依赖                    | —                   |
| chore   | 杂项（版本号/gitignore/工具链）     | —                   |
| revert  | 回滚提交                            | Removed             |
| i18n    | 词条翻译/本地化                     | Added / Changed     |
| data    | 设定包纯数据变更（无代码）          | Changed             |

## Scope 枚举（对应架构目录）

Scope 必须是以下之一，禁止使用模糊词如 `misc`、`other`、`global`：

| Scope              | 对应目录                                                |
|--------------------|---------------------------------------------------------|
| core               | core/ 下基础设施                                        |
| api                | api/ 自动生成接口                                       |
| module:\<name\>    | modules/\<name\>/，如 module:medical, module:inventory  |
| adapter:\<name\>   | modules/adapters/\<name\>, 如 adapter:arc9              |
| entity:\<name\>    | entities/\<name\>, 如 entity:ft_grenade_proj            |
| setting:\<pack\>   | setting_packs/\<pack\>/, 如 setting:coldwar             |
| locale:\<lang\>    | locale/\<lang\>.lua, 如 locale:zh-cn                    |
| content            | content/ 素材                                           |
| docs               | docs/ worklog/                                         |
| ci                 | .github/ CI 配置                                        |

### 多 Scope 处理

一次提交影响多个 scope 时，选最主要的一个作为 scope，其余在 body 中列出：

```
feat(module:medical): 新增肢体血量系统

同时更新:
module:hud (人形图面板)
module:suppression (疼痛叠加)
setting:coldwar (medical_rules.lua)
locale:en, locale:zh-cn
```

## Subject 书写规则

| 规则                       | ✅                                          | ❌                                                       |
|----------------------------|---------------------------------------------|---------------------------------------------------------|
| 动词开头，祈使语气          | add limb health system                      | Added limb health system                                |
| 不加句号                   | fix inventory grid overflow                 | Fix inventory grid overflow.                            |
| ≤72 字符                   | feat(module:medical): add bleeding tier tick| feat(module:medical): implement the bleeding classification tick system with configurable rates |
| 中文项目可用中文 subject    | feat(module:medical): 新增流血分级 tick     | —                                                       |

## Footer 约定

关联 Issue：

```
Closes #42
Refs #38, #40
```

破坏性变更（必须大写 `BREAKING CHANGE`）：

```
BREAKING CHANGE: Fireteam.Vitals.GetHealth() removed, use Fireteam.Medical.GetLimbHp(limb)
```

AI 协作署名：

```
Co-authored-by: Qwen <qwen@alibaba-inc.com>
```


## 完整示例

新功能：

```
feat(module:medical): add limb health system with 7 body parts

Head/chest zero = instant death
Limbs have independent HP pools
Black limb mechanic spreads damage to torso at 1.5x multiplier
Treatment requires specific items per wound type

Setting pack contract: medical_rules.limbMaxHp, treatmentItems

Closes #45
Co-authored-by: Qwen <qwen@alibaba-inc.com>
```

Bug 修复：

```
fix(module:inventory): prevent grid coordinate overflow on drag edge

Items dragged to container boundary could produce negative grid indices,
causing duplicate item slots and save corruption.

Clamp coordinates to [0, cols-1] × [0, rows-1] before placement validation.

Fixes #52
```

设定包数据变更：

```
data(setting:coldwar): adjust chest limb max HP from 80 to 70

Playtest feedback indicated TTK was too forgiving for center-mass shots
under tarkov_lite medical mode.

Refs #48
```

破坏性重构：

```
refactor(core:net_protocol): replace positional serialization with tagged format

WriteAny/ReadAny now uses self-describing type tags instead of implicit
ordering. Old saves are incompatible.

BREAKING CHANGE: Network protocol version bumped to 3. Clients on v2
will be rejected with FT_NET_VERSION_MISMATCH.

Closes #55
```

纯文档：

```
docs: add SYSTEMS_ROADMAP.md with full module dependency matrix

Co-authored-by: Qwen <qwen@alibaba-inc.com>
```

## 禁止事项

| ❌ 禁止                              | ✅ 替代                                  |
|-------------------------------------|------------------------------------------|
| update stuff / fix bug / changes    | 具体描述变更内容                         |
| feat(global): ...                   | 使用精确 scope                           |
| WIP 提交到主分支                    | 用 draft PR 或 feature branch            |
| 一个 commit 混合 feat + fix         | 拆分为独立提交                           |
| Subject 超过 72 字符                | 精简 subject，细节放 body                |
| 省略空行                            | 第一行与 body 之间必须空行               |

## 自动化集成建议

`.github/workflows/lint-commits.yml`：

```yaml
name: lint-commits
on: [pull_request]
jobs:
  commitlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: wagoid/commitlint-github-action@v6
        with:
          configFile: .commitlintrc.json
```

`.commitlintrc.json`：

```json
{
  "extends": ["@commitlint/config-conventional"],
  "rules": {
    "scope-enum": [2, "always", [
      "core", "api", "content", "docs", "ci",
      "module:squad", "module:class", "module:marker", "module:voice",
      "module:hud", "module:rounds", "module:pve", "module:vitals",
      "module:inventory", "module:commander", "module:resupply",
      "module:ai", "module:ballistics", "module:suppression",
      "module:stamina", "module:tacmap", "module:spectate",
      "module:seats", "module:admin", "module:packeditor",
      "module:vote", "module:mainmenu", "module:medical",
      "adapter:arc9", "adapter:tfa", "adapter:cw2",
      "adapter:simfphys", "adapter:lvs",
      "entity:ft_ammo_crate", "entity:ft_grenade_proj", "entity:ft_bot_teammate",
      "setting:coldwar", "setting:_template",
      "locale:en", "locale:zh-cn", "locale:zh-hant",
      "locale:de", "locale:es", "locale:fr", "locale:ja", "locale:ko", "locale:ru"
    ]],
    "type-enum": [2, "always", [
      "feat", "fix", "refactor", "perf", "style", "docs",
      "test", "build", "chore", "revert", "i18n", "data"
    ]],
    "header-max-length": [2, "always", 72],
    "body-leading-blank": [2, "always"]
  }
}
```

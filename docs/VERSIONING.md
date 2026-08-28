# FIRETEAM Versioning Specification / 版本号规范

FIRETEAM 版本号遵循 Semantic Versioning 2.0.0，并针对 GMod Gamemode + 设定包架构做了专属约定。

## Format / 格式

```
MAJOR.MINOR.PATCH[-pre.N]
```

| Segment  | EN Trigger                                            | 中文触发条件                                         | Example              |
|----------|-------------------------------------------------------|------------------------------------------------------|----------------------|
| MAJOR    | Breaking API / setting pack contract / net protocol   | 破坏性 API / 设定包契约 / 网络协议变更               | 1.0.0 → 2.0.0        |
| MINOR    | New module / new feature / new setting pack field (backward-compatible) | 新模块 / 新功能 / 新设定包字段（向后兼容） | 0.3.0 → 0.4.0        |
| PATCH    | Bug fix / locale update / performance tweak (no new feature) | 缺陷修复 / 词条更新 / 性能微调（无新功能）       | 0.3.0 → 0.3.1        |
| -pre.N   | Pre-release (alpha/beta/rc)                           | 预发布版本                                           | 0.3.0-alpha.1, 1.0.0-rc.3 |

> ⚠️ FIRETEAM currently at 0.x.y. Per SemVer, 0.x means public API is not yet stable.
> MAJOR bumps in 0.x are reserved for setting pack contract breaks and net protocol incompatibility.
>
> FIRETEAM 当前处于 0.x.y 阶段。依 SemVer，0.x 表示公共 API 尚未稳定。0.x 阶段的 MAJOR 升级
> 仅用于设定包契约破坏和网络协议不兼容。

## What Counts as Breaking / 破坏性变更判定

Only these trigger MAJOR bump (or MINOR bump during 0.x with explicit migration guide):
仅以下情况触发 MAJOR 升级（0.x 阶段为 MINOR 升级 + 强制迁移指南）：

| Category            | Examples / 示例                                                                 |
|---------------------|---------------------------------------------------------------------------------|
| Setting Pack Contract | Renaming/removing required fields in pack.json, classes.lua, items.lua; changing table structure; removing backward-compat fallback |
| Public API (api/)   | Removing/renaming functions; changing return types; altering callback signatures |
| Net Protocol        | Changing WriteAny/ReadAny serialization format; bumping protocol version constant |
| Entity Interface    | Changing entity class name; removing shared keyvalues that adapters depend on    |
| Config Registry Keys | Removing registered config keys without deprecation cycle                     |

### NOT Breaking / 不算破坏性变更

| Change                                                | Why Not Breaking / 原因                              |
|-------------------------------------------------------|------------------------------------------------------|
| Adding optional setting pack fields (with defaults)   | Old packs still load / 旧包仍可加载                  |
| Adding new modules                                    | No existing code depends on them / 无现有代码依赖   |
| Internal refactor within a module (same API surface)  | Callers unaffected / 调用方不受影响                  |
| Locale string additions/edits                         | Display-only / 仅显示层                              |
| Content asset additions/replacements                 | No code dependency / 无代码依赖                      |
| Adding new adapter                                    | Optional bridge / 可选桥接                           |

## Pre-release Tags / 预发布标签

| Tag     | Meaning / 含义                                  | When to Use / 使用时机                                              |
|---------|------------------------------------------------|---------------------------------------------------------------------|
| alpha.N | Feature-incomplete, internal testing          | Module skeleton exists but not functional / 模块骨架存在但不可用     |
| beta.N  | Feature-complete, community testing            | All planned features work, seeking bug reports / 功能完整，征集缺陷报告 |
| rc.N    | Release candidate, no new changes allowed      | Only critical fixes between rc.N and rc.N+1 / 仅允许关键修复         |

Pre-release versions have lower precedence than the associated normal version:
预发布版本优先级低于对应的正式版本：

```
0.3.0-alpha.1 < 0.3.0-beta.1 < 0.3.0-rc.1 < 0.3.0
```

## Setting Pack Versioning / 设定包版本

Setting packs are versioned independently from the framework. Each pack declares compatibility in pack.json:
设定包与框架独立版本化。每个包在 pack.json 中声明兼容性：

```json
{
  "name": "coldwar",
  "version": "1.2.0",
  "framework_compat": ">=0.3.0 <1.0.0"
}
```

| Field              | Description / 说明                                            |
|--------------------|---------------------------------------------------------------|
| version            | Pack's own SemVer / 包自身语义版本                            |
| framework_compat   | NPM-style range of compatible framework versions / 兼容的框架版本范围 |

Framework NEVER bundles hardcoded pack version checks. Compatibility is declared by the pack,
validated at load time by sv_setting_loader.lua.
框架绝不内置硬编码的包版本检查。兼容性由包自行声明，加载时由 sv_setting_loader.lua 校验。

## Git Tag & Release Naming / Git 标签与发布命名

**Git Tag** — `v<version>`
Examples: `v0.3.0`, `v0.3.1-beta.2`, `v1.0.0-rc.1`

**GitHub Release Title** — `FIRETEAM v<version> — <short bilingual tagline>`
Example: `FIRETEAM v0.3.0 — Limb Health System / 肢体血量系统`

**GMA Addon Version** — GMod workshop uses integer `addon_version`. Map from SemVer:
GMod 创意工坊使用整数 addon_version，映射规则：

```
addon_version = MAJOR * 10000 + MINOR * 100 + PATCH
```

| SemVer  | addon_version |
|---------|---------------|
| 0.3.0   | 300           |
| 0.3.1   | 301           |
| 1.0.0   | 10000         |
| 1.2.3   | 10203         |

Pre-releases are NOT published to Workshop. They are distributed via GitHub Releases only.
预发布版本不上传创意工坊，仅通过 GitHub Releases 分发。

## Bump Decision Flowchart / 版本升级决策流程

```
Change made / 发生变更
    │
    ├─ Breaking API / contract / protocol? ──YES──► MAJOR (or MINOR if 0.x + migration guide)
    │                                               破坏性？──是──► MAJOR（0.x 则为 MINOR + 迁移指南）
    │NO
    ├─ New module / feature / setting field? ──YES──► MINOR
    │                                                新功能？──是──► MINOR
    │NO
    ├─ Bug fix / locale / perf only? ──YES──► PATCH
    │                                          仅修复？──是──► PATCH
    │NO
    └─ Docs / CI / chore only ──────────────► No version bump (tag as needed)
                                               仅文档/CI/杂项 ──► 不升版本（按需打标签）
```

## Changelog Alignment / 与更新日志对齐

Every version bump MUST have a corresponding CHANGELOG.md entry. The changelog section header
matches the git tag exactly:
每次版本升级必须有对应的 CHANGELOG.md 条目。日志章节标题与 git tag 完全一致：

```
[0.3.0] - 2026-08-28
```

Unreleased changes accumulate under `[Unreleased]` and are moved to the new version section at bump time.
未发布变更累积在 `[Unreleased]` 下，升版时移入新版本章节。

## Deprecation Policy / 弃用策略

Breaking changes MUST follow this cycle (except during 0.x alpha):
破坏性变更必须遵循以下周期（0.x alpha 阶段除外）：

| Phase     | Duration / 时长      | Action / 操作                                                       |
|-----------|----------------------|--------------------------------------------------------------------|
| Deprecate | ≥1 MINOR release     | Mark deprecated in code + changelog; provide replacement           |
| Warn      | ≥1 MINOR release     | Runtime warning log when deprecated API is called                  |
| Remove    | Next MAJOR           | Remove code; document in BREAKING CHANGE section                   |

During 0.x: deprecation warnings are encouraged but not mandatory. Migration guides are required
for any breaking change.
0.x 阶段：鼓励但不强制弃用警告。任何破坏性变更均需提供迁移指南。

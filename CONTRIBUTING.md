# Contributing to AAPLCAD SDK

Thank you for your interest in AAPLCAD SDK.

This project currently focuses on a modern CAD SDK for macOS and Apple Silicon, with emphasis on:

- Core / Geometry / Database architecture
- Metal-first rendering and picking
- native macOS productivity workflows
- an evolvable, controllable SDK design without legacy baggage

Before contributing, please note that this repository is still in the design and prototype stage. The current priority is architectural correctness, clear boundaries, and long-term maintainability.

## What to Contribute

The following types of contributions are welcome:

- documentation improvements and corrections
- architecture proposals
- Core / Geometry / Database API drafts
- Metal Viewer prototype code
- performance benchmarks, test samples, and regression cases
- build system, repository structure, and toolchain improvements

The following types of changes are currently discouraged:

- cross-platform work unrelated to the current macOS-first direction
- large third-party dependency additions without prior discussion
- quick feature additions that break module boundaries
- large refactors without a short design explanation

## Before You Start

Please read the following first:

1. [README.md](README.md)
2. [docs/AAPLCAD_SDK_Design.md](docs/AAPLCAD_SDK_Design.md)
3. [docs/AAPLCAD_Development_Plan.md](docs/AAPLCAD_Development_Plan.md)
4. Confirm that your change aligns with the current macOS-first / Metal-first direction

## How to Work

### Small Changes

Suitable for:

- documentation fixes
- typo corrections
- small API naming adjustments
- minor build script improvements

These can usually be submitted as focused, self-contained changes.

### Medium or Large Changes

Suitable for:

- new modules
- public API changes
- rendering architecture updates
- database model changes
- geometry algorithm additions or replacements

Please provide a short design note first, including at least:

- what the change is for
- why it is needed
- which modules it affects
- whether it affects public APIs
- whether it affects performance, stability, or license boundaries

## Code and Design Principles

Please follow these principles when possible:

- fix root causes instead of surface-level patches
- keep module boundaries clear
- avoid over-design for hypothetical future cases
- avoid introducing uncontrollable black-box core dependencies
- do not let file format structures define the internal architecture
- prioritize macOS desktop productivity scenarios
- keep rendering, picking, and interaction aligned with the Metal-first direction

## Submission Guidance

Try to keep each contribution:

- focused in scope
- easy to explain
- consistent in naming
- aligned with the existing style
- free of unrelated changes

If your change touches public interfaces, core data structures, or the graphics pipeline, please also include:

- related documentation updates
- testing or validation notes
- potential risks and known limitations

## Testing and Validation

If the repository already contains relevant tests or demos, please run the appropriate validation before submitting.

Recommended validation order:

1. the smallest scope you changed
2. directly related modules
3. examples or integration scenarios
4. whether there is an obvious performance regression

## License

By contributing, you agree that:

- you have the right to submit the contribution
- your contribution may be distributed under the repository's [Apache-2.0](LICENSE) license
- you will not intentionally submit code or assets that are restricted, infringing, or of unclear origin

If your contribution depends on third-party code, please clearly identify its source and license, and make sure it is compatible with Apache-2.0.

## Design Priorities

When trade-offs occur, the default priority order is:

1. architectural correctness
2. macOS-first productivity experience
3. Metal-first consistency in rendering and picking
4. balance between performance and maintainability
5. feature count

## Communication

If you plan to contribute a larger module, it is recommended to share the following first:

- module goal
- initial interface draft
- relationship to the existing design documents
- risks and dependencies

This helps avoid direction drift and duplicated work during the early stage of the project.

---

# 参与 AAPLCAD SDK 开发

感谢你对 AAPLCAD SDK 的关注。

本项目当前聚焦于一个面向 macOS 与 Apple Silicon 的现代 CAD SDK，重点放在：

- Core / Geometry / Database 架构
- Metal-first 渲染与拾取
- macOS 原生生产力工作流
- 可演进、可控、无历史包袱的 SDK 设计

在提交贡献前，请先理解本仓库当前仍处于设计与原型阶段，优先级是架构正确、边界清晰与可持续演进。

## 贡献范围

欢迎以下类型的贡献：

- 文档完善与纠错
- 架构设计建议
- Core / Geometry / Database API 草案
- Metal Viewer 原型相关代码
- 性能基准、测试样例与回归案例
- 构建系统、工程结构与开发工具链改进

当前暂不鼓励以下类型的提交：

- 与当前 macOS-first 路线无关的跨平台适配
- 大量未讨论的第三方依赖引入
- 破坏模块边界的快速功能堆叠
- 未附设计说明的大规模重构

## 开始之前

建议在开始前：

1. 阅读 [README.md](README.md)
2. 阅读 [docs/AAPLCAD_SDK_Design.md](docs/AAPLCAD_SDK_Design.md)
3. 阅读 [docs/AAPLCAD_Development_Plan.md](docs/AAPLCAD_Development_Plan.md)
4. 确认你的改动是否符合当前的 macOS-first / Metal-first 路线

## 工作方式

### 小改动

适用于：

- 文档修正
- 拼写修复
- 小范围 API 命名调整
- 构建脚本微调

这类改动通常可以直接提交为聚焦、独立的小型变更。

### 中到大型改动

适用于：

- 新模块引入
- 公共 API 设计调整
- 渲染架构调整
- 数据库模型变化
- 几何算法引入或替换

建议先提供一份简短设计说明，至少说明：

- 目标是什么
- 为什么需要这项改动
- 影响哪些模块
- 是否影响公共 API
- 是否影响性能、稳定性或许可证边界

## 代码与设计原则

请尽量遵循以下原则：

- 优先修复根因，而不是表面补丁
- 优先保持模块边界清晰
- 不为假设性的未来场景过度设计
- 不引入不可控的黑盒核心依赖
- 不让文件格式结构反向定义内部架构
- 优先服务 macOS 桌面生产力场景
- 渲染、拾取与交互尽量围绕 Metal-first 思路推进

## 提交建议

每次提交尽量做到：

- 范围聚焦
- 变更可解释
- 命名一致
- 风格统一
- 不混入无关修改

如果你的变更涉及公共接口、核心数据结构或图形管线，请同时补充：

- 相关文档说明
- 测试或验证方法
- 潜在风险与已知限制

## 测试与验证

如果仓库中已有对应测试或 demo，请在提交前完成相关验证。

优先验证顺序：

1. 你修改的最小范围
2. 直接相关模块
3. 示例或集成场景
4. 是否存在明显的性能退化

## 许可证说明

提交贡献即表示你同意：

- 你有权提交这些内容
- 你的贡献可以在本仓库采用的 [Apache-2.0](LICENSE) 协议下分发
- 你不会故意提交受限、侵权或来源不明的代码与资源

如果你的贡献依赖第三方代码，请明确其来源与许可证，并确保其与 Apache-2.0 兼容。

## 设计优先级

在路线发生冲突时，默认优先级如下：

1. 架构正确性
2. macOS-first 生产力体验
3. Metal-first 渲染与拾取一致性
4. 性能与可维护性平衡
5. 功能数量

## 沟通建议

如果你准备贡献较大的模块，建议先同步以下内容：

- 模块目标
- 初步接口草案
- 与现有设计文档的关系
- 风险与依赖

这样可以避免项目早期出现方向偏移或重复建设。

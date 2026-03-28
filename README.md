# AAPLCAD SDK

AAPLCAD SDK is a modern CAD SDK for macOS and Apple Silicon. Its goal is not to port a traditional CAD platform to macOS, but to build a professional engineering foundation for native macOS productivity workflows by rethinking geometry, rendering, and interaction together.

## Positioning

- `macOS-first`: macOS is the only target platform for the current roadmap
- `Apple Silicon-first`: designed around M-series CPU, GPU, and unified memory characteristics
- `Metal-first`: rendering, picking, transient feedback, and the view pipeline are built around Metal
- `Productivity-first`: optimized for multi-window, multi-display, trackpad, keyboard/mouse, and document workflows
- `No legacy baggage`: avoids the black-box dependencies, historical APIs, and licensing baggage of traditional CAD SDKs

## Goals

AAPLCAD SDK is intended to provide the following capabilities for future professional engineering applications:

- 2D / 3D geometry modeling and topology representation
- High-precision constraints and parametric design
- High-performance display and interaction for large drawings and large models
- Interoperability with formats such as DXF / DWG
- Native workflow support for desktop productivity scenarios
- Stable SDK APIs and an extensibility model

## Current Documents

- [Changelog](CHANGELOG.md)
- [Architecture Design](docs/AAPLCAD_SDK_Design.md)
- [Development Plan](docs/AAPLCAD_Development_Plan.md)

## Current Scope

This repository has entered the initial scaffold stage, with focus on:

- SDK architecture definition
- module boundary design
- Apple Silicon / Metal technical direction
- native macOS productivity workflows
- Phase 1 project scaffold and minimum compile targets

## Repository Structure

```text
AAPLCADsdk/
  CMakeLists.txt
  README.md
  LICENSE
  CONTRIBUTING.md
  docs/
  include/
  src/
  apps/
  plugins/
  resources/
  tests/
  examples/
```

## Getting Started

Prerequisites:

- macOS
- CMake 3.20+
- Apple Clang / Xcode command line tools

Configure and build:

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

Current scaffold includes:

- a root `CMakeLists.txt`
- initial `core` and `platform` headers / sources
- a minimal console example target
- a macOS AppKit + Metal viewer prototype target
- a basic unit test target

Run the prototypes:

```bash
./build/aaplcad_minimal_viewer
./build/aaplcad_mac_viewer
```

## License

This repository is licensed under the standard open source [Apache-2.0](LICENSE) license.

This means:

- commercial and non-commercial use are allowed
- modification, redistribution, and derivative works are allowed
- license and copyright notices must be preserved
- patent grant and warranty disclaimer are explicitly included

## Contributing

Contributions around design, architecture, prototypes, testing, and documentation are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before contributing.

Suggested priority areas for contribution:

- Core / Geometry / Database API drafts
- Metal Viewer prototypes
- macOS input abstraction and command workflow design
- DXF / data model design
- performance tests and regression baselines

## Status

Current status: `Bootstrap / Phase 1`.

Completed:

1. Root project and directory scaffold
2. Initial Core / Platform API placeholders
3. Initial Geometry / Database API placeholders
4. Minimal example, macOS Metal viewer prototype, and unit test targets

Next:

1. macOS input abstraction expansion for trackpad / keyboard semantics
2. Basic testing and benchmarking expansion
3. Selection, picking, and navigation prototype wiring

---

# AAPLCAD SDK

AAPLCAD SDK 是一个面向 macOS 与 Apple Silicon 的现代 CAD SDK。它的目标不是把传统 CAD 平台移植到 macOS，而是从几何、渲染、交互三层一起重构，构建一个真正服务 macOS 原生生产力工作流的专业工程底座。

## 定位

- `macOS-first`：当前路线图的唯一目标平台是 macOS
- `Apple Silicon-first`：围绕 M 系列芯片的 CPU、GPU 与统一内存特性设计
- `Metal-first`：渲染、拾取、瞬态反馈与视图管线都以 Metal 为核心
- `Productivity-first`：强调多窗口、多显示器、触控板、键盘鼠标与文档工作流
- `No legacy baggage`：避免传统 CAD SDK 的黑盒依赖、历史 API 和许可证包袱

## 目标

AAPLCAD SDK 计划为后续专业级工程应用提供以下能力：

- 2D / 3D 几何建模与拓扑表示
- 高精度约束求解与参数化设计
- 大图纸 / 大模型的高性能显示与交互
- DXF / DWG 等格式互操作能力
- 面向桌面生产力场景的原生工作流支持
- 稳定的 SDK API 与扩展机制

## 当前文档

- [总体设计文档](docs/AAPLCAD_SDK_Design.md)
- [开发规划文档](docs/AAPLCAD_Development_Plan.md)

## 当前范围

当前仓库已进入初始工程骨架阶段，重点聚焦：

- SDK 架构定义
- 模块边界划分
- Apple Silicon / Metal 技术路线
- macOS 原生生产力工作流设计
- Phase 1 工程骨架与最小可编译目标

## 仓库结构

```text
AAPLCADsdk/
  CMakeLists.txt
  README.md
  LICENSE
  CONTRIBUTING.md
  docs/
  include/
  src/
  apps/
  plugins/
  resources/
  tests/
  examples/
```

## 快速开始

前置条件：

- macOS
- CMake 3.20+
- Apple Clang / Xcode Command Line Tools

配置与构建：

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

当前骨架已包含：

- 根级 `CMakeLists.txt`
- 初始 `core` 与 `platform` 头文件 / 源文件
- 最小控制台示例目标
- macOS AppKit + Metal viewer 原型目标
- 基础单元测试目标

运行原型：

```bash
./build/aaplcad_minimal_viewer
./build/aaplcad_mac_viewer
```

## 许可说明

本仓库采用标准开源协议 [Apache-2.0](LICENSE)。

这意味着：

- 允许商业和非商业使用
- 允许修改、分发和衍生开发
- 需要保留许可证与版权声明
- 明确包含专利授权与免责声明

## 贡献

欢迎围绕设计、架构、原型、测试和文档进行贡献。提交前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

建议优先贡献的方向：

- Core / Geometry / Database API 草案
- Metal Viewer 原型
- macOS 输入抽象与命令工作流
- DXF / 数据模型设计
- 性能测试与回归基线

## 状态

当前状态：`Bootstrap / Phase 1`。

已完成：

1. 根工程与目录骨架
2. 初始 Core / Platform API 占位
3. 初始 Geometry / Database API 占位
4. 最小示例、macOS Metal viewer 原型与单元测试目标

下一步：

1. macOS 输入抽象扩展到 trackpad / keyboard 语义
2. 基础测试与 benchmark 扩展
3. 选择、拾取与导航原型接线

# AAPLCAD SDK 设计文档（Apple-first / Apple Silicon 原生）

## 1. 项目目标

AAPLCAD SDK 的目标不是再做一个传统 CAD SDK 的 macOS 移植版，而是构建一个完全 Apple-first、面向 Apple Silicon 和 Apple 设备生态的现代 CAD 基础平台。它要为后续开发在 macOS 上接近或匹敌 AutoCAD 的专业级工程应用提供稳定、高性能、可扩展的技术底座，同时在交互方式、渲染架构、设备协同和开发者开放性上做出差异化。

该 SDK 不是单一绘图控件，而是一整套面向工程 CAD 的内核与平台能力集合，需覆盖：

- 2D/3D 几何建模与拓扑表示
- 高精度约束求解与参数化设计
- 大图纸/大模型的高性能显示与交互
- Metal-first 的渲染、拾取、瞬态反馈与视图管线
- 原生 macOS UI、触控板、键盘、窗口、多显示器与文件系统集成
- 面向 macOS 生产力平台的原生交互抽象与工作流优化
- 面向 M 系列芯片的 CPU/GPU/统一内存优化
- DXF/DWG 等格式的读写与互操作层，但不让历史格式反向定义核心架构
- 为上层专业应用提供稳定 SDK/API 与插件扩展机制

### 1.1 差异化目标

AAPLCAD SDK 的差异化不建立在“兼容传统 CAD 历史包袱”上，而建立在以下几点：

- 完全 Apple-first，而不是跨平台最小公约数
- Metal-first 渲染与拾取，而不是 OpenGL/旧图形后端兼容迁移
- 从第一天就为触控板、键盘、鼠标、多窗口、多显示器协作设计
- 几何层、显示层、交互层一起重构，而不是仅替换 UI 壳层
- 不背负传统 CAD SDK 的许可证、黑盒实现和历史 API 负担

### 1.2 产品战略定位

市场上已经存在“支持 Apple Silicon 的 CAD 软件”或“可在 macOS 上运行的 CAD 内核”，但真正从 Apple 生态特性出发设计的现代 CAD SDK 仍然稀缺。

因此，AAPLCAD SDK 的定位不是“另一个 CAD 内核”，而是：

- 一个 Apple 原生工程设计平台内核
- 一个面向未来设备形态的 CAD Interaction + Geometry + Rendering 基础设施
- 一个对上层应用开放、可控、无黑盒依赖的现代 SDK

---

## 2. 设计原则

### 2.1 Apple-first

- Apple 平台能力不是“适配项”，而是架构输入条件。
- macOS 是当前唯一目标平台，所有架构决策优先服务桌面生产力场景。
- 图形层、输入系统、文档系统、协同能力都优先围绕 macOS 专业工作流设计。

### 2.2 Metal-first

- 所有显示、拾取、瞬态反馈、选择高亮、自定义叠加层都以 Metal 为第一实现。
- 不以兼容旧式 OpenGL 或传统 CAD 图形管线为前提。
- 渲染与拾取架构从一开始统一设计，避免后期补丁式双系统并存。

### 2.3 Apple Silicon 优先

- 优先针对 M 系列 CPU 的高单核性能、大小核调度、统一内存、GPU 并行能力设计。
- 数据结构与执行模型考虑缓存局部性、SIMD、批处理、低复制。
- 避免沿用仅适合 x86 + 独显时代的内存与渲染架构。

### 2.4 交互一等公民

- 触控板手势、键盘快捷键、精确鼠标输入、多窗口焦点切换都属于一等输入语义。
- 几何层、显示层、交互层同步设计，避免传统 CAD 中“内核先定死，交互层被迫适配”的问题。
- 输入抽象应统一支持 macOS 下的多种输入设备与命令编辑语义。

### 2.5 内核与界面解耦

- 几何内核、数据库、约束系统、渲染后端、UI 框架严格分层。
- SDK 可作为静态库/动态库嵌入桌面应用，也应支持后续命令行批处理、测试工具、云端几何服务化复用。

### 2.6 专业 CAD 优先

- 优先满足工程场景的精度、稳定性、可恢复性、格式兼容性、批注与图层体系，而不是先做轻量草图工具。
- 关键操作需可撤销/重做、事务化、可审计。

### 2.7 无历史包袱

- 不复制 ObjectARX 式复杂历史 API。
- 不把外部文件格式结构直接当作内部对象模型。
- 不依赖难以控制的闭源黑盒模块作为核心架构基础。

### 2.8 可演进架构

- 初期实现可聚焦 2D + 基础 3D，但架构必须预留大型装配、参数化、BIM/MCAD 扩展、脚本自动化、插件生态能力。

---

## 3. 产品定位与范围

### 3.0 首先定义“不是做什么”

AAPLCAD SDK 不追求以下路线：

- 不做传统 Windows CAD 内核的简单 macOS 迁移壳层
- 不做只强调文件兼容的格式中间层
- 不做只能嵌入视图控件、却无法主导现代交互体验的老式 SDK
- 不做被许可证和黑盒算法严格锁死、难以深度定制的平台

### 3.1 短期目标（MVP ~ v1）

构建一个可用于专业 2D CAD 与基础 3D 浏览/编辑的 Apple-first 原生 SDK：

- 2D 图元：点、线、圆、圆弧、椭圆、样条、多段线、文字、标注、块引用
- 图纸数据库：图层、线型、颜色、样式、块表、对象 ID、事务
- 基础约束：水平、垂直、平行、垂直、同心、相切、尺寸驱动
- 渲染：高性能 2D 显示、Metal 拾取、缩放平移、瞬态反馈、打印预览
- 文件：DXF 稳定读写，DWG 通过适配层预留
- 原生应用集成：文档窗口、多 tab、撤销重做、文件拖放、Quick Look 预留
- 输入体验：触控板优先的视图导航、键盘驱动命令流、面向桌面生产力的交互一致性

### 3.2 中期目标（v2 ~ v3）

- ACIS / Parasolid 风格 B-Rep 能力或自主 B-Rep 内核
- 布尔运算、拉伸、旋转、扫掠、倒角、圆角
- 大型图纸分页加载与视图缓存
- 多线程求交、批量选择、后台索引与 Regen
- PDF/STEP/IGES/SVG 输出扩展
- 多窗口文档协同与多显示器工作流
- macOS 专业审阅、批注与发布能力
- 脚本/API 自动化层

### 3.3 长期目标（v4+）

- 复杂参数化装配
- 约束驱动 3D 特征建模
- 云协作/版本合并
- 行业插件生态
- BIM/GIS 互通
- AI 辅助识图、约束推断、命令补全
- 跨设备连续设计工作流
- 空间计算场景下的工程审阅与协同

---

## 4. 总体架构

建议采用如下分层：

1. Platform Layer（平台层）
2. Core Foundation（基础设施层）
3. Geometry Kernel（几何内核）
4. CAD Database（图形数据库层）
5. Constraint & Parametric（约束参数化层）
6. Graphics Engine（图形渲染层）
7. Interaction Engine（交互引擎层）
8. Device Experience Layer（设备体验层）
9. File IO & Interop（文件与互操作层）
10. Application Service Layer（应用服务层）
11. SDK API & Plugin Layer（对外接口与插件层）

---

## 5. 模块设计

## 5.1 Platform Layer

职责：封装 macOS / Apple Silicon 平台能力。

建议子模块：

- `platform::threading`
  - GCD 任务调度封装
  - QoS 优先级映射
  - 后台计算/前台渲染分离
- `platform::memory`
  - 小对象池
  - Arena/Frame allocator
  - 统一内存感知的缓存策略
- `platform::metal`
  - MTLDevice / CommandQueue / Pipeline 管理
- `platform::windowing`
  - NSWindow / NSView / NSResponder 封装
- `platform::fs`
  - 文件读写、沙盒兼容、文件监听
- `platform::telemetry`
  - os_log / signpost / tracing

设计要求：

- 不把 AppKit 直接渗透到几何内核。
- 不把 UIKit / PencilKit / RealityKit 直接渗透到几何内核。
- 平台层对上提供窄接口，便于单元测试和未来平台扩展。

---

## 5.2 Core Foundation

职责：提供整个 SDK 的基础设施。

包含：

- 基础数学类型：向量、矩阵、包围盒、区间、坐标系、变换
- 高精度数值工具：容差、稳健谓词、数值求解器接口
- 容器：小向量、稳定句柄表、slot map、稀疏集合
- RTTI/反射（轻量）
- 错误系统：`Result<T, Error>` / 错误码 / 诊断信息
- 日志系统
- 序列化框架
- UUID / Handle / ObjectId 系统

关键要求：

- 几何计算使用双精度 `double` 为主。
- 显示层可按需转换到 `float`/GPU buffer。
- 所有公共 API 使用稳定 ABI 边界策略，避免随意暴露 STL 细节。

---

## 5.3 Geometry Kernel

职责：提供 2D/3D 几何实体、求交、测量、投影、偏移、拓扑构建等能力。

### 实体层

2D：

- Point2D
- Line2D
- Ray2D
- Circle2D
- Arc2D
- Ellipse2D
- Spline2D / NURBS2D
- Polyline2D

3D：

- Point3D
- Line3D
- Plane
- Circle3D
- NURBSCurve
- NURBSSurface
- Mesh
- BRep（长期）

### 算法层

- 曲线求值与导数
- 包围盒计算
- 曲线/曲线、曲线/面求交
- 最近点查询
- 偏移
- 裁剪
- 投影
- 面积、长度、体积计算
- 网格化/细分

### 设计策略

- 2D 几何与 3D 几何共享数值基础，但接口分层清晰。
- 几何对象尽量不可变或逻辑不可变，修改通过编辑器/构造器完成。
- 对昂贵算法提供取消控制、进度反馈、后台执行能力。

---

## 5.4 CAD Database

职责：承载 CAD 文档对象模型，相当于 DWG/DXF 风格对象数据库抽象。

核心对象：

- Document
- Database
- Table / Record
- Layer
- Linetype
- BlockDefinition
- BlockReference
- Entity
- Viewport
- TextStyle
- DimStyle
- Material
- Layout

关键机制：

- 对象唯一 ID
- 打开/关闭对象语义（可借鉴 ARX 思路但做现代化简化）
- 事务系统
- Undo/Redo journal
- Dirty 标记与增量 regen
- 依赖图与引用关系
- 事件总线（对象创建/修改/删除）

建议数据模型：

- 持久对象用 `ObjectId`
- 运行时缓存用 `Handle`
- 大对象采用分块存储与写时复制策略

---

## 5.5 Constraint & Parametric

职责：提供草图约束与参数驱动能力。

功能：

- 几何约束
- 尺寸约束
- 参数表达式
- 解算器状态管理
- 冲突检测
- 欠约束/过约束分析

建议架构：

- `ConstraintGraph`
- `SolverContext`
- `ParameterTable`
- `ExpressionEngine`
- `DiagnosticEngine`

实现建议：

- MVP 可先支持 2D 草图级约束。
- 解算器可自研或集成成熟开源方案并进行 API 包装。
- 求解过程要支持增量求解，而非全量重算。

---

## 5.6 Graphics Engine

职责：提供基于 Metal 的高性能 CAD 显示引擎。

### 渲染目标

- Retina 清晰显示
- 超大图纸平滑缩放与平移
- 精确选择与高亮
- Metal-first 拾取与命令预览
- 图层显隐/冻结/锁定
- 线型、线宽、透明度、文本、标注正确渲染
- 3D 模型基础光照与边线显示

### 渲染分层

- Scene Graph / Draw List 构建
- Tessellation / Geometry Cache
- GPU Buffer Streaming
- Render Pass 管理
- Text & Annotation 渲染
- Selection / Picking Pass
- Print / Vector Export Pass
- Transient / Preview Overlay Pass

### Metal 优化方向

- 使用 argument buffers / indirect command buffers 预留批量绘制能力
- 大量实体采用 instancing 或统一结构 buffer
- CPU 端构建增量 draw list，减少全量重建
- 充分利用 unified memory，避免不必要 CPU-GPU 数据复制
- 文本与标注采用 atlas/cache 策略
- 对复杂样条和虚线进行多级缓存

### CAD 特有挑战

- 与游戏渲染不同，CAD 更强调几何精确性和线框清晰度
- 缩放级别跨度极大，需要 LOD 与精度切换策略
- 选择拾取必须精确且可解释

---

## 5.7 Interaction Engine

职责：管理视图交互、捕捉、命令输入与编辑反馈。

功能模块：

- 相机/视图控制
- 对象捕捉（端点、中点、圆心、切点、交点、最近点）
- 极轴追踪/对象追踪
- 选择框、套索、多选、过滤
- Grip 编辑
- 命令预览
- 动态输入
- 辅助标尺与状态栏反馈

架构建议：

- `InputEvent` 抽象层
- `CommandContext`
- `SelectionManager`
- `SnapEngine`
- `ManipulatorSystem`
- `TransientGraphics`

关键点：

- 输入系统与平台事件解耦。
- 瞬态图形与正式数据库对象分离。
- 保证高频鼠标移动下交互延迟低。
- 交互模型从一开始兼容触控板、手写笔和空间指向设备。

---

## 5.8 Device Experience Layer

职责：把 Apple 生态特有的输入与设备能力，映射为统一 CAD 交互语义。

建议子模块：

- `device::trackpad`
  - 双指平移、缩放、旋转手势
  - 惯性滚动与 CAD 视图控制映射
- `device::pencil`
  - 压力、倾角、悬停、笔尖/手指区分
  - 草图输入与精确约束预判
- `device::spatial`
  - Vision Pro 指向、凝视、手势确认、空间标注
- `device::continuity`
  - 多窗口状态同步与文档焦点切换
  - 跨显示器会话保持与工作区恢复

设计目标：

- 同一命令系统可由鼠标、触控板、键盘快捷键和桌面命令面板驱动。
- 输入设备差异体现在“能力映射层”，而不是污染几何和数据库 API。
- 当前阶段只服务 macOS；其他 Apple 设备形态仅保留未来扩展空间，不进入当前交付范围。

---

## 5.9 File IO & Interop

职责：负责文件格式读写和外部系统互通。

阶段性建议：

### 第一阶段

- 自定义 AAPLCAD 文档格式（建议二进制主文件 + JSON 元数据）
- DXF 导入导出
- SVG/PDF 导出

### 第二阶段

- DWG 适配层（通过商业库或授权方案）
- STEP/IGES 输入输出
- 图像与打印管线增强

设计原则：

- 文件解析层与数据库对象构建解耦
- 导入过程支持容错和诊断
- 对大型文件支持分阶段加载
- 保留版本升级/迁移机制

---

## 5.10 Application Service Layer

职责：提供接近完整 CAD 应用所需的通用服务。

包含：

- 命令系统
- 撤销/重做管理
- 文档管理
- 自动保存/恢复
- 配置系统
- 资源管理（字体、线型、模板）
- 打印/发布服务
- 脚本执行宿主
- 权限与许可预留

建议模式：

- 命令对象 + 事务边界
- 文档生命周期由 `DocumentController` 管理
- 全局服务与文档级服务分离

---

## 5.11 SDK API & Plugin Layer

职责：向上层应用与第三方扩展开放稳定接口。

### 对外 API 形态建议

- 首选 C++17 核心 API
- 提供 Objective-C++ / Swift bridge 供 macOS 应用层调用
- 预留 C API 边界，便于未来脚本绑定与 ABI 稳定

### 插件模型建议

- 命令扩展
- 自定义实体
- 文件格式扩展
- 面板/工具扩展
- 自动化脚本扩展

### API 稳定性原则

- Public SDK 头文件与 Internal 头文件分离
- `include/aaplcad/` 放稳定接口
- `src/` 内部实现不对外暴露
- 使用版本命名空间和特性开关

---

## 6. 针对 Apple Silicon 的专项优化

## 6.1 CPU 优化

- 针对高频几何计算做 SIMD 向量化
- 使用 SoA（Structure of Arrays）提升批量计算效率
- 将短小高频任务批量化，避免线程切换过碎
- 前台交互任务使用较高 QoS，后台 regen/index/IO 使用较低 QoS
- 根据性能剖析决定是否区分 P-Core / E-Core 友好任务模型

## 6.2 GPU 优化

- 2D/线框渲染尽量采用专用 pipeline，避免通用 3D 管线额外开销
- 高亮、选择、遮罩、文字分别设计 pass
- 通过 Metal buffer recycling 减少频繁分配
- 大模型场景采用 tile/region 增量刷新策略

## 6.3 统一内存策略

Apple Silicon 的统一内存意味着 CPU/GPU 共享物理内存，但仍需避免：

- 频繁改写大块共享 buffer
- 不必要的中间拷贝
- 非连续数据访问

建议：

- 建立只读几何缓存与短生命周期动态缓存分离机制
- 使用 immutable geometry cache + small dynamic overlay
- 将选择、捕捉、预览数据独立管理，避免污染主渲染缓存

## 6.4 启动与交互延迟优化

- 冷启动最小化初始化路径
- 文档打开采用分阶段加载：元数据、索引、当前视图、后台全量准备
- 首屏显示优先于全量解析
- 常用图元和字体资源预热

---

## 7. 推荐技术栈

## 7.1 语言

- 核心：C++17 或 C++20（建议以 C++17 起步，保持工具链稳定）
- macOS 集成层：Objective-C++
- 上层应用/UI 可选：AppKit + Swift/SwiftUI（但绘图视图仍建议 NSView/Metal）

## 7.2 构建系统

- CMake
- Xcode toolchain
- Clang
- Ninja（可选）

## 7.3 测试与质量

- 单元测试：Catch2 或 GoogleTest
- 基准测试：Google Benchmark 或自定义 benchmark harness
- 渲染回归：图像快照 + 几何结果校验
- 性能分析：Instruments + Metal System Trace + Time Profiler

## 7.4 第三方库策略

建议谨慎引入第三方库，仅在下列方向优先考虑：

- 数学库：自研轻量或受控引入
- 约束求解器：可引入成熟方案做包装
- 文件格式：对 DWG 优先使用商业授权方案
- 文本整形与字体：使用 Core Text / Core Graphics 能力优先

原则：

- 几何核心、数据库核心、交互核心尽量自主掌控
- 关键商业壁垒不依赖不可控开源组件

---

## 8. Apple-first 差异化路线

SDK 的差异化应明确围绕以下方向展开：

### 8.1 输入范式差异化

- 不是只支持鼠标键盘，而是把触控板作为主流输入方式之一
- 触控板、快捷键、命令面板和多窗口联动必须优于传统移植式 CAD 体验
- macOS 原生文档、预览、拖放、服务集成要成为生产力差异化的一部分

### 8.2 架构差异化

- 几何层、显示层、交互层同步设计，而不是几何先行、交互补丁式追加
- Metal 拾取与渲染统一规划，避免传统 CPU picking 与 GPU render 割裂
- 设备能力通过统一交互语义抽象，不为单一历史平台妥协

### 8.3 生态差异化

- 以 macOS 作为唯一主设计与主生产力平台
- 跨应用、跨窗口、跨显示器工作流作为桌面端差异化能力
- 跨设备工作流从文档状态与命令语义层面设计，而非简单文件同步

### 8.4 商业差异化

- 降低对传统黑盒 CAD SDK 的依赖
- 避免高许可证成本和核心能力不可控问题
- 将“现代 Apple 原生体验”变成 SDK 的独特卖点，而不仅是上层应用的 UI 包装

---

## 9. 代码组织建议

建议目录结构：

```text
AAPLCADsdk/
  CMakeLists.txt
  docs/
  include/
    aaplcad/
      core/
      geometry/
      database/
      graphics/
      io/
      app/
  src/
    core/
    geometry/
    database/
    constraints/
    graphics/
    interaction/
    io/
    platform/
    app/
  apps/
    mac_viewer/
    mac_professional/
  plugins/
  tests/
    unit/
    integration/
    performance/
  examples/
  resources/
```

命名约定：

- 命名空间：`aaplcad::core`、`aaplcad::geom`、`aaplcad::db` 等
- 对外头文件只暴露必要类型
- 模块内部实现使用 PImpl 或 internal namespace 控制编译依赖

---

## 10. API 设计建议

## 9.1 核心 API 风格

- 倾向现代 C++，但避免过度模板化污染 SDK 易用性
- 公共接口使用清晰、稳定、可文档化的对象模型
- 对错误敏感操作返回显式状态，而不是依赖异常传递全部错误

示例风格：

```cpp
namespace aaplcad::db {

class Document {
public:
    Result<ObjectId> addEntity(std::unique_ptr<Entity> entity);
    Result<void> eraseEntity(ObjectId id);
    Result<Entity*> openEntity(ObjectId id, OpenMode mode);
};

}
```

## 9.2 线程模型建议

- `Document` 默认非线程安全写入
- 允许只读快照并发访问
- 大型计算通过 job system 输出结果后再主线程提交事务

## 9.3 扩展性建议

- 实体基类保留自定义扩展点
- 渲染器支持 entity adapter
- 文件导入导出器使用 provider 注册机制

---

## 11. 性能目标（建议指标）

以下为设计阶段建议目标，可在原型后细化：

- 10 万级 2D 实体图纸下保持流畅缩放/平移
- 常见编辑操作反馈时间 < 16 ms（理想）/ < 50 ms（上限）
- 文档冷启动进入首屏时间显著优于传统跨平台方案
- 批量选择、捕捉、重生成可增量执行
- 大模型/大图纸内存占用对统一内存环境友好

---

## 12. 关键风险与应对

## 11.1 DWG 兼容风险

风险：DWG 生态复杂，完全自研成本极高。

应对：

- 第一阶段聚焦 DXF + 自有格式
- DWG 通过商业授权库/适配层集成
- 核心数据库模型与具体文件格式解耦

## 11.2 几何内核复杂度高

风险：稳健求交、B-Rep、约束求解难度极高。

应对：

- 先做强 2D 内核与基础 3D
- 高风险算法分阶段引入
- 建立严格几何回归测试集

## 11.3 渲染精度与性能平衡

风险：CAD 需要精度与清晰度，容易与 GPU 高吞吐设计冲突。

应对：

- CPU 双精度 + GPU 渲染缓存分层
- 视图空间变换与多级缓存策略
- 针对文本、线型、选择单独优化

## 11.4 macOS 原生 UI 与复杂交互融合

风险：工程级交互复杂，SwiftUI 单独承载不合适。

应对：

- 核心绘图与交互使用 AppKit + Metal
- SwiftUI 仅用于外围面板/设置等可选区域

---

## 13. 分阶段实施路线图

## Phase 0：技术预研

目标：明确关键技术选择与风险。

产出：

- Geometry math prototype
- Metal 2D viewer prototype
- Document/ObjectId/Transaction prototype
- DXF importer prototype
- 性能基准与 profiling 基线

## Phase 1：SDK 核心骨架

目标：搭建可持续演进的工程结构。

产出：

- CMake 工程
- core/platform/database/geometry 基础模块
- 公共头文件与内部实现分离
- 单元测试框架
- 基础 viewer demo

## Phase 2：2D 专业能力

目标：形成可用的 2D CAD 内核。

产出：

- 常见 2D 图元
- 图层/块/样式/标注基础
- 选择、捕捉、缩放平移
- DXF 导入导出
- Undo/Redo 与事务

## Phase 3：约束与高级交互

目标：增强工程设计能力。

产出：

- 2D 约束解算器
- Grip 编辑
- 命令系统
- 动态输入与预览

## Phase 4：3D 与高级格式

目标：进入更完整专业 CAD 能力。

产出：

- 3D 几何与显示
- STEP/IGES
- 布尔/拉伸/旋转等基础特征
- 大模型优化

## Phase 5：商业化与生态

目标：形成专业产品平台。

产出：

- 插件系统
- 脚本自动化
- 授权/部署/崩溃恢复
- DWG 商业互通能力

---

## 14. 首批建议落地对象

如果下一步开始写代码，建议优先实现以下最小闭环：

1. `core`：数学、错误、ID、日志
2. `geometry2d`：Line/Circle/Arc/Polyline 基础几何
3. `database`：Document、Entity、Layer、Transaction
4. `graphics`：Metal 2D viewer
5. `interaction`：Pan/Zoom/Select/Snap 基础能力
6. `io`：最小 DXF 导入器
7. `app demo`：macOS 原生示例程序

这个闭环一旦完成，就具备：

- 打开简单图纸
- 显示与交互
- 基本编辑
- 构建性能基线
- 验证后续架构正确性

---

## 15. 建议的下一步

建议按以下顺序继续推进：

1. 固化代码目录与 CMake 工程骨架
2. 定义 `core` / `geometry` / `database` 的公共 API 草案
3. 搭建 Metal 原型 viewer
4. 建立基准测试与回归测试机制
5. 再进入 DXF / 约束 / 交互系统的实现

如果需要，我下一步可以继续直接完成以下任一内容：

- 初始化整个 SDK 的目录结构与 CMake 工程
- 先搭建 `core + geometry + database` 代码骨架
- 先做一个 macOS + Metal 的原生 CAD Viewer 原型
- 把这份设计文档再细化成模块级接口规范

# Celestia-Shell 项目分析报告

> 本报告完全基于项目源代码分析，不参考任何 Markdown 文档或注释（除非代码本身自带）。

---

## 1. 项目概述

**CuTShell-Niri (Celestia-Shell)** 是一个基于 **Quickshell** 框架、为 **Niri** Wayland 窗口管理器打造的桌面环境 Shell。项目通过 C++ 原生插件与 Niri 的 Unix Socket IPC 直接通信，实现了工作区管理、窗口操作、键盘布局监控等深度集成。

**文件统计（仅源码）：**
- QML: ~280 个 `.qml` 文件
- C++: ~38 个文件（`.cpp` + `.hpp`）+ 5 个 `CMakeLists.txt`
- Python: ~18 个 `.py` 文件
- Shell: ~17 个 `.sh` 文件
- 构建: `CMakeLists.txt` × 5、`flake.nix`、`devbox.json`

---

## 2. 技术栈

| 层面 | 技术 |
|---|---|
| Shell 框架 | Quickshell (QML 运行时 + Wayland layer-shell) |
| UI 语言 | QML (Qt6 Declarative) |
| 原生插件 | C++20, Qt6 (Core/Qml/Quick/Concurrent/Network/Sql/Multimedia/Gui/DBus) |
| 构建系统 | CMake 3.19+, Ninja |
| 包管理 | Nix Flake (NixOS/nix 用户) + devbox (通用开发环境) |
| IPC 协议 | Niri Wayland compositor JSON-over-Unix-Socket |
| 音频后端 | PipeWire (libpipewire-0.3) |
| 主题引擎 | Material You (matugen / material-color-utilities) |
| 外部依赖 | cava (音频可视化), aubio (节拍检测), libqalculate (计算器) |

---

## 3. 项目结构

```
.
├── shell.qml                          # 入口文件
├── shell.json                          # 用户配置文件（运行时）
├── CMakeLists.txt                      # 顶层 CMake 构建（版本提取、模块分发）
├── flake.nix                           # Nix Flake 构建 / 开发环境
├── devbox.json                         # Devbox 开发环境
│
├── config/                             # 19 个文件 — 配置系统
│   ├── Config.qml                      # 核心配置适配器（Singleton + JsonAdapter）
│   ├── Appearance.qml                  # 外观快捷访问（重导出）
│   ├── AppearanceConfig.qml            # 视觉外观：圆角/间距/字体/动画曲线/透明度
│   ├── BarConfig.qml                   # 顶部栏：工作区/托盘/状态/时钟/布局
│   ├── BackgroundConfig.qml            # 桌面背景：壁纸/桌面时钟/可视化
│   ├── BorderConfig.qml                # 窗口边框：厚度/圆角
│   ├── ControlCenterConfig.qml         # 控制中心尺寸
│   ├── DashboardConfig.qml             # 仪表盘：性能/天气/媒体
│   ├── ExtraConfig.qml                 # 额外功能：漫画/小说开关
│   ├── GeneralConfig.qml               # 通用：应用命令/电池警告
│   ├── LauncherConfig.qml              # 启动器：模糊搜索/收藏/尺寸
│   ├── LockConfig.qml                  # 锁屏：指纹/尺寸
│   ├── NotifsConfig.qml                # 通知：过期/分组/尺寸
│   ├── OsdConfig.qml                   # OSD：亮度/音量显示
│   ├── ServiceConfig.qml               # 服务：天气/时钟/GPU/播放器
│   ├── SessionConfig.qml               # 电源：命令/快捷键
│   ├── SidebarConfig.qml               # ⚠ 未接入 Config.qml
│   ├── UserPaths.qml                   # 用户路径：壁纸目录
│   └── UtilitiesConfig.qml             # 工具：Toast/VPN
│
├── services/                           # 30 个文件 — 后台服务层（全部 pragma Singleton）
│   ├── AppUsage.qml                    # 应用使用统计（SQLite 持久化）
│   ├── Audio.qml                       # PipeWire 音频管理
│   ├── BatteryMonitor.qml              # UPower 电池监控 + 自动休眠
│   ├── BeatDetector.qml                # ⚠ 节拍检测（死代码，硬编码 150 BPM）
│   ├── Brightness.qml                  # 亮度控制（brightnessctl / ddcutil / asdbctl）
│   ├── Cava.qml                        # ⚠ 音频可视化（死代码，空实现）
│   ├── Colours.qml                     # Material You 颜色管理（460 行）
│   ├── Fonts.qml                       # 系统字体列表
│   ├── FrequencyTracker.qml            # 应用启动频率追踪
│   ├── IdleInhibitor.qml              # 空闲抑制（systemd-inhibit）
│   ├── IdleService.qml                 # 空闲检测（xprintidle）
│   ├── M3Variants.qml                  # M3 色彩变体选择
│   ├── Manga.qml                       # 漫画阅读器服务（639 行）
│   ├── Network.qml                     # 网络管理（NetworkManager）
│   ├── NetworkUsage.qml               # 网络流量监控（/proc/net/dev）
│   ├── Niri.qml                        # Niri IPC 门面封装（470 行）
│   ├── Nmcli.qml                       # nmcli 底层封装（1377 行，最大文件）
│   ├── Notifs.qml                      # 通知服务（524 行，JSON 持久化）
│   ├── Novel.qml                       # 小说阅读器服务（494 行）
│   ├── Players.qml                     # MPRIS 媒体播放器
│   ├── PolkitService.qml               # PolicyKit 鉴权代理
│   ├── Schemes.qml                     # 配色方案管理
│   ├── SysMonitorService.qml          # 系统监控（362 行，CPU/GPU/内存/进程）
│   ├── SystemUsage.qml                 # 轻量系统资源使用
│   ├── Time.qml                        # 时钟（简洁，27 行）
│   ├── VPN.qml                         # VPN 管理（WireGuard/WARP/NetBird/Tailscale）
│   ├── Visibilities.qml                # 面板可见性状态
│   ├── Wallpapers.qml                  # 壁纸管理
│   └── Weather.qml                     # 天气（Open-Meteo API）
│
├── modules/                            # UI 模块层
│   ├── bar/                            # 顶部栏（13+ 文件）
│   │   ├── Bar.qml, BarWrapper.qml
│   │   ├── components/ ActiveWindow, Clock, Tray, StatusIcons, Power, IdleInhibitor
│   │   ├── components/workspaces/ Workspaces, Workspace, WindowIcon, Pager, OccupiedBg...
│   │   └── popouts/ Wrapper, Content, Audio, Bluetooth, Network, WsContextPopout...
│   ├── dashboard/                      # 仪表盘（15+ 文件）
│   │   ├── Wrapper, Content, Dash, Tabs, Performance, Media, UsagePanel, WeatherPanel
│   │   ├── DonutChart, ActiveWindow, NiriThing, Background
│   │   └── dash/ User, Weather, DateTime, Calendar, Resources, Media
│   ├── launcher/                       # 应用启动器（13+ 文件）
│   │   ├── Wrapper, Content, AppList, ContentList, EmojiList, WallpaperList, Background
│   │   ├── items/ AppItem, ActionItem, CalcItem, ClipItem, ClipPreview, SchemeItem...
│   │   └── services/ Actions, Apps
│   ├── drawers/                        # 根 Shell 窗口
│   │   ├── Drawers.qml                 # 核心编排器（159 行）
│   │   ├── Interactions.qml            # 全局交互：点击/拖拽/悬停
│   │   ├── Panels.qml                  # 面板布局
│   │   ├── Backgrounds.qml, Border.qml, ClickEffects.qml, Exclusions.qml
│   ├── lock/                           # 锁屏（12 个文件）
│   │   ├── Lock.qml, LockSurface.qml, Content.qml, Center.qml
│   │   ├── InputField.qml, Pam.qml, Fetch.qml
│   │   ├── Media.qml, NotifDock.qml, NotifGroup.qml, Resources.qml, WeatherInfo.qml
│   ├── notifications/                  # 通知系统（4 个文件）
│   │   └── Notification.qml (537 行), Content.qml, Wrapper.qml, Background.qml
│   ├── session/                        # 电源菜单（3 个文件）
│   │   └── Content.qml (长按执行), Wrapper.qml, Background.qml
│   ├── osd/                            # OSD 叠加层（4 个文件）
│   ├── quicktoggles/                   # 快捷开关（4 个文件）
│   ├── controlcenter/                  # 控制中心（14+ 个子目录）
│   │   ├── ControlCenter.qml, NavRail.qml, Panes.qml, PaneRegistry.qml
│   │   ├── Session.qml, WindowFactory.qml, WindowTitle.qml
│   │   ├── 13 个配置面板目录 + 13 个共享组件
│   ├── background/                     # 桌面背景（5 个文件）
│   │   ├── Backdrop.qml, Background.qml, Wallpaper.qml
│   │   ├── DesktopClock.qml, Visualiser.qml
│   ├── areapicker/                     # 区域截图/OCR/Lens（2 个文件）
│   ├── polkit/                         # PolicyKit 鉴权对话框
│   ├── utilities/                      # Toast 通知
│   ├── keybinds/                       # ⚠ 仅 Python 脚本，无 QML
│   ├── manga/                          # 漫画阅读器
│   └── novel/                          # 小说阅读器
│
├── components/                         # 27 个文件 — 可复用 UI 组件库
│   ├── effects/ Elevation, Colouriser, ColouredIcon, OpacityMask, InnerBorder...
│   ├── controls/ TextButton, IconButton, StyledSwitch, StyledSlider, FilledSlider...
│   ├── containers/ StyledWindow, StyledListView, WrappedLoader
│   ├── behaviors/ SizeBehavior, PositionBehavior, OpacityBehavior
│   ├── widgets/ WindowDecorations, NotificationList, ExtraIndicator
│   ├── images/ CachingImage, CachingIconImage
│   ├── misc/ Ref (引用计数辅助)
│   ├── filedialog/ FileDialog, Sidebar, HeaderBar, FolderContents...
│   └── 根级: Anim, CAnim, StyledText, StyledRect, Card, Chip, MaterialIcon...
│
├── plugin/src/Celestia/              # C++ 原生插件（4 个 QML 模块）
│   ├── Celestia/ (核心)
│   │   ├── CUtils (截图/QQuickItem 保存)
│   │   ├── Qalculator (数学表达式求值)
│   │   ├── ImageAnalyser (图像主色调/亮度分析)
│   │   ├── Toaster (Toast 通知系统)
│   │   ├── Requests (HTTP GET)
│   │   └── AppDb (应用数据库 + SQLite)
│   ├── Celestia.Internal/ (内部)
│   │   ├── NiriIpc / NiriEventSocket / NiriRequestSocket (Niri IPC)
│   │   ├── CachingImageManager (磁盘缓存图像)
│   │   └── CircularIndicatorManager (动画数学)
│   ├── Celestia.Models/ (数据模型)
│   │   └── FileSystemModel (虚拟文件系统浏览)
│   └── Celestia.Services/ (C++ 服务)
│       ├── SysMonitor (/proc 系统监控)
│       ├── UsageTracker (SQLite 应用使用统计)
│       ├── AudioCollector (PipeWire 音频捕获，lock-free 双缓冲)
│       ├── AudioProcessor / BeatProcessor (aubio 节拍检测)
│       └── CavaProcessor (cava 音频可视化)
│
├── utils/                             # 8 个文件 — 工具模块（全部 Singleton）
│   ├── Icons.qml                       # 图标映射（天气/网络/蓝牙/电池/音量等）
│   ├── SysInfo.qml                     # 系统信息（OS/内核/用户）
│   ├── Paths.qml                       # XDG 路径管理
│   ├── NetworkConnection.qml           # 网络连接逻辑
│   ├── Images.qml                      # 图片验证
│   ├── Strings.qml                     # 字符串匹配工具
│   ├── Searcher.qml                    # 通用搜索器（fzf / fuzzysort）
│
├── scripts/                           # 辅助脚本
│   ├── setup/                          # 安装脚本（v1 + v2 两套）
│   ├── colors/                         # Material You 颜色管线
│   │   ├── switchwall.sh              # 总入口（壁纸→取色→主题全套）
│   │   ├── generate_colors_material.py # 核心颜色生成
│   │   ├── applycolor.sh              # 终端颜色应用
│   │   ├── scheme_for_image.py         # 色彩丰富度分析
│   │   ├── generate_nvchad_theme.py    # Neovim 主题生成
│   │   ├── kde/ KDE/Plasma 主题
│   │   └── kvantum/ Kvantum 主题
│   ├── areaPicker/                     # 截图/OCR/搜索脚本
│   ├── webWallpaper/                   # 在线壁纸下载
│   │   ├── wallhaven/                  # Wallhaven API 客户端
│   │   └── uhdpaper/                   # uhdpaper.com 爬虫
│   ├── manga/                          # 漫画后端服务器（Python）
│   └── novel/                          # 小说后端服务器（Python，多数据源）
│
├── extras/                            # 额外组件
│   └── version.cpp                     # 版本信息打印
│
├── dotfiles/                          # 可部署配置
│   ├── .config/ (matugen 配置)
│   └── niri-celestia-sddm/ (SDDM 主题)
│
├── assets/                            # 静态资源
│   ├── emoji.json, logo.svg
│   ├── bongocat.gif, kurukuru.gif, dino.png
│   ├── shaders/ (GLSL)
│   └── pam.d/ (PAM 配置)
│
├── build/                             # CMake 构建输出（gitignored）
└── images/                            # 截图
```

---

## 4. 架构分析

### 4.1 整体架构模式

项目采用 **三层架构 + 事件驱动** 模式：

```
 shell.qml (入口)
    │
    ├── 配置层 (config/)           ← JSON 文件 ↔ Config Singleton
    │       │
    ├── 服务层 (services/)          ← QML Singleton 后台服务
    │       │
    ├── UI 模块层 (modules/)       ← 用户界面组件
    │       │
    ├── 组件库 (components/)       ← 可复用 M3 控件
    │
    └── C++ 原生层 (plugin/)       ← Qt6 QML 插件
```

**关键特性：** 所有层通过 QML 的 `import` 机制和 Quickshell 的 `Singleton` / `IpcHandler` / `Process` / `FileView` 等基础设施连接。

### 4.2 入口文件 (shell.qml)

```qml
ShellRoot {
    Backdrop {}          // 桌面背景/壁纸
    Background {}        // 桌面窗口
    Drawers {}           // 核心 Shell 窗口（面板容器）
    AreaPicker {}        // 截图/OCR 区域选择
    Lock {}              // 锁屏
    Shortcuts {}         // IPC 命令中心
    QuickTogglesPanel {} // 快捷开关
    PolkitDialog {}      // PolicyKit 鉴权对话框
    ReloadPopup {}       // Quickshell 重载提示
}
```

`ShellRoot` 是 Quickshell 定义的根组件。每个子组件负责独立的桌面功能，无直接父子耦合，通过全局 Service Singleton 通信。

### 4.3 配置系统

**核心文件：** `config/Config.qml`

- **模式：** `FileView` + `JsonAdapter` 组合
- **路径：** `${Paths.config}/shell.json`
- **管理 16 个配置段：** appearance / general / background / bar / border / dashboard / controlCenter / launcher / notifs / osd / session / lock / utilities / extra / services / paths
- **特性：**
  - 脏追踪 `_dirtySections`（增量序列化）
  - 防抖保存（500ms Timer）
  - 文件热重载（`watchChanges: true`）
  - 缺失文件自动初始化（3 次重试后 `mkdir -p` + 写默认配置）
  - 日志 toast：成功/错误通知

**注意：** `SidebarConfig.qml` 虽然存在，但**未接入** `Config.qml` 的 `JsonAdapter` 或 `serializeConfig()`。

### 4.4 服务层 (services/)

全部 30 个服务均为 `pragma Singleton`，在 QML 引擎中全局唯一。

**通信模式：**
- **Niri IPC：** `Niri.qml` → `NiriIpc` (C++) → `NiriEventSocket` / `NiriRequestSocket` → Niri compositor
- **系统调用：** 通过 `Quickshell.Io.Process` 执行外部命令（nmcli, matugen, systemctl 等）
- **HTTP：** `Requests` (C++) / `XMLHttpRequest` (QML)
- **本地文件：** `FileView` + JSON 序列化持久化
- **DBus：** 通过 PipeWire/UPower/NetworkManager Qt 模块

**关键服务：**

| 服务 | 复杂度 | 说明 |
|---|---|---|
| Nmcli.qml | 1377 行 | 最大的服务文件，nmcli 命令封装全部手动解析 |
| Manga.qml | 639 行 | 漫画阅读器后端（HTTP 服务器通信 + 库管理） |
| Notifs.qml | 524 行 | 通知管理（持久化、分组、超时） |
| Niri.qml | 470 行 | Niri IPC 门面（30+ 窗口/工作区操作函数） |
| Colours.qml | 460 行 | Material You 颜色管线 |
| Network.qml | 382 行 | 网络管理（WiFi/Ethernet） |
| SysMonitorService.qml | 362 行 | 系统监控（CPU/GPU/内存/进程） |
| Schemes.qml | 330 行 | 配色方案管理 |
| Brightness.qml | 321 行 | 三后端亮度控制 |

**死代码服务：**
- `BeatDetector.qml` — 硬编码 `bpm: 150`，全部功能已注释
- `Cava.qml` — 空实现，`values: []`, `provider: null`

### 4.5 C++ 原生插件层

**4 个 QML 模块，共用 ~38 个 C++ 文件：**

#### Celestia (核心)
| 类 | 功能 |
|---|---|
| `CUtils` | QQuickItem 截图保存（异步，QtConcurrent） |
| `Qalculator` | libqalculate 数学表达式求值 |
| `ImageAnalyser` | 图像主色调 + 亮度分析（5-bit 颜色量化） |
| `AppDb` | 应用数据库（SQLite，频率/收藏排序） |
| `Toaster` | Toast 通知系统（锁定/解锁机制） |
| `Requests` | HTTP GET（QNetworkAccessManager） |

#### Celestia.Internal (内部)
| 类 | 功能 |
|---|---|
| `NiriIpc` | Niri 窗口管理器全状态镜像（工作区/窗口/输出/键盘） |
| `NiriEventSocket` | 持久化 Unix Socket 事件流（自动重连，指数退避） |
| `NiriRequestSocket` | 每请求单次 Socket（队列串行化） |
| `CachingImageManager` | 图像磁盘缓存（SHA-256, LRU, 100MB 上限） |
| `CircularIndicatorManager` | 循环进度动画（BezierSpline 数学驱动） |

#### Celestia.Models
| 类 | 功能 |
|---|---|
| `FileSystemModel` | QAbstractListModel + 虚拟文件系统浏览 + QFileSystemWatcher + 异步更新 |

#### Celestia.Services
| 类 | 功能 |
|---|---|
| `SysMonitor` | /proc 解析：CPU/内存/网络/磁盘/GPU/进程 |
| `UsageTracker` | SQLite 应用使用时间追踪 |
| `AudioCollector` | PipeWire 音频捕获（std::jthread）+ lock-free 双缓冲 |
| `BeatProcessor` | aubio 节拍检测（QThread 驱动） |
| `CavaProcessor` | cava 音频可视化 + monstercat 滤镜 |

**线程模型：**
- 主线程：所有 QObject
- `QtConcurrent::run`：图像分析、文件枚举、SHA-256、图像缩放
- `std::jthread`：PipeWire 音频捕获
- `QThread`：音频处理器循环

### 4.6 UI 模块层 (modules/)

**统一模式：** 每个功能模块遵循 `Wrapper → Content → Background` 三层结构：

```
Wrapper.qml            // 动画容器（implicitHeight/Width 状态切换）
  └─ Content.qml       // 实际功能内容
  └─ Background.qml    // ShapePath 背景（边缘面板特有）
```

**面板可见性管理：** 集中存储在 `Drawers.qml` 的 `PersistentProperties` 对象中，注册到 `Visibilities.screens[monitorName]`，通过 `Interactions.qml` 或 IPC 切换。

**通信方式：**
- **IPC 入口：** `Shortcuts.qml` 定义的 `IpcHandler` 暴露给外部（`qs -c Celestia-Shell ipc call ...`）
- **目标列表：** drawers / controlCenter / toaster / clipboard / mangaReader / novelReader / picker / lock / quicktoggles / mpris / notifs / brightness / wallpaper / idleInhibitor

### 4.7 组件库 (components/)

**Material Design 3 控件体系：**

| 类别 | 控件 |
|---|---|
| **基础** | StyledText, StyledRect, StyledClippingRect, MaterialIcon |
| **按钮** | TextButton, IconButton, IconTextButton, ToggleButton, StyledRadialButton, SplitButton |
| **输入** | StyledTextField, StyledInputField, StyledSwitch, StyledSlider, FilledSlider, StyledRadioButton, CustomSpinBox |
| **导航** | Menu, MenuItem, Tooltip, Chip, Card |
| **容器** | StyledWindow, StyledListView, StyledFlickable, CollapsibleSection, SectionContainer |
| **特效** | Elevation, ElevationGlow, Colouriser, ColouredIcon, OpacityMask, InnerBorder, CornerPiece |
| **动画** | Anim, CAnim, SizeBehavior, PositionBehavior, OpacityBehavior |
| **图片** | CachingImage, CachingIconImage |
| **其他** | CircularProgress, CircularIndicator, StyledBusyIndicator, ScrollBar, StateLayer, FocusRing, NotificationList |

**主题方案：**
- 颜色：`Colours.palette.m3*` (Material 3 token)，`Colours.layer()` 分层
- 字体：`Appearance.font.family.*`, `Appearance.font.size.*`
- 间距：`Appearance.spacing.*`, `Appearance.padding.*`
- 圆角：`Appearance.rounding.*`
- 动画：`Appearance.anim.durations.*`, `Appearance.anim.curves.*` (BezierSpline)

---

## 5. 数据流

### 5.1 Niri IPC 数据流

```
Niri Compositor
    │ Unix Socket (NIRI_SOCKET env)
    ▼
NiriEventSocket (持久连接)     NiriRequestSocket (每请求单连接)
    │ 事件流: JSON newline       │ 请求: 构造 JSON Action
    ▼                            ▼
NiriIpc (C++ Singleton)
    │ 属性同步: workspaces / windows / outputs / keyboard
    ▼
Niri.qml (QML Singleton)
    │ 高级 API: switchToWorkspace / focusWindow / moveColumnToIndex
    ▼
模块 (Bar/Dashboard/Session 等)
```

### 5.2 壁纸/颜色管线

```
用户选择壁纸
    │
    ▼
Wallpapers.qml
    │ setWallpaper(path)
    ▼
switchwall.sh (Bash)
    ├── ffmpeg 视频帧提取（如为视频壁纸）
    ├── generate_colors_material.py (Material You SCSS)
    ├── matugen 模板渲染
    ├── applycolor.sh → Kitty / 终端 OSC
    ├── kvantum / KDE / VSCode 主题
    └── SDDM 同步
    │
    ▼
Colours.qml 重新加载配色
    │
    ▼
全局 UI 更新 (m3* 颜色属性绑定)
```

### 5.3 配置持久化

```
Config.qml::save()
    │ markDirty(section) → 500ms 防抖
    ▼
serializeConfig() → JSON.stringify
    │
    ▼
FileView::setText() → shell.json
    │ watchChanges: true
    ▼
FileView::onFileChanged() → 热重载
    │ 120ms 防抖 → 重新解析 JSON
    ▼
JsonAdapter 自动更新所有 Config.* 属性
    │
    ▼
QML 绑定自动触发 UI 更新
```

---

## 6. 代码质量问题（基于源代码分析）

### 6.1 安全风险

| 风险 | 文件 | 问题 |
|---|---|---|
| 命令注入 | `ClipItem.qml` | cliphist ID 未转义直接拼接 bash 命令 |
| 命令注入 | `EmojiList.qml` | emoji 字符直接拼接 shell |
| 命令注入 | `WebWallpaperGrid.qml` | 用户搜索词/slug/API key 拼接 bash 命令 |
| 密码泄露 | `Nmcli.qml` | WiFi 密码在 `/proc/*/cmdline` 可见 |
| 进程注入 | `Picker.qml` | 几何坐标通过 shell 拼接 |
| 无超时 | `nirisocket.cpp` | IPC 请求 socket 无超时机制（永久挂起） |
| 无界缓冲 | `nirisocket.cpp` | 事件流缓冲区无上限检查 |
| 缺进程验证 | `SysMonitorService.qml` | `kill(pid)` 仅检查 `pid > 0` |

### 6.2 Bug

| Bug | 位置 |
|---|---|
| `_moveAfterFocusCb` vs `_moveAfterFocusPendingCb` | `Niri.qml:382` — 错误的属性名被赋值 |
| `Qt.callLater` 第二个参数被忽略 | `Network.qml:153,166,249...` — 延迟不生效 |
| 历史数组不响应 | `SysMonitorService.qml` — `.push()` 不会触发 QML 绑定重算 |
| `Visibilities.load()` 忽略参数 | `Visibilities.qml` — `screen` 形参未被使用 |
| `setup.sh` 检查 `.zrc` 而非 `.zshrc` | `v2/sdata/subcmd-install/2.setups.sh:31` |
| `BeatDetector` / `Cava` 无功能 | 硬编码返回值，所有实质代码已注释 |

### 6.3 架构问题

| 问题 | 说明 |
|---|---|
| `SidebarConfig.qml` 未接入 | 存在于 `config/` 但 `Config.qml` 未引用 |
| Manga/Novel 大量代码重复 | 两个服务、两个阅读器、四个视图组件几乎完全相同 |
| `cidrToSubnetMask()` 重复 | `Network.qml` 和 `Nmcli.qml` 各定义一次 |
| `_get`/`_post` HTTP 辅助重复 | `Manga.qml` 和 `Novel.qml` 两套相同实现 |
| 配置双重路径 | `~/.config/quickshell/Celestia/Shell/shell.json` vs `~/.config/niri_celestia/shell.json` |
| `Brightness.qml` 服务含 UI | `Monitor` QML 组件内联在服务中，职责不清晰 |
| 无私有属性机制 | QML 不强制私有，仅靠 `_` 前缀约定 |

### 6.4 死代码

| 文件 | 内容 |
|---|---|
| `BeatDetector.qml` | 全文件除 `property real bpm: 150` 外全部注释 |
| `Cava.qml` | 空壳，`values: []`，`provider: null` |
| `modules/utilities/Content.qml` | 27 行，无实际内容（Behavior + 注释矩形） |
| 5 个文件中的 CustomShortcut 块 | Niri 不支持的 Hyprland 特性，注释保留 |
| `keybinds/` | 仅 Python 脚本，无 QML 集成 |

### 6.5 注意事项

- **服务层文件极大：** `Nmcli.qml` (1377 行)、`Manga.qml` (639 行)、`Notifs.qml` (524 行)、`Niri.qml` (470 行)、`Colours.qml` (460 行)
- **内联组件定义：** 大服务文件内部定义完整 QML 组件（`Notif`、`M3Palette`、`Monitor`、`AccessPoint` 等），不适合单元测试
- **单例模式不可测试：** 全部服务为 Singleton，无法在不启动完整 Quickshell 引擎的情况下模拟
- **外部命令依赖：** 服务层大量通过 `Process` 调用外部二进制（nmcli、matugen、brightnessctl、ddcutil、ffmpeg、systemctl 等）
- **两套安装系统：** `scripts/setup/` (v1) 和 `scripts/setup/v2/`，功能重叠

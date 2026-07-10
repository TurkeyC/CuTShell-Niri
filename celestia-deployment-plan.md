# Celestia-Shell 跨设备部署方案

## 1. 诉求

**开发环境：** Fedora + Nix（Fedora 为基础 OS，Nix 辅助管理包）
**目标环境：** 日常用 Fedora 机器（不使用 Nix）

**期望的交付物：**

```
~/.config/quickshell/celestia/
├── shell.qml              ← qs -c celestia 入口
├── shell.json             ← 用户配置
├── config/                ← QML 配置定义
├── modules/               ← UI 模块
├── services/              ← 后台服务
├── components/            ← 可复用组件
├── utils/                 ← 工具模块
├── assets/                ← 资源文件
├── qml/                   ← 编译产物：C++ QML 插件
│   ├── Celestia/libcelestia.so
│   ├── Celestia/Internal/libcelestia-internal.so
│   ├── Celestia/Models/libcelestia-models.so
│   └── Celestia/Services/libcelestia-services.so
├── lib/                   ← 编译产物：二进制工具
│   └── version
```

**核心要求：**
1. 整个 `celestia/` 目录是**自包含的**，放在 `~/.config/quickshell/` 下即可使用
2. 不污染系统目录（`/usr/lib64/`、`/etc/xdg/` 等）
3. 日常机不使用 Nix
4. 启动命令：`QML2_IMPORT_PATH=~/.config/quickshell/celestia/qml qs -c celestia`

---

## 2. 为什么需要编译

项目由两部分组成：

| 部分 | 需要编译 | 原因 |
|---|---|---|
| QML 文件（~280 个 .qml） | ❌ 不需要 | Quickshell 运行时加载 |
| C++ 原生插件（~38 个文件） | ✅ 必须 | 编译为 .so 供 QML 引擎 dlopen |

C++ 插件提供 QML 无法实现的能力：

- **NiriIpc** — Unix Domain Socket 与 Niri 窗口管理器通信，管理工作区/窗口/键盘布局
- **SysMonitor** — 解析 `/proc` 实时监控 CPU/内存/网络/磁盘/GPU
- **UsageTracker** — SQLite 应用使用统计
- **AudioCollector** — PipeWire 音频捕获（音频可视化/节拍检测需 libpipewire/aubio）
- **Qalculator** — 数学表达式求值（libqalculate）
- **CachingImageManager** — 磁盘 LRU 图像缓存
- **FileSystemModel** — 异步文件系统浏览
- **AppDb** — SQLite 应用数据库
- **Toaster** — Toast 通知系统

---

## 3. 核心矛盾：跨设备二进制兼容

编译产物的 `.so` 文件动态链接到宿主系统的库：

| 依赖 | 来源 | ABI 兼容性 |
|---|---|---|
| `libc.so.6`（glibc） | 系统基础 | 版本必须 <= 目标机 |
| `libstdc++.so.6` | GCC | 版本必须 <= 目标机 |
| `libQt6Core.so.*` | qt6-qtbase | 大版本内不保证二进制兼容 |
| `libpipewire-0.3.so.*` | pipewire | 版本需匹配 |
| `libaubio.so.*` | aubio | 版本需匹配 |
| `libqalculate.so.*` | libqalculate | 版本需匹配 |

因此，在开发机上编译的 `.so` 无法保证在任意 Linux 发行版上运行。

---

## 4. 解决方案：Mock 构建 + /opt 安装

### 步骤概述

```
开发机 (Fedora + Nix)
  │
  ├─ ① 编写 RPM .spec 文件
  │
  ├─ ② 调整 CMake 安装路径（INSTALL_QMLDIR=.，INSTALL_QSCONFDIR=.）
  │
  ├─ ③ mock -r fedora-44-x86_64 celestia-shell.src.rpm
  │     │ 在干净 Fedora 44 chroot 中构建
  │     │ 自动处理 BuildRequires 依赖
  │     │
  │     └─ 产物: celestia-shell-2.0.0-1.fc44.x86_64.rpm
  │
  └─ ④ 从 RPM 提取 celestia/ 目录：
       rpm2cpio celestia-shell-*.rpm | cpio -idmv
       # 提取出 ./qml/Celestia/*.so 等文件
       # 加上源码中的 QML 文件，组成自包含目录
```

### 在目标机上的最终布局

```
~/.config/quickshell/celestia/
├── qml/Celestia/libcelestia.so          ← 来自 RPM（Fedora 44 构建）
├── qml/Celestia/Internal/libcelestia-internal.so
├── qml/Celestia/Models/libcelestia-models.so
├── qml/Celestia/Services/libcelestia-services.so
├── config/                                 ← 来自源码（跨平台通用）
├── modules/
├── services/
├── components/
├── utils/
├── assets/
├── shell.qml
├── shell.json
└── lib/version
```

### 使用

```bash
export QML2_IMPORT_PATH=~/.config/quickshell/celestia/qml
qs -c celestia
```

或者在 Niri 配置中：

```kdl
spawn-at-startup "sh" "-c" "QML2_IMPORT_PATH=$HOME/.config/quickshell/celestia/qml qs -c celestia"
```

---

## 5. 多目标机策略

不同 Fedora 版本的 Qt6 / glibc 版本不同，需要分别构建：

```bash
# Fedora 44（日常机）
mock -r fedora-44-x86_64 celestia-shell.spec

# Fedora 43（另一台机器）
mock -r fedora-43-x86_64 celestia-shell.spec
```

产物结构完全一致，仅 `.so` 文件不同。用 CI（GitHub Actions + Copr）可自动化这一过程。

---

## 6. CMake 安装路径调整

需要修改 `CMakeLists.txt` 中的安装目标，使产物适合目录级部署而非系统安装：

| 变量 | 当前默认值 | 调整后 |
|---|---|---|
| `CMAKE_INSTALL_PREFIX` | `/usr` | `$PWD/build/celestia` |
| `INSTALL_QMLDIR` | `usr/lib/qt6/qml` | `qml` |
| `INSTALL_QSCONFDIR` | `etc/xdg/quickshell/caelestia` | `.` |
| `INSTALL_LIBDIR` | `usr/lib/caelestia` | `lib` |

这样 `cmake --install` 输出即为自包含目录，`.so` 在 `./qml/` 下，QML 文件在根目录。

或者**更优做法**：不动 CMake，直接在 spec 的 `%install` 阶段重组文件布局。这样不破坏上游 CMake 的结构，patch 最小。

---

## 7. 已有条件

- **Quickshell 已进入 Fedora 仓库**（`dnf install quickshell` 可直接安装），spec 不需要额外 COPR 源
- **开发机就是 Fedora**，mock 原生支持
- **所有 C++ 依赖都在 Fedora 仓库中**：`qt6-qtbase-devel`、`qt6-qtdeclarative-devel`、`qt6-qtmultimedia-devel`、`pipewire-devel`、`aubio-devel`、`libqalculate-devel`、`cmake`、`ninja`、`gcc-c++`

---

## 8. 与本报告中其他方案的关系

| 方案 | 推荐度 | 理由 |
|---|---|---|
| Distrobox 容器构建 | 备用 | 需要额外工具，不适用无容器环境 |
| Nix + patchelf | 不推荐 | 需要 pin nixpkgs 版本匹配 Fedora Qt6，维护成本高 |
| Rust 重写 | 不推荐 | 8-11 月工作量，不解决跨设备兼容问题，QAbstractListModel 桥接极复杂 |
| **Mock + 自包含目录** | **推荐** | 原生 Fedora 工具链，ABI 100% 兼容，产物自包含无系统污染 |

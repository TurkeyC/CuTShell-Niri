# 在 Distrobox 中进行的可迁移自包含开发

## 综述

本文记录了 Celestia-Shell 项目的完整开发环境搭建与重构经历。核心思路是：**在 distrobox 容器内进行所有构建工作，产物为自包含目录，直接复制到宿主机即可运行，宿主机零污染。**

---

## 一、完整过程回顾

### 第一阶段：环境评估与规划

**初始状态：**
- 宿主机：Fedora 44 + Niri 窗口管理器
- 容器：Fedora 44 distrobox 容器（`casuki` 用户，HOME 映射到 `/home/FedoraHome`）
- 项目位置：`/home/FedoraHome/.config/quickshell/Celestia/`
- 项目性质：Quickshell 桌面 Shell，**296 个 QML 文件** + **46 个 C++ 源文件**（4 个 QML 插件模块）
- 容器内无任何构建工具（无 cmake、g++、Qt6 devel 包），但 `qs`（quickshell）已安装

**发现的关键问题：**
- 项目名称拼写不一致：仓库名 `Celestia`（正确），但代码内大量使用 `Caelestia`（拼写错误）
- 旧编译产物来自不同路径（`/home/casuki/...`），是 Release 模式
- 需要在动手前先做全量重命名

### 第二阶段：全面重命名（Caelestia → Celestia）

这是整个过程中最耗时、最需要谨慎的部分。涉及范围：

| 类别 | 文件数 | 关键变更 |
|------|--------|----------|
| 目录名 | 1 个 | `plugin/src/Caelestia/` → `Celestia/`（git mv） |
| C++ namespace | 46 个 | `namespace caelestia` → `celestia` |
| CMakeLists.txt | 7 个 | project 名、module URI、install 路径 |
| QML imports | ~50 个 | `import Caelestia.*` → `import Celestia.*` |
| QML 代码引用 | ~15 个 | ID、namespace 字符串、notify-send、systemd 等 |
| 运行时路径 | 6 处 | `XDG_*/caelestia` → `XDG_*/Celestia/Shell` |
| Dotfiles | ~25 个 | niri 配置、SDDM 主题、mpv 脚本 |
| 脚本 | ~30 个 | setup 脚本、颜色脚本、wallhaven |
| 文档 | ~7 个 | README、INSTALL、THEME、CODE_REVIEW 等 |
| .claude/settings | 1 个 | 历史命令引用 |

**命名规范（最终确定的）：**

| 用途 | 格式 | 示例 |
|------|------|------|
| C++ namespace | 全小写 | `celestia` |
| QML module URI | PascalCase | `Celestia`、`Celestia.Internal` |
| 运行时 XDG 路径 | PascalCase + 斜杠 | `~/.local/share/Celestia/Shell/` |
| CMake project/target | 小写 kebab | `celestia-shell`、`celestia` |
| QS 配置标识符 | PascalCase + kebab | `qs -c Celestia-Shell` |
| WlrLayershell 命名空间 | PascalCase | `Celestia-polkit`、`Celestia-${name}` |
| 环境变量 | 全大写 | `CELESTIA_LIB_DIR` |

### 第三阶段：构建环境搭建

**安装的依赖包：**
```
cmake ninja-build gcc-c++
qt6-qtbase-devel qt6-qtdeclarative-devel
qt6-qtmultimedia-devel qt6-qtsvg-devel
pipewire-devel aubio-devel libqalculate-devel
gdb
```

工具链版本（Fedora 44）：
- GCC 16.1.1
- CMake 4.3.0
- Ninja 1.13.2
- Qt 6.11.1
- PipeWire 1.6.8
- Aubio 0.4.9
- libqalculate 5.9.0

### 第四阶段：编译与验证

**CMake 配置（自包含开发模式）：**
```bash
cmake -S . -B build \
  -DCMAKE_INSTALL_PREFIX=$PWD/build/celestia \
  -DINSTALL_QMLDIR="qml" \
  -DINSTALL_QSCONFDIR="." \
  -DINSTALL_LIBDIR="lib" \
  -DCMAKE_BUILD_TYPE=Debug \
  -G Ninja
```

- 81/81 编译步骤全部通过，零错误（仅有既有 GCC 警告）
- 4 个 QML 模块全部正确注册：`Celestia`、`Celestia.Internal`、`Celestia.Models`、`Celestia.Services`

### 第五阶段：宿主机部署与运行

**部署到宿主机：**
```bash
cp -r build/celestia ~/.config/quickshell/Celestia-Shell
```

**宿主机还需要安装运行时库**（只有 -devel 包的运行时部分，不需要编译工具）：
```bash
sudo dnf install aubio           # libaubio.so.5 — 节拍检测
```

**启动命令：**
```bash
QML2_IMPORT_PATH=~/.config/quickshell/Celestia-Shell/qml qs -c Celestia-Shell
```

**结果：** Shell 成功启动，所有运行时路径正确。

---

## 二、关键决策与原因

### 1. 自包含目录架构

**决策：** 构建产物是一个可移动的目录，不安装到 `/usr/` 或 `/etc/` 等系统路径。

**原因：**
- 容器内编译 → 宿主机直接运行，不需要在宿主机装任何 -devel 包
- 版本切换只需换目录，不影响系统
- 删除即卸载，零残留
- 多个版本可以共存

### 2. 名称统一规范

**决策：** 从 `Caelestia`（拼写错误）统一为 `Celestia`，并建立完整的命名规范表。

**教训：** 项目早期没有建立命名规范，导致 C++ namespace、QML URI、路径、配置标识符各用各的格式（`caelestia`、`Caelestia`、`niri-caelestia-shell`、`niri_caelestia`），后期统一时工作量很大。

**如果重来：** 项目初始化时就定义好命名规范表，用脚本自动生成各场景的对应关系。

### 3. 在容器内安装 quickshell 运行时

**决策：** 容器内安装 `quickshell` 包，用于在容器内直接测试。

**优势：** 可以在容器内完成完整的编译-测试循环，不需要频繁复制到宿主机。
**注意：** 需要 Wayland socket 共享（distrobox 默认已做）。

### 4. CMake 参数覆盖而非修改默认值

**决策：** CMakeLists.txt 保留 RPM 安装的默认路径（`/usr/lib/...`、`/etc/xdg/...`），开发时通过命令行参数覆盖。

```
# 默认（RPM 安装）
INSTALL_LIBDIR="usr/lib/Celestia/Shell"
INSTALL_QMLDIR="usr/lib/qt6/qml"
INSTALL_QSCONFDIR="etc/xdg/quickshell/Celestia/Shell"

# 开发时覆盖（自包含）
INSTALL_LIBDIR="lib"
INSTALL_QMLDIR="qml"
INSTALL_QSCONFDIR="."
```

**好处：** 一份 CMakeLists.txt 同时支持开发自包含模式和发行版打包。

---

## 三、Distrobox 开发模式详解

### 架构示意

```
┌─────────────────────────────────────────────────┐
│  宿主机 (Fedora 44 + Niri)                       │
│                                                   │
│  ┌─────────────────────────────────────────┐     │
│  │  Distrobox 容器: celestia-dev             │     │
│  │  ┌──────────────────────────────────┐   │     │
│  │  │  Source: ~/config/.../Celestia   │   │     │
│  │  │  Build:   build/celestia/        │   │     │
│  │  │  Tools:   cmake, g++, Qt6-devel  │   │     │
│  │  │  Runtime: qs (quickshell)        │   │     │
│  │  └──────────────────────────────────┘   │     │
│  │         │ cp -r (产物迁移)               │     │
│  │         ▼                                │     │
│  │  ~/.config/quickshell/Celestia-Shell/   │     │
│  │  └── 直接 qs -c Celestia-Shell 运行     │     │
│  └─────────────────────────────────────────┘     │
│                                                   │
│  宿主只需装: aubio, libqalculate (运行时库)        │
└─────────────────────────────────────────────────┘
```

### 日常开发循环

```
# 1. 进入容器
distrobox enter celestia-dev

# 2. 修改代码

# 3. 增量编译
cmake --build build -j$(nproc) && cmake --install build

# 4. 容器内测试
QML2_IMPORT_PATH=$PWD/build/celestia/qml qs -c $PWD/build/celestia
# 或映射到宿主机的 Niri 上显示

# 5. 确认正常后，复制到宿主机
cp -r build/celestia ~/.config/quickshell/Celestia-Shell
```

### 容器管理

```bash
# 创建容器
distrobox create --name celestia-dev --image fedora:44 \
  --volume ~/.config/quickshell/Celestia:/home/$USER/.config/quickshell/Celestia

# 进入
distrobox enter celestia-dev

# 停止（不删除）
distrobox stop celestia-dev

# 彻底删除（所有 -devel 包、编译器一并消失）
distrobox rm celestia-dev
```

---

## 四、经验与教训

### 教训 1：命名一致性应该从一开始就建立

**问题：** 项目代码中同一个概念有 3-4 种不同写法（`Caelestia`、`caelestia`、`niri-caelestia-shell`、`niri_caelestia`），导致重命名涉及上百个文件。

**建议：**
- 项目初始化时就定义命名规范表，明确每个场景（namespace、URI、路径、env var 等）使用的格式
- 用代码生成器或脚本模板保证一致性

### 教训 2：大规模重命名要用结构化方法

**问题：** 直接在 300+ 文件中做字符串替换需要非常小心，不同上下文需要不同的替换策略。

**经验：**
- 先分类（C++ 代码、CMake、QML、文档、脚本）
- 按优先级处理（先改影响编译的，再改文档）
- 用 sed 批量处理通用模式，用 Edit 处理特殊案例
- 每处理完一类就做一个 grep 验证

### 教训 3：自包含目录的路径设计要彻底

**问题：** 运行时路径（XDG 路径）和安装路径（CMake 路径）是两套不同的系统。XDG 路径由 Paths.qml 定义，安装路径由 CMake 参数控制。

**关键理解：**
- `qs -c Celestia-Shell` → Quickshell 查找 `~/.config/quickshell/Celestia-Shell/shell.qml`
- `QML2_IMPORT_PATH=.../qml` → Qt 在 `qml/` 下找 `Celestia/` 模块目录
- `Paths.qml` 定义运行时数据存放位置（XDG）

这三者互不冲突，但要确保它们使用的命名一致。

### 教训 4：容器隔离是把双刃剑

**优点：**
- 宿主机不会被 -devel 包污染
- 删除容器 = 清理整个开发环境
- 可以随时重建，版本一致

**注意事项：**
- **编译产物依赖运行时库**：容器内链接的 `.so` 在宿主机上运行时需要对应的运行时库（`libaubio.so`）。`-devel` 包自动拉了运行时库进容器，但宿主机没有
- **解决方案**：在宿主机安装 `aubio` 等运行时库（只需 `aubio` 包，不需要 `aubio-devel`）
- **入口检查指令**：部署后用 `ldd *.so | grep "not found"` 检查缺失的动态库

### 教训 5：验证命名完整性的方法

```bash
# 终极验证：扫描所有源文件
grep -rn "old-name" --include="*.cpp" --include="*.hpp" \
  --include="*.qml" --include="CMakeLists.txt" \
  --exclude-dir=.git --exclude-dir=build

# 验证编译产物路径
ls -d build/celestia/qml/Celestia/

# 验证运行时路径（从日志中可见）
grep -rn "Celestia/Shell" --include="*.cpp" --include="*.qml"
```

---

## 五、最终产物清单

### 自包含目录结构

```
~/.config/quickshell/Celestia-Shell/
├── qml/Celestia/                     ← C++ QML 插件
│   ├── libcelestia.so
│   ├── libcelestiaplugin.so
│   ├── Internal/libcelestia-internal*.so
│   ├── Models/libcelestia-models*.so
│   └── Services/libcelestia-services*.so
├── lib/version                       ← 版本工具（可选）
├── shell.qml                         ← Shell 入口
├── config/  (19 个 QML 文件)         ← 配置面板
├── components/  (76 个 QML 文件)     ← 可复用组件
├── modules/  (170 个 QML 文件)       ← Shell 模块
├── services/  (31 个 QML 文件)       ← 后台服务
├── utils/  (9 个 QML 文件)           ← 工具函数
└── assets/  (10 个文件)              ← 静态资源
```

### 运行时路径清单

| 用途 | 路径 |
|------|------|
| 用户数据 | `~/.local/share/Celestia/Shell/` |
| 状态 | `~/.local/state/Celestia/Shell/` |
| 缓存 | `~/.cache/Celestia/Shell/` |
| 配置 | `~/.config/Celestia/Shell/` |
| 应用使用量 DB | `~/.local/share/Celestia/Shell/app_usage.db` |
| 通知数据 | `~/.local/share/Celestia/Shell/notifications.json` |
| 配色方案 | `~/.local/state/Celestia/Shell/scheme.json` |
| 壁纸记录 | `~/.local/state/Celestia/Shell/wallpaper/path.txt` |
| 应用频率 | `~/.local/state/Celestia/Shell/app-frequency.json` |
| 视频帧缓存 | `~/.local/state/Celestia/Shell/generated/video_frames/` |
| 图片缓存 | `~/.cache/Celestia/Shell/imagecache/` |

### 启动方式

```bash
# 开发版（直接在容器内或宿主机 build 目录）
QML2_IMPORT_PATH=~/.../build/celestia/qml qs -c ~/.../build/celestia

# 部署版（复制到 ~/.config/quickshell/Celestia-Shell/ 后）
QML2_IMPORT_PATH=~/.config/quickshell/Celestia-Shell/qml qs -c Celestia-Shell
```

---

## 六、数据统计

| 指标 | 数值 |
|------|------|
| QML 文件总数 | ~296 |
| C++ 源文件（hpp+cpp） | 46 |
| C++ QML 模块数 | 4 |
| 重命名涉及文件数 | ~120+ |
| 编译步骤 | 81 |
| 编译错误 | 0 |
| 宿主机需额外安装的运行时 | 1 个包（`aubio`） |
| 容器内 -devel 包数 | ~10 个 |
| 从容器内编译到宿主机运行 | 1 条 `cp` 命令 |

---

*文档生成于 2026-07-10，记录 Celestia-Shell 项目在 Fedora 44 distrobox 容器中的自包含开发完整历程。*

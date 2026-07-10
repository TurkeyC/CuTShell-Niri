# 安装指南

## 环境

- Fedora 43 + niri
- quickshell 0.3.0（通过 Fedora COPR 安装）
- GCC 15 / CMake 3.31

## 依赖

### 构建依赖

| 依赖 | 用途 | 安装命令 |
|------|------|----------|
| qt6-qtbase-devel | Qt6 基础 | `sudo dnf install qt6-qtbase-devel` |
| qt6-qtdeclarative-devel | Qt6 QML | `sudo dnf install qt6-qtdeclarative-devel` |
| qt6-qtmultimedia-devel | 音频 | `sudo dnf install qt6-qtmultimedia-devel` |
| qt6-qtsvg-devel | SVG 支持 | `sudo dnf install qt6-qtsvg-devel` |
| libpipewire-0.3-devel | 音频管道（PipeWire） | `sudo dnf install pipewire-devel` |
| aubio-devel | 节拍检测 | `sudo dnf install aubio-devel` |
| libqalculate-devel | 计算器 | `sudo dnf install libqalculate-devel` |
| cmake | 构建系统 | `sudo dnf install cmake` |
| gcc-c++ | C++ 编译器 | `sudo dnf install gcc-c++` |

### 运行时依赖

| 依赖 | 用途 | 安装命令 |
|------|------|----------|
| quickshell | Shell 引擎 | 通过 Fedora COPR 安装 |
| material-symbols-fonts | Material 图标字体 | `sudo dnf install material-symbols-fonts` |
| matugen | 壁纸动态取色生成配色 | `sudo dnf install matugen` |
| cliphist | 剪贴板历史 | `sudo dnf install cliphist` |
| wl-clipboard | Wayland 剪贴板工具 | `sudo dnf install wl-clipboard` |
| grim | 区域截图（OCR） | `sudo dnf install grim` |
| tesseract | OCR 文字识别 | `sudo dnf install tesseract` |
| brightnessctl | 屏幕亮度控制 | `sudo dnf install brightnessctl` |
| ddcutil | 外接显示器亮度控制（DDC/CI） | `sudo dnf install ddcutil` |
| libnotify | 通知（notify-send） | `sudo dnf install libnotify` |
| nmcli | 网络管理（NetworkManager） | `sudo dnf install NetworkManager` |
| xdg-utils | 文件打开（xdg-open） | `sudo dnf install xdg-utils` |
| cava | 音频可视化（见下文说明） | `sudo dnf install cava` |
| app2unit | 应用启动包装（systemd transient unit） | 见下文 |

### app2unit 安装

`app2unit` 是 quickshell 的工具，Fedora 包未携带，需手动创建：

```bash
sudo tee /usr/local/bin/app2unit << 'SCRIPT'
#!/bin/bash
exec systemd-run --user --scope --collect "$@"
SCRIPT
sudo chmod +x /usr/local/bin/app2unit
```

### 可选依赖

| 依赖 | 用途 | 安装命令 |
|------|------|----------|
| papirus-icon-theme | 系统托盘图标主题 | `sudo dnf install papirus-icon-theme` |
| fish | 计算器功能使用的 shell | `sudo dnf install fish` |

### 完整安装命令

```bash
sudo dnf install material-symbols-fonts matugen cliphist wl-clipboard grim \
  tesseract brightnessctl ddcutil libnotify NetworkManager xdg-utils cava \
  papirus-icon-theme fish

## 安装步骤

### 1. 配置

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
```

### 2. 编译

```bash
cmake --build build -j$(nproc)
```

### 3. 安装

**注意**：Fedora 的 Qt6 QML 路径是 `/usr/lib64/qt6/qml/`，不是 `/usr/lib/qt6/qml/`。安装时必须指定正确的路径，否则 QML 引擎找不到新编译的插件（会加载 Fedora 包自带的旧版 Celestia 模块，缺少 `CachingImageManager` 等类型）。

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DINSTALL_QMLDIR="usr/lib64/qt6/qml"
sudo cmake --install build --prefix /
```

### 安装内容

| 路径 | 内容 |
|------|------|
| `/usr/lib64/qt6/qml/Celestia/` | C++ 插件（.so + qmldir + qmltypes） |
| `/usr/lib/Celestia/Shell/version` | 版本二进制 |
| `/etc/xdg/quickshell/Celestia/Shell/` | Shell 配置（QML 组件、模块、服务等） |

## 启动

Celestia 以 quickshell 配置的方式运行：

```bash
quickshell --config Celestia
```

## 常见问题

### 1. cava 依赖缺失

**症状**：CMake 配置时报错找不到 `cava` / `libcava`。

**原因**：Celestia 的 `CavaProvider` 需要 cava 的开发库（`libcava` + `<cava/cavacore.h>`），但 Fedora 的 `cava` 包只提供了 `/usr/bin/cava` 二进制，**没有**打包 `-devel` 子包。

**解决方案**：从构建中剔除 cava 模块。修改以下文件后重新编译：

- `plugin/src/Celestia/CMakeLists.txt` — 删除 `pkg_check_modules(Cava ...)` 三行
- `plugin/src/Celestia/Services/CMakeLists.txt` — 从 `SOURCES` 移除 `cavaprovider.cpp/hpp`，从 `LIBRARIES` 移除 `PkgConfig::Cava`
- `services/Cava.qml` — 替换为空桩

**后果**：音频可视化（Cava 频谱条）功能不可用。

**如需恢复**：从源码编译 cava：

```bash
git clone https://github.com/karlstav/cava.git
cd cava
./autogen.sh
./configure --prefix=/usr
make
sudo make install
```

然后恢复上述三个文件的修改，重新编译安装。建议向 Fedora 提交 `cava-devel` 子包请求。

### 2. 安装路径错误导致 CachingImageManager 找不到

**症状**：quickshell 加载时报错：
```
CachingImageManager is not a type
```
错误链：`Background` → `Wallpaper` → `FileDialog` → `FolderContents` → `CachingIconImage` → `CachingImage` → `CachingImageManager`

**原因**：Fedora 的 Qt6 QML 路径是 `/usr/lib64/qt6/qml/`，但项目默认安装到 `/usr/lib/qt6/qml/`。QML 引擎使用前者，加载了 Fedora 自带的老版本 Celestia 模块（不含 `CachingImageManager`）。

**解决方案**：

1. 重新配置并安装，指定正确的 QML 路径：
   ```bash
   cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DINSTALL_QMLDIR="usr/lib64/qt6/qml"
   sudo cmake --install build --prefix /
   ```

2. 如果已有文件安装到两个路径，需要同步修改两个位置的 `qmldir`，去掉 `optional` 关键字（否则 QML 引擎静默跳过插件加载）：
   ```bash
   sudo sed -i 's/optional plugin Celestia-internalplugin/plugin Celestia-internalplugin/' \
     /usr/lib64/qt6/qml/Celestia/Internal/qmldir
   sudo sed -i 's/optional plugin Celestia-internalplugin/plugin Celestia-internalplugin/' \
     /usr/lib/qt6/qml/Celestia/Internal/qmldir
   ```

### 3. 图标不显示——Material Symbols 字体缺失

**症状**：Celestia 界面中所有图标显示为文本或紫黑色方块，包括音量、Wi-Fi、蓝牙、电池等状态图标。

**原因**：Celestia 的 `MaterialIcon` 组件使用 `"Material Symbols Rounded"` 字体渲染图标，该字体未安装。

**解决方案**：
```bash
sudo dnf install material-symbols-fonts
```

安装后重启 quickshell 即可。

### 4. 系统托盘和 KDE 应用图标显示为紫黑色方块

**症状**：系统托盘图标（如 XRay、Kontact 等）以及 KDE 应用的图标显示为紫黑色方块占位符。

**原因**：在 niri 下直接启动 quickshell 时，KDE 环境变量（`KDE_SESSION_VERSION`、`KDE_FULL_SESSION`）未设置，Qt 无法找到 KDE 图标主题。

**解决方案**（二选一）：

**方案 A**：在 niri 配置 `~/.config/niri/config.kdl` 中添加：
```
environment {
    QT_QPA_PLATFORMTHEME "kde"
}
```

**方案 B**：创建 `niri+kde` 会话。创建 `/usr/share/wayland-sessions/niri+kde.desktop`：

```desktop
[Desktop Entry]
Name=Niri + KDE
Comment=Niri with KDE environment
Exec=env KDE_SESSION_VERSION=6 KDE_FULL_SESSION=true /usr/bin/niri
Type=Application
```

然后注销，在 SDDM 登录界面选择 **"Niri + KDE"** 会话登录。

此后所有 Qt 应用都能正确读取 KDE 图标主题。

### 5. OccupiedBg.qml 的 TypeError

**症状**：日志中反复出现：
```
TypeError: Value is undefined and could not be converted to an object
```
指向 `modules/bar/components/workspaces/OccupiedBg.qml`。

**原因**：`buildPills()` 中 `count` 为 0 时 `pills[count - 1]` 访问 `pills[-1]`，得到 `undefined`。

**修复**：在 `line 37` 的访问前加 `count > 0` 判断：
```qml
if (!occupied[ws + 1] && count > 0)
    pills[count - 1].end = ws;
```

### 6. 主题无法切换（配色无法生效）

**症状**：launcher 中切换配色方案无效，界面颜色不变化。

**原因**：默认使用 `dynamic` 模式（从壁纸动态取色），依赖 `matugen` 生成配色。如果 `matugen` 未安装或状态文件异常，颜色数据为空。

**解决方案**（二选一）：

**方案 A**：安装 `matugen` 启用动态取色：
```bash
sudo dnf install matugen
```

**方案 B**：手动指定预定义主题，修改 `~/.local/state/Celestia/Shell/scheme.json`：
```json
{
  "name": "catppuccin",
  "flavour": "mocha",
  "mode": "dark",
  "colours": {}
}
```
重启 quickshell 即可生效。

### 7. 休眠按钮改成锁屏

**需求**：系统休眠被禁用，希望把 session 面板的休眠按钮改成锁屏。

**解决方案**：修改 `~/.config/niri_Celestia/shell.json`，将 `hibernate` 命令改为调用 quickshell IPC 触发 Celestia 自带的锁屏（基于 `WlSessionLock`）：

```json
"hibernate": ["qs", "-c", "Celestia", "ipc", "call", "lock", "lock"]
```

或者使用 systemd-logind：
```json
"hibernate": ["loginctl", "lock-session"]
```

### 8. novel_server / manga_server 退出码 127

**症状**：日志中大量：
```
[ServiceNovel] Server exited with code 127
[ServiceManga] Server exited with code 127
```

**原因**：小说和漫画阅读器的后端服务器程序未安装（在 `extras/` 目录下，需要额外构建），不影响 Celestia 核心功能。

**解决方案**：如果不使用小说/漫画功能，可以忽略。如需使用，需构建并安装 `extras/` 下的对应服务端。

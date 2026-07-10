# Celestia-Shell 开发方案 — Distrobox 容器开发

## 目录

1. [方案概述](#1-方案概述)
2. [环境搭建](#2-环境搭建)
3. [日常开发循环](#3-日常开发循环)
4. [调试手段](#4-调试手段)
5. [发布打包](#5-发布打包)
6. [容器管理](#6-容器管理)
7. [参考命令速查](#7-参考命令速查)

---

## 1. 方案概述

```
日常机 (Fedora + Niri)
  │
  └─ Distrobox 容器: celestia-dev
       │ image: fedora:44
       │
       ├─ 所有构建依赖 (gcc-c++, qt6-devel, pipewire-devel, aubio...)
       ├─ 源码目录（映射宿主机 ~/Projects/Celestia-Shell）
       ├─ 编译产物（build/celestia/ 自包含目录）
       └─ quickshell（运行测试用）
            │
            └─ 通过共享 Wayland socket 连接到宿主机 Niri
```

**隔离性：** 所有 `-devel` 包、编译器、构建产物全在容器内，宿主机零污染。

**数据持久性：** 源码存在宿主机上，容器删除不丢代码。

---

## 2. 环境搭建

### 2.1 宿主机准备

```bash
# 安装 distrobox（Fedora 仓库直接有）
sudo dnf install distrobox podman

# 容器用户与宿主机共享（distrobox 自动处理 UID/GID 映射）
```

### 2.2 创建开发容器

```bash
distrobox create \
  --name celestia-dev \
  --image fedora:44 \
  --volume $HOME/Projects/Celestia-Shell:/home/$USER/Projects/Celestia-Shell

distrobox enter celestia-dev
```

### 2.3 容器内安装依赖

```bash
# 构建工具
sudo dnf install cmake ninja-build gcc-c++

# Qt6 开发头文件
sudo dnf install qt6-qtbase-devel qt6-qtdeclarative-devel \
  qt6-qtmultimedia-devel qt6-qtsvg-devel

# 音频
sudo dnf install pipewire-devel aubio-devel

# 数学计算
sudo dnf install libqalculate-devel

# 运行时 Shell 框架
sudo dnf install quickshell

# 可选：发行版打包工具
sudo dnf install rpm-build mock
```

验证安装：

```bash
g++ --version
cmake --version
pkg-config --modversion Qt6Core
pkg-config --modversion libpipewire-0.3
pkg-config --modversion aubio
pkg-config --modversion libqalculate
quickshell --version
```

---

## 3. 日常开发循环

### 3.1 目录结构约定

宿主机侧（容器删除后保留）：

```
~/Projects/Celestia-Shell/
├── CMakeLists.txt
├── shell.qml
├── plugin/              ← C++ 源文件
├── config/
├── modules/
├── services/
├── components/
├── utils/
├── assets/
├── build/               ← 编译产物（gitignored）
│   └── celestia/        ← 自包含产物目录
│       ├── qml/Celestia/*.so
│       ├── shell.qml
│       ├── config/
│       ├── modules/
│       └── ...
└── scripts/
```

### 3.2 进入容器

```bash
distrobox enter celestia-dev
```

### 3.3 首次构建

```bash
cd ~/Projects/Celestia-Shell

cmake -S . -B build \
  -DCMAKE_INSTALL_PREFIX=$PWD/build/celestia \
  -DINSTALL_QMLDIR="qml" \
  -DINSTALL_QSCONFDIR="." \
  -DINSTALL_LIBDIR="lib" \
  -DCMAKE_BUILD_TYPE=Debug

cmake --build build -j$(nproc)
cmake --install build
```

### 3.4 增量编译 + 测试

```bash
# 每次修改代码后：
cmake --build build -j$(nproc) && cmake --install build

# 立即在宿主机 Niri 上启动测试
QML2_IMPORT_PATH=$PWD/build/celestia/qml qs -c $PWD/build/celestia
```

按 `<Ctrl+C>` 停止 Shell，修改代码，重复。

### 3.5 完整构建脚本

`~/Projects/Celestia-Shell/scripts/build.sh`：

```bash
#!/bin/bash
set -euo pipefail

BUILD_DIR="$(dirname "$0")/../build"

cmake -S "$(dirname "$0")/.." -B "$BUILD_DIR" \
  -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/celestia" \
  -DINSTALL_QMLDIR="qml" \
  -DINSTALL_QSCONFDIR="." \
  -DINSTALL_LIBDIR="lib" \
  -DCMAKE_BUILD_TYPE=Debug

cmake --build "$BUILD_DIR" -j"$(nproc)"
cmake --install "$BUILD_DIR"

echo "---"
echo "Build complete. Run with:"
echo "QML2_IMPORT_PATH=$BUILD_DIR/celestia/qml qs -c $BUILD_DIR/celestia"
```

### 3.6 仅编译 C++ 插件（更快）

如果只改了 C++ 代码，不需要重新 `cmake --install`（QML 文件没变）：

```bash
cmake --build build -j$(nproc)

QML2_IMPORT_PATH=$PWD/build/celestia/qml qs -c $PWD/build/celestia
```

---

## 4. 调试手段

### 4.1 QML 日志

```bash
# 在 Niri 配置中启动，捕获日志
spawn-at-startup "sh" "-c" "QML2_IMPORT_PATH=$HOME/Projects/Celestia-Shell/build/celestia/qml qs -c $HOME/Projects/Celestia-Shell/build/celestia -l /tmp/celestia-debug.log"
```

查看日志：

```bash
tail -f /tmp/celestia-debug.log
```

### 4.2 Qt 调试环境变量

```bash
QML_IMPORT_TRACE=1 \
QT_LOGGING_RULES="*.debug=true" \
QSG_RENDERER_DEBUG=1 \
QML2_IMPORT_PATH=$PWD/build/celestia/qml \
qs -c $PWD/build/celestia
```

### 4.3 GDB 调试 C++ 插件

在容器内编译 Debug 版本后：

```bash
# 容器内安装 gdb
sudo dnf install gdb

# 启动带调试的 Shell
QML2_IMPORT_PATH=$PWD/build/celestia/qml gdb --args qs -c $PWD/build/celestia

# 或 attach 到运行中的进程
gdb -p $(pidof qs)
```

### 4.4 在宿主机 Niri 配置中使用开发版本

编辑 `~/.config/niri/config.kdl`：

```kdl
spawn-at-startup "sh" "-c" "QML2_IMPORT_PATH=/home/$HOME/Projects/Celestia-Shell/build/celestia/qml qs -c /home/$HOME/Projects/Celestia-Shell/build/celestia"
```

改完切换工作区触发 Niri 重载配置，或在容器内测试好了之后再更新生产配置。

---

## 5. 发布打包

当代码稳定后，在容器内用 mock 打 RPM：

```bash
# 进入容器
distrobox enter celestia-dev

# 生成源码 tarball
cd ~/Projects/Celestia-Shell
git archive --format=tar.gz -o ~/rpmbuild/SOURCES/celestia-shell-2.0.0.tar.gz HEAD

# 构建 SRPM
rpmbuild -bs celestia-shell.spec

# 在 Fedora 44 chroot 中构建
sudo mock -r fedora-44-x86_64 ~/rpmbuild/SRPMS/celestia-shell-*.src.rpm

# 产物在 /var/lib/mock/fedora-44-x86_64/result/
# 提取为自包含目录
cd /tmp
rpm2cpio /var/lib/mock/fedora-44-x86_64/result/celestia-shell-*.x86_64.rpm | cpio -idmv
tar czf celestia-release.tar.gz ./qml/ ./lib/ ./shell.qml ./config/ ...
```

RPM 的 spec 中 `%install` 阶段将产物布局成自包含目录：

```
%install
# 编译产物在 %buildroot 下重组为：
# qml/Celestia/*.so
# shell.qml
# config/
# modules/
# ...
```

---

## 6. 容器管理

```bash
# 进入容器
distrobox enter celestia-dev

# 在宿主机上直接执行容器内命令
distrobox enter celestia-dev -- cmake --build ~/Projects/Celestia-Shell/build -j$(nproc)

# 停止容器（不删除）
distrobox stop celestia-dev

# 删除容器（所有 -devel 包、编译器一并消失，宿主零残留）
distrobox rm celestia-dev

# 列出容器
distrobox list
```

---

## 7. 参考命令速查

```
# 首次搭建
sudo dnf install distrobox podman
distrobox create --name celestia-dev --image fedora:44 --volume ~/Projects/Celestia-Shell:/home/$USER/Projects/Celestia-Shell
distrobox enter celestia-dev
sudo dnf install cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel qt6-qtsvg-devel pipewire-devel aubio-devel libqalculate-devel quickshell

# 日常开发
distrobox enter celestia-dev
cd ~/Projects/Celestia-Shell
cmake --build build -j$(nproc) && cmake --install build
QML2_IMPORT_PATH=$PWD/build/celestia/qml qs -c $PWD/build/celestia

# 发布
distrobox enter celestia-dev
sudo mock -r fedora-44-x86_64 celestia-shell-*.src.rpm
```

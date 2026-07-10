# CuTShell-Niri 代码审查报告

## 审查范围

- 340 QML 文件、79 C++/HPP 文件、36 Python 文件、27 Shell 脚本
- 重点：安全漏洞、命令注入、死代码、废弃代码片段

---

## 第一部分：安全漏洞

### 🔴 HIGH — 命令注入漏洞

#### 1. ClipItem.qml — cliphist 条目 ID 未转义

**文件**: `modules/launcher/items/ClipItem.qml:24, 80`

```qml
// 第 24 行
Quickshell.execDetached(["sh", "-c", "cliphist decode '" + root.entryId + "' | wl-copy"]);
// 第 80 行
"sh", "-c", "cliphist decode '" + root.entryId + "' | wl-copy"
```

**问题**: `entryId` 来自 cliphist 输出，未经转义直接拼接进单引号 shell 命令。若剪贴板历史中的条目 ID 包含单引号 (`'`)，攻击者可构造恶意剪贴板条目实现命令注入。

**修复建议**: 使用数组参数而非 shell 拼接，或进行单引号转义 (`'` → `'\''`)：
```qml
const escapedId = root.entryId.replace(/'/g, "'\\''");
Quickshell.execDetached(["sh", "-c", "cliphist decode '" + escapedId + "' | wl-copy"]);
```

> 注: `ClipPreview.qml:48` 已经做了转义，但 `ClipItem.qml` 没有 — 不一致。

---

#### 2. EmojiList.qml — Emoji 字符直接拼接 shell 命令

**文件**: `modules/launcher/EmojiList.qml:258`

```qml
Quickshell.execDetached(["sh", "-c", "echo -n '" + (modelData?.emoji ?? "") + "' | wl-copy"]);
```

**问题**: Emoji 字符被直接拼接进 shell 命令。虽然大部分 emoji 是安全的，但 `emoji.json` 中的某些条目可能包含特殊 shell 字符 (如 `$`, `` ` ``)，或者未来数据变更可能引入风险。

**修复建议**: 使用 `printf` + 数组参数避免 shell 解析：
```qml
Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "--", modelData?.emoji ?? ""]);
```

---

#### 3. Picker.qml — 几何坐标拼接进 shell 命令

**文件**: `modules/areapicker/Picker.qml:172`

```qml
Quickshell.execDetached(["sh", "-c", `grim -l 0 -g '${geom}' - | swappy -f -`]);
```

**问题**: `geom` 变量由鼠标坐标计算得出（`Math.ceil`, `Math.floor`），理论上安全（纯数字），但通过 `sh -c` 拼接的方式是脆弱的设计。如果未来逻辑变更引入了非数字内容，注入风险会悄然出现。

**修复建议**: 使用管道数组参数：
```qml
Quickshell.execDetached(["sh", "-c", "grim -l 0 -g \"$1\" - | swappy -f -", "--", geom]);
```

---

#### 4. WebWallpaperGrid.qml — 多处用户输入拼接 bash 命令

**文件**: `modules/controlcenter/components/WebWallpaperGrid.qml:161-205`

```qml
// 第 161 行 - 搜索关键词
cmd = `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py ${root.keyword ? "--keyword '" + root.keyword + "'" : ""} --pages 3 --list --json`;

// 第 168 行 - 搜索关键词 + 分类 + 排序
cmd = `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py search ${root.keyword ? "'" + root.keyword + "'" : ""} --categories '${cats}' ...`;

// 第 184 行 - 壁纸 slug
cmd = `cd '${root.scriptDir}' && $CAELESTIA_VIRTUAL_ENV/bin/python3 main.py --slug '${slug}' --res ${root.resolution} ...`;

// 第 194 行 - API key (无引号!)
configProcess.command = ["bash", "-c", `cd '${root.scriptDir}' && ... main.py config set api_key ${key}`];
```

**问题**:
- `root.keyword` (用户搜索输入) 被拼接到 bash 命令中，包含单引号包裹，但 `keyword` 本身可能包含单引号 → **命令注入**
- `slug` (来自 API 响应) 被拼接 → 如果 API 被劫持返回恶意 slug → 命令注入
- `key` (API key 输入) **完全没有引号包裹** → 空格或特殊字符直接导致命令错误或注入
- `$CAELESTIA_VIRTUAL_ENV` 是环境变量，未加引号

**修复建议**: 将用户输入通过环境变量或独立参数传递，避免 shell 内联拼接。

---

#### 5. Nmcli.qml — WiFi 密码通过命令行参数传递

**文件**: `services/Nmcli.qml:384, 418, 432`

```qml
// 第 384 行
cmd.push(root.connectionParamPassword, password);

// 第 418 行
const cmd = [..., root.securityPsk, password];

// 第 432 行
let fallbackCmd = [..., root.connectionParamPassword, password];
```

**问题**: WiFi 密码作为命令行参数传递给 `nmcli`。虽然使用数组（非 shell 拼接）避免了 shell 注入，但密码会出现在进程列表 (`/proc/*/cmdline`) 中，任何用户可通过 `ps` 看到。

**严重度**: Medium（进程列表泄露）

**修复建议**: 使用 `nmcli` 的 `--ask` 模式或通过 stdin 传递密码，避免命令行暴露。

---

### 🟡 MEDIUM — 中等风险

#### 6. SysMonitorService.qml — kill 操作缺乏验证

**文件**: `services/SysMonitorService.qml:183-186`

```qml
function killProcess(pid) {
    if (pid > 0) {
        Quickshell.execDetached("kill", [pid.toString()]);
    }
}
```

**问题**: 仅验证 `pid > 0`，未检查 PID 是否属于当前用户进程。理论上可以发送 kill 信号给任意 PID（虽然受系统权限限制）。IPC 接口暴露此功能时风险更高。

**修复建议**: 添加用户进程白名单验证，或使用 `kill(pid, 0)` 先检查进程归属。

---

#### 7. Notification.qml — 通知链接直接传递给 app2unit

**文件**: `modules/notifications/Notification.qml:441`

```qml
Quickshell.execDetached(["app2unit", "-O", "--", link]);
```

**问题**: 通知中的 `link` 来自外部应用发送的通知，未经验证直接传递。恶意应用可以发送包含危险 URL 的通知。

**修复建议**: 验证 URL scheme（仅允许 `http://`, `https://`, `mailto:` 等安全协议）。

---

#### 8. SDDM setup.sh — NOPASSWD sudo 配置

**文件**: `dotfiles/niri-celestia-sddm/setup.sh:87-94`

```bash
echo "$REAL_USER ALL=(ALL) NOPASSWD: $CONFIG_DIR/sddm-theme-apply.sh"
echo "$REAL_USER ALL=(ALL) NOPASSWD: $CONFIG_DIR/shell-sync.sh"
```

**问题**: 为用户配置 NOPASSWD sudo 权限。如果目标脚本目录对用户可写，攻击者可以篡改脚本获取 root 权限。

**缓解**: 脚本目录 (`/etc/sddm.conf.d/`) 通常只有 root 可写，风险较低。但建议在文档中明确警告此配置。

---

#### 9. region_ocr.sh / region_search.sh — 临时文件 trap 引号问题

**文件**: `scripts/areaPicker/region_ocr.sh:11-12`, `scripts/areaPicker/region_search.sh:11-12`

```bash
TMPFILE=$(mktemp /tmp/ocr-XXXXXX.png)
trap "rm -f '$TMPFILE'" EXIT
```

**问题**: `trap` 内的 `$TMPFILE` 在 trap 设置时被展开（双引号字符串），如果文件名包含特殊字符（虽然 mktemp 不会生成），单引号会被提前闭合。

**修复建议**: 使用单引号 trap 延迟展开：
```bash
trap 'rm -f "$TMPFILE"' EXIT
```

---

### 🟢 LOW — 低风险

#### 10. API Key 明文在进程列表中可见

**文件**: `modules/controlcenter/components/WebWallpaperGrid.qml:194`

```qml
configProcess.command = ["bash", "-c", `... main.py config set api_key ${key}`];
```

API key 在进程列表中短暂可见（`ps aux`）。建议通过 stdin 或环境变量传递。

#### 11. Requests C++ 类 — HTTP 无 SSL 验证

**文件**: `plugin/src/Celestia/requests.cpp`

使用 `QNetworkAccessManager` 的默认配置，未显式配置 SSL 证书验证。虽然 Qt 默认会验证，但未处理证书错误信号（如 `sslErrors` 信号），可能导致某些边缘情况下的中间人攻击。

#### 12. shell.json 配置文件 — 无完整性校验

`Config.qml` 从 `shell.json` 读取配置，仅验证 JSON 格式合法性，不验证内容完整性。恶意修改配置文件可改变 session 命令（如 `shutdown` 命令被替换为恶意命令）。

**缓解**: 配置文件权限应为 600，位于用户目录下。

---

## 第二部分：死代码与废弃代码

### 🔴 大块注释代码（可安全删除）

#### 13. CustomShortcut 遗留代码 — 6 个文件

Niri 不支持 `CustomShortcut`（Hyprland 特性），迁移时全部注释但保留：

| 文件 | 行号 | 注释内容 |
|------|------|---------|
| `services/Players.qml` | 36-70 | 4 个 CustomShortcut (mediaToggle/Prev/Next/Stop) |
| `services/Brightness.qml` | 167-177 | 2 个 CustomShortcut (brightnessUp/Down) |
| `modules/lock/Lock.qml` | 26-36 | 2 个 CustomShortcut (lock/unlock) |
| `modules/areapicker/AreaPicker.qml` | 80-98 | 2 个 CustomShortcut (screenshot/screenshotFreeze) |
| `services/BeatDetector.qml` | 18-28 | 整个 Process 块 + import |

**建议**: 全部删除。功能已由 IPC + Niri binds.kdl 替代。

---

#### 14. ElevationGlow.qml — 注释掉的旧用法示例

**文件**: `components/effects/ElevationGlow.qml:6-14`

```qml
// RectangularShadow {
//     anchors.fill: myRectangle
//     offset.x: -10
//     ...
// }
```

**建议**: 删除。这是从原版拷贝的用法注释，不是实际代码。

---

#### 15. NiriThing.qml — 大块注释 UI 代码

**文件**: `modules/dashboard/NiriThing.qml:152-180, 347-369`

```qml
// ActionButton { ... }
// ActionButton { ... }
// Rect { ... }
// Rect { ... }
// Behavior on opacity { PropertyAnimation { ... } }
```

约 30 行注释掉的 UI 元素，属于早期开发遗留。

**建议**: 删除。

---

#### 16. Backdrop.qml — 注释掉的 Rectangle 装饰

**文件**: `modules/background/Backdrop.qml:56-66`

```qml
// Rectangle {
//     ...
// }
```

**建议**: 删除。

---

#### 17. Bar.qml — 注释掉的 IdleInhibitor DelegateChoice

**文件**: `modules/bar/Bar.qml:182-187`

```qml
// DelegateChoice {
//     roleValue: "idleInhibitor"
//     delegate: WrappedLoader {
//         sourceComponent: IdleInhibitor {}
//     }
// }
```

**建议**: 删除。如需恢复可通过 git 历史找回。

---

#### 18. ContextIndicator.qml — 注释掉的锚点和 Timer 代码

**文件**: `modules/bar/components/workspaces/context/ContextIndicator.qml:49-61`

```qml
// onYChanged: { ... }
// property Timer wsAnchorClearTimer: Timer { ... }
```

**建议**: 删除。功能已移至 `Niri.qml` 中的 `wsAnchorClearTimer`。

---

#### 19. popouts/Wrapper.qml — 注释掉的 Component.onCompleted

**文件**: `modules/bar/popouts/Wrapper.qml:201`

```qml
// Component.onCompleted: { ... }
```

**建议**: 删除。

---

#### 20. utilities/Content.qml — 注释掉的 Rectangle

**文件**: `modules/utilities/Content.qml:14`

```qml
// Rectangle {
```

**建议**: 删除。

---

#### 21. dash/Weather.qml — 注释掉的 StyledText

**文件**: `modules/dashboard/dash/Weather.qml:47`

```qml
// StyledText {
```

**建议**: 删除。

---

#### 22. MultiWindowContext.qml — 注释掉的 AnimatedText

**文件**: `modules/bar/components/workspaces/context/MultiWindowContext.qml:207`

```qml
// AnimatedText {
```

**建议**: 删除。

---

### 🟡 半死不活的服务/模块

#### 23. BeatDetector.qml — 完全无功能的 Singleton

**文件**: `services/BeatDetector.qml`

整个文件除了 `property real bpm: 150` 外全部注释掉。返回硬编码值 150，无任何实际功能。

**建议**: 如果 `beat_detector` 二进制文件不再维护，删除整个文件。如果有其他模块引用 `BeatDetector.bpm`，需同时清理引用。

---

#### 24. Players.qml — 注释掉的 import

**文件**: `services/Players.qml:3`

```qml
// import qs.components.misc
```

**建议**: 删除。

---

### 🟢 TODO/FIXME 未解决项

#### 25. 未解决的 TODO 标记

| 文件 | 行号 | 内容 |
|------|------|------|
| `modules/drawers/Drawers.qml` | 71 | `TODO: Implement focus grab for Niri when available` |
| `modules/bar/popouts/Wrapper.qml` | 74 | `TODO: Implement focus grab for Niri when available` |
| `modules/bar/popouts/WorkspacesPopout.qml` | 3 | `TODO: do not forget this :D` |
| `modules/bar/popouts/TrayMenu.qml` | 31 | `TODO: Implement compositor-agnostic focus grab if needed` |
| `modules/dashboard/ActiveWindow.qml` | 17 | `TODO: Fix change window when panel open, still overflows` |
| `modules/notifications/Notification.qml` | 442 | `TODO: change back to popup when notif dock impled` |
| `components/widgets/WindowDecorations.qml` | 18 | `TODO: Implement alternative if Niri adds pin support` |

**建议**: 
- `Drawers.qml:71` + `Wrapper.qml:74` + `TrayMenu.qml:31`: 同类问题（Niri focus grab），建议统一追踪
- `WorkspacesPopout.qml:3`: "do not forget this :D" 含义不明，建议补充说明或删除
- 其余为功能等待上游支持，保留但添加版本号预期

---

## 第三部分：代码质量问题

### 26. ClipItem.qml 与 ClipPreview.qml 转义不一致

**文件**: `modules/launcher/items/ClipItem.qml` vs `modules/launcher/items/ClipPreview.qml`

`ClipPreview.qml:48` 正确地进行了单引号转义：
```qml
const escapedId = root.entryId.replace(/'/g, "'\\''");
```

但 `ClipItem.qml:24, 80` 完全没有转义。同一数据源，两种处理方式。

---

### 27. WebWallpaperGrid.qml — `root.scriptDir` 路径注入

**文件**: `modules/controlcenter/components/WebWallpaperGrid.qml` (多处)

所有 bash 命令都使用 `` `cd '${root.scriptDir}' && ...` `` 模式。`scriptDir` 来自 QML 属性，如果路径包含单引号，所有命令都会失败或被注入。

---

### 28. Session Content.qml — 命令执行未验证

**文件**: `modules/session/Content.qml:122`

```qml
Quickshell.execDetached(button.command);
```

`button.command` 来自 `Config.session.commands.logout/shutdown/hibernate/reboot`，是用户配置。如果配置文件被恶意修改，可执行任意命令。

**缓解**: 配置文件权限限制 + 用户自行负责。

---

### 29. C++ NiriSocket — 无界读取缓冲区

**文件**: `plugin/src/Celestia/Internal/nirisocket.cpp:74`

```cpp
m_readBuffer.append(m_socket->readAll());
```

如果 Niri 发送大量事件导致缓冲区无限增长（例如异常循环），可能造成内存耗尽。

**建议**: 添加缓冲区大小上限检查。

---

### 30. C++ NiriRequestSocket — 新 socket 无超时

**文件**: `plugin/src/Celestia/Internal/nirisocket.cpp:164-224`

每个 IPC 请求创建新 `QLocalSocket`，但没有超时机制。如果 Niri 无响应，socket 会永久挂起，`m_busy` 永远为 true，阻塞所有后续请求。

**建议**: 添加 `QTimer` 超时（如 5 秒），超时后 `sock->abort()` 并处理队列。

---

## 第四部分：建议优先级

### 立即修复 (P0)
1. **ClipItem.qml 命令注入** (#1) — 可被恶意剪贴板利用
2. **WebWallpaperGrid.qml 命令注入** (#4) — 用户输入直接拼接

### 短期修复 (P1)
3. **EmojiList.qml shell 拼接** (#2) — 改为数组参数
4. **Picker.qml shell 拼接** (#3) — 防御性修复
5. **Nmcli 密码进程列表泄露** (#5) — 改用 stdin
6. **NiriRequestSocket 无超时** (#30) — 可能导致 IPC 死锁
7. **ClipItem/ClipPreview 转义一致性** (#26)

### 中期清理 (P2)
8. 删除所有 CustomShortcut 注释代码 (#13)
9. 删除 BeatDetector.qml 死服务 (#23)
10. 清理所有 TODO 标记 (#25)
11. 清理小块注释代码 (#14-#22, #24)

### 低优先级 (P3)
12. NiriSocket 缓冲区大小限制 (#29)
13. 通知链接验证 (#7)
14. API Key 传递方式改进 (#10)

---

## 附录：文件安全审计矩阵

| 文件 | 用户输入 | Shell 拼接 | 风险等级 |
|------|---------|-----------|---------|
| ClipItem.qml | cliphist ID | ✅ `sh -c` | 🔴 HIGH |
| EmojiList.qml | emoji 字符 | ✅ `sh -c` | 🔴 HIGH |
| WebWallpaperGrid.qml | 搜索词/slug/API key | ✅ `bash -c` | 🔴 HIGH |
| Picker.qml | 鼠标坐标 | ✅ `sh -c` | 🟡 MEDIUM |
| ClipPreview.qml | cliphist ID | ✅ `sh -c` (已转义) | 🟢 LOW |
| Nmcli.qml | WiFi 密码 | ❌ 数组参数 | 🟡 MEDIUM |
| Notification.qml | 通知链接 | ❌ 数组参数 | 🟡 MEDIUM |
| session/Content.qml | 配置文件命令 | ❌ 数组参数 | 🟢 LOW |
| SystemLogo.qml | 无 | ✅ `sh -c` | 🟢 LOW |
| Pam.qml | 无 ($USER) | ✅ `sh -c` | 🟢 LOW |
| Brightness.qml | 无 | ✅ `sh -c` | 🟢 LOW |
| IdleService.qml | 无 | ✅ `bash -c` | 🟢 LOW |

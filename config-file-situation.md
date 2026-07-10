# 配置文件（shell.json）二象性

## 现象

系统中有两个不同路径的 `shell.json`，内容不同，且被不同组件读取。

---

## 文件对比

| | `~/.config/quickshell/Celestia/Shell/shell.json` | `~/.config/niri_celestia/shell.json` |
|---|---|---|
| 大小 | 244 字节 | 8549 字节 |
| 完整度 | 极简（仅 `background` + `wallpaperTheming`） | 完整（含所有 QML 配置段） |
| 被 QML 读取 | ✅ `Config.qml` 通过 `Paths.config/shell.json` | ❌ 不读取 |
| 被 bash 脚本读取 | ✅ `_env.sh` 硬编码 `SHELL_CONFIG_FILE` 指向此处 | ❌ 不读取 |
| 会被 QML 覆写 | ❗ 会——`serializeAppearance()` 不含 `wallpaperTheming`，保存时会丢失该段 | ❌ 不会 |
| 含 `wallpaperTheming.enableTerminal` | 有（设为 `false`） | 无 |

## 读取链路

```
Quickshell (qs -c Celestia-Shell)
  └─ QML: Config.qml → Paths.config/shell.json
       = /home/casuki/.config/quickshell/Celestia/Shell/shell.json
  └─ 脚本: _env.sh → SHELL_CONFIG_FILE
       = /home/casuki/.config/quickshell/Celestia/Shell/shell.json

~/.config/niri_celestia/shell.json  ← 从未被任何代码读取
```

## 已发现的 Bug（已修复）

`scripts/colors/_env.sh` 中 `config_get()` 使用 jq 的 `//` 操作符：

```bash
jq -r "${jq_path} // \"${default}\""  # 旧代码
```

jq 的 `//` 将 `false` 视为 falsy 值，因此 `"enableTerminal": false` 被静默替换为默认值 `true`。

修复后：

```bash
jq -r "if ${jq_path} == null then \"${default}\" else ${jq_path} end"
```

## 待抉择

- 是否统一配置来源？
- 如果以 `~/.config/niri_celestia/shell.json` 为准，需要修改 `_env.sh` 和 `Config.qml` 的路径
- 如果以 `~/.config/quickshell/Celestia/Shell/shell.json` 为准，需要确保 `serializeAppearance()` 不丢失 `wallpaperTheming`，并将完整配置迁移过去

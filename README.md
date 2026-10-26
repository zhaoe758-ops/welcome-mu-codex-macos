# Welcome MU · macOS Codex 开屏动画

这是一个适用于 macOS 的 Codex 启动动画。它保留原项目的 Canvas 手写 `welcome → MU → 彩色图标` 动画，并使用白色背景和原生 AppKit + WKWebView 作为启动器：第一次启动 Codex 时播放动画，Codex 已经运行时只激活已有窗口。

## 使用方式

需要 macOS 13 或更高版本，以及 Xcode Command Line Tools（包含 Swift）。在项目目录执行：

```bash
chmod +x scripts/build-macos-app.sh
./scripts/build-macos-app.sh
open "dist/Welcome MU.app"
./scripts/install-macos-monitor.sh
```

可以把 `dist/Welcome MU.app` 拖到“应用程序”文件夹，之后从 Finder 双击使用。想单独预览动画时执行：

```bash
open "dist/Welcome MU.app" --args --preview
```

动画窗口覆盖主显示器，支持按 Esc 或单击跳过，完成后自动淡出。运行 `./scripts/install-macos-monitor.sh` 后，监听器会随用户登录启动；以后从 Finder、Dock 或 Spotlight 直接打开 ChatGPT/Codex 时也会播放动画。安装前请先退出当前 ChatGPT，再重新打开验证。监听器只监听应用启动事件，不修改 Codex 数据。

## Codex 路径设置

启动器会依次尝试 `com.openai.codex`、`/Applications/Codex.app` 和 `/Applications/ChatGPT.app`。如果你的 Codex 安装在其他位置，可创建配置文件：

`~/Library/Application Support/WelcomeMU/settings.json`

```json
{
  "CodexPath": "/Applications/Codex.app",
  "CodexBundleIdentifier": "com.openai.codex"
}
```

`CodexPath` 留空时使用应用标识查找。若使用 ChatGPT 桌面版，可将 `CodexBundleIdentifier` 改为 `com.openai.ChatGPT`。

## 项目结构

- `Sources/WelcomeMU/main.swift`：macOS 原生启动器、全屏窗口和 Codex 激活逻辑。
- `Sources/WelcomeMU/Resources/animation/`：动画 HTML、Canvas JavaScript 和图标路径。
- `scripts/build-macos-app.sh`：构建 Swift 可执行文件并生成可双击的 `.app`。
- `scripts/install-macos-monitor.sh`：安装 macOS LaunchAgent，监听直接打开 ChatGPT/Codex 的事件。
- `source/`：原 Windows 版本源码，保留用于对照；macOS 构建不依赖 .NET、PowerShell 或 WebView2。

## 来源

动画路径及第三方声明沿用原项目，详见 `Sources/WelcomeMU/Resources/animation/THIRD_PARTY_NOTICES.md`。

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Welcome MU.app"
PLIST_PATH="$HOME/Library/LaunchAgents/com.mouyuhui.welcomemu.monitor.plist"

if [[ ! -x "$APP_PATH/Contents/MacOS/WelcomeMU" ]]; then
  echo "请先运行 ./scripts/build-macos-app.sh" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.mouyuhui.welcomemu.monitor</string>
  <key>ProgramArguments</key><array>
    <string>$APP_PATH/Contents/MacOS/WelcomeMU</string><string>--monitor</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST

USER_ID="$(id -u)"
launchctl bootout "gui/$USER_ID/com.mouyuhui.welcomemu.monitor" 2>/dev/null || true
launchctl bootstrap "gui/$USER_ID" "$PLIST_PATH"
echo "已安装启动监听：$PLIST_PATH"

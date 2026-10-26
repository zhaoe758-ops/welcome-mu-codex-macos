#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Keep SwiftPM and clang caches inside the project so a locked-down machine can build.
export SWIFT_PACKAGE_CACHE_PATH="$ROOT_DIR/.swiftpm-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.clang-cache"

swift build -c release
PRODUCT_PATH="$(swift build -c release --show-bin-path)/WelcomeMU"
RESOURCE_BUNDLE="$(find .build -type d -name 'WelcomeMU_WelcomeMU.bundle' -print -quit)"
if [[ ! -x "$PRODUCT_PATH" || -z "$RESOURCE_BUNDLE" ]]; then
  echo "无法找到构建产物或资源包" >&2
  exit 1
fi

APP_PATH="$ROOT_DIR/dist/Welcome MU.app"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$PRODUCT_PATH" "$APP_PATH/Contents/MacOS/WelcomeMU"
cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/"

cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDisplayName</key><string>Welcome MU</string>
  <key>CFBundleExecutable</key><string>WelcomeMU</string>
  <key>CFBundleIdentifier</key><string>com.mouyuhui.welcomemu</string>
  <key>CFBundleName</key><string>Welcome MU</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

echo "已生成：$APP_PATH"

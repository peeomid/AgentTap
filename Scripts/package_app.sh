#!/usr/bin/env bash
set -euo pipefail

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

source "$ROOT/version.env"

ARCHES=( ${ARCHES:-} )
if [[ ${#ARCHES[@]} -eq 0 ]]; then
  HOST_ARCH=$(uname -m)
  case "$HOST_ARCH" in
    arm64) ARCHES=(arm64) ;;
    x86_64) ARCHES=(x86_64) ;;
    *) ARCHES=("$HOST_ARCH") ;;
  esac
fi

for ARCH in "${ARCHES[@]}"; do
  swift build -c "$CONF" --arch "$ARCH"
done

APP="$ROOT/AgentTap.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

BUNDLE_ID="com.osimify.agenttap"
LOWER_CONF=$(printf "%s" "$CONF" | tr '[:upper:]' '[:lower:]')
if [[ "$LOWER_CONF" == "debug" ]]; then
  BUNDLE_ID="com.osimify.agenttap.debug"
fi

BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AgentTap</string>
    <key>CFBundleDisplayName</key><string>AgentTap</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>AgentTap</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>AgentTap</string>
    <key>AgentTapBuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>AgentTapGitCommit</key><string>${GIT_COMMIT}</string>
</dict>
</plist>
PLIST

build_product_path() {
  local name="$1"
  local arch="$2"
  case "$arch" in
    arm64|x86_64) echo ".build/${arch}-apple-macosx/$CONF/$name" ;;
    *) echo ".build/$CONF/$name" ;;
  esac
}

if [[ ${#ARCHES[@]} -eq 1 ]]; then
  BIN_PATH=$(build_product_path AgentTap "${ARCHES[0]}")
  cp -f "$BIN_PATH" "$APP/Contents/MacOS/AgentTap"
else
  TMP_BIN="$ROOT/.build/AgentTap-universal"
  LIPO_INPUTS=()
  for ARCH in "${ARCHES[@]}"; do
    LIPO_INPUTS+=("$(build_product_path AgentTap "$ARCH")")
  done
  lipo -create "${LIPO_INPUTS[@]}" -output "$TMP_BIN"
  cp -f "$TMP_BIN" "$APP/Contents/MacOS/AgentTap"
fi

cp -f "$ROOT/Sources/AgentTap/Resources/AgentTap.icns" "$APP/Contents/Resources/AgentTap.icns"

SIGN_IDENTITY=${SIGN_IDENTITY:-}
SIGNING_MODE=${SIGNING_MODE:-}
if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"
elif [[ "$SIGNING_MODE" == "adhoc" ]]; then
  codesign --force --deep --sign - "$APP"
else
  echo "WARN: App is not signed. Set SIGN_IDENTITY or SIGNING_MODE=adhoc." >&2
fi

echo "Packaged: $APP"

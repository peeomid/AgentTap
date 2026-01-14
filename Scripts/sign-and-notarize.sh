#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

SIGN_IDENTITY=${SIGN_IDENTITY:?"Set SIGN_IDENTITY to your Developer ID Application identity"}
APP="$ROOT/AgentTap.app"

if [[ ! -d "$APP" ]]; then
  echo "AgentTap.app not found. Run Scripts/package_app.sh first." >&2
  exit 1
fi

codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"

echo "Signed: $APP"

echo "Notarization is not automated here. If needed, submit with xcrun notarytool." >&2

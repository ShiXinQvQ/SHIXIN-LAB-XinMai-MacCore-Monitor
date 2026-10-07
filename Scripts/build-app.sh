#!/usr/bin/env bash

# Copyright (C) 2026 SHIXIN LAB / Shixin
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SHIXIN LAB · 「芯脉」"
PRODUCT_NAME="ShixinStressPower"
HELPER_PRODUCT_NAME="ShixinStressPowerHelper"
HELPER_LABEL="com.shixinqvq.shixinlab.macstresspower.helper"
INFO_PLIST="$ROOT_DIR/Packaging/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
HELPER_VERSION="$(sed -n 's/.*helperVersion = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Sources/ShixinStressPowerCore/HelperProtocol.swift" | head -n 1)"
test -n "$HELPER_VERSION"
if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  SOURCE_COMMIT="$(git -C "$ROOT_DIR" rev-parse --verify HEAD)"
  if [ -n "$(git -C "$ROOT_DIR" status --porcelain=v1 --untracked-files=all)" ]; then
    SOURCE_TREE_STATE="dirty"
  else
    SOURCE_TREE_STATE="clean"
  fi
else
  SOURCE_COMMIT="unavailable (source archive)"
  SOURCE_TREE_STATE="unavailable"
fi
# Development builds stay inside the project so they never replace the installed
# app. Set SHIXIN_APP_INSTALL_DIR explicitly to install elsewhere.
APP_INSTALL_DIR="${SHIXIN_APP_INSTALL_DIR:-$ROOT_DIR/Dist/Development}"
APP_DIR="$APP_INSTALL_DIR/${APP_NAME}.app"
STAGING_ROOT="$(mktemp -d /private/tmp/shixin-maccore-build.XXXXXX)"
STAGED_APP_DIR="$STAGING_ROOT/${APP_NAME}.app"
SWIFT_BUILD_ARGS=(-c release --jobs "${SHIXIN_BUILD_JOBS:-2}")
if [ -n "${SHIXIN_SWIFT_SCRATCH_PATH:-}" ]; then
  SWIFT_BUILD_ARGS+=(--scratch-path "$SHIXIN_SWIFT_SCRATCH_PATH")
fi

cd "$ROOT_DIR"
bash "$ROOT_DIR/Scripts/swift-build.sh" build "${SWIFT_BUILD_ARGS[@]}" --product "$PRODUCT_NAME"
HELPER_BUILD_ARGS=(-c release --jobs "${SHIXIN_BUILD_JOBS:-2}")
if [ -n "${SHIXIN_HELPER_SWIFT_SCRATCH_PATH:-${SHIXIN_SWIFT_SCRATCH_PATH:-}}" ]; then
  HELPER_BUILD_ARGS+=(--scratch-path "${SHIXIN_HELPER_SWIFT_SCRATCH_PATH:-$SHIXIN_SWIFT_SCRATCH_PATH}")
fi
BIN_PATH="$(swift build "${SWIFT_BUILD_ARGS[@]}" --product "$PRODUCT_NAME" --show-bin-path)/$PRODUCT_NAME"
if [ -n "${SHIXIN_HELPER_BINARY_SOURCE:-}" ]; then
  # Preserve an already verified Helper when this release only changes the App.
  # Keep its exact source revision explicit for GPL source correspondence.
  test -n "${SHIXIN_HELPER_SOURCE_COMMIT:-}"
  git cat-file -e "${SHIXIN_HELPER_SOURCE_COMMIT}^{commit}"
  test -x "$SHIXIN_HELPER_BINARY_SOURCE"
  codesign --verify --strict "$SHIXIN_HELPER_BINARY_SOURCE"
  HELPER_BIN_PATH="$SHIXIN_HELPER_BINARY_SOURCE"
else
  SHIXIN_BUILD_SDK_PATH="${SHIXIN_HELPER_BUILD_SDK_PATH:-${SHIXIN_BUILD_SDK_PATH:-}}" \
    bash "$ROOT_DIR/Scripts/swift-build.sh" build "${HELPER_BUILD_ARGS[@]}" --product "$HELPER_PRODUCT_NAME"
  HELPER_BIN_PATH="$(swift build "${HELPER_BUILD_ARGS[@]}" --product "$HELPER_PRODUCT_NAME" --show-bin-path)/$HELPER_PRODUCT_NAME"
fi

mkdir -p "$STAGED_APP_DIR/Contents/MacOS" "$STAGED_APP_DIR/Contents/Resources/PrivilegedHelperTools" "$STAGED_APP_DIR/Contents/Resources/Tools" "$STAGED_APP_DIR/Contents/Resources/Licenses"
cp "$BIN_PATH" "$STAGED_APP_DIR/Contents/MacOS/$PRODUCT_NAME"
cp "$HELPER_BIN_PATH" "$STAGED_APP_DIR/Contents/Resources/PrivilegedHelperTools/$HELPER_LABEL"
cp "$ROOT_DIR/Packaging/Info.plist" "$STAGED_APP_DIR/Contents/Info.plist"
SHIXIN_UPDATE_PUBLIC_KEY_FILE="${SHIXIN_UPDATE_PUBLIC_KEY_FILE:-$ROOT_DIR/Packaging/Sparkle-public-key.txt}"
if [ -f "$SHIXIN_UPDATE_PUBLIC_KEY_FILE" ]; then
  python3 - "$SHIXIN_UPDATE_PUBLIC_KEY_FILE" "$STAGED_APP_DIR/Contents/Info.plist" <<'PY'
import base64, plistlib, sys
from pathlib import Path
key = Path(sys.argv[1]).read_text().strip()
if len(base64.b64decode(key, validate=True)) != 32:
    raise SystemExit("Update public key must be a base64-encoded 32-byte Ed25519 key")
path = Path(sys.argv[2])
info = plistlib.loads(path.read_bytes())
info["SUPublicEDKey"] = key
path.write_bytes(plistlib.dumps(info))
PY
fi
python3 "$ROOT_DIR/Scripts/embed-sparkle.py" \
  --scratch "${SHIXIN_SWIFT_SCRATCH_PATH:-$ROOT_DIR/.build}" --app "$STAGED_APP_DIR"
cp "$ROOT_DIR/Packaging/THIRD-PARTY-NOTICES.txt" "$STAGED_APP_DIR/Contents/Resources/Licenses/THIRD-PARTY-NOTICES.txt"
if [ -d "$ROOT_DIR/Sources/ShixinStressPower/Resources" ]; then
  find "$ROOT_DIR/Sources/ShixinStressPower/Resources" -maxdepth 1 -name "*.lproj" -type d -exec cp -R {} "$STAGED_APP_DIR/Contents/Resources/" \;
fi
cp "$ROOT_DIR/Packaging/AppIcon.icns" "$STAGED_APP_DIR/Contents/Resources/AppIconOpenStyle.icns"
for asset in AppIconPreview.png AppIconPreviewInApp.png; do
  if [ -f "$ROOT_DIR/Packaging/$asset" ]; then
    cp "$ROOT_DIR/Packaging/$asset" "$STAGED_APP_DIR/Contents/Resources/$asset"
  fi
done

{
  printf '%s\n' 'SHIXIN LAB · 「芯脉」 Build Provenance / 构建来源'
  printf 'Schema: 1\n'
  printf 'Source commit: %s\n' "$SOURCE_COMMIT"
  printf 'Source working tree: %s\n' "$SOURCE_TREE_STATE"
  printf 'Build script: Scripts/build-app.sh\n'
  printf 'App version: %s\n' "$APP_VERSION"
  printf 'App build: %s\n' "$APP_BUILD"
  printf 'Helper version: %s\n' "$HELPER_VERSION"
  printf 'Helper source commit: %s\n' "${SHIXIN_HELPER_SOURCE_COMMIT:-$SOURCE_COMMIT}"
  printf 'App build SDK: %s\n' "${SHIXIN_BUILD_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
  printf 'Helper build SDK: %s\n' "${SHIXIN_HELPER_BUILD_SDK_PATH:-${SHIXIN_BUILD_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}}"
} > "$STAGED_APP_DIR/Contents/Resources/SHIXIN-LAB-Build-Provenance.txt"

SMARTCTL_SOURCE="${SHIXIN_SMARTCTL_SOURCE:-}"
if [ -n "$SMARTCTL_SOURCE" ] && [ ! -x "$SMARTCTL_SOURCE" ]; then
  echo "SHIXIN_SMARTCTL_SOURCE is not executable: $SMARTCTL_SOURCE" >&2
  exit 1
fi
if [ -z "$SMARTCTL_SOURCE" ] && [ -x "$ROOT_DIR/Tools/smartctl" ]; then
  SMARTCTL_SOURCE="$ROOT_DIR/Tools/smartctl"
fi

if [ -n "$SMARTCTL_SOURCE" ]; then
  cp "$SMARTCTL_SOURCE" "$STAGED_APP_DIR/Contents/Resources/Tools/smartctl"
  chmod +x "$STAGED_APP_DIR/Contents/Resources/Tools/smartctl"
  cp "$ROOT_DIR/Packaging/THIRD-PARTY-NOTICES.txt" "$STAGED_APP_DIR/Contents/Resources/Licenses/THIRD-PARTY-NOTICES.txt"
  if [ -f "$ROOT_DIR/Packaging/smartmontools-COPYING.txt" ]; then
    cp "$ROOT_DIR/Packaging/smartmontools-COPYING.txt" "$STAGED_APP_DIR/Contents/Resources/Licenses/smartmontools-COPYING.txt"
  fi
  "$SMARTCTL_SOURCE" --version > "$STAGED_APP_DIR/Contents/Resources/Licenses/smartctl-version.txt"
fi

chmod +x "$STAGED_APP_DIR/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$STAGED_APP_DIR/Contents/Resources/PrivilegedHelperTools/$HELPER_LABEL"

if command -v codesign >/dev/null 2>&1; then
  if [ -z "${SHIXIN_HELPER_BINARY_SOURCE:-}" ]; then
    codesign --force --sign - "$STAGED_APP_DIR/Contents/Resources/PrivilegedHelperTools/$HELPER_LABEL" >/dev/null
  else
    cmp -s "$SHIXIN_HELPER_BINARY_SOURCE" "$STAGED_APP_DIR/Contents/Resources/PrivilegedHelperTools/$HELPER_LABEL"
  fi
  if [ -f "$STAGED_APP_DIR/Contents/Resources/Tools/smartctl" ]; then
    codesign --force --sign - "$STAGED_APP_DIR/Contents/Resources/Tools/smartctl" >/dev/null
    SMARTCTL_SHA="$(shasum -a 256 "$STAGED_APP_DIR/Contents/Resources/Tools/smartctl" | awk '{print $1}')"
    printf '%s  smartctl\n' "$SMARTCTL_SHA" >> "$STAGED_APP_DIR/Contents/Resources/Licenses/smartctl-version.txt"
  fi
  codesign --force --sign - "$STAGED_APP_DIR" >/dev/null
  codesign --verify --deep --strict "$STAGED_APP_DIR"
fi
python3 "$ROOT_DIR/Scripts/verify-updater-bundle.py" "$STAGED_APP_DIR"

mkdir -p "$APP_INSTALL_DIR"
if [ -e "$APP_DIR" ]; then
  TRASH_DIR="${SHIXIN_TRASH_DIR:-$HOME/.Trash}"
  PREVIOUS_APP="$TRASH_DIR/${APP_NAME}-prebuild-$(date +%Y%m%d-%H%M%S)-$$.app"
  mkdir -p "$TRASH_DIR"
  mv "$APP_DIR" "$PREVIOUS_APP"
  echo "Previous build moved to Trash: $PREVIOUS_APP"
fi
mv "$STAGED_APP_DIR" "$APP_DIR"
rmdir "$STAGING_ROOT"

echo "Built: $APP_DIR"

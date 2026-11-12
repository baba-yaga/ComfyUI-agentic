#!/bin/bash
set -euo pipefail

AGENTIC_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ComfyUI Agentic.app"
APPLICATIONS_DIR="$HOME/Applications"
APP_PATH="$APPLICATIONS_DIR/$APP_NAME"
ICON_SOURCE="$AGENTIC_ROOT/assets/comfyui-agentic-icon.ico"

if [[ ! -f "$AGENTIC_ROOT/run_comfyui_cdp.sh" || ! -f "$ICON_SOURCE" ]]; then
    echo "ERROR: Companion launcher or mascot icon is missing." >&2
    exit 1
fi

mkdir -p "$APPLICATIONS_DIR"
if [[ -e "$APP_PATH" ]]; then
    existing_root="$(plutil -extract ComfyUIAgenticRoot raw "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$existing_root" != "$AGENTIC_ROOT" ]]; then
        echo "ERROR: $APP_PATH exists but is not this companion's application." >&2
        exit 1
    fi
fi

BUILD_DIR="$(mktemp -d "$APPLICATIONS_DIR/.comfyui-agentic.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT
APP_BUILD="$BUILD_DIR/$APP_NAME"
ICONSET="$BUILD_DIR/comfyui-agentic.iconset"

osacompile -s -o "$APP_BUILD" "$AGENTIC_ROOT/macos/ComfyUI-Agentic.applescript"
mkdir -p "$ICONSET"
make_icon() {
    local size="$1"
    local name="$2"
    sips -s format png -z "$size" "$size" "$ICON_SOURCE" \
        --out "$ICONSET/$name" >/dev/null
}
make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png
iconutil --convert icns --output "$APP_BUILD/Contents/Resources/comfyui-agentic-icon.icns" "$ICONSET"
plutil -replace CFBundleIconFile -string "comfyui-agentic-icon.icns" "$APP_BUILD/Contents/Info.plist"
plutil -replace CFBundleIconName -string "comfyui-agentic-icon" "$APP_BUILD/Contents/Info.plist"
plutil -insert CFBundleDisplayName -string "ComfyUI Agentic" "$APP_BUILD/Contents/Info.plist"
plutil -insert ComfyUIAgenticRoot -string "$AGENTIC_ROOT" "$APP_BUILD/Contents/Info.plist"
if [[ -e "$APP_PATH" ]]; then
    mv "$APP_PATH" "$BUILD_DIR/previous.app"
fi
if ! mv "$APP_BUILD" "$APP_PATH"; then
    if [[ -e "$BUILD_DIR/previous.app" ]]; then
        mv "$BUILD_DIR/previous.app" "$APP_PATH"
    fi
    exit 1
fi

echo "Installed $APP_PATH"

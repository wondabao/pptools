#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET_DIR="/tmp/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

echo "正在从 logo.svg 生成高分辨率图标集合…"
# 渲染 1024x1024 主图 (RGBA)
magick -background none -density 1200 logo.svg -resize 1024x1024 "$ICONSET_DIR/icon_512x512@2x.png"

# 生成各分辨率尺寸
sips -z 16 16     "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
sips -z 32 32     "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
sips -z 64 64     "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
sips -z 256 256   "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
sips -z 512 512   "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$ICONSET_DIR/icon_512x512@2x.png" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null

mkdir -p Sources/PPTTools/Resources
iconutil -c icns "$ICONSET_DIR" -o Sources/PPTTools/Resources/AppIcon.icns
rm -rf "$ICONSET_DIR"
rm -f test_icon.png
echo "成功生成 AppIcon.icns: Sources/PPTTools/Resources/AppIcon.icns"

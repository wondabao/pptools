#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# 1. 确保构建最新 Release App
echo "==> 正在构建 Release 应用..."
./scripts/build-app.sh

APP_PATH="$PWD/build/有用工具.app"
if [ ! -d "$APP_PATH" ]; then
    echo "错误：未找到构建产物 $APP_PATH" >&2
    exit 1
fi

# 2. 读取版本号
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.1.0")
VOL_NAME="有用工具"
DMG_NAME="有用工具-v${VERSION}.dmg"
DMG_PATH="$PWD/build/$DMG_NAME"
GENERIC_DMG="$PWD/build/有用工具.dmg"

echo "==> 准备打包 DMG (版本: v${VERSION})..."

# 3. 准备临时目录
TMP_DIR="$PWD/build/tmp-dmg"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

# 复制 App 到临时目录
cp -R "$APP_PATH" "$TMP_DIR/"

# 创建 Applications 软链接
ln -s /Applications "$TMP_DIR/Applications"

# 如果存在 AppIcon，也可作为卷标图标
if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    cp "$APP_PATH/Contents/Resources/AppIcon.icns" "$TMP_DIR/.VolumeIcon.icns"
fi

# 4. 删除旧的 DMG 产物（如果存在）
rm -f "$DMG_PATH" "$GENERIC_DMG"

# 5. 生成 UDZO (高压缩) 格式的 DMG
echo "==> 正在使用 hdiutil 生成压缩 DMG 镜像..."
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# 为方便发布，生成一份固定名称的副本
cp "$DMG_PATH" "$GENERIC_DMG"

# 6. 计算 SHA-256 校验和
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
echo "$SHA256  $DMG_NAME" > "$PWD/build/$DMG_NAME.sha256"

echo "=================================================="
echo "✅ DMG 打包完成："
echo "   版本镜像: $DMG_PATH"
echo "   通用镜像: $GENERIC_DMG"
echo "   文件大小: $(du -sh "$DMG_PATH" | awk '{print $1}')"
echo "   SHA-256:  $SHA256"
echo "=================================================="

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p "$PWD/.build/clang-cache" "$PWD/build"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"

# Generate AppIcon from official logo if not already present
if [ -f "Sources/PPTTools/Resources/AppIcon.icns" ]; then
    : # Reuse existing icon
elif [ -f "logo.png" ]; then
    swift scripts/make-icon.swift logo.png Sources/PPTTools/Resources/AppIcon.icns
elif [ -f "logo.svg" ]; then
    swift scripts/make-icon.swift logo.svg Sources/PPTTools/Resources/AppIcon.icns
fi

swift build -c release --disable-sandbox
app="$PWD/build/有用工具.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/PPTTools "$app/Contents/MacOS/PPTTools"
# App uses standard resources when bundled and Bundle.module under SwiftPM.
cp Sources/PPTTools/Resources/templates.json "$app/Contents/Resources/"
if [ -f Sources/PPTTools/Resources/Credits.rtf ]; then
    cp Sources/PPTTools/Resources/Credits.rtf "$app/Contents/Resources/"
fi
if [ -f Sources/PPTTools/Resources/AppIcon.icns ]; then
    cp Sources/PPTTools/Resources/AppIcon.icns "$app/Contents/Resources/"
fi
if [ -f Sources/PPTTools/Resources/logo.png ]; then
    cp Sources/PPTTools/Resources/logo.png "$app/Contents/Resources/"
fi
for f in Sources/PPTTools/Resources/ppt_icon.* Sources/PPTTools/Resources/pdf_icon.*; do
    [ -f "$f" ] && cp "$f" "$app/Contents/Resources/"
done
if [ -d Sources/PPTTools/Resources/HeroAssets ]; then
    cp -r Sources/PPTTools/Resources/HeroAssets "$app/Contents/Resources/"
fi
BUNDLE_DIR=$(find .build -name "PPTTools_PPTTools.bundle" -type d | head -n 1)
if [ -n "$BUNDLE_DIR" ] && [ -d "$BUNDLE_DIR" ]; then
    cp -R "$BUNDLE_DIR" "$app/Contents/Resources/"
fi
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>有用工具</string>
<key>CFBundleDisplayName</key><string>有用工具</string>
<key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
<key>CFBundleLocalizations</key><array><string>zh-Hans</string></array>
<key>CFBundleIdentifier</key><string>local.pptools.app</string>
<key>CFBundleExecutable</key><string>PPTTools</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIconName</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.1</string>
<key>CFBundleVersion</key><string>1.0.1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>演示文稿与 PDF</string>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSHandlerRank</key><string>Alternate</string>
<key>LSItemContentTypes</key><array><string>com.adobe.pdf</string><string>org.openxmlformats.presentationml.presentation</string></array>
</dict></array>
</dict></plist>
PLIST
DEV_SIGN_ID=$( (security find-identity -v -p codesigning 2>/dev/null || true) | (grep "Apple Development" || true) | head -n 1 | awk -F '"' '{print $2}' )
if [ -n "${DEV_SIGN_ID:-}" ]; then
    codesign --force --deep --sign "$DEV_SIGN_ID" "$app" || codesign --force --deep --sign - "$app"
else
    codesign --force --deep --sign - "$app"
fi
printf '已生成：%s\n' "$app"

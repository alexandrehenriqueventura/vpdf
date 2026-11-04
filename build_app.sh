#!/bin/bash
set -e

echo "🔨 Compilando vpdf para macOS..."

APP_NAME="vpdf"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="${TMPDIR:-/tmp}/vpdf_build"
CACHE_DIR="${TMPDIR:-/tmp}/clang-cache"

mkdir -p "$BUILD_DIR"
mkdir -p "$CACHE_DIR"

# Detecta o caminho dos plugins de macros do Swift (compatível com CLT local e GitHub Actions)
PLUGIN_FLAG=""
DEV_DIR="$(xcode-select -p 2>/dev/null || echo "")"
if [[ "$DEV_DIR" == *"CommandLineTools"* ]] && [ -d "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins" ]; then
    PLUGIN_FLAG="-plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins"
elif [ -n "$DEV_DIR" ] && [ -d "$DEV_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins" ]; then
    PLUGIN_FLAG="-plugin-path $DEV_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins"
elif [ -d "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins" ]; then
    PLUGIN_FLAG="-plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins"
fi

swiftc -module-cache-path "$CACHE_DIR" \
    $PLUGIN_FLAG \
    Sources/vpdf/Models/*.swift \
    Sources/vpdf/Services/*.swift \
    Sources/vpdf/ViewModels/*.swift \
    Sources/vpdf/Views/*.swift \
    Sources/vpdf/App.swift \
    -o "$BUILD_DIR/$APP_NAME"

echo "📦 Montando pacote $APP_BUNDLE..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Sources/vpdf/Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
if [ -f "Sources/vpdf/Resources/AppIcon.icns" ]; then
    cp Sources/vpdf/Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "🔐 Assinando com App Sandbox e Security-Scoped Bookmarks..."
codesign -s - --force --deep --entitlements Sources/vpdf/Resources/vpdf.entitlements "$APP_BUNDLE"

echo "================================================="
echo "✅ Aplicativo compilado e assinado com sucesso!"
echo "👉 Para abrir agora mesmo, execute: open $APP_BUNDLE"
echo "================================================="

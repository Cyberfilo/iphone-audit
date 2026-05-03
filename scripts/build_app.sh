#!/usr/bin/env bash
# Build iSpow.app — a clickable macOS app bundle, no Xcode required.
#
# Output: ./iSpow.app at the repo root.
# Strategy:
#   1. Compile Sources/iSpow/*.swift with swiftc directly (no SwiftPM).
#   2. Assemble a standard .app bundle layout.
#   3. Write Info.plist.
#   4. Ad-hoc codesign so Gatekeeper allows it to launch.
#
# Run from anywhere; the script resolves paths relative to itself.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$REPO_ROOT/frontend"
APP_NAME="iSpow"
APP_BUNDLE="$REPO_ROOT/${APP_NAME}.app"
BINARY_NAME="iSpow"
BUNDLE_ID="app.iphoneharden.iSpow"
VERSION_STRING="$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo "1.000")"
DEPLOYMENT_TARGET="13.0"

# Build target — match host arch by default. Override with TARGET=x86_64-apple-macos13 for Intel.
TARGET="${TARGET:-arm64-apple-macos${DEPLOYMENT_TARGET}}"

echo "▸ Cleaning previous bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "▸ Resolving SDK..."
SDK="$(xcrun --show-sdk-path --sdk macosx)"
echo "  SDK: $SDK"

echo "▸ Compiling Swift sources (target: $TARGET)..."
SOURCES=("$FRONTEND_DIR"/Sources/iSpow/*.swift)
/usr/bin/swiftc \
    -O \
    -target "$TARGET" \
    -sdk "$SDK" \
    -module-name "$APP_NAME" \
    -emit-executable \
    -o "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME" \
    "${SOURCES[@]}"

echo "▸ Writing Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>iSpow — iPhone Audit & Hardening</string>
    <key>CFBundleExecutable</key>
    <string>${BINARY_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION_STRING}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION_STRING}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>${DEPLOYMENT_TARGET}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
EOF

echo "▸ Writing PkgInfo..."
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

echo "▸ Ad-hoc codesigning..."
codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE" 2>&1 \
    | sed 's/^/  /'

echo "▸ Verifying signature..."
codesign --verify --verbose=2 "$APP_BUNDLE" 2>&1 | sed 's/^/  /'

echo
echo "✓ Built: $APP_BUNDLE"
echo "  Size:  $(du -sh "$APP_BUNDLE" | awk '{print $1}')"
echo
echo "Run with:"
echo "  open '$APP_BUNDLE'"
echo
echo "The app expects the backend venv at: $REPO_ROOT/backend/.venv/bin/python"
echo "If missing: cd $REPO_ROOT/backend && python3.13 -m venv .venv && .venv/bin/pip install -e '.[dev]'"

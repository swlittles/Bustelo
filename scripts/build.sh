#!/bin/bash
# Build Bustelo.app. Local builds are ad-hoc signed; set BUSTELO_SIGNING_IDENTITY for Developer ID.
set -euo pipefail
cd "$(dirname "$0")/.."
OUTPUT_DIR="${BUSTELO_OUTPUT_DIR:-$PWD/dist}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)
VARIANT="${BUSTELO_BUILD_VARIANT:-development}"
case "$VARIANT" in
    development) APP_NAME="Bustelo Dev"; BUNDLE_ID="io.github.swlittles.Bustelo.dev" ;;
    production) APP_NAME="Bustelo"; BUNDLE_ID="io.github.swlittles.Bustelo" ;;
    *) echo 'BUSTELO_BUILD_VARIANT must be development or production.' >&2; exit 1 ;;
esac
DESTINATION="$OUTPUT_DIR/$APP_NAME.app"
VERSION=$(cat VERSION)
BUILD_NUMBER=$(cat BUILD_NUMBER)
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "Invalid BUILD_NUMBER" >&2; exit 1; }
IDENTITY="${BUSTELO_SIGNING_IDENTITY:--}"

if /bin/ps -axo comm= | /usr/bin/grep -Fxq "$DESTINATION/Contents/MacOS/$APP_NAME"; then
    echo "$APP_NAME is running. Quit it from the menu bar before rebuilding." >&2
    exit 1
fi

STAGING=$(mktemp -d "$OUTPUT_DIR/.Bustelo-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [ "${BUSTELO_UNIVERSAL:-0}" = "1" ]; then
    for arch in arm64 x86_64; do
        swift build -c release --triple "$arch-apple-macosx13.0" --scratch-path ".build/distribution-$arch"
    done
    lipo -create .build/distribution-arm64/release/Bustelo .build/distribution-x86_64/release/Bustelo \
        -output "$APP/Contents/MacOS/$APP_NAME"
    lipo "$APP/Contents/MacOS/$APP_NAME" -verify_arch arm64 x86_64
    FRAMEWORK_SOURCE=.build/distribution-arm64/release/Sparkle.framework
else
    swift build -c release
    cp .build/release/Bustelo "$APP/Contents/MacOS/$APP_NAME"
    FRAMEWORK_SOURCE=.build/release/Sparkle.framework
fi

# Sparkle's framework is already universal; embed it and sign its helpers inside-out.
mkdir -p "$APP/Contents/Frameworks"
ditto "$FRAMEWORK_SOURCE" "$APP/Contents/Frameworks/Sparkle.framework"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
SIGN_ARGS=(--force --sign "$IDENTITY")
if [ "$IDENTITY" != - ]; then SIGN_ARGS+=(--options runtime --timestamp); fi
for component in "$FRAMEWORK/Versions/B/Autoupdate" \
    "$FRAMEWORK/Versions/B/Updater.app" \
    "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
    "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" "$FRAMEWORK"; do
    codesign "${SIGN_ARGS[@]}" "$component"
done

ICON_DIR="$PWD/assets"
if [ "$VARIANT" = development ]; then
    ICON_DIR="$STAGING/dev-assets"
    swift scripts/make-icon.swift "$ICON_DIR" --development
    iconutil -c icns "$ICON_DIR/Bustelo.iconset" -o "$ICON_DIR/Bustelo.icns"
fi
cp "$ICON_DIR/Bustelo.icns" docs/THIRD_PARTY_NOTICES.txt "$APP/Contents/Resources/"
# Only release builds get an update feed; development builds never check for updates.
UPDATE_KEYS=""
if [ "$VARIANT" = production ]; then
    UPDATE_KEYS="<key>SUFeedURL</key><string>https://github.com/swlittles/Bustelo/releases/latest/download/appcast.xml</string>
<key>SUPublicEDKey</key><string>COeL5WubKML8Vo8pShkYXPA0MRWSsJiYsXd3P2RvR24=</string>
<key>SUEnableAutomaticChecks</key><true/>
<key>SUAutomaticallyUpdate</key><false/>
<key>SUAllowsAutomaticUpdates</key><false/>
<key>SUEnableSystemProfiling</key><false/>
<key>SUVerifyUpdateBeforeExtraction</key><true/>
<key>SURequireSignedFeed</key><true/>"
fi
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleIconFile</key><string>Bustelo</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundleDisplayName</key><string>$APP_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>© 2026 Stephen Little. MIT License.</string>
$UPDATE_KEYS
</dict></plist>
PLIST
if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP"
else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"
rm -rf "$DESTINATION"
mv "$APP" "$DESTINATION"
echo "Built $DESTINATION"
if [ "$IDENTITY" = "-" ]; then
    echo "Ad-hoc build: after rebuilding you may need to re-enable $APP_NAME under Accessibility."
fi

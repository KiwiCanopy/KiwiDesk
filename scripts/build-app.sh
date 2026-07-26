#!/bin/bash
# Assemble KiwiDesk.app from the release build (#89).
#
# SwiftPM cannot emit an .app, so the bundle is assembled here.
# Everything the plist declares is derived, never re-typed: the
# version comes from KiwiDeskVersion.swift (the same constant
# `kiwidesk --version` prints) and the two icon keys come from
# actool's own partial plist. A second hand-maintained copy of
# either would be one more thing to forget on release day.
#
# Usage:
#   scripts/build-app.sh [--identity <id>] [--notarize <profile>]
#                        [--output <dir>] [--skip-build]
#
#   --identity   Signing identity. Default: "-" (ad-hoc).
#                Ad-hoc works with no Apple account, but its code
#                identity IS the binary hash, so macOS treats
#                every rebuild as a different app and the
#                Accessibility grant resets each time. Any stable
#                certificate (a self-signed one is enough) keeps
#                the grant across rebuilds; a "Developer ID
#                Application: ..." identity is the one that can
#                also be notarized for distribution.
#   --notarize   Submit to Apple and staple, using a notarytool
#                keychain profile you created yourself with
#                `xcrun notarytool store-credentials`. Requires a
#                Developer ID identity. This script never handles
#                your credentials — it only names the profile.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY="-"
NOTARY_PROFILE=""
OUT="$ROOT/.build/app"
SKIP_BUILD=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --identity)  IDENTITY="$2"; shift 2 ;;
        --notarize)  NOTARY_PROFILE="$2"; shift 2 ;;
        --output)    OUT="$2"; shift 2 ;;
        --skip-build) SKIP_BUILD=1; shift ;;
        *) echo "error: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

# Checked here rather than at the notarize step, so an
# unsatisfiable request fails in a second instead of after a
# full release build and sign.
if [ -n "$NOTARY_PROFILE" ] && [ "$IDENTITY" = "-" ]; then
    echo "error: --notarize needs --identity with a Developer ID" \
         "certificate; an ad-hoc signature cannot be notarized" >&2
    exit 2
fi

APP="$OUT/KiwiDesk.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
BUILT="$ROOT/.build/release"

# ---------------------------------------------------------------
# 1. Build

if [ "$SKIP_BUILD" -eq 0 ]; then
    echo "==> swift build -c release"
    (cd "$ROOT" && swift build -c release)
fi
[ -x "$BUILT/KiwiDesk" ] || {
    echo "error: $BUILT/KiwiDesk missing" >&2; exit 1
}

# ---------------------------------------------------------------
# 2. Skeleton

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"
cp "$BUILT/KiwiDesk" "$MACOS/KiwiDesk"

# SwiftPM resource bundles resolve via `Bundle.module`, which
# looks NEXT TO THE EXECUTABLE — so they belong in Contents/MacOS,
# not Contents/Resources. Put them in Resources and the locales,
# palettes, app font and brand assets all silently fall back to
# their defaults with no error anywhere.
shopt -s nullglob
bundles=("$BUILT"/*.bundle)
shopt -u nullglob
if [ ${#bundles[@]} -eq 0 ]; then
    echo "error: no *.bundle in $BUILT — resources would be" \
         "missing at runtime" >&2
    exit 1
fi
for b in "${bundles[@]}"; do
    cp -R "$b" "$MACOS/"
    echo "    resource bundle: $(basename "$b")"
done

# ---------------------------------------------------------------
# 3. Icon (#89). One .icon yields both the modern Assets.car
#    renditions and the legacy .icns; actool reports the exact
#    Info.plist keys for them, which step 4 merges in verbatim.

ICON_SRC="$ROOT/assets/AppIcon.icon"
ICON_PLIST="$OUT/icon-partial.plist"
if command -v actool >/dev/null 2>&1 && [ -d "$ICON_SRC" ]; then
    echo "==> actool $ICON_SRC"
    actool "$ICON_SRC" --compile "$RES" --platform macosx \
        --minimum-deployment-target 14.0 --app-icon AppIcon \
        --output-partial-info-plist "$ICON_PLIST" >/dev/null
else
    echo "warning: actool or $ICON_SRC missing — building" \
         "without an app icon" >&2
    : > "$ICON_PLIST"
fi

# ---------------------------------------------------------------
# 4. Info.plist

VERSION_FILE="$ROOT/Sources/KiwiDeskCore/App/KiwiDeskVersion.swift"
VERSION="$(sed -n 's/.*let semantic = "\(.*\)".*/\1/p' \
    "$VERSION_FILE")"
[ -n "$VERSION" ] || {
    echo "error: could not read the version from" \
         "$VERSION_FILE" >&2
    exit 1
}
echo "==> Info.plist (version $VERSION)"

PLIST="$APP/Contents/Info.plist"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>KiwiDesk</string>
    <key>CFBundleIdentifier</key>
    <string>com.kiwicanopy.kiwidesk</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>KiwiDesk</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <!-- Launch as an agent: no Dock tile, no menu bar. The app
         still promotes itself to .regular at runtime while a
         content window is open (DockPresentation.swift). Drop
         this key and every launch flashes a Dock tile before
         the code demotes it. -->
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>KiwiCanopy</string>
</dict>
</plist>
PLISTEOF

# Merge actool's own icon keys rather than re-typing them.
if [ -s "$ICON_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Print" "$ICON_PLIST" \
        > /dev/null 2>&1 && {
        while IFS= read -r key; do
            value=$(/usr/libexec/PlistBuddy \
                -c "Print :$key" "$ICON_PLIST")
            /usr/libexec/PlistBuddy \
                -c "Add :$key string $value" "$PLIST" >/dev/null
            echo "    $key = $value"
        done < <(/usr/libexec/PlistBuddy -c "Print" "$ICON_PLIST" \
            | sed -n 's/^ *\([A-Za-z]*\) = .*/\1/p')
    }
fi
plutil -lint "$PLIST" >/dev/null

# ---------------------------------------------------------------
# 5. Sign

echo "==> codesign (identity: $IDENTITY)"
if [ "$IDENTITY" = "-" ]; then
    echo "    note: ad-hoc — the Accessibility grant will reset" \
         "on every rebuild."
fi
# Deep-sign the nested resource bundles first, then the app.
for b in "$MACOS"/*.bundle; do
    [ -e "$b" ] || continue
    codesign --force --timestamp=none --sign "$IDENTITY" "$b"
done
codesign --force --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

# ---------------------------------------------------------------
# 6. Notarize (optional)

if [ -n "$NOTARY_PROFILE" ]; then
    if [ "$IDENTITY" = "-" ]; then
        echo "error: notarization needs a Developer ID identity," \
             "not an ad-hoc signature" >&2
        exit 1
    fi
    ZIP="$OUT/KiwiDesk.zip"
    echo "==> notarizing via keychain profile '$NOTARY_PROFILE'"
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" \
        --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
fi

echo
echo "built $APP"
echo "  run:  open \"$APP\""
echo "  cli:  $MACOS/KiwiDesk --version"

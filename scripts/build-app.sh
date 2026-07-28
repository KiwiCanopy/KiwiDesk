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
#                        [--output <dir>] [--skip-build] [--dmg]
#
#   --identity   Signing identity. Omit it and the sole
#                "Developer ID Application" identity in the
#                keychain is used, falling back to "-" (ad-hoc)
#                when there is none — so this needs no argument
#                on a release machine nor on a contributor's.
#                Ad-hoc works with no Apple account, but its code
#                identity IS the binary hash, so macOS treats
#                every rebuild as a different app and the
#                Accessibility grant resets each time. Any stable
#                certificate (a self-signed one is enough) keeps
#                the grant across rebuilds; a Developer ID
#                identity is the one that can also be notarized
#                for distribution.
#   --notarize   Submit to Apple and staple, using a notarytool
#                keychain profile you created yourself with
#                `xcrun notarytool store-credentials`. Requires a
#                Developer ID identity. This script never handles
#                your credentials — it only names the profile.
#   --dmg        Also wrap the finished bundle in a disk image for
#                the website download. The Homebrew cask installs
#                from a .zip and never needs this. Combine with
#                --notarize: the disk image is a separate piece of
#                signed code and needs its own ticket (see step 7).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY=""
NOTARY_PROFILE=""
OUT="$ROOT/.build/app"
SKIP_BUILD=0
ALLOW_NO_ICON=0
MAKE_DMG=0

usage() {
    cat <<'EOF'
Assemble KiwiDesk.app from the release build (#89).

Usage: scripts/build-app.sh [options]

  --identity <id>    Signing identity. Omit to use the sole
                     "Developer ID Application" in the keychain,
                     falling back to "-" (ad-hoc) when none.
  --notarize <prof>  Submit to Apple and staple, via a notarytool
                     keychain profile (needs a Developer ID).
  --output <dir>     Where to write the bundle (default .build/app).
  --skip-build       Reuse the existing release build.
  --dmg              Also wrap the bundle in a disk image.
  --allow-no-icon    Proceed even if actool cannot compile the icon.
  -h, --help         Show this help and exit.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --identity|--notarize|--output)
            # Named, because `set -u` alone would report only a
            # bare "$2: unbound variable".
            [ "$#" -ge 2 ] || {
                echo "error: $1 needs a value" >&2
                exit 2
            }
            case "$1" in
                --identity) IDENTITY="$2" ;;
                --notarize) NOTARY_PROFILE="$2" ;;
                --output)   OUT="$2" ;;
            esac
            shift 2 ;;
        --skip-build) SKIP_BUILD=1; shift ;;
        --dmg) MAKE_DMG=1; shift ;;
        --allow-no-icon) ALLOW_NO_ICON=1; shift ;;
        *) echo "error: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

# Temporary artifacts are cleared on ANY exit, not just a clean
# one. A rejected submission or a dropped connection mid-staple
# used to strand a full zipped copy of the bundle and the disk
# image staging tree in the output directory. Declared here so
# the handler can never trip `set -u` on a path the run had not
# reached yet.
STAGE=""
DMG_PARTIAL=""
APP_ZIP=""
DMG_UNTICKETED=0
cleanup_temp() {
    # `set +e` first, and it is load-bearing: errexit applies
    # inside a trap handler too, so a single failing `rm` would
    # abort the handler BEFORE the later lines — stranding the
    # partial image this exists to remove — and would replace
    # the script's real exit status with 1. `rm -f` returns 0
    # for a missing file, so this only bites when the output
    # directory itself refuses the unlink (`--output` is
    # user-supplied and unvalidated), which is precisely the
    # case no ordinary run exercises.
    set +e
    [ -n "$APP_ZIP" ] && rm -f "$APP_ZIP"
    [ -n "$STAGE" ] && rm -rf "$STAGE"
    [ -n "$DMG_PARTIAL" ] && rm -f "$DMG_PARTIAL"
    return 0
}
trap cleanup_temp EXIT

# Resolve the identity from the keychain when none was given.
# The identity STRING IS NOT A SECRET — it is stamped into every
# binary it signs and any user can read it back with
# `codesign -dv` — so it is discovered here rather than
# hardcoded to one developer's name or smuggled through a CI
# secret. Only the certificate itself is secret, and that lives
# in the keychain either way. CI imports the .p12 first and then
# lands on the same branch below.
if [ -z "$IDENTITY" ]; then
    found=()
    while IFS= read -r line; do
        [ -n "$line" ] && found+=("$line")
    done < <(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p')

    if [ "${#found[@]}" -eq 1 ]; then
        IDENTITY="${found[0]}"
        echo "==> signing identity: $IDENTITY"
    elif [ "${#found[@]}" -eq 0 ]; then
        IDENTITY="-"
    else
        echo "error: several Developer ID Application identities" \
             "in the keychain — pass --identity with one of:" >&2
        printf '  %s\n' "${found[@]}" >&2
        exit 2
    fi
fi

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

# Resource bundles go in Contents/Resources: the conventional
# place, and the only signable one. `Bundle.module` will NOT find
# them there — see `ResourceBundle.swift`, which is why every
# call site routes through `Bundle.kiwiDeskCore` /
# `Bundle.kiwiDeskGui` instead. Copying them where the generated
# accessor wants them (the bundle root) is not an option:
# codesign refuses it outright with "unsealed contents present in
# the bundle root", leaving `Sealed Resources=none`.
shopt -s nullglob
bundles=("$BUILT"/*.bundle)
shopt -u nullglob
if [ ${#bundles[@]} -eq 0 ]; then
    echo "error: no *.bundle in $BUILT — resources would be" \
         "missing at runtime" >&2
    exit 1
fi
for b in "${bundles[@]}"; do
    cp -R "$b" "$RES/"
    echo "    resource bundle: $(basename "$b")"
done

# ---------------------------------------------------------------
# 3. Icon (#89). One .icon yields both the modern Assets.car
#    renditions and the legacy .icns; actool reports the exact
#    Info.plist keys for them, which step 4 merges in verbatim.

ICON_SRC="$ROOT/assets/AppIcon.icon"
ICON_PLIST="$OUT/icon-partial.plist"
if ACTOOL="$(xcrun -f actool 2>/dev/null)" \
    && [ -d "$ICON_SRC" ]; then
    echo "==> actool $ICON_SRC"
    # Invoke the resolved path: /usr/bin/actool is a shim that
    # exists without Xcode, so probing and invoking must agree.
    "$ACTOOL" "$ICON_SRC" --compile "$RES" --platform macosx \
        --minimum-deployment-target 14.0 --app-icon AppIcon \
        --output-partial-info-plist "$ICON_PLIST" >/dev/null
elif [ -n "$NOTARY_PROFILE" ] || [ "$ALLOW_NO_ICON" -eq 0 ]; then
    echo "error: actool (Xcode, not just Command Line Tools) or" \
         "$ICON_SRC is missing, so this build would have the" \
         "generic blank icon. Pass --allow-no-icon if that is" \
         "really what you want." >&2
    exit 1
else
    echo "warning: no actool or no $ICON_SRC — building without" \
         "an app icon (--allow-no-icon)" >&2
    : > "$ICON_PLIST"
fi

# ---------------------------------------------------------------
# 4. Info.plist

VERSION_FILE="$ROOT/Sources/KiwiDeskCore/App/KiwiDeskVersion.swift"
VERSION="$(sed -n 's/.*let semantic = "\(.*\)".*/\1/p' \
    "$VERSION_FILE" | head -1)"
# CFBundleVersion accepts only 1-3 dot-separated integers, and
# bump-version.sh permits a prerelease suffix (`0.2.0-rc1`) that
# would be rejected downstream. plutil -lint validates XML, not
# this, so check the shape here.
case "$VERSION" in
    ''|*[!0-9.]*|*..*|.*|*.|*.*.*.*)
    echo "error: '$VERSION' from $VERSION_FILE is not usable as" \
         "CFBundleVersion (1-3 dot-separated integers)" >&2
    exit 1 ;;
esac
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
    /usr/libexec/PlistBuddy -c "Print :CFBundleIconName" \
        "$PLIST" >/dev/null 2>&1 || {
        echo "error: actool produced a partial plist but no icon" \
             "keys could be merged — its output format changed." \
             "See $ICON_PLIST" >&2
        exit 1
    }
fi
plutil -lint "$PLIST"

# ---------------------------------------------------------------
# 5. Sign

echo "==> codesign (identity: $IDENTITY)"
# A secure timestamp is required for notarization, but an ad-hoc
# signature cannot carry one — so it is requested for every real
# identity and only skipped for "-".
TS=(--timestamp)
if [ "$IDENTITY" = "-" ]; then
    TS=(--timestamp=none)
    echo "    note: ad-hoc — the Accessibility grant will reset" \
         "on every rebuild, and this cannot be notarized."
fi
# Inside-out: nested code must already be sealed when the outer
# bundle is signed, or the outer signature does not cover it.
for b in "$RES"/*.bundle; do
    [ -e "$b" ] || continue
    codesign --force "${TS[@]}" --options runtime \
        --sign "$IDENTITY" "$b"
done
codesign --force "${TS[@]}" --options runtime \
    --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

# ---------------------------------------------------------------
# 6. Notarize (optional)

# Submit <payload>, wait for the verdict, staple the ticket into
# <staple_target>. Both the .app and the .dmg go through here:
# they are two separate pieces of signed code and Apple tickets
# each one individually — the app's ticket does not travel with
# the image that carries it.
#
# The two arguments are separate because notarytool takes an
# archive while the thing that must end up stapled is the
# original: an .app is submitted as a zip and stapled as a
# bundle, a .dmg is both. Callers own the payload — including
# deleting a temporary one — so that a caller wanting a KEEPABLE
# archive is not fighting this function for it.
notarize_and_staple() {
    payload="$1"
    staple_target="$2"
    submit_log="$OUT/notarytool-$(basename "$staple_target").json"
    echo "==> notarizing $(basename "$staple_target") via keychain" \
         "profile '$NOTARY_PROFILE'"
    # `submit --wait` has historically exited 0 on
    # `status: Invalid`. Without this branch the rejection
    # surfaces as a confusing *stapler* error, and the
    # submission id `notarytool log` needs has already scrolled
    # past in unstructured output.
    # `|| true`: under `set -o pipefail` a non-zero notarytool
    # exit (auth, network, expired profile — all plausible on a
    # first submission) would abort here, before the branch that
    # prints the reason and the log.
    xcrun notarytool submit "$payload" \
        --keychain-profile "$NOTARY_PROFILE" --wait \
        --output-format json | tee "$submit_log" || true
    status="$(sed -n 's/.*"status"[: ]*"\([^"]*\)".*/\1/p' \
        "$submit_log" | tail -1)"
    if [ "$status" != "Accepted" ]; then
        echo "error: notarization of $(basename "$staple_target")" \
             "returned '${status:-unknown}'" >&2
        sub_id="$(sed -n 's/.*"id"[: ]*"\([^"]*\)".*/\1/p' \
            "$submit_log" | tail -1)"
        if [ -n "$sub_id" ]; then
            xcrun notarytool log "$sub_id" \
                --keychain-profile "$NOTARY_PROFILE" >&2 || true
        fi
        exit 1
    fi
    xcrun stapler staple "$staple_target"
    return 0
}

# The ad-hoc case already exited during argument handling; this
# function is reached only with a real identity.
if [ -n "$NOTARY_PROFILE" ]; then
    # Assigned to the variable the EXIT handler already knows,
    # never a second copy of the path — renaming it here would
    # otherwise leave the handler quietly cleaning nothing.
    APP_ZIP="$OUT/KiwiDesk-notarize.zip"
    ditto -c -k --keepParent "$APP" "$APP_ZIP"
    notarize_and_staple "$APP_ZIP" "$APP"
    rm -f "$APP_ZIP"
    APP_ZIP=""
    # Local assessment only — NOT the verdict a downloader gets.
    # `spctl --assess` is satisfied by an online lookup, so it
    # answers "accepted" for a notarized-but-unstapled artifact;
    # the ticket being physically attached is what buys the
    # offline pass, and only `stapler validate` proves that. For
    # the real download verdict see the quarantine recipe in
    # .claude/rules/packaging-and-release.md.
    spctl -a -vvv -t exec "$APP" 2>&1 | sed 's/^/    /'
fi

# ---------------------------------------------------------------
# 7. Disk image (optional)
#
# For the website download only — a Homebrew cask installs from a
# .zip and never sees this. Built AFTER step 6 on purpose: the
# image should carry an already-stapled app, so that unpacking it
# yields a bundle that passes Gatekeeper offline on its own.

if [ "$MAKE_DMG" -eq 1 ]; then
    DMG="$OUT/KiwiDesk-$VERSION.dmg"
    # Assemble under a partial name and rename only once the
    # image is stapled. A failure between here and there would
    # otherwise leave a correctly-named, plausibly-sized, signed
    # but TICKETLESS image at the path a release upload reads —
    # and nothing on disk says it is bad.
    # The suffix stays `.dmg`: hdiutil APPENDS .dmg to an output
    # path that lacks it, so a `$DMG.partial` name would silently
    # produce `$DMG.partial.dmg` and everything downstream would
    # then act on a file that does not exist.
    DMG_PARTIAL="$OUT/KiwiDesk-$VERSION-partial.dmg"
    STAGE="$OUT/dmg-staging"

    # Assert what the comment above claims, rather than trusting
    # the caller's flag order. Two ways to arrive here with an
    # unstapled bundle: no --notarize at all, or a --notarize run
    # followed by a bare `--skip-build --dmg`, which re-assembles
    # and RE-SIGNS the app (step 2 removes it, step 5 signs it),
    # discarding the ticket the earlier run stapled. Neither is
    # detectable once the image is built: a locally-built .dmg
    # carries no quarantine attribute, so it opens fine on this
    # machine and only fails after a download.
    DMG_UNTICKETED=0
    if ! xcrun stapler validate "$APP" >/dev/null 2>&1; then
        DMG_UNTICKETED=1
        if [ -n "$NOTARY_PROFILE" ]; then
            echo "error: $APP is not stapled even though step 6" \
                 "ran — refusing to package it" >&2
            exit 1
        fi
        echo "warning: the app is not notarized, so this image is" \
             "for local inspection only — a downloaded copy will" \
             "be refused. Re-run with --notarize <profile>." >&2
        # Same principle as the partial name above: the FILE says
        # whether it is distributable, not a warning that scrolls
        # away. Otherwise `ls` a week later shows a normally-named
        # release artifact that Gatekeeper will reject.
        DMG="$OUT/KiwiDesk-$VERSION-unnotarized.dmg"
    fi

    echo "==> building $DMG"
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    # ditto, not cp -R: this copies a signed bundle, and cp is
    # not obliged to carry every extended attribute across.
    ditto "$APP" "$STAGE/KiwiDesk.app"
    # The drag-to-install convention. Cosmetic only — no window
    # background or icon layout, which would need an AppleScript
    # pass over the mounted volume.
    ln -s /Applications "$STAGE/Applications"
    rm -f "$DMG" "$DMG_PARTIAL"
    hdiutil create -volname "KiwiDesk" -srcfolder "$STAGE" \
        -fs HFS+ -format UDZO -ov "$DMG_PARTIAL" >/dev/null
    rm -rf "$STAGE"

    if [ "$IDENTITY" = "-" ]; then
        echo "warning: ad-hoc identity — the disk image is left" \
             "unsigned and will trip Gatekeeper on download" >&2
    else
        codesign --force --timestamp --sign "$IDENTITY" \
            "$DMG_PARTIAL"
    fi

    if [ -n "$NOTARY_PROFILE" ]; then
        notarize_and_staple "$DMG_PARTIAL" "$DMG_PARTIAL"
    fi
    mv "$DMG_PARTIAL" "$DMG"
    DMG_PARTIAL=""

    if [ -n "$NOTARY_PROFILE" ]; then
        # The image is the artifact this whole two-submission
        # design exists to attach a ticket to, so verify the
        # ticket is really on it rather than trusting spctl,
        # which an online lookup alone can satisfy.
        xcrun stapler validate "$DMG" >/dev/null || {
            echo "error: $DMG has no stapled ticket after" \
                 "notarization — it would fail offline" >&2
            exit 1
        }
        # -t open, not -t exec: the download is opened, not run,
        # and primary-signature is the context Gatekeeper uses
        # for a quarantined disk image. Local assessment only —
        # see the note in step 6.
        spctl -a -vvv -t open \
            --context context:primary-signature "$DMG" 2>&1 \
            | sed 's/^/    /'
    fi
fi

echo
echo "built $APP"
echo "  run:  open \"$APP\""
echo "  cli:  $MACOS/KiwiDesk --version"
if [ "$MAKE_DMG" -eq 1 ]; then
    if [ "$DMG_UNTICKETED" -eq 1 ]; then
        echo "  dmg:  $DMG  (NOT notarized — do not distribute)"
    else
        echo "  dmg:  $DMG"
    fi
fi
exit 0

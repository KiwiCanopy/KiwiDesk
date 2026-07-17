#!/bin/bash
# Re-vendor the SketchyBar App Font assets (issue #294).
#
# Downloads the latest tagged release of
# https://github.com/kvndrsslr/sketchybar-app-font (CC0-1.0) and
# replaces the vendored snapshot in
# Sources/KiwiDeskCore/Resources/AppFont/:
#   - sketchybar-app-font.ttf   (the glyph font)
#   - icon_map.json             (app display name -> ligature map)
# then rewrites UPSTREAM.md with the pinned tag and date.
#
# Manual developer tool — NEVER a build step (builds must not touch
# the network). After running, `swift test` must pass: the
# shipped-resource guard tests catch a bad drop (undecodable map,
# unloadable font). Usage:
#   ./scripts/update-app-font.sh          # latest release
#   ./scripts/update-app-font.sh v2.0.62  # pin a specific tag
set -euo pipefail

REPO="kvndrsslr/sketchybar-app-font"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Sources/KiwiDeskCore/Resources/AppFont"
ASSETS=("sketchybar-app-font.ttf" "icon_map.json")

if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI required (brew install gh)" >&2
    exit 1
fi

TAG="${1:-}"
if [ -z "$TAG" ]; then
    TAG="$(gh release view --repo "$REPO" \
        --json tagName --jq .tagName)"
fi

echo "Vendoring $REPO@$TAG -> $DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for asset in "${ASSETS[@]}"; do
    gh release download "$TAG" --repo "$REPO" \
        --pattern "$asset" --dir "$TMP"
    if [ ! -s "$TMP/$asset" ]; then
        echo "error: $asset missing or empty in $TAG" >&2
        exit 1
    fi
done

# Sanity: the map must keep the upstream shape (an array of
# {iconName, appNames[]} entries) before we clobber anything.
if ! python3 -c "
import json
with open('$TMP/icon_map.json') as f:
    m = json.load(f)
assert isinstance(m, list) and m, 'not a non-empty array'
for e in m:
    assert isinstance(e['iconName'], str)
    assert isinstance(e['appNames'], list)
" >/dev/null 2>&1; then
    echo "error: icon_map.json in $TAG has an unexpected shape" >&2
    exit 1
fi

mkdir -p "$DEST"
for asset in "${ASSETS[@]}"; do
    mv "$TMP/$asset" "$DEST/$asset"
done

cat > "$DEST/UPSTREAM.md" <<EOF
# Vendored: sketchybar-app-font

- Upstream: https://github.com/$REPO
- Release: $TAG
- Vendored: $(date +%Y-%m-%d)
- License: CC0-1.0 (see upstream)

Snapshot of the release assets \`sketchybar-app-font.ttf\` and
\`icon_map.json\`. Do not hand-edit either file — refresh with
\`./scripts/update-app-font.sh\` and re-run \`swift test\` (the
shipped-resource guard tests validate the drop).
EOF

echo "Done. Pinned $TAG. Now run: swift test"

#!/bin/bash
# Re-vendor the SketchyBar App Font assets (issue #294).
#
# Downloads the latest tagged release of
# https://github.com/kvndrsslr/sketchybar-app-font (CC0-1.0) and
# replaces the vendored font in
# Sources/KiwiDeskCore/Resources/AppFont/sketchybar-app-font.ttf,
# then rewrites UPSTREAM.md with the pinned tag and date. The
# app name -> ligature table is read from the font's own `meta`
# table (`APPM`), so upstream's icon_map.* snapshots are not
# vendored.
#
# NEVER a build step (builds must not touch the network). Run by
# hand, and weekly by .github/workflows/app-font.yml, which opens a
# PR with the result — that workflow calls this script rather than
# re-implementing it, and reads back the tag this file stamps into
# UPSTREAM.md (AppFontWorkflowTests holds both couplings).
#
# After running, `swift test` must pass: the shipped-resource guard
# tests catch a bad drop (no name table, unloadable font). Usage:
#   ./scripts/update-app-font.sh          # latest release
#   ./scripts/update-app-font.sh v2.0.62  # pin a specific tag
set -euo pipefail

REPO="kvndrsslr/sketchybar-app-font"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Sources/KiwiDeskCore/Resources/AppFont"
ASSETS=("sketchybar-app-font.ttf")

if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI required (brew install gh)" >&2
    exit 1
fi

TAG="${1:-}"
if [ -z "$TAG" ]; then
    TAG="$(gh release view --repo "$REPO" \
        --json tagName --jq .tagName)"
fi
# A leading '-' would be parsed by gh as a flag.
if ! printf '%s' "$TAG" | grep -Eq '^v?[0-9][A-Za-z0-9._-]*$'
then
    echo "error: suspicious tag '$TAG'" >&2
    exit 1
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

# Sanity: the font must carry the APPM name table (schema 1, an
# array of [ligature, codepoint, appNames|null]) before we clobber
# anything.
if ! python3 -c "
import json, struct
b = open('$TMP/sketchybar-app-font.ttf', 'rb').read()
tables = {}
for i in range(struct.unpack('>H', b[4:6])[0]):
    o = 12 + i * 16
    tables[b[o:o + 4]] = struct.unpack('>I', b[o + 8:o + 12])[0]
m = tables[b'meta']
for i in range(struct.unpack('>I', b[m + 12:m + 16])[0]):
    r = m + 16 + i * 12
    if b[r:r + 4] == b'APPM':
        off, n = struct.unpack('>II', b[r + 4:r + 12])
        p = json.loads(b[m + off:m + off + n])
        break
assert p['version'] == 1, 'unknown APPM schema'
assert isinstance(p['icons'], list) and p['icons'], 'no icons'
for lig, cp, names in p['icons']:
    assert isinstance(lig, str) and isinstance(cp, int)
    assert names is None or isinstance(names, list)
" >/dev/null 2>&1; then
    echo "error: the font in $TAG has no usable APPM table" >&2
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
- SHA-256:
$(cd "$DEST" && shasum -a 256 "${ASSETS[@]}" | sed 's/^/  - /')

Snapshot of the release asset \`sketchybar-app-font.ttf\`; the
app name table is read from its \`meta\` table (\`APPM\`). Do not
hand-edit it — refresh with \`./scripts/update-app-font.sh\` and
re-run \`swift test\` (the shipped-resource guard tests validate
the drop).
EOF

echo "Done. Pinned $TAG. Now run: swift test"

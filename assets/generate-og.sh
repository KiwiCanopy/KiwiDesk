#!/bin/sh

# Regenerate the KiwiDesk link-preview banner from the hand-authored
# master. Same spirit as KiwiCV / KiwiCanopy: a static SVG rendered by
# macOS built-ins, committed to the repo. No satori / @vercel/og /
# puppeteer / npm deps. Run manually, not in CI.
#
#   og-banner.svg     →  og-banner.jpg      (1200×630 banner, en)
#   og-banner.de.svg  →  og-banner.de.jpg   (same banner, German tagline)
#   og-banner.ja.svg  →  og-banner.ja.jpg   (same banner, Japanese tagline)
#
# Per-locale because /de/ and /ja/ serve localized titles and descriptions;
# en keeps the bare og-banner.jpg name so shared links stay valid. Keep the
# masters viewBox-only — an explicit width/height makes qlmanage aspect-FILL
# the square canvas and the crop returns a zoomed centre strip.
#
# The mark is referenced by relative href, so logo.svg must sit next to
# og-banner.svg for qlmanage to resolve it. It points at the ONE mark
# master on purpose (#479): the banner used to embed a private copy,
# which kept the retired teal shell for a whole rebrand because nobody
# remembered it was a copy.

set -eu

asset_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# "<svg basename>:<jpg basename>" — en is the bare og-banner.jpg, per above.
banners="og-banner.svg:og-banner.jpg og-banner.de.svg:og-banner.de.jpg og-banner.ja.svg:og-banner.ja.jpg"
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/kiwidesk-og.XXXXXX")

cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT HUP INT TERM

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required macOS command: $1" >&2
    exit 1
  fi
}

require_command qlmanage
require_command sips
require_command xmllint

for pair in $banners; do
  xmllint --noout "$asset_dir/${pair%%:*}"
done

# --- Link-preview banners (opaque JPEG), one per locale ---
made=""
for pair in $banners; do
  svg="${pair%%:*}"
  jpg="${pair##*:}"
  qlmanage -t -s 1200 -o "$temp_dir" "$asset_dir/$svg" >/dev/null
  sips --cropToHeightWidth 630 1200 "$temp_dir/$svg.png" \
    --out "$temp_dir/$jpg.png" >/dev/null
  sips -s format jpeg -s formatOptions 88 "$temp_dir/$jpg.png" \
    --out "$asset_dir/$jpg" >/dev/null
  made="$made $jpg"
done

echo "Regenerated KiwiDesk banners (1200×630):$made"

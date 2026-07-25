#!/bin/sh

# Regenerate the KiwiDesk link-preview banner from the hand-authored
# master. Same spirit as KiwiCV / KiwiCanopy: a static SVG rendered by
# macOS built-ins, committed to the repo. No satori / @vercel/og /
# puppeteer / npm deps. Run manually, not in CI.
#
#   og-banner.svg  →  og-banner.jpg   (1200×630 link-preview banner)
#
# The mark is referenced by relative href, so logo.svg must sit next to
# og-banner.svg for qlmanage to resolve it. It points at the ONE mark
# master on purpose (#479): the banner used to embed a private copy,
# which kept the retired teal shell for a whole rebrand because nobody
# remembered it was a copy.

set -eu

asset_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
social_svg="$asset_dir/og-banner.svg"
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

xmllint --noout "$social_svg"

# --- Link-preview banner (opaque JPEG) from og-banner.svg ---
qlmanage -t -s 1200 -o "$temp_dir" "$social_svg" >/dev/null
sips --cropToHeightWidth 630 1200 "$temp_dir/og-banner.svg.png" \
  --out "$temp_dir/og-banner.png" >/dev/null
sips -s format jpeg -s formatOptions 88 "$temp_dir/og-banner.png" \
  --out "$asset_dir/og-banner.jpg" >/dev/null

echo "Regenerated KiwiDesk banner: og-banner.jpg (1200×630)"

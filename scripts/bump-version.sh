#!/bin/bash
# Stamps KiwiDeskVersion.swift with a semantic version and the
# current short commit SHA. Run this as the last step before
# tagging a release, then commit the result.
#
# Usage: scripts/bump-version.sh <semantic-version>
#   e.g. scripts/bump-version.sh 0.2.0
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/Sources/KiwiDeskCore/App/KiwiDeskVersion.swift"

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <semantic-version>" >&2
    exit 1
fi

VERSION="$1"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"

sed -i '' \
    -e "s/let semantic = \".*\"/let semantic = \"$VERSION\"/" \
    -e "s/let commit = \".*\"/let commit = \"$COMMIT\"/" \
    "$FILE"

echo "stamped $FILE -> $VERSION ($COMMIT)"

#!/bin/bash
# Stamps KiwiDeskVersion.swift with a semantic version, and — for
# a release build only — the commit that build is made from.
#
# Usage: scripts/bump-version.sh <semantic-version> [--stamp-commit]
#   e.g. scripts/bump-version.sh 0.9.0
#
# WHY THE COMMIT IS NOT STAMPED BY DEFAULT. A commit cannot
# contain its own SHA, so the release commit's identity does not
# exist yet while its content is being written. This script used
# to stamp `git rev-parse --short HEAD` here anyway, which named
# the *parent* of the release commit every single time — not
# "as of the last bump" but reliably off by one, and wrong in the
# direction that looks right (#32).
#
# So the checked-in constant says `"unknown"`, which is true, and
# the exact SHA is stamped at build time by the release workflow
# with `--stamp-commit`, where HEAD *is* the commit being built.
# One sed, two callers: the workflow never re-implements the
# stamping format, so the file's shape has one owner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/Sources/KiwiDeskCore/App/KiwiDeskVersion.swift"

VERSION=""
STAMP_COMMIT=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --stamp-commit) STAMP_COMMIT=1 ;;
        -*) echo "error: unknown option '$1'" >&2; exit 2 ;;
        *)
            if [ -n "$VERSION" ]; then
                echo "error: unexpected argument '$1'" >&2
                exit 2
            fi
            VERSION="$1"
            ;;
    esac
    shift
done

if [ -z "$VERSION" ]; then
    echo "usage: $0 <semantic-version> [--stamp-commit]" >&2
    exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][A-Za-z0-9.]+)?$ ]]
then
    echo "error: invalid version '$VERSION'" \
        "(expected e.g. 1.2.3 or 1.2.3-rc1)" >&2
    exit 1
fi

# "unknown" is the honest value for a checked-in tree, and
# resetting it is deliberate: leaving a previous release's SHA in
# place would let a dev build claim a commit it is not.
if [ "$STAMP_COMMIT" -eq 1 ]; then
    COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
else
    COMMIT="unknown"
fi

sed -i '' \
    -e "s/let semantic = \".*\"/let semantic = \"$VERSION\"/" \
    -e "s/let commit = \".*\"/let commit = \"$COMMIT\"/" \
    "$FILE"

echo "stamped $FILE -> $VERSION ($COMMIT)"

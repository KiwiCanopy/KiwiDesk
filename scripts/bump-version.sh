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
#
# This script is the only thing that WRITES KiwiDeskVersion.swift
# — anything needing a stamp calls it rather than adding a second
# sed. It is not the only thing that READS the declaration's
# shape: build-app.sh step 4 and the release workflow's tag check
# both parse `let semantic` with their own regex, because both
# have to know the version without being the one who set it. The
# readback at the bottom of this file is what keeps a drifted
# declaration from being reported as a successful stamp.
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

# Three integers, and NO prerelease suffix. `0.9.0-rc1` is valid
# SemVer and unusable as CFBundleVersion, which takes 1-3
# dot-separated integers and nothing else — so build-app.sh
# rejects it in step 4. That used to be merely annoying: the
# packaging run failed and you edited the constant. Since #32 the
# version reaches packaging as a pushed git TAG, and a tag is the
# one artifact here that cannot be taken back once fetched — so
# the narrower of the two owners has to be the one that runs
# first, not the one that runs after the irreversible step.
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: invalid version '$VERSION' (expected three" \
        "integers, e.g. 1.2.3 — a prerelease suffix like" \
        "'1.2.3-rc1' cannot be a CFBundleVersion)" >&2
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

# Read back what was written. `sed -i ''` exits 0 when it matches
# NOTHING, so without this the script announces a successful
# stamp over a file it did not touch — and the next thing to look
# at the version is a release build. Any edit to the declaration
# that moves it away from `let <name> = "<value>"` (a type
# annotation, a wrap for the 79-column limit, a computed
# property) silently defeats the sed, and this is what turns that
# into a failure here instead of a mislabelled artifact later.
# `ScriptStampTests` exercises both.
for pair in "semantic:$VERSION" "commit:$COMMIT"; do
    name="${pair%%:*}"
    want="${pair#*:}"
    if ! grep -q "let $name = \"$want\"" "$FILE"; then
        echo "error: $FILE still does not declare" \
             "\`let $name = \"$want\"\` after the stamp — the" \
             "declaration's shape changed and the sed above no" \
             "longer matches it" >&2
        exit 1
    fi
done

echo "stamped $FILE -> $VERSION ($COMMIT)"

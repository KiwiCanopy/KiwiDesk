#!/bin/bash
# KiwiDesk lint: formatting, line length (79), file size (350).
# Usage: scripts/lint.sh [file ...]   (defaults to all Swift files)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAX_LINE=79
SOFT_FILE=250
HARD_FILE=350
STATUS=0

if [ "$#" -gt 0 ]; then
    FILES=("$@")
else
    FILES=()
    while IFS= read -r f; do
        FILES+=("$f")
    done < <(find "$ROOT/Sources" "$ROOT/Tests" -name '*.swift' \
        2>/dev/null; echo "$ROOT/Package.swift")
fi

for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue

    # Line length check
    long=$(awk -v max=$MAX_LINE 'length($0) > max {print FNR": "$0}' \
        "$f")
    if [ -n "$long" ]; then
        echo "ERROR: lines exceed $MAX_LINE chars in $f"
        echo "$long" | head -5
        STATUS=1
    fi

    # File size check (skip tests: data-heavy fixtures are fine)
    case "$f" in
        */Tests/*) continue ;;
    esac
    lines=$(wc -l < "$f" | tr -d ' ')
    if [ "$lines" -gt "$HARD_FILE" ]; then
        echo "ERROR: $f has $lines lines (hard limit $HARD_FILE)"
        STATUS=1
    elif [ "$lines" -gt "$SOFT_FILE" ]; then
        echo "WARNING: $f has $lines lines (sweet spot <=$SOFT_FILE)"
    fi
done

# swift-format lint (ships with Xcode 16+ toolchains)
if swift format --version >/dev/null 2>&1; then
    if ! swift format lint --strict --recursive \
        --configuration "$ROOT/.swift-format" \
        "$ROOT/Sources" "$ROOT/Tests" "$ROOT/Package.swift"; then
        echo "ERROR: swift format lint failed"
        STATUS=1
    fi
else
    echo "NOTE: 'swift format' not found; skipping format lint"
fi

# Locale manifest freshness + drift guard (issue #9): fails if
# en.json doesn't match the L(...) call sites in Sources/KiwiDesk
# and Sources/KiwiDeskCore, or if the same key was authored with
# two different English strings.
if ! python3 "$ROOT/scripts/extract-keys" --check; then
    STATUS=1
fi

if [ "$STATUS" -eq 0 ]; then
    echo "Lint OK"
fi
exit $STATUS

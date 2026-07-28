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

    # File size check.
    #
    # .claude/rules/tests.md applies the §2.1 hard ceiling to suites
    # as well — "split test suites early" is what forced every one
    # of the ratified shared-helper extractions — but this used to
    # `continue` on */Tests/*, so the rule was unenforceable AND
    # invisible to anyone reading §5. A 448-line suite passed a
    # green gate under two reviews explicitly hunting AGENTS
    # violations (#277). The old reason ("data-heavy fixtures are
    # fine") is about fixture files, not suites.
    #
    # #560 split the 11 suites that were over the ceiling, so the
    # test case is now ERROR too — a source file and a test file
    # fail identically at the hard limit. The soft 250 target stays
    # source-only: dozens of test files exceed it, and that much
    # noise would train people to ignore the whole check.
    #
    # No file is exempt today, so the hard-limit branch below is an
    # unconditional ERROR. If a genuine data-heavy *fixture* file
    # ever must exceed the ceiling, add a named `case "$f"` branch
    # for it here with its reason — the repo idiom for narrow
    # classes — rather than re-introducing the blanket `*/Tests/*`
    # skip that hid the whole backlog for so long (#277).
    lines=$(wc -l < "$f" | tr -d ' ')
    case "$f" in
        */Tests/*) is_test=1 ;;
        *) is_test=0 ;;
    esac
    if [ "$lines" -gt "$HARD_FILE" ]; then
        echo "ERROR: $f has $lines lines (hard limit $HARD_FILE)"
        STATUS=1
    elif [ "$is_test" -eq 0 ] && [ "$lines" -gt "$SOFT_FILE" ]; then
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

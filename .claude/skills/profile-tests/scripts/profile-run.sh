#!/bin/bash
# Times one test target under the gate slot while recording the
# helper's window census every 20 s and two samples, 60 s apart,
# once the run passes the --sample-after mark (#1868).
# Usage: profile-run.sh <target> <out-dir> [--sample-after SECONDS]
# Run from the worktree root on a build made with
# `swift build --build-tests`; the run itself is --skip-build.
set -uo pipefail
TARGET="${1:?target, e.g. KiwiDeskCoreTests}"
OUT="${2:?output directory}"
AFTER=150
if [ "${3:-}" = "--sample-after" ]; then AFTER="${4:?seconds}"; fi
HERE="$(cd "$(dirname "$0")" && pwd)"
CENSUS="$(getconf DARWIN_USER_TEMP_DIR)kiwidesk-window-census"
if [ ! -x "$CENSUS" ] || [ "$HERE/window-census.swift" -nt "$CENSUS" ]; then
    swiftc -O "$HERE/window-census.swift" -o "$CENSUS" || exit 1
fi
mkdir -p "$OUT"
BUNDLE="$PWD/.build"
START=$(date +%s)
scripts/gate-lock swift test --skip-build --filter "$TARGET" \
    > "$OUT/run.log" 2>&1 &
RUN=$!
SAMPLED=0
while kill -0 "$RUN" 2>/dev/null; do
    sleep 20
    HELPER=$(pgrep -n -f "swiftpm-testing-helper.*$BUNDLE")
    [ -z "$HELPER" ] && continue
    AGE=$(( $(date +%s) - START ))
    echo "${AGE}s $("$CENSUS" "$HELPER")" >> "$OUT/windows.txt"
    if [ "$SAMPLED" = 0 ] && [ "$AGE" -ge "$AFTER" ]; then
        ps -o pid,pcpu,state -p "$HELPER" > "$OUT/ps.txt"
        sample "$HELPER" 8 -file "$OUT/sample-a.txt" >/dev/null 2>&1
        "$CENSUS" "$HELPER" --by-shape > "$OUT/shapes.txt"
        sleep 60
        sample "$HELPER" 8 -file "$OUT/sample-b.txt" >/dev/null 2>&1
        SAMPLED=1
    fi
done
wait "$RUN"
STATUS=$?
echo "exit $STATUS after $(( $(date +%s) - START ))s" > "$OUT/summary.txt"
grep -E "Test run with" "$OUT/run.log" >> "$OUT/summary.txt"
tail -3 "$OUT/windows.txt" >> "$OUT/summary.txt" 2>/dev/null
cat "$OUT/summary.txt"

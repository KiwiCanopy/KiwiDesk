#!/bin/bash
# Times one test target inside the gate slot, recording the helper's
# window census every 10 s and two samples, at --sample-after and 60 s
# later while the helper is still alive (#1868).
# Usage: profile-run.sh <target> <out-dir> [--sample-after SECONDS]
# Run from the worktree root on a build made with
# `swift build --build-tests`; the run itself is --skip-build.
set -uo pipefail
# Take the gate first, so the clock below starts at acquisition and a
# queue wait is never counted as test time.
if [ "${KIWIDESK_GATE_LOCK_HELD:-}" != 1 ]; then
    exec scripts/gate-lock "$0" "$@"
fi
TARGET="${1:?target, e.g. KiwiDeskCoreTests}"
OUT="${2:?output directory}"
AFTER=150
if [ "${3:-}" = "--sample-after" ]; then AFTER="${4:?seconds}"; fi
HERE="$(cd "$(dirname "$0")" && pwd)"
CENSUS="$(getconf DARWIN_USER_TEMP_DIR)kiwidesk-window-census"
if [ ! -x "$CENSUS" ] || [ "$HERE/window-census.swift" -nt "$CENSUS" ]
then
    swiftc -O "$HERE/window-census.swift" -o "$CENSUS" || exit 1
fi
mkdir -p "$OUT"
BUNDLE="$PWD/.build"
START=$(date +%s)
swift test --skip-build --filter "$TARGET" > "$OUT/run.log" 2>&1 &
RUN=$!
TAKEN=""
while kill -0 "$RUN" 2>/dev/null; do
    sleep 10
    HELPER=$(pgrep -n -f "swiftpm-testing-helper.*$BUNDLE")
    [ -z "$HELPER" ] && continue
    AGE=$(( $(date +%s) - START ))
    LINE=$("$CENSUS" "$HELPER" 2>/dev/null) || continue
    echo "${AGE}s $LINE" >> "$OUT/windows.txt"
    # Samples run beside the census, never instead of it, and only
    # against a helper that is still alive.
    if [ -z "$TAKEN" ] && [ "$AGE" -ge "$AFTER" ]; then
        ps -o pid,pcpu,state -p "$HELPER" > "$OUT/ps.txt"
        "$CENSUS" "$HELPER" --by-shape > "$OUT/shapes.txt"
        sample "$HELPER" 8 -file "$OUT/sample-a.txt" >/dev/null 2>&1 &
        TAKEN=$AGE
    elif [ -n "$TAKEN" ] && [ "$TAKEN" != done ] \
        && [ "$AGE" -ge $(( TAKEN + 60 )) ]; then
        ps -o pid,pcpu,state -p "$HELPER" > "$OUT/ps-b.txt"
        sample "$HELPER" 8 -file "$OUT/sample-b.txt" >/dev/null 2>&1 &
        TAKEN=done
    fi
done
wait "$RUN"
STATUS=$?
END=$(( $(date +%s) - START ))
{
    echo "exit $STATUS after ${END}s (from gate acquisition)"
    grep -E "Test run with" "$OUT/run.log"
    awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^onScreen=/) {
            split($i, v, "="); if (v[2] + 0 > peak) peak = v[2] + 0 } }
        END { print "peak onScreen windows: " peak + 0 }' \
        "$OUT/windows.txt" 2>/dev/null
} > "$OUT/summary.txt"
cat "$OUT/summary.txt"

#!/bin/bash
# Switches between two Spaces and reads the work counters (#1508).
# Usage: measure-switches.sh <bundle.app> <space-a> <space-b> <rounds>
#                            [--load] [--gap SECONDS]
# Each round is two switches (a→b, b→a), --gap apart (default 0.8 s,
# past the 300 ms settle). --load runs one `yes` per core for the
# duration. Prints the `get_work_counters` JSON for the window.
set -uo pipefail
CLI="${1:?bundle}/Contents/MacOS/KiwiDesk"
A="${2:?space a}"; B="${3:?space b}"; N="${4:?rounds}"
shift 4
LOAD=""; GAP=0.8
while [ $# -gt 0 ]; do
    case "$1" in
    --load) LOAD=1 ;;
    --gap) GAP="${2:?seconds}"; shift ;;
    esac
    shift
done
HOGS=()
cleanup() { [ ${#HOGS[@]} -gt 0 ] && kill "${HOGS[@]}" 2>/dev/null; }
trap cleanup EXIT
if [ -n "$LOAD" ]; then
    for _ in $(seq "$(sysctl -n hw.ncpu)"); do
        yes > /dev/null & HOGS+=($!)
    done
    sleep 2
fi
"$CLI" focus_space "$A" > /dev/null || exit 1
sleep 1
"$CLI" get_work_counters true > /dev/null || exit 1
for _ in $(seq "$N"); do
    "$CLI" focus_space "$B" > /dev/null; sleep "$GAP"
    "$CLI" focus_space "$A" > /dev/null; sleep "$GAP"
done
"$CLI" get_work_counters

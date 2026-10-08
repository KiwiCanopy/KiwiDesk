#!/bin/bash
# Switches between two Spaces and reads the work counters (#1508).
# Usage: measure-switches.sh <bundle.app> <space-a> <space-b> <rounds>
#                            [--load | --gpu-load] [--gap SECONDS]
# Each round is two switches (a→b, b→a), --gap apart (default 0.8 s,
# past the `.spaceSettle` delay in KiwiCore+SpaceFocusHandoff).
# --load runs one `yes` per core for the duration. --gpu-load (#2030)
# serves gpu-load.html on 127.0.0.1, opens it in Safari, refuses to
# measure until the GPU reads >= 90 % busy, runs inside
# `caffeinate -d`, and prints the GPU trace to stderr; every piece is
# torn down on exit, Ctrl-C included. Prints the `get_work_counters`
# JSON for the window.
set -uo pipefail
CLI="${1:?bundle}/Contents/MacOS/KiwiDesk"
A="${2:?space a}"; B="${3:?space b}"; N="${4:?rounds}"
shift 4
LOAD=""; GPU=""; GAP=0.8
while [ $# -gt 0 ]; do
    case "$1" in
    --load) LOAD=1 ;;
    --gpu-load) GPU=1 ;;
    --gap) GAP="${2:?seconds}"; shift ;;
    esac
    shift
done
if [ -n "$LOAD" ] && [ -n "$GPU" ]; then
    echo "measure-switches: --load and --gpu-load are separate" \
        "conditions; run them one at a time" >&2
    exit 2
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
PIDS=(); PORT=""; TRACE=""
gpu_busy() {
    ioreg -r -d 1 -c IOAccelerator \
        | grep -o '"Device Utilization %"=[0-9]*' \
        | head -1 | cut -d= -f2
}
cleanup() {
    if [ -n "$PORT" ]; then
        # Closes only the tab this run opened.
        osascript -e "tell application \"Safari\" to close (every \
tab of every window whose URL contains \"127.0.0.1:$PORT\")" \
            >/dev/null 2>&1 \
            || echo "measure-switches: close the Safari tab on" \
                "127.0.0.1:$PORT by hand" >&2
    fi
    [ ${#PIDS[@]} -gt 0 ] && kill "${PIDS[@]}" 2>/dev/null
    if [ -n "$TRACE" ] && [ -s "$TRACE" ]; then
        awk '{ s += $1; n++; if (min == "" || $1 < min) min = $1 }
            END { printf "gpu-load: %d samples, min %d %%, mean %.0f %%\n",
                n, min, s / n }' "$TRACE" >&2
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM
if [ -n "$LOAD" ]; then
    for _ in $(seq "$(sysctl -n hw.ncpu)"); do
        yes > /dev/null & PIDS+=($!)
    done
    sleep 2
fi
if [ -n "$GPU" ]; then
    PORT=$(python3 -c 'import socket; s = socket.socket(); \
s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
    python3 -m http.server "$PORT" --bind 127.0.0.1 \
        --directory "$HERE" > /dev/null 2>&1 & PIDS+=($!)
    caffeinate -d & PIDS+=($!)
    sleep 1
    open -a Safari "http://127.0.0.1:$PORT/gpu-load.html"
    busy=0
    for _ in $(seq 30); do
        busy=$(gpu_busy); [ "${busy:-0}" -ge 90 ] && break
        sleep 1
    done
    if [ "${busy:-0}" -lt 90 ]; then
        echo "measure-switches: GPU reached only ${busy:-0} %" \
            "(needs 90); refusing to measure" >&2
        exit 3
    fi
    TRACE=$(mktemp -t gpu-trace)
    ( while true; do gpu_busy >> "$TRACE"; sleep 1; done ) &
    PIDS+=($!)
fi
"$CLI" focus_space "$A" > /dev/null || exit 1
sleep 1
"$CLI" get_work_counters true > /dev/null || exit 1
for _ in $(seq "$N"); do
    "$CLI" focus_space "$B" > /dev/null; sleep "$GAP"
    "$CLI" focus_space "$A" > /dev/null; sleep "$GAP"
done
"$CLI" get_work_counters

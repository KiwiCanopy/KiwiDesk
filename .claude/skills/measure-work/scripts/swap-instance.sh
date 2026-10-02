#!/bin/bash
# Swaps the running KiwiDesk for a scratch bundle and back (#1508).
# Usage: swap-instance.sh start <bundle.app> <state-file>
#        swap-instance.sh restore <state-file>
# `start` records the running app's bundle in <state-file>, stops it
# by its own path and opens <bundle.app>; `restore` stops that bundle
# and reopens the recorded one. Never a generic pkill: another
# session's build may be the one running.
set -uo pipefail
EXE="Contents/MacOS/KiwiDesk"

running() {  # full path of the running app executable, if any
    # Anchored at the end: a CLI call carries arguments, and a test
    # helper's path is an .xctest, so neither matches.
    local pid
    pid=$(pgrep -f "KiwiDesk\.app/$EXE\$" | head -1)
    [ -n "$pid" ] && ps -o command= -p "$pid"
}

stop() {  # stop the app at bundle $1 and wait for its pid to go
    local pid
    pid=$(pgrep -f "^$1/$EXE\$") || return 0
    kill -TERM "$pid"
    for _ in $(seq 50); do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.2
    done
    echo "pid $pid did not exit (a modal sheet blocks TERM?)" >&2
    return 1
}

launch() {  # open bundle $1 and wait until it is the running app
    open "$1"
    for _ in $(seq 50); do
        [ "$(running)" = "$1/$EXE" ] && { echo "running: $1"; return 0; }
        sleep 0.2
    done
    echo "$1 did not start; running: $(running)" >&2
    return 1
}

case "${1:-}" in
start)
    MINE="$(cd "${2:?bundle}" && pwd)"
    STATE="${3:?state file}"
    PREV="$(running)"
    PREV="${PREV%/$EXE}"
    printf 'prev=%s\nmine=%s\n' "$PREV" "$MINE" > "$STATE"
    [ -n "$PREV" ] && { echo "stopping: $PREV"; stop "$PREV" || exit 1; }
    launch "$MINE"
    ;;
restore)
    STATE="${2:?state file}"
    PREV=$(sed -n 's/^prev=//p' "$STATE")
    MINE=$(sed -n 's/^mine=//p' "$STATE")
    stop "$MINE" || exit 1
    if [ -n "$PREV" ]; then launch "$PREV"; else echo "nothing to restore"; fi
    ;;
*)
    sed -n 2,7p "$0"; exit 2
    ;;
esac

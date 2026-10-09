#!/bin/bash
# The fixed desk a release comparison measures on (#1910).
# Usage: fixture-desk.sh up <bundle.app> <state-dir> [extra.lua]
#        fixture-desk.sh down <state-dir>
# `up` stops the running KiwiDesk by its own path, points
# ~/.config/KiwiDesk at a fresh Lua-only config (every release reads
# init.lua and none migrates it, where an older build refuses a newer
# gui.json), opens <bundle.app> and files a known set of windows,
# one layout per Space:
#   Space 2 bsp       — 3 TextEdit
#   Space 3 scrolling — 2 TextEdit + 2 VS Code at "50%" slots, two
#                       scrolled out (VS Code is the slow-AX
#                       Electron case parks pay for)
#   Space 4 floating  — 2 Script Editor
#   Space 5 stack     — 3 Script Editor
#   Space 6 monocle   — 3 Script Editor
# Terminal is left out: its new windows open on the Desktop its
# restored ones live on, not the one shown (measured 2026-10-09).
# Space 1 is the floating park the GPU load's Safari lands in.
# Run it on an EMPTY macOS Desktop: the windows open where you are,
# and the owner's own windows stay on theirs. Measure pairs 2↔3,
# 3↔4 and 5↔6. `down` closes only the windows `up` opened, restores the
# config link and reopens the KiwiDesk that was running. Run `down`
# before the next bundle's `up`, so every bundle starts fresh.
# [extra.lua] is appended to the config, for a setting one release
# has and an older one lacks — e.g. turning 2.2.0's Space-switch
# slide off so it compares with a release that never animated.
set -uo pipefail
EXE="Contents/MacOS/KiwiDesk"
LINK="$HOME/.config/KiwiDesk"
APPS=("TextEdit" "Script Editor" "Visual Studio Code")
CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

running() {
    local pid
    pid=$(pgrep -f "KiwiDesk\.app/$EXE\$" | head -1)
    [ -n "$pid" ] && ps -o command= -p "$pid"
}

pids_of() {  # pids whose whole command is bundle $1's executable
    local pid
    for pid in $(pgrep -f "KiwiDesk\.app/$EXE\$"); do
        [ "$(ps -o command= -p "$pid")" = "$1/$EXE" ] && echo "$pid"
    done
}

stop() {  # TERM the app at bundle $1 and wait for it to go
    local pid
    for pid in $(pids_of "$1"); do kill -TERM "$pid"; done
    for _ in $(seq 50); do
        [ -z "$(pids_of "$1")" ] && return 0
        sleep 0.2
    done
    echo "fixture-desk: $1 did not exit (a modal sheet?)" >&2
    return 1
}

launch() {
    open "$1"
    for _ in $(seq 50); do
        [ "$(running)" = "$1/$EXE" ] && return 0
        sleep 0.2
    done
    echo "fixture-desk: $1 did not start" >&2
    return 1
}

window_ids() {  # one app's window ids, comma-separated
    # Never launch the app just to ask: TextEdit opens a panel.
    pgrep -xq "$1" || return 0
    osascript -e "tell application \"$1\" to get id of every window" \
        2>/dev/null | tr -d ' '
}

write_config() {
    rm -rf "$1" && mkdir -p "$1"
    cat > "$1/init.lua" <<'LUA'
-- #1910 fixed desk. Lua-owned, so no gui.json is seeded.
KiwiDesk.set_mode(1, "floating")
KiwiDesk.set_mode(2, "bsp")
KiwiDesk.set_mode(3, "scrolling")
KiwiDesk.set_mode(4, "floating")
KiwiDesk.set_mode(5, "stack")
KiwiDesk.set_mode(6, "monocle")
scroll.set_slot_size("50%")
-- Every animation both releases know, pinned to the shipped
-- defaults, so a default moving in a release cannot move a row.
-- The Space-switch animation differs between releases and is the
-- caller's to state, through [extra.lua].
animations.set_duration(150)
animations.set_scroll_duration(150)
animations.set_monocle_flip_duration(450)
animations.set_on_shelf(true)
animations.set_shelf_duration(750)
animations.set_on_scrolling(true)
animations.set_on_window_resize(true)
animations.set_on_window_swap(true)
animations.set_on_relayout(true)
animations.set_on_monocle_focus(true)
app_rules = { ["com.apple.Safari"] = "1" }
LUA
}

open_windows() {  # $1 = app, $2 = how many
    local cmd
    cmd='make new document'
    # Activate first: a window an app makes while inactive opens on
    # the Desktop macOS last had current, not the one shown.
    osascript -e "tell application \"$1\" to activate" >/dev/null
    sleep 1
    for _ in $(seq "$2"); do
        osascript -e "tell application \"$1\" to $cmd" >/dev/null
    done
}

tracked() {  # how many fixture windows the instance tracks
    "$1" get_state | python3 -c '
import json, sys
apps = ("com.apple.textedit", "com.apple.scripteditor2",
        "com.microsoft.vscode")
wins = json.load(sys.stdin)["windows"]
print(sum(w["bundle_id"].lower() in apps for w in wins))
'
}

file_windows() {  # move each new window into its layout's Space
    # A launched app's first windows can arrive seconds late, through
    # the heal sweep, so wait until all fifteen are tracked.
    for _ in $(seq 60); do
        [ "$(tracked "$1")" -ge 15 ] && break
        sleep 0.5
    done
    "$1" get_state | python3 -c '
import json, sys
plan = {"com.apple.textedit": ["2"] * 3 + ["3"] * 2,
        "com.microsoft.vscode": ["3"] * 2,
        "com.apple.scripteditor2": ["4"] * 2 + ["5"] * 3 + ["6"] * 3}
state = json.load(sys.stdin)
park = next(s for s in state["spaces"] if s["id"] == "1")
apps = {w["id"]: w["bundle_id"].lower() for w in state["windows"]}
for wid in sorted(park["windows"]):
    targets = plan.get(apps.get(wid), [])
    if targets:
        print(targets.pop(0), wid)
left = {k: len(v) for k, v in plan.items() if v}
if left:
    print("missing", left, file=sys.stderr)
' | while read -r space wid; do
        "$1" move_to_space "$space" "$wid" >/dev/null
    done
}

case "${1:-}" in
file)  # re-run the filing alone against a running instance
    file_windows "${2:?bundle}/$EXE"
    ;;
up)
    MINE="$(cd "${2:?bundle}" && pwd -P)"
    DIR="${3:?state dir}"; mkdir -p "$DIR"
    if [ ! -L "$LINK" ]; then
        echo "fixture-desk: $LINK is not a symlink; refusing" >&2
        exit 1
    fi
    PREV="$(running)"; PREV="${PREV%/$EXE}"
    {
        printf 'prev=%s\nmine=%s\nlink=%s\n' \
            "$PREV" "$MINE" "$(readlink "$LINK")"
        for app in "${APPS[@]}"; do
            printf 'before.%s=%s\n' "$app" "$(window_ids "$app")"
        done
    } > "$DIR/state"
    # Stop first, so the owner's build writes its snapshot into its
    # own config, never into the fixture.
    [ -n "$PREV" ] && { stop "$PREV" || exit 1; }
    write_config "$DIR/config"
    [ -n "${4:-}" ] && cat "$4" >> "$DIR/config/init.lua"
    ln -sfn "$DIR/config" "$LINK"
    launch "$MINE" || exit 1
    sleep 5
    "$MINE/$EXE" focus_space 1 >/dev/null
    open_windows TextEdit 5
    open_windows "Script Editor" 8
    "$CODE" -n >/dev/null 2>&1; sleep 3
    "$CODE" -n >/dev/null 2>&1
    sleep 4
    file_windows "$MINE/$EXE"
    sleep 1
    "$MINE/$EXE" focus_space 2 >/dev/null
    "$MINE/$EXE" get_state
    ;;
down)
    DIR="${2:?state dir}"
    get() { sed -n "s/^$1=//p" "$DIR/state"; }
    MINE="$(get mine)"; PREV="$(get prev)"
    stop "$MINE"
    for app in "${APPS[@]}"; do
        if [ -z "$(get "before.$app")" ]; then
            # The fixture launched it: close everything and quit.
            osascript -e "tell application \"$app\" to close every \
document saving no" >/dev/null 2>&1
            osascript -e "tell application \"$app\" to quit" \
                >/dev/null 2>&1
            continue
        fi
        before=",$(get "before.$app"),"
        for id in $(window_ids "$app" | tr ',' ' '); do
            case "$before" in *",$id,"*) continue ;; esac
            osascript -e "tell application \"$app\" to close \
(window id $id) saving no" >/dev/null 2>&1 \
                || osascript -e "tell application \"$app\" to close \
(window id $id)" >/dev/null 2>&1
        done
    done
    ln -sfn "$(get link)" "$LINK"
    echo "config link: $(readlink "$LINK")"
    [ -n "$PREV" ] && launch "$PREV" && echo "running: $PREV"
    ;;
*)
    sed -n 2,17p "$0"; exit 2
    ;;
esac

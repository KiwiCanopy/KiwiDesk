---
title: SketchyBar Integration
description: Build a spaces widget with KiwiDesk events,
  window icons, and click-to-focus.
---

# SketchyBar

The flagship integration: a live spaces widget with click to
focus, window icons per space, and layout-aware styling.

## How the bridge works

KiwiDesk never triggers sketchybar events itself. Instead, you
write a hook in your `init.lua` that listens to KiwiDesk events
and calls `sketchybar --trigger <custom-event>` via
`KiwiDesk.exec`. Your sketchybar items subscribe to that custom
event and update when it fires.

```
KiwiDesk event → init.lua hook → sketchybar --trigger custom-event
                                      ↓
                            sketchybar item script runs
                            (queries get_state, updates display)
```

This decouples the two processes: sketchybar's script runs in
its own Lua sandbox, outside the app watchdog and main-thread
restrictions.

> **Wedged daemon → runaway triggers.**
> `sketchybar --trigger` normally exits in milliseconds. If the
> sketchybar daemon is absent or wedged, the trigger blocks instead
> — and because these hooks fire on *every* KiwiDesk event,
> unbounded fire-and-forget would let thousands of stuck `--trigger`
> processes pile up (re-parented to launchd, some alive for hours),
> measurably loading the scheduler.
>
> `KiwiDesk.exec` bounds this automatically: each trigger gets a
> 30 s default `timeout` and identical in-flight commands are
> deduped, so even a permanently wedged daemon leaves **at most
> one** stuck child per distinct trigger, reaped every 30 s (see
> [`KiwiDesk.exec`](../lua-reference.md#kiwideskexec)). KiwiDesk
> also warns in its log once more than 20 children are outstanding.
>
> If you hit a pile-up from an older config (or a hard-wedged
> daemon), clear the clients and restart the daemon:
>
> ```sh
> pkill -f "sketchybar --trigger"    # clients only, not the daemon
> brew services restart sketchybar
> ```

## Events you can subscribe to

Every event below fires whenever KiwiDesk's state changes. Hook
any of them to keep sketchybar in sync:

| Event | Lua arguments | Fires when |
|---|---|---|
| `space_change` | `space_id`, `mode` | A KiwiDesk space switches |
| `layout_change` | `space_id`, `mode` | Layout mode changes on a space |
| `focus_change` | `window_id`, `app`, `bundle_id` | Focused window changes |
| `monitor_change` | `monitor_count` | Monitors connect or disconnect |
| `native_space_change` | `native_space`, `monitor` | A macOS Desktop switches on some screen (`monitor` 1 is the main screen) |
| `window_created` | `window_id`, `app`, `space`, `reason`, `bundle_id` | A managed window appears (`new`/`returned`/`restored`) |
| `window_destroyed` | `window_id`, `app`, `space`, `reason`, `bundle_id` | A managed window disappears (`closed`/`minimized`/`hidden`/`vanished`) |
| `window_moved_to_space` | `window_id`, `app`, `from`, `to`, `bundle_id` | See caveats |

**Caveats:**

- `window_created` and `window_destroyed` track the *visible
  window set*, not app lifecycle — deminiaturizing and macOS
  Desktop switches also fire them. Filter on the `reason`
  argument to ignore the artifacts (`vanished`/`returned`
  bursts on every Mission Control round-trip). If you do
  filter, keep a `native_space_change` handler that re-queries
  state: a window closed while its Desktop was off-screen was
  already emitted as `vanished` and never gets a corrective
  `closed`.
- `space` in Lua callbacks is always a string (the space id).
  A window on an unknown space receives `""` (empty string
  instead of nil, so the argument list doesn't truncate). In
  the CLI JSON event stream, the key is `space_id` and the
  value is `null` for unknown spaces.
- `window_moved_to_space` fires only on explicit
  `move_to_space` commands with a different target;
  bulk operations like profile loads stay silent.

## Minimal recipe

A simple space label + layout mode display:

```lua
KiwiDesk.on("space_change", function(space_id, mode)
    KiwiDesk.exec(
        "sketchybar --trigger kiwi_space_change "
        .. "SPACE=" .. space_id .. " MODE=" .. mode)
end)

KiwiDesk.on("focus_change", function(window_id, app)
    KiwiDesk.exec(
        "sketchybar --trigger kiwi_focus APP='"
        .. app .. "'")
end)

-- macOS Desktop indicator (Mission Control number). With
-- "Displays have separate Spaces" on, secondary screens report
-- their own switches too — filter on the main screen so the
-- indicator tracks the Desktop that selects profiles:
KiwiDesk.on("native_space_change", function(desktop, monitor)
    if monitor ~= 1 then return end
    KiwiDesk.exec(
        "sketchybar --trigger kiwi_desktop DESKTOP="
        .. desktop)
end)

-- Window icons stay fresh even when focus doesn't change.
-- Reason-filtered: Desktop-switch bursts (vanished/returned)
-- spawn no processes; the native_space_change handler above
-- already refreshes on the round-trip.
for _, event in ipairs({
    "window_created", "window_destroyed",
}) do
    KiwiDesk.on(event, function(id, app, space, reason)
        if reason == "vanished" or reason == "returned" then
            return
        end
        KiwiDesk.exec(
            "sketchybar --trigger kiwi_space_change")
    end)
end
KiwiDesk.on("window_moved_to_space", function()
    KiwiDesk.exec(
        "sketchybar --trigger kiwi_space_change")
end)
```

In your `sketchybarrc`:

```sh
sketchybar --add event kiwi_space_change
sketchybar --add item kiwi_space left
sketchybar --set kiwi_space \
    script="sketchybar --set kiwi_space \
      label=\"\$SPACE (\$MODE)\"" \
    --subscribe kiwi_space kiwi_space_change
```

## Full spaces widget

A complete, production-ready widget with window icons, click
to focus per space, and smart app icon display.

### Architecture overview

The widget creates one item per space, pre-allocates window
icon slots beneath each, and polls state via
`kiwidesk get_state | jq` on every `kiwidesk_update` event. A
cold-start watchdog polls until the first successful read, then
goes event-driven.

### SbarLua item script

Add this to your sketchybar config in a new file (e.g.,
`items/kiwidesk_spaces.lua`) and require it in your main
config:

```lua
-- =============================================================
-- KIWIDESK SPACES WIDGET
-- =============================================================
-- SbarLua handle. This script uses `SBAR` throughout; alias it
-- to whatever your config uses (the SbarLua default global is
-- `sbar`):
local SBAR = require("sketchybar")

-- Binary path: absolute, like JQ below. sketchybar is spawned by
-- launchd with a minimal PATH that usually lacks
-- /opt/homebrew/bin, so a bare "kiwidesk" would not resolve here
-- even though the cask installs it there. Point this at your
-- clone instead if you built from source.
local KIWIDESK = "/opt/homebrew/bin/kiwidesk"
local JQ = "/opt/homebrew/bin/jq"

-- Optional: load an icon map (app name → icon character).
-- This example uses sketchybar-app-font. Define it yourself
-- or comment out if you have your own icon scheme.
-- local icon_map = require("helpers.icon_map")

local function kiwidesk_cmd(args)
    return "'" .. KIWIDESK .. "' " .. args
end

-- =============================================================
-- STATE & ITEM CREATION
-- =============================================================
local spaces_store = {}
local space_item_list = {}
local has_data = false
local space_names = { "1", "2", "3", "4", "5", "6" }
local current_focused_space = "1"

for _, space_key in ipairs(space_names) do
    local space = SBAR.add("item", "space." .. space_key, {
        position = "left",
        icon = { string = space_key },
        label = { drawing = false },
        drawing = true,
    })

    table.insert(space_item_list, space.name)

    local win_items = {}
    spaces_store[space_key] = {
        item = space,
        win_items = win_items,
    }

    local function on_click()
        os.execute(
            kiwidesk_cmd(
              "focus_space " .. space_key)
        )
    end

    space:subscribe("mouse.clicked", on_click)

    -- Pre-allocate 5 window item slots per space
    for i = 1, 5 do
        local win_item = SBAR.add(
            "item",
            "space." .. space_key .. ".win." .. i,
            {
                position = "left",
                icon = { drawing = false },
                label = {
                    string = "",
                    font = {
                        family = "sketchybar-app-font",
                        style = "Regular",
                        size = 14.0,
                    },
                    padding_left = 2,
                    padding_right = 2,
                },
                drawing = false,
            }
        )

        table.insert(space_item_list, win_item.name)
        table.insert(win_items, win_item)

        win_item:subscribe("mouse.clicked", on_click)
    end
end

-- =============================================================
-- UPDATE: QUERY STATE & REFRESH DISPLAY
-- =============================================================
local function update_spaces()
    local handle = io.popen(
        kiwidesk_cmd("get_state")
            .. " 2>/dev/null | " .. JQ .. " -r "
            .. "'.active_space, \"---SPACES---\", "
            .. "(.spaces[] | \"\\(.id):\\(.focused):"
            .. "\\(.windows | join(\",\"))\"), "
            .. "\"---WINDOWS---\", "
            .. "(.windows[] | \"\\(.id):\\(.app):"
            .. "\\(.floating)\")' 2>/dev/null"
    )
    if not handle then
        return
    end

    local active_space = handle:read("*l")
    if not active_space or active_space == "" then
        handle:close()
        return
    end

    local line = handle:read("*l")
    if line ~= "---SPACES---" then
        handle:close()
        return
    end

    has_data = true

    -- Parse spaces: id:focused_window:window1,window2,...
    local spaces = {}
    line = handle:read("*l")
    while line and line ~= "---WINDOWS---" do
        local id, focused_win, windows_str =
            line:match("([^:]+):([^:]*):(.*)")
        if id then
            local window_ids = {}
            if windows_str and windows_str ~= "" then
                for win_id in windows_str:gmatch("([^,]+)") do
                    table.insert(window_ids, tonumber(win_id))
                end
            end
            spaces[id] = {
                focused = tonumber(focused_win),
                windows = window_ids
            }
        end
        line = handle:read("*l")
    end

    -- Parse windows: id:app:floating
    local windows = {}
    line = handle:read("*l")
    while line do
        local id, app, floating =
            line:match("([^:]+):([^:]+):([^:]+)")
        if id and app then
            windows[tonumber(id)] = {
                app = app,
                floating = (floating == "true")
            }
        end
        line = handle:read("*l")
    end
    handle:close()

    current_focused_space = active_space

    -- Update each space and its window items
    for _, space_key in ipairs(space_names) do
        local w = spaces[space_key]
        local is_focused = (space_key == active_space)
        local space_data = spaces_store[space_key]

        if space_data then
            space_data.item:set({
                icon = {
                    color = is_focused and 0xffffffff
                        or 0xff888888
                }
            })

            local win_count = 0
            if w and w.windows and #w.windows > 0 then
                for _, win_id in ipairs(w.windows) do
                    local win = windows[win_id]
                    if win and win_count < 5 then
                        win_count = win_count + 1
                        local win_item =
                            space_data.win_items[win_count]

                        -- Use your icon_map here, or a plain
                        -- app abbreviation:
                        local icon = (win.app or ""):sub(1, 1)

                        local icon_color = is_focused
                            and 0xffffffff or 0xff888888
                        if is_focused and
                           w.focused == win_id then
                            icon_color = 0xff00ff00  -- green
                        end

                        win_item:set({
                            label = {
                                string = icon,
                                color = icon_color,
                            },
                            drawing = true,
                        })
                    end
                end
            end

            -- Hide unused window slots
            for i = win_count + 1, 5 do
                space_data.win_items[i]:set({
                    drawing = false
                })
            end
        end
    end
end

-- =============================================================
-- EVENT SUBSCRIPTION & COLD-START WATCHDOG
-- =============================================================
SBAR.add("event", "kiwidesk_update")

local event_item = SBAR.add("item", { drawing = false })
event_item:subscribe("kiwidesk_update", function()
    update_spaces()
end)

-- Initial update
update_spaces()

-- Self-heal: on a cold start (sketchybar loads before the
-- KiwiDesk socket is ready, e.g., a reload KiwiDesk triggers
-- while loading init.lua), the initial update fails silently.
-- Poll every 2 seconds until the first successful read, then
-- stop and go event-driven.
local watchdog = SBAR.add("item", {
    drawing = false,
    update_freq = 2
})
watchdog:subscribe("routine", function()
    if has_data then
        watchdog:set({ update_freq = 0 })
    else
        update_spaces()
    end
end)
```

### Hooks in init.lua

Wire up the events to trigger sketchybar updates:

```lua
-- Fire kiwidesk_update on all relevant events.
-- native_space_change is not optional: a window closed while
-- its Desktop was off-screen never gets a corrective event,
-- so the Mission Control round-trip must re-query (see the
-- caveats above).
for _, event in ipairs({
    "space_change",
    "layout_change",
    "focus_change",
    "native_space_change",
    "window_created",
    "window_destroyed",
    "window_moved_to_space",
}) do
    KiwiDesk.on(event, function()
        KiwiDesk.exec(
            "sketchybar --trigger kiwidesk_update"
        )
    end)
end
```

> **Keep your hooks in init.lua under GUI-managed settings**
>
> When the Settings app takes ownership of your config
> (adopting it into `gui.json`), only the *managed* parts of
> `init.lua` go inert — tiling settings, keybindings, window
> rules. `KiwiDesk.on(...)` event hooks are not managed: they
> keep running from `init.lua` on every reload, and `init.lua`
> stays the only place they can live. Don't delete your
> sketchybar hooks because "the GUI owns the config now" —
> that silently kills the bar.

### Cold-start race condition

If sketchybar loads items conditionally (e.g., only when
KiwiDesk is running) and its item loader fires before
KiwiDesk's config process reaches the event loop, the initial
`update_spaces()` call in the item script will fail (the socket
isn't ready). Add a grace period to your loader:

```sh
sleep 1 && sketchybar --add item kiwidesk_spaces right
```

Or use the watchdog above, which polls until the first
successful read.

> **io.popen inside sketchybar's SbarLua**
>
> The sketchybar widget script runs in sketchybar's own Lua
> process, not inside KiwiDesk's. sketchybar bundles its own
> Lua (SbarLua), separate from KiwiDesk's embedded 5.5 VM, and
> it is a normal unrestricted runtime — so `io.popen` is fully
> available. Inside KiwiDesk's Lua VM, `io.popen` is disabled
> to prevent blocking the main thread — use `KiwiDesk.exec`
> with a callback instead (see [Lua
> reference](../lua-reference.md)).

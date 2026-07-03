# Configuring KiwiDesk

KiwiDesk is configured through a single Lua file:

```
~/.config/KiwiDesk/init.lua
```

It is created with a commented starter template on first
launch and re-read on `KiwiDesk reload_config`. The embedded
interpreter is **Lua 5.5** with the full standard library.

Two safety rails apply to all Lua code:

- Any single call into the VM is aborted after **500 ms** —
  an accidental `while true do end` cannot freeze KiwiDesk.
- A callback (event handler or keybinding) that errors or
  times out is **disabled** and logged; everything else keeps
  working until the next `reload_config`.

## Layouts & Gaps

```lua
-- The first argument is a SPACE (virtual workspace)
-- identifier — a number or a name, never a monitor. Every
-- space defaults to "bsp".
-- Modes: bsp | stack | scrolling | monocle | grid | floating
KiwiDesk.set_mode(1, "stack")
KiwiDesk.set_mode("music", "floating")

-- One value for all gaps...
KiwiDesk.set_gap_global(10)
-- ...or per space (0 = fullscreen feel):
KiwiDesk.set_gap_override("browser", 0)
```

Spaces are identified by **strings or numbers** — `1` and
`"1"` are the same space, `"code"` and `"Code"` are not.
Monitors never carry a layout themselves: windows live in
spaces, and spaces are mapped to monitors (see
`space_monitor_map` below).

### Per-layout tuning

```lua
-- BSP
bsp.set_strategy("shortest_side")  -- or "alternating"
bsp.set_ratio(0.5)                 -- first split share

-- Master/Stack
stack.set_master_count(1)
stack.set_master_ratio(0.6)
stack.promote()                    -- focused window -> master
stack.demote()                     -- focused window -> stack

-- Scrolling (PaperWM style)
scroll.set_width(800)              -- fixed column width
scroll.set_anchor("center")        -- center | left | right
scroll.set_speed(250)              -- animation ms

-- Grid
grid.set_type("dynamic")           -- dynamic | rigid
grid.set_fill_empty_space(true)
grid.set_split_direction("horizontal")
grid.set_dimensions(3, 2)          -- rigid: columns, rows
```

### When windows run out of space

No layout ever shrinks a window below `min_window_size`.
When a zone gets too crowded, downsizing stops and the
overflow **cascades vertically**: offset 40 pt downward per
window, so every title bar stays visible and clickable.
There is no horizontal (side-reveal) stacking — overflow is
always resolved top-to-bottom via title bars.

The stack layout degrades gradually, per zone: as many
windows as still fit keep their full size, and only the
remainder collapses into a cascade at the bottom of the
column (last window fully visible, the ones above it showing
their title bars). Only when not even one full window fits
does the whole zone cascade. If the screen is too narrow to
give both zones `min_window_size`, the split is abandoned
entirely and all windows cascade over the whole usable area.

For a cascade to read correctly, upper windows must sit
*behind* lower ones. KiwiDesk restores this z-order whenever
a window crosses the master/stack boundary (drag swap,
directional `swap`, `stack.promote` / `stack.demote`).
Focusing a window still raises it to the front — that
override is deliberate and lasts until the next boundary
crossing re-stacks the zone.

## Window Rules

```lua
-- Windows that always float. "App" matches every window of
-- the app; "App:Title" matches when the title contains the
-- fragment. Dialogs, sheets, and picture-in-picture windows
-- float automatically.
float_rules = { "Calculator", "Finder:Get Info" }

-- New windows of these apps go to a fixed space:
app_rules = {
    ["Spotify"] = "music",
    ["Mail"]    = "mail",
}
```

## Keybindings

```lua
KiwiDesk.bind("cmd+alt+left", function()
    KiwiDesk.focus("left")
end)
KiwiDesk.bind("cmd+alt+f", function()
    KiwiDesk.make_floating()
end)
```

Modifiers: `cmd`, `alt`/`opt`, `ctrl`, `shift`. Keys: letters,
digits, `left/right/up/down`, `space`, `return`, `tab`,
`escape`, `f1`–`f12`, and common punctuation.

Hotkeys use the Carbon API: macOS filters them before they
reach any app, and KiwiDesk never needs the Input Monitoring
permission.

### Modal modes

Define vim-style modes; only the active mode's bindings fire:

```lua
KiwiDesk.define_mode("resize", {
    ["h"]      = function() KiwiDesk.resize("x", -50) end,
    ["l"]      = function() KiwiDesk.resize("x", 50) end,
    ["j"]      = function() KiwiDesk.resize("y", 50) end,
    ["k"]      = function() KiwiDesk.resize("y", -50) end,
    ["escape"] = function() KiwiDesk.switch_mode("default") end,
})

KiwiDesk.bind("ctrl+alt+r", function()
    KiwiDesk.switch_mode("resize")
end)
```

## Events

Subscribe to state changes (see also
[integrations](integrations.md)):

```lua
KiwiDesk.on("space_change", function(space_id, mode)
    os.execute(
        "sketchybar --trigger space_change SPACE="
        .. space_id)
end)
```

| Event | Lua arguments |
|---|---|
| `space_change` | `space_id`, `mode` |
| `layout_change` | `space_id`, `mode` |
| `focus_change` | `window_id`, `app` |
| `monitor_change` | `monitor_count` |

## Profiles & Monitors

```lua
-- Save/load named profiles (layout modes + all settings):
KiwiDesk.save_profile("Developer Rig")
KiwiDesk.load_profile("Developer Rig")
```

Profiles remember the monitor fingerprints they were saved
with. When displays change, KiwiDesk loads the profile with
the exact same monitors; failing that, one saved for the same
*number* of monitors; failing that, it keeps a transient state
and flags the profile as dirty.

Fallback chains for disconnects (per-space beats per-monitor):

```lua
monitor_fallback = {
    ["LG 27"]   = { "Built-in", "Dell 24" },
    ["Dell 24"] = { "Built-in" },
}

space_monitor_map = {
    ["1"] = { "LG 27", "Built-in" },
    ["3"] = { "Dell 24", "LG 27", "Built-in" },
}
```

## Animations, Sleep & Wake

```lua
KiwiDesk.enable_animations(true)
KiwiDesk.set_animation_duration(250)  -- ms, clamped 50-1000

KiwiDesk.enable_wake_restore(true)
KiwiDesk.set_wake_restore_delay(1500) -- ms after wake
```

## Debugging

```lua
KiwiDesk.debug_log("hello from init.lua")
local state = KiwiDesk.get_state()   -- table
print(state.active_space)
```

Typo'd a function name? KiwiDesk logs
`unknown KiwiDesk function 'focsu' — see KiwiDesk.help()`
instead of crashing your config.

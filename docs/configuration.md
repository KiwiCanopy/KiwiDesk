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

Tiling respects the menu bar and the Dock. If the menu bar
is set to auto-hide (System Settings > Control Center), its
strip is reclaimed automatically and only your configured
gaps remain at the top. On MacBooks with a notch, the camera
housing row stays reserved — macOS does not allow regular
windows there.

Spaces are identified by **strings or numbers** — `1` and
`"1"` are the same space, `"code"` and `"Code"` are not.
Monitors never carry a layout themselves: windows live in
spaces, and spaces are mapped to monitors (see
`space_monitor_map` below).

### How inactive spaces hide their windows

Switching virtual spaces hides the other spaces' tiled
windows the same way
[AeroSpace does](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces):
they are parked in the bottom-right corner of their screen
with only a few pixels peeking in (macOS refuses fully
offscreen windows). They return to their tiles when their
space becomes active — instantly by default; see
`set_space_animation` under Animations. Focusing a hidden
window (cmd+tab) pulls its space forward automatically. Floating windows —
including picture-in-picture — are never stashed and stay
visible across all virtual spaces.

**Minimizing** a window removes it from its space entirely.
Restoring it from the Dock opens it in the virtual space you
are on at that moment (an `app_rules` entry for its app still
wins), just like a new window — it does not pull you back to
the space it was minimized from.

With **multiple monitors**, arrange your displays so no
monitor sits directly right of or below another one's
bottom-right corner, or the parked windows peek onto the
neighbor. This is the same constraint AeroSpace documents —
see their
[proper monitor arrangement guide](https://nikitabobko.github.io/AeroSpace/guide#proper-monitor-arrangement);
KiwiDesk solves hiding in a similar fashion, so the same
arrangements work.

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
-- Overflow: "cascade_overflow" (default) keeps as many full
-- windows as fit and cascades the rest at the bottom;
-- "cascade_all" cascades the whole zone.
stack.set_overflow_style("cascade_overflow")

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

### Where new windows land

Every layout takes the same `new_window_placement` values —
`"first"`, `"last"`, `"before_focused"`, `"after_focused"` —
describing where a new window enters the space's window
order. Only the default differs per layout:

- **BSP** `after_focused` — the new window splits the
  focused window's region.
- **Master/Stack** `first` — dwm-style: the new window
  becomes master, the last master slides into the stack.
  Prefer a calm master? `"last"` appends to the bottom of
  the stack instead.
- **Scrolling** `after_focused` — the new column opens next
  to the one you are working in (PaperWM behavior).
- **Grid** `last` — appending keeps every existing cell in
  place.

```lua
stack.set_new_window_placement("last")
bsp.set_new_window_placement("after_focused")
scroll.set_new_window_placement("after_focused")
grid.set_new_window_placement("last")

-- Per-space override, beats the layout default (like
-- set_gap_override): mail space collects new windows at
-- the end no matter the layout.
KiwiDesk.set_new_window_placement_override("mail", "last")
```

### Mouse resizing

Resizing a tiled window with the mouse adjusts the layout the
same way the `resize` command does, applied when you release:
neighbors give or take the space. What changes depends on the
layout — Master/Stack maps width changes to the master ratio
(pull the stack wider and the master shrinks), BSP steers its
split ratio toward the dragged side, Scrolling adjusts the
column width. Axes a layout has no parameter for (stack
heights, grid, monocle) animate back into place. Floating
windows resize freely.

```lua
-- "layout" (default) or "snap_back" (always revert):
KiwiDesk.set_mouse_resize("snap_back")
```

The layout follows the size the window actually reached when
you release. If you flick faster than a (slow) app resizes
its window and release mid-motion, only the distance the
window managed to follow is applied.

Only edges **shared with a neighbor** trade space — pulling
a window's outer, screen-side edge has nobody to trade with
and snaps back.

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
does the whole zone cascade. Prefer the old all-or-nothing
behavior? `stack.set_overflow_style("cascade_all")` cascades
the entire zone as soon as it overflows. If the screen is
too narrow to give both zones `min_window_size`, the split
is abandoned entirely and all windows cascade over the whole
usable area regardless of the style.

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
```

Panels and overlays that live above the normal window layer
(e.g. Ghostty's quick terminal) also float automatically, no
rule needed. Detection is re-checked as windows come and go,
so a window that reported wrong metadata while its app was
still launching corrects itself instead of staying tiled. A
manual `make_floating` override is never reverted by these
re-checks.

```lua

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
| `native_space_change` | `native_space` (desktop number) |

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

Profiles live as JSON files in `~/.config/kiwidesk/profiles/`
and are meant to be readable (and hand-editable — reload with
`load_profile`). Keys mirror the Lua API: the command name
with the `set_` verb stripped, grouped by namespace —
`set_gap_override` becomes `gap.override`, `bsp.set_ratio`
becomes `layout.bsp.ratio`:

```jsonc
{
  "fingerprints": ["Built-in Retina Display:1728x1117"],
  "monitor_count": 1,
  "name": "Desk One",
  "saved_at": "2026-07-04T12:00:00Z",
  "settings": {
    "drag": { "show_drop_zone": true, "show_ghost": true },
    "gap": {
      "global": {
        "inner": { "horizontal": 20, "vertical": 20 },
        "outer": {
          "top": 20, "bottom": 20, "left": 20, "right": 20
        }
      },
      "override": {}              // per space id
    },
    "layout": {
      "bsp": {
        "new_window_placement": "after_focused",
        "ratio": 0.5,
        "strategy": "shortest_side"
      },
      "grid": { "columns": 3, "rows": 2, "type": "dynamic",
                "fill_empty_space": true,
                "split_direction": "horizontal",
                "new_window_placement": "last" },
      "scroll": { "anchor": "center", "width": 800,
                  "new_window_placement": "after_focused" },
      "stack": { "master_count": 1, "master_ratio": 0.6,
                 "overflow_style": "cascade_overflow",
                 "new_window_placement": "first" }
    },
    "min_window_size": 300,
    "new_window_placement_override": {}  // per space id
  },
  "space_modes": { "1": "stack", "2": "bsp" }
}
```

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

### Native macOS Spaces (Mission Control)

KiwiDesk's spaces above are *virtual* workspaces, independent
of Mission Control. On top of that, each native macOS Space
(desktop) can carry its own profile:

```lua
KiwiDesk.bind_profile_to_native_space(1, "Developer Rig")
KiwiDesk.bind_profile_to_native_space(2, "Creator Studio")
```

When you switch desktops (Ctrl+arrow, Mission Control, …),
KiwiDesk loads the bound profile — its virtual workspaces,
layouts, and settings. Desktops without a binding keep
whatever profile is active. `native_space` is the desktop
number as Mission Control counts them (1-based; fullscreen
apps don't count). Unsure which number you're on? Check
`KiwiDesk get_state` (field `native_space`), or subscribe to
the `native_space_change` event.

KiwiDesk never moves windows between native Spaces — windows
stay on their desktop, and KiwiDesk manages the ones on the
desktop you're looking at.

Each desktop also remembers which *virtual* space it was
showing: switch away and back, and you land on the same
virtual space with the same windows hidden. A desktop you
haven't visited yet starts on the first virtual space.

## Animations, Sleep & Wake

```lua
KiwiDesk.enable_animations(true)
KiwiDesk.set_animation_duration(250)  -- ms, clamped 50-1000

-- Virtual space switches snap instantly by default: flying
-- many windows in from the hiding corner at once needs one
-- blocking AX call per window per frame, which stutters on
-- slow apps. Opt in if you like the effect anyway:
KiwiDesk.set_space_animation(true)

KiwiDesk.enable_wake_restore(true)
KiwiDesk.set_wake_restore_delay(1500) -- ms after wake
```

### Quit & restart

Quitting KiwiDesk saves the current arrangement — window
order per virtual space, focus, and the active space — and
restores it on the next launch, so tiles do not shuffle
across restarts. This works within one login session (macOS
window ids reset on logout/reboot; after that, windows are
re-tiled fresh). Crashes restore from the last autosave (30 s
interval) instead.

## Extras

### Per-desktop keybinds (profiles + modes)

Profiles carry layouts and tiling settings, **not**
keybindings — binds in `init.lua` are global and survive
every profile swap. To get "global binds, overridden per
native desktop" anyway, combine modal modes with the
`native_space_change` event. Only the active mode's bindings
fire, so build each desktop's mode by merging your shared
binds with its overrides:

```lua
-- Shared binds, present in every mode:
local common = {
    ["cmd+alt+1"] = function()
        KiwiDesk.focus_virtual_space(1)
    end,
    ["cmd+alt+left"] = function()
        KiwiDesk.focus("left")
    end,
    -- ...
}

local function mode(overrides)
    local merged = {}
    for k, v in pairs(common) do merged[k] = v end
    for k, v in pairs(overrides) do merged[k] = v end
    return merged
end

-- Desktop 2 overrides cmd+alt+m, inherits the rest:
KiwiDesk.define_mode("desk1", mode({}))
KiwiDesk.define_mode("desk2", mode({
    ["cmd+alt+m"] = function()
        KiwiDesk.set_mode("monocle")
    end,
}))

KiwiDesk.on("native_space_change", function(n)
    KiwiDesk.switch_mode(n == 2 and "desk2" or "desk1")
end)
KiwiDesk.switch_mode("desk1")
```

Pair it with `bind_profile_to_native_space` (see above) and
each desktop gets its own layouts *and* its own keybinds.

## Debugging

```lua
KiwiDesk.debug_log("hello from init.lua")
local state = KiwiDesk.get_state()   -- table
print(state.active_space)
```

Typo'd a function name? KiwiDesk logs
`unknown KiwiDesk function 'focsu' — see KiwiDesk.help()`
instead of crashing your config.

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

## The Settings app and the managed block

You can edit everything below from the menu bar **Settings…**
window instead of by hand. When you save, the app rewrites a
delimited region of `init.lua`:

```lua
-- >>> KiwiDesk managed block (edit in the app, not by hand) >>>
KiwiDesk.set_gap_global(10)
-- ...generated settings, modes, and keybindings...
-- <<< KiwiDesk managed block <<<
```

Anything you write **outside** that region is preserved across
saves. If the app finds custom Lua it can't represent with its
visual controls, it opens the integrated Lua editor for the
whole file instead of risking your code. From there you can keep
editing raw Lua, or click **Adopt into the GUI** to import your
current gaps, layouts, and rules into a fresh managed block —
your previous file is kept verbatim as a commented backup, and
keybindings (which can't be recovered from executed Lua) are
re-added from the Keybindings tab. The editor's own
state (keybinding actions, mode icons) is mirrored to
`~/.config/KiwiDesk/gui.json`; delete that file to reset the
GUI to what `init.lua` currently declares. Custom keybinding
Lua is stored there and runs on reload, so treat `gui.json`
with the same trust as `init.lua` — don't import one from an
untrusted source.

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

-- Per-edge control: pass a table instead of a number.
-- Missing keys default to 10. Both setters accept it.
KiwiDesk.set_gap_global({
    top = 4, bottom = 8, left = 12, right = 12,
    inner_horizontal = 6, inner_vertical = 6,
})

-- Windows below this width or height fall back to the
-- Overlap Stack instead of shrinking further (pt).
KiwiDesk.set_min_window_size(300)
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
`space_monitor_map` below). You can rename a space in place from
the Settings app's **Spaces** tab; the rename follows the id
everywhere it is used — its layout mode, app rules, monitor
map, and any keybindings that target it.

### How inactive spaces hide their windows

Switching virtual spaces hides the other spaces' tiled
windows the same way
[AeroSpace does](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces):
they are parked in the bottom-right corner of their screen
with only a few pixels peeking in (macOS refuses fully
offscreen windows). They return to their tiles when their
space becomes active — instantly by default; see
`animations.set_on_space_change` under Animations. Focusing a hidden
window (cmd+tab) pulls its space forward automatically. Floating windows —
including picture-in-picture — are never stashed and stay
visible across all virtual spaces.

Sending a window elsewhere with `move_to_virtual_space` makes
it that space's focused window, so the first time you switch
there it is the window you land on — even without `_and_follow`.

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
scroll.set_slot_size(0)            -- slot size along the scroll
                                   -- axis. 0 = auto (1100px column
                                   -- horizontal, 80% of available
                                   -- height vertical); a number =
                                   -- px; "NN%" = fraction of the
                                   -- available axis (minus bar/gaps)
scroll.set_anchor("center")        -- center (any orientation), or
                                   -- an edge: left|right horizontal,
                                   -- top|bottom vertical
scroll.set_speed(250)              -- animation ms
scroll.set_orientation("horizontal")  -- horizontal: columns
                                   -- scroll left/right.
                                   -- vertical: rows scroll up/down

-- Grid
grid.set_type("dynamic")           -- dynamic | rigid
grid.set_fill_empty_space(true)
grid.set_split_direction("horizontal")
grid.set_dimensions(3, 2)          -- rigid: columns, rows
```

### App Bar

The **app bar** lists every window in the current space — for
layouts where windows can hide each other (**monocle**) or
scroll off-screen (**scrolling**) — so you always see what's
there. Click an item to focus its window; drag to reorder.

Its look is **global**: set it once with `app_bar.set_*` and
every layout's bar shares it. Each layout then decides only
whether it shows a bar and, if it wants, **overrides** any
individual field just for itself with `<layout>.set_app_bar_*`.

```lua
-- Global look — the shared baseline for every bar.
app_bar.set_thickness(32)          -- strip depth (pt), carved
                                   -- out of the layout so bar
                                   -- and windows never overlap
app_bar.set_style("pills")         -- pills | segments | underline
app_bar.set_position("top")        -- default edge (see below)

-- Per layout: turn the bar on (default) and, optionally,
-- override a field. Unset overrides inherit the global value.
monocle.set_app_bar_enabled(true)
scroll.set_app_bar_enabled(true)
scroll.set_app_bar_style("segments")  -- scrolling only; monocle
                                      -- keeps the global pills
```

**Orientation** decides which focus axis cycles through the
windows, and with it which edges the bar may sit on. Both
monocle and scrolling have one:

```lua
-- horizontal (default): focus("left"/"right") steps through
-- the windows; the bar sits on top/bottom. vertical:
-- focus("up"/"down") cycles; the bar sits on left/right and
-- stacks the letters vertically (icon on top). A position that
-- doesn't fit the orientation is logged and falls back to that
-- orientation's default edge (top / left).
monocle.set_orientation("horizontal")
scroll.set_orientation("horizontal")
```

Position is resolved per layout: `app_bar.set_position` (or a
per-layout `set_app_bar_position` override) is clamped to the
layout's own orientation.

Items appear in window order and are always **equal-sized**:
`item_size` pt along the bar (width on horizontal bars,
height on vertical ones). Left at `0` (the default), each
`content` mode gets a sensible standard — a compact square
for `icon`, wider once text is shown. Whatever the source,
the size is clamped: at least the icon square (icons never
clip), at most a quarter of the bar (single items never
balloon).

Items that don't fit the strip **scroll** instead of
shrinking: the bar follows the focused window as you cycle,
and clickable arrows appear over the ends that hide more
items, each click shifting the bar by one slot. Names
truncate (ellipsis) only when they genuinely don't fit their
slot; with `icon_and_name`, only the name shrinks, the icon
always survives. Clicking an item focuses its window (the
panel never steals key focus); hovering swaps the item's
background to the hover color — the already-active item
ignores clicks and shows no hover.

Adjacent windows of the same app collapse into **one item**
wearing a count badge (`group_adjacent_windows`, on by
default); same-app windows that are not adjacent stay
separate. Clicking a grouped item focuses its first window
and the group **expands** — its members widen out into
individual items (overflow just scrolls as usual), so any
member can be picked directly. Focus leaving the group
collapses it again. Items can also be **dragged** along the
bar to reorder the windows: a collapsed group moves as a
whole, an expanded member moves alone.

```lua
app_bar.set_style("pills")     -- pills | segments | underline
app_bar.set_active_style("highlight")  -- highlight | gap
app_bar.set_item_size(0)  -- pt; 0 (default) = standard
                              -- size per content mode
app_bar.set_item_gap(6)        -- pt between items
app_bar.set_content("icon_and_name")  -- icon | name |
                                          -- icon_and_name
app_bar.set_group_adjacent_windows(true)  -- collapse
                                              -- same-app runs
app_bar.set_font_size(0)   -- 0 (default) = auto: text
                               -- scales with bar_thickness;
                               -- any positive value pins it
app_bar.set_corner_radius(8)
```

- **pills** — rounded floating badges, `item_gap` apart.
- **segments** — one continuous strip divided into slots
  (an `item_gap` > 0 inserts separators).
- **underline** — names on one shared translucent box, the
  most minimal look.
- `active_style = "gap"` doesn't highlight the focused
  window's item — it leaves the slot **empty**, so the hole
  marks the active window. Works with every style.

Colors take `#RRGGBB` / `#RRGGBBAA` like the drag visuals.
The defaults are kiwi-themed: cream text in translucent
shell-brown boxes; the active item turns flesh-green while
its box stays brown. The **highlight** is one color with a
style-dependent shape: a ring around the active pill, an
accent bar on the window-facing edge of the active segment,
or the underline itself.

```lua
app_bar.set_text_color("#F2EBD9")
app_bar.set_box_color("#8B5E3C66")
app_bar.set_active_text_color("#4E9F3D")
app_bar.set_active_box_color("#8B5E3C66")
app_bar.set_highlight_color("#4E9F3D")
-- Hover feedback on clickable items: a lighter translucent
-- green by default, deliberately a shade off the highlight.
app_bar.set_hover_color("#6DBF5B80")
app_bar.set_hover_text_color("#F2EBD9")
-- The strip behind everything (default fully transparent):
app_bar.set_background_color("#00000000")
-- The count badge on grouped items:
app_bar.set_group_badge_color("#FF3B30")
app_bar.set_group_badge_text_color("#FFFFFF")
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

### Drag & drop rearranging

Dragging a tiled window over another window's slot and
releasing swaps the two; dropping anywhere else snaps the
window back. While you drag, KiwiDesk shows two visuals:

- **Ghost**: the dragged window's own slot — where it snaps
  back, and where the displaced window would move.
- **Drop zone**: the slot under the window's center, i.e.
  the window a drop would swap with.

Each visual has an on/off switch plus an independently
toggle-able border and fill with configurable colors
(`#RRGGBB`, or `#RRGGBBAA` for translucency), thickness,
and alignment (`"inside"` or `"outside"` relative to the slot).
The defaults are kiwi-themed: the ghost is flesh-green
filled with a shell-brown border, the drop zone the inverse.

```lua
drag.set_ghost_enabled(true)
drag.set_ghost_border(true)
drag.set_ghost_border_thickness(5)
drag.set_ghost_border_alignment("inside")
drag.set_ghost_border_color("#8B5E3C")
drag.set_ghost_fill(true)
drag.set_ghost_fill_color("#4E9F3D40")  -- 25% alpha

drag.set_drop_zone_enabled(true)
drag.set_drop_zone_border(true)
drag.set_drop_zone_border_thickness(5)
drag.set_drop_zone_border_alignment("inside")
drag.set_drop_zone_border_color("#4E9F3D")
drag.set_drop_zone_fill(true)
drag.set_drop_zone_fill_color("#8B5E3C40")

-- Corner rounding of both visuals; tune it to match the
-- window corners of your macOS release (default 16).
drag.set_corner_radius(16)
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
also float automatically, no rule needed. Detection is
re-checked as windows come and go, so a window that reported
wrong metadata while its app was still launching corrects
itself instead of staying tiled. A manual `make_floating`
override is never reverted by these re-checks.

**Ghostty's quick terminal** goes one step further: it is
not managed at all — no space assignment, no window events.
Even a floating window belongs to a space, and since macOS
shows the quick terminal over *every* space, focusing it
would drag you to whichever space it was first seen on. It
can take focus freely; KiwiDesk simply pretends it does not
exist.

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

Modifiers: `cmd`/`command`, `alt`/`opt`/`option`,
`ctrl`/`control`, `shift`. Keys: letters, digits,
`left/right/up/down`, `space`, `return`, `tab`, `escape`,
`f1`–`f12`, and punctuation. Punctuation accepts both the
symbol and a word name, so `";"` and `"semicolon"` are the
same key — likewise `comma`/`,`, `period`/`.`, `slash`/`/`,
`backslash`/`\`, `minus`/`-`, `equal`/`=`,
`leftbracket`/`[`, `rightbracket`/`]`, `grave`/`` ` ``,
`quote`/`'`. The Settings app's shortcut recorder writes the
long forms (`command`, `option`, `semicolon`, …) for
readability; every alias round-trips.

Hotkeys use the Carbon API: macOS filters them before they
reach any app, and KiwiDesk never needs the Input Monitoring
permission. Left and right modifiers are treated as the same
key (Carbon can't distinguish them without Input Monitoring).

### Conflict detection

The Settings app's Shortcuts tab flags any row whose combo
duplicates another row in the same mode, or a reserved macOS
shortcut, with a persistent ⚠️ next to that row; hover it for a
tooltip naming the clash. This indicator always reflects the
current bindings, live, with no action needed to see it.

On top of that, KiwiDesk shows a dismissible in-app banner the
moment a conflict is introduced: right after you record a
clashing shortcut in the Shortcuts tab, or after adopting a
hand-written config, or after saving from the raw Lua editor
finds one or more conflicts in the result. The banner names
every current conflict. With exactly one:

```
Shortcut for "Close" is conflicting with the macOS
shortcut "Close Window".
```

With more than one, a bulleted summary:

```
Several shortcuts are conflicting:
– "First" with "Second"
– "Second" with "First"
```

The banner clears itself once the last conflict is fixed (or
can be dismissed early with its own close button). It does not
appear on app launch, when Settings is simply opened, on Load
Profile, or on a normal visual-editor Save — those already
reflect any conflict through the persistent ⚠️, and showing the
banner there would be redundant with the action that actually
created it.

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

An optional third argument sets a menu bar indicator for the
mode — an SF Symbol name or a flat emoji. While the mode is
active, the KiwiDesk status item swaps to it:

```lua
KiwiDesk.define_mode("resize", { --[[ bindings ]] },
    { icon = "arrow.left.and.right" })
KiwiDesk.define_mode("service", { --[[ bindings ]] },
    { icon = "⚙️" })
```

The default mode (`KiwiDesk.bind`) never takes an icon — it
always shows the standard KiwiDesk glyph. The Settings app
reflects this by hiding the icon picker while the default mode
is selected. An icon set on the default mode by hand (e.g. in
directly-edited profile JSON) is simply ignored and never shown.

## Events

Subscribe to state changes (see also
[integrations](integrations.md)):

```lua
KiwiDesk.on("space_change", function(space_id, mode)
    KiwiDesk.exec(
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
| `window_created` | `window_id`, `app`, `space` |
| `window_destroyed` | `window_id`, `app`, `space` |
| `window_minimized` | `window_id`, `app`, `space` |
| `window_moved_to_space` | `window_id`, `app`, `from`, `to` |

The window lifecycle events fire even when focus does not
change (a background window opening or closing), so status
bars stay current without polling. `space` is always the
space the window lives in — for the gone-events, the one it
disappeared from, even when that space is not active. A
minimize fires only `window_minimized`, never
`window_destroyed`. In the CLI event stream the key is
`space_id` (matching `space_change`) and an unknown space is
JSON `null`; the Lua callback receives `""` instead, since a
positional `nil` would truncate the argument list.

`window_moved_to_space` fires on an explicit
`move_to_virtual_space` (with or without follow) when the
target differs from the window's current space. Bulk
reassignments — profile loads, session restore — stay
silent. JSON keys: `from_space_id` (null if unknown) and
`to_space_id`.

Two caveats: `window_created` / `window_destroyed` also fire
when windows *appear to* come and go — deminiaturizing a
window surfaces as `window_created`, and switching native
macOS Spaces makes every managed window on the old desktop
vanish from the accessibility tree (a burst of
`window_destroyed`) and reappear on return (a burst of
`window_created`). Treat the events as "the visible window
set changed", not as app lifecycle.

## External Commands

Config callbacks run on KiwiDesk's main thread — a shell
command that waits synchronously there would freeze window
management, animations, and the menu bar. External commands
therefore always run in the background.

### `KiwiDesk.exec(command [, callback])`

**Expects:** `command` — a string, run via `/bin/sh -c`, so
pipes, quoting, `&&`, and `$PATH` lookups work exactly as in
a terminal. `callback` — an optional Lua function; if given,
it is called once the command has exited, with:

| Callback argument | Type | Meaning |
|---|---|---|
| `code` | number | exit code (`0` = success) |
| `stdout` | string | everything written to stdout |
| `stderr` | string | everything written to stderr |

**Does:** starts the command in the background and returns
immediately — KiwiDesk never waits for it. Returns the
child's pid (a number), or `nil` when the command could not
be started. If the config reloads before the command
finishes, the callback is dropped silently. The child's
`PATH` gets `/opt/homebrew/bin` and `/usr/local/bin`
appended, so Homebrew tools (`sketchybar`, `borders`, …)
resolve even when KiwiDesk was launched from Finder — GUI
apps inherit launchd's minimal `PATH`, not your shell's.

**Example:**

```lua
-- Fire and forget:
KiwiDesk.exec("sketchybar --reload")

-- Read a command's output via the callback:
KiwiDesk.exec("defaults read -g AppleInterfaceStyle",
    function(code, out, err)
        dark = (code == 0 and out:match("Dark") ~= nil)
    end)
```

### `os.execute(command)` — asynchronous in KiwiDesk

**Expects:** a command string, like standard Lua. Calling it
with no argument keeps its stdlib meaning ("is a shell
available?") and returns `true`.

**Does:** forwards the command to `KiwiDesk.exec` and returns
`true` **immediately** — it does *not* wait, and the return
value says nothing about whether the command succeeded. When
you need the exit code or output, use `KiwiDesk.exec` with a
callback instead.

**Example:**

```lua
-- Fine: fire-and-forget side effect.
os.execute("open -a Spotify")

-- Wrong: the file is NOT guaranteed to exist yet here.
os.execute("touch /tmp/marker")
-- do_something("/tmp/marker")
```

### `io.popen(command)` — disabled

**Expects:** n/a — any call is rejected.

**Does:** returns `nil` plus an explanatory message instead
of a file handle. Reading a child's output synchronously
cannot be done without blocking the app; `KiwiDesk.exec`
with a callback delivers the same output asynchronously.

**Example:**

```lua
-- Instead of: local h = io.popen("pmset -g batt")
KiwiDesk.exec("pmset -g batt", function(code, out)
    battery_info = out
end)
```

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
      "monocle": { "orientation": "horizontal",
                   "bar": { "enabled": true,
                            "position": "top",
                            "style": "pills",
                            "item_size": 0 } },
      "scroll": { "anchor": "center", "slot_size": 0,
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

You can also author `space_monitor_map` visually: in the
Settings app's **Canvas** tab, drag a space from the palette
onto a monitor to pin it there. Drops are saved to `init.lua`
on the next Save and survive a reload. (`monitor_fallback`
stays Lua-only for now.)

### Native macOS Spaces (Mission Control)

KiwiDesk's spaces above are *virtual* workspaces, independent
of Mission Control. On top of that, each native macOS Space
(desktop) can carry its own profile:

```lua
KiwiDesk.bind_profile_to_native_space(1, "Developer Rig")
KiwiDesk.bind_profile_to_native_space(2, "Creator Studio")
```

The **Canvas** tab lists each native Space with a profile
dropdown, and you can also drag a profile chip onto a Space to
bind it. Bindings save to `init.lua` and take effect when that
Space next activates.

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
-- Animation duration for every spring-animated move (runtime
-- only, not saved in a profile). scroll.set_speed shares it.
animations.set_duration(250)          -- ms, clamped 50-1000

-- Per-trigger animation toggles. An "off" trigger snaps
-- instantly: the un-animated path drops the app's
-- EnhancedUserInterface around a size→position→size AX set, so
-- the frame lands in one pass instead of the app running its
-- own move animation. This is reliable on most apps; a few
-- grid-snapping apps still clamp an instant *resize*.

-- Virtual space switches: flying many windows in from the
-- hiding corner at once stutters on slow apps, so off by
-- default. Opt in if you like the effect anyway:
animations.set_on_space_change(false)  -- default false

-- The layout slide as focus moves within a Scrolling space:
animations.set_on_scrolling(true)      -- default true

-- Window resizes (split-ratio changes, mouse-resize settle):
animations.set_on_window_resize(true)  -- default true

-- Swapping two tiles:
animations.set_on_window_swap(true)    -- default true

-- The layout reflow when a window opens or closes, the mode
-- switches, or a gap / layout parameter changes:
animations.set_on_relayout(true)       -- default true

KiwiDesk.enable_wake_restore(true)
KiwiDesk.set_wake_restore_delay(1500) -- ms after wake
```

`on_space_change` governs KiwiDesk's own **virtual-space**
transitions only. The native macOS desktop slide (three-finger
swipe, Ctrl+←/→) is the OS's own animation — KiwiDesk cannot
turn it off; use System Settings › Accessibility › Display ›
Reduce Motion for that.

> **Profiles own these toggles.** Like every other tiling
> setting, `animations.*` is saved in a profile. When a profile
> is bound to a native macOS Space
> (`bind_profile_to_native_space`), switching to that Space
> loads the profile and **replaces** the live settings — so the
> `animations.*` calls in `init.lua` apply only until a bound
> profile activates. To make a toggle stick on a bound Space,
> set it and re-save that profile (or edit the profile JSON).

> The old `KiwiDesk.set_space_animation(bool)` and
> `KiwiDesk.set_animation_duration(ms)` still work as deprecated
> aliases for `animations.set_on_space_change` and
> `animations.set_duration`.

### Quit & restart

Quitting KiwiDesk saves the current arrangement — window
order per virtual space, focus, and the active space — and
restores it on the next launch, so tiles do not shuffle
across restarts. After the restore, KiwiDesk lands on the
virtual space of the window that has focus *right now*,
falling back to the space that was active at quit. This
works within one login session (macOS window ids reset on
logout/reboot; after that, windows are re-tiled fresh).
Crashes restore from the last autosave (30 s interval)
instead.

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

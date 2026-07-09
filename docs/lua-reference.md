---
title: Lua Reference
description: The complete init.lua / config API — every setting
  in expects → does → example form.
---

# Lua Reference

KiwiDesk is configured through a single Lua file:

```
~/.config/KiwiDesk/init.lua
```

It is created with a commented starter template on first launch
and re-read on `KiwiDesk reload_config`. The embedded
interpreter is **Lua 5.5** with the full standard library.

Three safety rails apply to all Lua code:

- Any single call into the VM is aborted after **500 ms** —
  an accidental `while true do end` cannot freeze KiwiDesk.
- A callback (event handler or keybinding) that errors or
  times out is **disabled** and logged; everything else keeps
  working until the next `reload_config`.
- A typo'd function name on `KiwiDesk` or a layout table
  (`scroll.set_width(…)` instead of
  `scroll.set_slot_size(…)`) does **not** abort the config:
  the call becomes a no-op that logs a did-you-mean hint,
  and everything below it still runs. During a config load
  the typo is also reported in the menu bar's **Config
  Issues** window, so it cannot pass silently.

## Settings app vs init.lua

The Settings window lets you edit layouts, gaps, and keybindings
visually. The app stores its own settings in
`~/.config/KiwiDesk/gui.json` plus profile JSON files and applies
them directly. **Saving never rewrites `init.lua`**: the file is
yours alone, for event hooks and custom Lua. For the full GUI
workflow, see the [user guide](user-guide.md).

## Navigation & Movement

The verbs you bind to shortcuts to move focus and windows
around. Direction arguments are `"left"`, `"right"`, `"up"`,
or `"down"`.

### focus

**Expects:** a direction (`"left"`, `"right"`, `"up"`, or
`"down"`).

**Does:** moves keyboard focus to the neighboring window in
that direction, following the active layout's geometry. In
monocle and scrolling layouts the axis cycles through the
space's windows (see the layout's orientation).

**Example:**

```lua
KiwiDesk.focus("left")
```

### swap

**Expects:** a direction (`"left"`, `"right"`, `"up"`, or
`"down"`).

**Does:** swaps the focused window with its neighbor in that
direction, reordering the flat window array — the two windows
trade slots in the layout.

**Example:**

```lua
KiwiDesk.swap("right")
```

### focus_space

**Expects:** a space identifier (number or string).

**Does:** switches to that virtual space, hiding the current
space's tiled windows and revealing the target's.

**Example:**

```lua
KiwiDesk.focus_space(2)
KiwiDesk.focus_space("mail")
```

### move_to_space

**Expects:** a space identifier.

**Does:** moves the focused window to that space **without
following** it — you stay on the current space. The moved
window becomes the target space's focused window, so the first
time you switch there it is the window you land on.

**Example:**

```lua
KiwiDesk.move_to_space("mail")
KiwiDesk.move_to_space(3)
```

### move_to_space_and_follow

**Expects:** a space identifier.

**Does:** moves the focused window to that space **and**
switches you there with it.

**Example:**

```lua
KiwiDesk.move_to_space_and_follow("mail")
KiwiDesk.move_to_space_and_follow(3)
```

## Layouts & Gaps

### set_mode

**Expects:**

- A space identifier (number or string).
- A layout mode: `bsp`, `stack`, `scrolling`, `monocle`, `grid`,
  or `floating`.

**Does:** sets the layout mode for the space. Every space
defaults to `bsp`.

**Example:**

```lua
KiwiDesk.set_mode(1, "stack")
KiwiDesk.set_mode("music", "floating")
```

### set_gap_global

**Expects:**

- A number (points), or a table with keys: `top`, `bottom`,
  `left`, `right`, `inner_horizontal`, `inner_vertical` (all
  optional; missing keys default to 10).

**Does:** sets gaps for all spaces. The gaps are carved out of
the layout, so the bar and windows never overlap. If the menu bar
is set to auto-hide, its strip is reclaimed automatically. On
MacBooks with a notch, the camera housing stays reserved.

**Example:**

```lua
-- One value for all gaps:
KiwiDesk.set_gap_global(10)

-- Per-edge control (missing keys default to 10):
KiwiDesk.set_gap_global({
    top = 4, bottom = 8, left = 12, right = 12,
    inner_horizontal = 6, inner_vertical = 6,
})
```

### set_gap_override

**Expects:**

- A space identifier.
- A number or per-edge table, same shape as `set_gap_global`.

**Does:** overrides the global gap for one space. Pass `0` for a
fullscreen feel.

**Example:**

```lua
KiwiDesk.set_gap_override("browser", 0)
KiwiDesk.set_gap_override("editor", {
    top = 20, bottom = 20, left = 20, right = 20
})
```

### set_min_window_size

**Expects:** a number (points).

**Does:** windows below this width or height
[cascade](#when-windows-run-out-of-space) instead of shrinking
further.

**Example:**

```lua
KiwiDesk.set_min_window_size(300)
```

### set_resize_step

**Expects:** a number (points).

**Does:** sets the global magnitude the **Grow** / **Shrink**
keybindings nudge the layout by (default 50). The Shortcuts
catalog authors those bindings as `resize("x", ±step)` from this
value, and importing a config reads a recovered magnitude back
into it. Does not move any window on its own — it only sizes the
Grow/Shrink presets — so it takes effect the next time such a
binding fires.

**Example:**

```lua
KiwiDesk.set_resize_step(75)
```

### Space Identity

Spaces are identified by **strings or numbers** — `1` and `"1"`
are the same space, `"code"` and `"Code"` are not. Monitors never
carry a layout themselves; windows live in spaces, and spaces are
mapped to monitors (see *Profiles & Monitors* below). You can
rename a space in place from the Settings app's **Spaces**
section; the rename follows the id everywhere it is used — its
layout mode, app rules, monitor pins, and any keybindings.

### How inactive spaces hide their windows

Switching virtual spaces hides the other spaces' tiled windows the
same way [AeroSpace
does](https://nikitabobko.github.io/AeroSpace/guide#emulation-of-virtual-workspaces):
they are parked in the bottom-right corner of their screen with
only a few pixels peeking in (macOS refuses fully offscreen
windows). They return to their tiles when their space becomes
active — instantly by default; see `animations.set_on_space_change`
under Animations. Focusing a hidden window (cmd+tab) pulls its
space forward automatically. Floating windows — including
picture-in-picture — are never stashed and stay visible across all
virtual spaces.

Sending a window elsewhere with
[`move_to_space`](#move_to_space) makes it that
space's focused window, so the first time you switch there it is
the window you land on — even without `_and_follow`.

**Minimizing** a window removes it from its space entirely.
Restoring it from the Dock opens it in the virtual space you are
on at that moment (an `app_rules` entry for its app still wins),
just like a new window — it does not pull you back to the space it
was minimized from.

With **multiple monitors**, arrange your displays so no monitor
sits directly right of or below another one's bottom-right corner,
or the parked windows peek onto the neighbor. This is the same
constraint AeroSpace documents — see their [proper monitor
arrangement guide](https://nikitabobko.github.io/AeroSpace/guide#proper-monitor-arrangement);
KiwiDesk solves hiding similarly, so the same arrangements work.

## Per-Layout Tuning

### bsp.set_strategy

**Expects:** `"shortest_side"` or `"alternating"`.

**Does:** sets the BSP split strategy.

**Example:**

```lua
bsp.set_strategy("shortest_side")
```

### bsp.set_ratio

**Expects:** a number between 0 and 1 (default 0.5).

**Does:** sets the first window's share of a BSP split.

**Example:**

```lua
bsp.set_ratio(0.5)
```

### bsp.set_strategy_override

**Expects:**

- A space identifier.
- A strategy string.

**Does:** overrides the global BSP strategy for one space. Unset
spaces inherit the global value.

**Example:**

```lua
bsp.set_strategy_override("3", "alternating")
```

### bsp.set_ratio_override

**Expects:**

- A space identifier.
- A ratio number.

**Does:** overrides the global BSP ratio for one space.

**Example:**

```lua
bsp.set_ratio_override("3", 0.6)
```

### stack.set_master_count

**Expects:** a positive integer.

**Does:** sets how many windows are in the master zone.

**Example:**

```lua
stack.set_master_count(1)
```

### stack.set_master_ratio

**Expects:** a number between 0 and 1.

**Does:** sets the master zone's share of the space's width.

**Example:**

```lua
stack.set_master_ratio(0.6)
```

### stack.promote

**Expects:** nothing.

**Does:** moves the focused window to the master zone.

**Example:**

```lua
stack.promote()
```

### stack.demote

**Expects:** nothing.

**Does:** moves the focused window out of the master zone into the
stack.

**Example:**

```lua
stack.demote()
```

### stack.set_overflow_style

**Expects:** `"cascade_overflow"` (default) or `"cascade_all"`.

**Does:** when the stack overflows, `cascade_overflow` keeps as
many full windows as fit and cascades the rest at the bottom;
`cascade_all` cascades the whole zone.

**Example:**

```lua
stack.set_overflow_style("cascade_overflow")
```

### stack.set_new_window_placement

**Expects:** `"first"`, `"last"`, `"before_focused"`, or
`"after_focused"`.

**Does:** sets where new windows enter the stack's order. For
stack, the default is `"first"` (dwm-style: new window becomes
master).

**Example:**

```lua
stack.set_new_window_placement("last")
```

### stack.set_master_count_override

**Expects:**

- A space identifier.
- A count number.

**Does:** overrides the global master count for one space.

**Example:**

```lua
stack.set_master_count_override("3", 2)
```

### stack.set_master_ratio_override

**Expects:**

- A space identifier.
- A ratio number.

**Does:** overrides the global master ratio for one space.

**Example:**

```lua
stack.set_master_ratio_override("3", 0.7)
```

### stack.set_overflow_style_override

**Expects:**

- A space identifier.
- An overflow style string.

**Does:** overrides the global overflow style for one space.

**Example:**

```lua
stack.set_overflow_style_override("3", "cascade_all")
```

### scroll.set_slot_size

**Expects:** a number (px), `"NN%"` (fraction of available axis),
or `0` (auto, default).

**Does:** sets the size of columns (horizontal) or rows (vertical)
in scrolling layouts. Auto is 1100px horizontal, 80% of available
height vertical.

**Example:**

```lua
scroll.set_slot_size(0)            -- auto
scroll.set_slot_size(400)          -- 400 px
scroll.set_slot_size("50%")        -- half of available
```

### scroll.set_anchor

**Expects:** `"center"` or an edge (`left`/`right` for horizontal,
`top`/`bottom` for vertical).

**Does:** sets the anchor point within the layout.

**Example:**

```lua
scroll.set_anchor("center")
```

### scroll.set_orientation

**Expects:** `"horizontal"` or `"vertical"`.

**Does:** sets the scroll direction. Horizontal: columns scroll
left/right. Vertical: rows scroll up/down.

**Example:**

```lua
scroll.set_orientation("horizontal")
```

### scroll.set_new_window_placement

**Expects:** a placement string (same values as `bsp` above).

**Does:** sets where new windows land. Default is `"after_focused"`
(PaperWM behavior).

**Example:**

```lua
scroll.set_new_window_placement("after_focused")
```

### scroll.set_slot_size_override

**Expects:**

- A space identifier.
- A slot size (same shape as `scroll.set_slot_size`).

**Does:** overrides the global slot size for one space.

**Example:**

```lua
scroll.set_slot_size_override("3", 400)
```

### scroll.set_anchor_override

**Expects:**

- A space identifier.
- An anchor string.

**Does:** overrides the global anchor for one space.

**Example:**

```lua
scroll.set_anchor_override("3", "center")
```

### scroll.set_orientation_override

**Expects:**

- A space identifier.
- An orientation string.

**Does:** overrides the global orientation for one space.

**Example:**

```lua
scroll.set_orientation_override("3", "vertical")
```

### grid.set_type

**Expects:** `"dynamic"` or `"rigid"`.

**Does:** sets the grid layout type.

**Example:**

```lua
grid.set_type("dynamic")
```

### grid.set_fill_empty_space

**Expects:** `true` or `false`.

**Does:** if true, resizes windows to fill empty cells.

**Example:**

```lua
grid.set_fill_empty_space(true)
```

### grid.set_split_direction

**Expects:** `"horizontal"` or `"vertical"`.

**Does:** sets the preferred split direction for new cells.

**Example:**

```lua
grid.set_split_direction("horizontal")
```

### grid.set_dimensions

**Expects:** two positive integers (columns, rows).

**Does:** for rigid grids, locks the layout to this size.

**Example:**

```lua
grid.set_dimensions(3, 2)
```

### grid.set_type_override

**Expects:**

- A space identifier.
- A type string.

**Does:** overrides the global grid type for one space.

**Example:**

```lua
grid.set_type_override("3", "rigid")
```

### grid.set_fill_empty_space_override

**Expects:**

- A space identifier.
- A boolean.

**Does:** overrides the global fill behavior for one space.

**Example:**

```lua
grid.set_fill_empty_space_override("3", false)
```

### grid.set_split_direction_override

**Expects:**

- A space identifier.
- A direction string.

**Does:** overrides the global split direction for one space.

**Example:**

```lua
grid.set_split_direction_override("3", "vertical")
```

### grid.set_dimensions_override

**Expects:**

- A space identifier.
- Two integers (columns, rows).

**Does:** overrides the global dimensions for one space.

**Example:**

```lua
grid.set_dimensions_override("3", 4, 3)
```

### monocle.set_orientation

**Expects:** `"horizontal"` or `"vertical"`.

**Does:** sets the focus axis. Horizontal: `focus("left"/"right")`
cycles through windows; the bar sits on top/bottom. Vertical:
`focus("up"/"down")` cycles; the bar sits on left/right.

**Example:**

```lua
monocle.set_orientation("horizontal")
```

### monocle.set_orientation_override

**Expects:**

- A space identifier.
- An orientation string.

**Does:** overrides the global orientation for one space.

**Example:**

```lua
monocle.set_orientation_override("3", "vertical")
```

## App Bar

The **app bar** lists every window in the current space — for
layouts where windows can hide each other (**monocle**) or scroll
off-screen (**scrolling**) — so you always see what's there. Click
an item to focus its window; drag to reorder.

With **multiple monitors** each display shows its own bar for the
space currently on it, all at once — a bar-hosting space on a
secondary display draws its bar there, not on the main screen.
Dragging an item reorders that display's own space.

Its look is **global**: set it once with `app_bar.set_*` and every
layout's bar shares it. Each layout then decides only whether it
shows a bar and, if it wants, **overrides** any individual field
just for itself.

**Orientation** decides which focus axis cycles through the
windows, and with it which edges the bar may sit on. Position is
resolved per layout: `app_bar.set_position` (or a per-layout
`set_app_bar_position` override) is clamped to the layout's own
orientation.

Items appear in window order and are always **equal-sized**: `item_size`
pt along the bar (width on horizontal bars, height on vertical
ones). Left at `0` (the default), each `content` mode gets a
sensible standard. The size is clamped: at least the icon square
(icons never clip), at most a quarter of the bar.

Items that don't fit the strip **scroll** instead of shrinking: the
bar follows the focused window as you cycle, and clickable arrows
appear over the ends that hide more items. Names truncate only when
they genuinely don't fit their slot; with `icon_and_name`, only the
name shrinks, the icon always survives. Clicking an item focuses
its window; hovering swaps the item's background to the hover color
— the already-active item ignores clicks and shows no hover.

Adjacent windows of the same app collapse into **one item** wearing
a count badge (`group_adjacent_windows`, on by default); same-app
windows that are not adjacent stay separate. Clicking a grouped item
focuses its first window and the group **expands** — its members
widen out into individual items, so any member can be picked
directly. Focus leaving the group collapses it again. Items can also
be **dragged** along the bar to reorder the windows.

### app_bar.set_position

**Expects:** `"top"`, `"bottom"`, `"left"`, or `"right"`
(default `"top"`).

**Does:** sets the default edge for all layout bars. The value is
clamped to the layout's orientation — a horizontal layout keeps
top/bottom, a vertical one left/right — so a position that doesn't
fit is logged and falls back to that orientation's default edge.
Per-layout overrides can change it.

**Example:**

```lua
app_bar.set_position("top")
```

### app_bar.set_thickness

**Expects:** a positive number (points).

**Does:** sets the strip depth, carved out of the layout.

**Example:**

```lua
app_bar.set_thickness(32)
```

### app_bar.set_style

**Expects:** `"pills"`, `"segments"`, or `"underline"`.

**Does:** sets the visual style:
- **pills** — rounded floating badges, `item_gap` apart.
- **segments** — one continuous strip divided into slots.
- **underline** — names on one shared translucent box.

**Example:**

```lua
app_bar.set_style("pills")
```

### app_bar.set_active_style

**Expects:** `"highlight"` or `"gap"`.

**Does:** how the focused window is marked:
- `"highlight"` — color the active item.
- `"gap"` — leave the slot empty, so the hole marks the active
  window.

**Example:**

```lua
app_bar.set_active_style("highlight")
```

### app_bar.set_item_size

**Expects:** a number (points); `0` means auto (default).

**Does:** sets the width (horizontal) or height (vertical) of each
item. Auto picks a sensible default per content mode.

**Example:**

```lua
app_bar.set_item_size(0)
```

### app_bar.set_item_gap

**Expects:** a non-negative number (points).

**Does:** sets the space between items.

**Example:**

```lua
app_bar.set_item_gap(6)
```

### app_bar.set_content

**Expects:** `"icon"`, `"name"`, or `"icon_and_name"`.

**Does:** sets what each item displays.

**Example:**

```lua
app_bar.set_content("icon_and_name")
```

### app_bar.set_font_size

**Expects:** a number (points); `0` means auto (default).

**Does:** if `0`, text scales with bar thickness; any positive
value pins the font size.

**Example:**

```lua
app_bar.set_font_size(0)
```

### app_bar.set_corner_radius

**Expects:** a non-negative number (points).

**Does:** sets the corner rounding of bar items and backgrounds.

**Example:**

```lua
app_bar.set_corner_radius(8)
```

### app_bar.set_group_adjacent_windows

**Expects:** `true` or `false`.

**Does:** if true, collapses adjacent same-app windows into one
item with a count badge.

**Example:**

```lua
app_bar.set_group_adjacent_windows(true)
```

### app_bar.set_text_color

**Expects:** a hex color (`#RRGGBB` or `#RRGGBBAA`).

**Does:** sets the text color (default `#F2EBD9`).

**Example:**

```lua
app_bar.set_text_color("#F2EBD9")
```

### app_bar.set_box_color

**Expects:** a hex color.

**Does:** sets the background box color (default
`#8B5E3C66`, translucent shell-brown).

**Example:**

```lua
app_bar.set_box_color("#8B5E3C66")
```

### app_bar.set_active_text_color

**Expects:** a hex color.

**Does:** sets the text color of the focused item (default
`#4E9F3D`, flesh-green).

**Example:**

```lua
app_bar.set_active_text_color("#4E9F3D")
```

### app_bar.set_active_box_color

**Expects:** a hex color.

**Does:** sets the background box color of the focused item.

**Example:**

```lua
app_bar.set_active_box_color("#8B5E3C66")
```

### app_bar.set_highlight_color

**Expects:** a hex color.

**Does:** sets the highlight (ring on pills, accent bar on
segments, or underline itself).

**Example:**

```lua
app_bar.set_highlight_color("#4E9F3D")
```

### app_bar.set_hover_color

**Expects:** a hex color.

**Does:** sets the hover feedback on clickable items (default
`#6DBF5B80`, light translucent green).

**Example:**

```lua
app_bar.set_hover_color("#6DBF5B80")
```

### app_bar.set_hover_text_color

**Expects:** a hex color.

**Does:** sets the text color during hover.

**Example:**

```lua
app_bar.set_hover_text_color("#F2EBD9")
```

### app_bar.set_background_color

**Expects:** a hex color.

**Does:** sets the strip background (default fully transparent).

**Example:**

```lua
app_bar.set_background_color("#00000000")
```

### app_bar.set_group_badge_color

**Expects:** a hex color.

**Does:** sets the count badge background color.

**Example:**

```lua
app_bar.set_group_badge_color("#FF3B30")
```

### app_bar.set_group_badge_text_color

**Expects:** a hex color.

**Does:** sets the count badge text color.

**Example:**

```lua
app_bar.set_group_badge_text_color("#FFFFFF")
```

### Per-Layout App Bar Overrides

Each bar-hosting layout (monocle, scrolling) can override any
individual bar field for itself. Only these two layouts show a
bar, so only they expose `set_app_bar_*`. Unset fields inherit
the global value. The available overrides are the same setters
prefixed with the layout name:

- `monocle.set_app_bar_enabled`, `monocle.set_app_bar_position`,
  `monocle.set_app_bar_thickness`, etc.
- `scroll.set_app_bar_enabled`, `scroll.set_app_bar_style`, etc.

**Example:**

```lua
monocle.set_app_bar_enabled(true)
scroll.set_app_bar_enabled(true)
scroll.set_app_bar_style("segments")  -- override for scrolling
```

## Where New Windows Land

### set_new_window_placement_override

**Expects:**

- A space identifier.
- A placement value: `"first"`, `"last"`, `"before_focused"`, or
  `"after_focused"`.

**Does:** sets where new windows enter one space's order. Beats the
layout's default.

**Example:**

```lua
KiwiDesk.set_new_window_placement_override("mail", "last")
```

**Layout defaults:**

- **BSP** `after_focused` — the new window splits the focused
  window's region.
- **Master/Stack** `first` — new window becomes master.
- **Scrolling** `after_focused` — opens next to the focused
  column.
- **Grid** `last` — appending keeps existing cells in place.
- **Monocle** `last`.

Each layout also has its own global setter (e.g.
`bsp.set_new_window_placement`, `stack.set_new_window_placement`).

## Drag & Drop Rearranging

Dragging a tiled window over another window's slot and releasing
swaps the two; dropping anywhere else snaps the window back. While
you drag, KiwiDesk shows two visuals:

- **Ghost**: the dragged window's slot — where it snaps back, and
  where the displaced window would move.
- **Drop zone**: the slot under the window's center, i.e. the
  window a drop would swap with.

Each visual has an on/off switch plus an independently toggle-able
border and fill with configurable colors, thickness, and alignment.

### drag.set_ghost_enabled

**Expects:** `true` or `false`.

**Does:** shows or hides the ghost visual.

**Example:**

```lua
drag.set_ghost_enabled(true)
```

### drag.set_ghost_border

**Expects:** `true` or `false`.

**Does:** enables the border on the ghost visual.

**Example:**

```lua
drag.set_ghost_border(true)
```

### drag.set_ghost_border_thickness

**Expects:** a non-negative number (points).

**Does:** sets the border thickness of the ghost.

**Example:**

```lua
drag.set_ghost_border_thickness(5)
```

### drag.set_ghost_border_alignment

**Expects:** `"inside"` or `"outside"`.

**Does:** positions the border inside or outside the slot boundary.

**Example:**

```lua
drag.set_ghost_border_alignment("inside")
```

### drag.set_ghost_border_color

**Expects:** a hex color.

**Does:** sets the ghost border color (default `#8B5E3C`,
shell-brown).

**Example:**

```lua
drag.set_ghost_border_color("#8B5E3C")
```

### drag.set_ghost_fill

**Expects:** `true` or `false`.

**Does:** enables the fill on the ghost visual.

**Example:**

```lua
drag.set_ghost_fill(true)
```

### drag.set_ghost_fill_color

**Expects:** a hex color.

**Does:** sets the ghost fill color (default `#4E9F3D40`,
flesh-green with 25% alpha).

**Example:**

```lua
drag.set_ghost_fill_color("#4E9F3D40")
```

### drag.set_drop_zone_enabled

**Expects:** `true` or `false`.

**Does:** shows or hides the drop zone visual.

**Example:**

```lua
drag.set_drop_zone_enabled(true)
```

### drag.set_drop_zone_border

**Expects:** `true` or `false`.

**Does:** enables the border on the drop zone visual.

**Example:**

```lua
drag.set_drop_zone_border(true)
```

### drag.set_drop_zone_border_thickness

**Expects:** a non-negative number (points).

**Does:** sets the border thickness of the drop zone.

**Example:**

```lua
drag.set_drop_zone_border_thickness(5)
```

### drag.set_drop_zone_border_alignment

**Expects:** `"inside"` or `"outside"`.

**Does:** positions the border inside or outside the slot boundary.

**Example:**

```lua
drag.set_drop_zone_border_alignment("inside")
```

### drag.set_drop_zone_border_color

**Expects:** a hex color.

**Does:** sets the drop zone border color (default `#4E9F3D`,
flesh-green).

**Example:**

```lua
drag.set_drop_zone_border_color("#4E9F3D")
```

### drag.set_drop_zone_fill

**Expects:** `true` or `false`.

**Does:** enables the fill on the drop zone visual.

**Example:**

```lua
drag.set_drop_zone_fill(true)
```

### drag.set_drop_zone_fill_color

**Expects:** a hex color.

**Does:** sets the drop zone fill color (default `#8B5E3C40`,
shell-brown with 25% alpha).

**Example:**

```lua
drag.set_drop_zone_fill_color("#8B5E3C40")
```

### drag.set_corner_radius

**Expects:** a non-negative number (points).

**Does:** sets the corner rounding of both visuals (default 16).

**Example:**

```lua
drag.set_corner_radius(16)
```

## Mouse Resizing

Resizing a tiled window with the mouse adjusts the layout the same
way the `resize` command does, applied when you release: neighbors
give or take the space. What changes depends on the layout —
Master/Stack maps width changes to the master ratio, BSP steers its
split ratio toward the dragged side, Scrolling adjusts the column
width. Axes a layout has no parameter for (stack heights, grid,
monocle) animate back into place. Floating windows resize freely.

Only edges **shared with a neighbor** trade space — pulling a
window's outer, screen-side edge has nobody to trade with and
snaps back.

The layout follows the size the window actually reached when you
release. If you flick faster than a (slow) app resizes its window
and release mid-motion, only the distance the window managed to
follow is applied.

### set_mouse_resize

**Expects:** `"layout"` (default) or `"snap_back"`.

**Does:** sets whether mouse resizes apply the new layout
(`"layout"`) or always revert (`"snap_back"`).

**Example:**

```lua
KiwiDesk.set_mouse_resize("snap_back")
```

## When Windows Run Out of Space

No layout ever shrinks a window below `min_window_size`. When a
zone gets too crowded, downsizing stops and the overflow
**cascades vertically**: offset 40 pt downward per window, so every
title bar stays visible and clickable. There is no horizontal
(side-reveal) stacking — overflow is always resolved top-to-bottom
via title bars.

The stack layout degrades gradually, per zone: as many windows as
still fit keep their full size, and only the remainder collapses
into a cascade at the bottom of the column. Only when not even one
full window fits does the whole zone cascade.

For a cascade to read correctly, upper windows must sit *behind*
lower ones. KiwiDesk restores this z-order whenever a window
crosses the master/stack boundary (drag swap, directional `swap`,
`stack.promote` / `stack.demote`). Focusing a window still raises it
to the front — that override is deliberate and lasts until the next
boundary crossing re-stacks the zone.

## Window Rules

### float_rules

**Expects:** a Lua table of strings (app or app:title matchers).

**Does:** windows matching any entry always float. "App" matches
every window of the app; "App:Title" matches when the title
contains the fragment. Dialogs, sheets, and picture-in-picture
windows float automatically. Detection is re-checked as windows
come and go, so a window that reported wrong metadata while
launching corrects itself. A manual `make_floating` override is
never reverted by these re-checks.

Panels and overlays that live above the normal window layer also
float automatically, no rule needed.

**Ghostty's quick terminal** is not managed at all — no space
assignment, no window events. KiwiDesk simply pretends it does not
exist.

**Example:**

```lua
float_rules = { "Calculator", "Finder:Get Info" }
```

### app_rules

**Expects:** a Lua table mapping app names to space identifiers.

**Does:** new windows of listed apps go to their assigned space.

**Example:**

```lua
app_rules = {
    ["Spotify"] = "music",
    ["Mail"]    = "mail",
}
```

## Making Windows Floating or Tiled

### make_floating

**Expects:** nothing.

**Does:** marks the focused window as floating. It is no longer
tiled and stays visible across all virtual spaces.

**Example:**

```lua
KiwiDesk.make_floating()
```

### make_tiled

**Expects:** nothing.

**Does:** marks the focused window as tiled. It returns to its
space's tiling layout.

**Example:**

```lua
KiwiDesk.make_tiled()
```

### Example: toggle floating

There is no built-in toggle; use `get_state()` to check the focused
window's current state:

**Example:**

```lua
KiwiDesk.bind("cmd+alt+f", function()
    local state = KiwiDesk.get_state()
    if not state.active_space then return end
    local active_space = state.active_space
    local focused_id = nil
    for _, space in ipairs(state.spaces) do
        if space.id == active_space then
            focused_id = space.focused
            break
        end
    end
    if focused_id then
        for _, window in ipairs(state.windows) do
            if window.id == focused_id then
                if window.floating then
                    KiwiDesk.make_tiled()
                else
                    KiwiDesk.make_floating()
                end
                break
            end
        end
    end
end)
```

## Launching Apps

### pull_or_spawn

**Expects:** an app name (e.g., "Zen", "Safari").

**Does:** if the app is already running, focuses its window. If it
is not running, launches a new instance.

**Example:**

```lua
KiwiDesk.bind("ctrl+return", function()
    KiwiDesk.pull_or_spawn("Zen")
end)
```

### spawn_new

**Expects:** an app name.

**Does:** always launches a new instance of the app, even if one is
already running.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+return", function()
    KiwiDesk.spawn_new("Terminal")
end)
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

### Modifiers and Keys

**Modifiers:** `cmd`/`command`, `alt`/`opt`/`option`,
`ctrl`/`control`, `shift`.

**Keys:** letters, digits, `left`, `right`, `up`, `down`,
`home`, `end`, `pageup`, `pagedown`, `space`,
`return`/`enter`, `tab`, `escape`/`esc`, `f1`–`f12`, and
punctuation.

**Punctuation aliases:** both the symbol and the word form work, so
`";"` and `"semicolon"` are the same key. Aliases:
- `comma`/`,`
- `period`/`.`
- `slash`/`/`
- `backslash`/`\`
- `minus`/`-`
- `equal`/`=`
- `leftbracket`/`[`
- `rightbracket`/`]`
- `grave`/`backtick`/`` ` ``
- `quote`/`apostrophe`/`'`
- `return`/`enter`
- `delete`/`backspace`
- `escape`/`esc`

The Settings app's shortcut recorder writes the long forms
(`command`, `option`, `semicolon`, …) for readability; every alias
round-trips.

A combo is any set of modifiers plus **exactly one key**. Multi-key
chords (`cmd+j+k`) are not expressible — Carbon registers modifiers
plus a single key code — so a hand-written combo that doesn't parse
is never registered and the Shortcuts section flags the row with ⚠
*"isn't a recognized shortcut"*.

### Modal Modes

Define vim-style modes; only the active mode's bindings fire:

```lua
KiwiDesk.define_mode("resize", {
    ["h"]      = function() KiwiDesk.resize("x", -50) end,
    ["l"]      = function() KiwiDesk.resize("x", 50) end,
    ["escape"] = function() KiwiDesk.switch_mode("default") end,
})

KiwiDesk.bind("ctrl+alt+r", function()
    KiwiDesk.switch_mode("resize")
end)
```

#### resize

**Expects:**

- An axis: `"x"` or `"y"`.
- A delta (points; positive = grow, negative = shrink).

**Does:** grows or shrinks the focused window. Only applies in bsp,
stack, and scrolling layouts; a no-op in monocle, grid, and
floating. What the `delta` actually adjusts depends on the layout:

- **bsp / stack** — it nudges the split / master ratio, so there
  is no independent width and height today: the `axis` argument
  only scales the step by the screen's width or height, and both
  axes move the same ratio.
- **scrolling** — it adjusts the slot size in real points along
  the layout's own scroll axis (columns for horizontal, rows for
  vertical), regardless of which `axis` you pass — the `x`/`y`
  argument does not steer it.

Prefer a single shrink/enlarge pair (#56).

**Example:**

```lua
KiwiDesk.resize("x", -50)
KiwiDesk.resize("y", 50)
```

#### Mode Icons

An optional third argument to `define_mode` sets a menu bar
indicator — an SF Symbol name or a flat emoji. While the mode is
active, the KiwiDesk status item swaps to it. The default mode
(`KiwiDesk.bind`) never takes an icon — it always shows the
standard KiwiDesk glyph.

**Example:**

```lua
KiwiDesk.define_mode("resize", { --[[ bindings ]] },
    { icon = "arrow.left.and.right" })
KiwiDesk.define_mode("service", { --[[ bindings ]] },
    { icon = "⚙️" })
```

### Config Cascade (Per-Profile Keybindings)

Keybindings resolve through a two-tier cascade, mirroring how
tiling layers (global settings ← profile):

> **The base config is the seed; the profile wins.** The base
> shortcuts (the app's `gui.json`, or your Lua-declared binds
> in a hand-written config) apply first. When the loaded
> profile carries a `"modes"` override, each of its rows
> shadows the base row with the same combo in the same mode;
> everything the profile does not mention stays active.
> Event hooks fire on their event — they are never a cascade
> layer.

The override is **sparse and soft by design**:

- A profile stores only the modes and rows that diverge; a
  profile without a `"modes"` key inherits the base shortcuts
  completely.
- Every base binding the profile doesn't rebind survives — in
  particular your profile-switch shortcut, so a profile can
  never trap you by *omission*. Rebinding the same combo
  differently per profile stays possible.
- Removing a base binding per profile is not expressible:
  deleting an inherited row in the editor just resets it. To
  disable a combo in one profile, rebind it to a no-op action.
  The same applies to a base mode's menu bar icon — a profile
  can *change* it, but clearing it just reverts to the base
  icon.
- Keybindings live in ONE home: the structured config (gui.json +
  profiles) when GUI-managed, or your `init.lua` otherwise —
  never merged. Hand-written binds that evade the managed-
  vocabulary detection are silently unregistered on every reload
  while GUI-managed.

Profiles re-resolve their bindings whenever they apply: on
`load_profile`, on a monitor change, and on a native-Space binding
switch. Switching profiles also returns you to the default key
mode.

## Events

Subscribe to state changes (see also the [recipes](recipes/index.md)):

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

The window lifecycle events fire even when focus does not change (a
background window opening or closing), so status bars stay current
without polling. `space` is always the space the window lives in —
for the gone-events, the one it disappeared from, even when that
space is not active. A minimize fires only `window_minimized`, never
`window_destroyed`. In the CLI event stream the key is `space_id`
(matching `space_change`) and an unknown space is JSON `null`; the
Lua callback receives `""` instead, since a positional `nil` would
truncate the argument list.

`window_moved_to_space` fires on an explicit `move_to_space`
(with or without follow) when the target differs from the window's
current space. Bulk reassignments — profile loads, session restore —
stay silent. JSON keys: `from_space_id` (null if unknown) and
`to_space_id`.

Two caveats: `window_created` / `window_destroyed` also fire when
windows *appear to* come and go — deminiaturizing a window surfaces
as `window_created`, and switching native macOS Spaces makes every
managed window on the old desktop vanish from the accessibility tree
(a burst of `window_destroyed`) and reappear on return (a burst of
`window_created`). Treat the events as "the visible window set
changed", not as app lifecycle.

## External Commands

Config callbacks run on KiwiDesk's main thread — a shell command that
waits synchronously there would freeze window management, animations,
and the menu bar. External commands therefore always run in the
background.

### KiwiDesk.exec

**Expects:**

- `command` — a string, run via `/bin/sh -c`, so pipes, quoting,
  `&&`, and `$PATH` lookups work exactly as in a terminal.
- `callback` — an optional Lua function called once the command
  has exited, with:

| Argument | Type | Meaning |
|---|---|---|
| `code` | number | exit code (`0` = success) |
| `stdout` | string | everything written to stdout |
| `stderr` | string | everything written to stderr |

- `timeout` — an optional number of seconds. If given and the
  command has not exited by then, it receives SIGTERM and the
  callback is still invoked with the termination code.

**Does:** starts the command in the background and returns
immediately — KiwiDesk never waits for it. Returns the child's pid
(a number), or `nil` when the command could not be started. If the
config reloads before the command finishes, the callback is dropped
silently.

**Output cap:** stdout and stderr are each capped at ~1 MB. Output
beyond the cap is still read (so the child never blocks writing), but
the string delivered to the callback is truncated and ends with
`[output truncated at 1 MB]`.

**Quit policy:** exec children are fire-and-forget. When KiwiDesk
exits, running children are re-parented to launchd and finish
naturally — a `sketchybar --notify` hook will complete even if
KiwiDesk quits first. Use `timeout` for commands that must not
outlive a reasonable interval.

The child's `PATH` gets `/opt/homebrew/bin` and `/usr/local/bin`
appended, so Homebrew tools (`sketchybar`, `borders`, …) resolve
even when KiwiDesk was launched from Finder.

**Example:**

```lua
-- Fire and forget:
KiwiDesk.exec("sketchybar --reload")

-- Read a command's output via the callback:
KiwiDesk.exec("defaults read -g AppleInterfaceStyle",
    function(code, out, err)
        dark = (code == 0 and out:match("Dark") ~= nil)
    end)

-- With a 5-second timeout:
KiwiDesk.exec("some-slow-tool", function(code, out, err)
    -- code is non-zero if killed by the watchdog
end, 5)
```

### os.execute

**Expects:** a command string, like standard Lua. Calling it with no
argument keeps its stdlib meaning ("is a shell available?") and
returns `true`.

**Does:** forwards the command to `KiwiDesk.exec` and returns `true`
**immediately** — it does *not* wait, and the return value says
nothing about whether the command succeeded. When you need the exit
code or output, use `KiwiDesk.exec` with a callback instead.

**Example:**

```lua
-- Fine: fire-and-forget side effect.
os.execute("open -a Spotify")

-- Wrong: the file is NOT guaranteed to exist yet here.
os.execute("touch /tmp/marker")
-- do_something("/tmp/marker")
```

### io.popen

**Expects:** n/a — any call is rejected.

**Does:** returns `nil` plus an explanatory message instead of a file
handle. Reading a child's output synchronously cannot be done without
blocking the app; `KiwiDesk.exec` with a callback delivers the same
output asynchronously.

**Example:**

```lua
-- Instead of: local h = io.popen("pmset -g batt")
KiwiDesk.exec("pmset -g batt", function(code, out)
    battery_info = out
end)
```

### os.exit

**Expects:** n/a — any call is a no-op with a log message.

**Does:** calling `os.exit()` from a config file would kill the
KiwiDesk process immediately, including your window layout. It is
stubbed out to prevent accidental or malicious instant app
termination. If you want to restart KiwiDesk use `KiwiDesk service
restart` from a terminal or a keybinding via `KiwiDesk.exec`.

Note that, unlike real `os.exit`, the stub **returns** — code after
the call keeps running. Don't rely on `os.exit()` to halt a script;
use an explicit `return` or `if/else`.

## Startup Scripts

Commands at `init.lua` top level run on load and on reload. See the
External Commands section above for `KiwiDesk.exec` semantics (e.g.,
commands are async, a callback is optional). Any tiling commands at
top level are applied before profiles load, serving as base state.

**Example:**

```lua
-- Set base gaps; these apply before a profile loads.
KiwiDesk.set_gap_global(10)

-- Fire an async command at startup:
KiwiDesk.exec("sketchybar --reload")

-- Subscribe to an event:
KiwiDesk.on("space_change", function(space_id)
    print("Switched to space: " .. space_id)
end)
```

## Profiles & Monitors

### save_profile, load_profile, delete_profile, set_default_profile

**Expects:**

- `save_profile(name)` — a name string; updates if it exists.
- `load_profile(name)` — a name string.
- `delete_profile(name)` — a name string.
- `set_default_profile(name)` — a name string (sets the profile to
  load for this monitor count when no exact match exists).

**Does:**

- `save_profile` persists the current layout (gaps, modes,
  parameters, animations, window positions, and optionally a sparse
  keybinding override).
- `load_profile` switches to the named profile and reconciles spaces
  by name.
- `delete_profile` removes the profile; deleting the last profile of
  a count reverts that count to its built-in Standard.
- `set_default_profile` marks a profile as the fallback for its
  monitor count.

**Example:**

```lua
KiwiDesk.save_profile("Developer Rig")
KiwiDesk.load_profile("Developer Rig")
KiwiDesk.delete_profile("Developer Rig")
KiwiDesk.set_default_profile("Developer Rig")
```

**Profiles are the single source of truth for tiling.** A profile
owns the gaps, per-space layout modes, layout parameters,
animations, mouse-resize behavior, and the space→monitor
assignments — plus, optionally, a **sparse keybinding override**.
The global, shared declarations — keybindings, `app_rules`,
`float_rules`, and profile bindings — live in the app's own
`gui.json` when GUI-managed, or in your hand-written `init.lua`
otherwise.

### set_fallback_space

**Expects:** a space identifier (or `""` to clear back to the first
space).

**Does:** sets where windows land when a profile switch drops their
space. Without an explicit choice (or when the chosen space doesn't
exist in the profile), windows land in the **first space** of the
profile's ordered list.

**Example:**

```lua
KiwiDesk.set_fallback_space("mail")
```

### set_space_icon

**Expects:**

- A space identifier.
- An SF Symbol name, emoji, single character, or `""` to clear.

**Does:** sets a recognition icon next to the space name in the
Spaces list, Monitors cards, and per-space shortcut rows. Icons ride
the profile like every other tiling setting.

**Example:**

```lua
KiwiDesk.set_space_icon("mail", "envelope")
KiwiDesk.set_space_icon("web", "🌐")
KiwiDesk.set_space_icon("chat", "")  -- clear
```

### bind_profile_to_native_space

**Expects:**

- A native space number (desktop number as Mission Control counts them,
  1-based; fullscreen apps don't count).
- A profile name.

**Does:** when you switch to that desktop, KiwiDesk loads the bound
profile — its virtual workspaces, layouts, and settings. Desktops
without a binding keep whatever profile is active. A binding takes
effect when that Space next activates. In a hand-written config the
call lives in `init.lua`; when the config is GUI-managed, bindings
are stored in `gui.json` (`profile_bindings`) and edited in the
Profiles section instead.

**Example:**

```lua
KiwiDesk.bind_profile_to_native_space(1, "Developer Rig")
KiwiDesk.bind_profile_to_native_space(2, "Creator Studio")
```

### Space Reconciliation

**Switching profiles reconciles your spaces.** Explicitly loading a
profile makes its space set authoritative: a space is matched to the
new profile **by name** (not position), so a window in a space whose
name also exists in the new profile stays put — regardless of any
layout difference. A space whose name the new profile doesn't define
is dropped, and any windows it held are forwarded to the profile's
fallback space.

This reconcile happens only on an explicit `load_profile`; automatic
applies on a monitor change or a native-Space binding leave your
spaces untouched.

### Profile Monitor Sets

A profile covers one or more concrete **monitor sets** — each a list
of monitor fingerprints plus the space→monitor pins valid for that
arrangement. Updating a profile while a new combination is connected
teaches it that combination. When displays change, KiwiDesk resolves
in this order:

1. **Exact match** — a profile stores exactly the connected monitors
   → loaded clean.
2. **Count default** — the profile marked `default` for that screen
   count → loaded with the dirty flag.
3. **Built-in Standard** — no saved profile for that count → a built-in
   positional layout composes silently; screens beyond its plan each
   get one monocle space, so no screen is ever blank.

   The Standard only *owns tiling* when the config is GUI-managed: a
   `gui.json` sidecar exists *and* `init.lua` holds no code touching
   the managed vocabulary. With a hand-written — or hybrid — config,
   your Lua-declared tiling stays authoritative and the Standard
   merely steers the space→screen placement.

Every space always resolves to a screen: an explicit fingerprint pin
wins, then the **Main** role (the space follows whatever display is
currently main — dock and undock without stale fingerprints), then
the built-in positional default.

Explicitly loading a profile whose stored sets don't cover the
connected monitors works, but the state loads *dirty* until you
update the profile on this hardware or return to a covered set.

### Profile JSON Format

Profiles live as JSON files in `~/.config/KiwiDesk/profiles/` and are
meant to be readable (and hand-editable — reload with `load_profile`).
Keys mirror the Lua API: the command name with the `set_` verb
stripped, grouped by namespace — `set_gap_override` becomes
`gap.override`, `bsp.set_ratio` becomes `layout.bsp.ratio`.

**Example:**

```jsonc
{
  "name": "Desk One",
  "default": true,            // this count's fallback profile
  "monitor_sets": [
    {
      "monitors": ["Built-in Retina Display:1728x1117"],
      "space_monitor_map": {  // explicit pins only (sparse)
        "2": "Built-in Retina Display:1728x1117"
      }
    }
  ],
  "main_spaces": ["1"],       // follow the main display
  "fallback_space": "1",      // rehome target on switch
  "saved_at": "2026-07-04T12:00:00Z",
  "settings": {
    "drag": {
      "corner_radius": 16,
      "ghost": {
        "enabled": true, "border": true,
        "border_color": "#8B5E3C", "border_thickness": 5,
        "border_alignment": "inside",
        "fill": true, "fill_color": "#4E9F3D40"
      },
      "drop_zone": {
        "enabled": true, "border": true,
        "border_color": "#4E9F3D", "border_thickness": 5,
        "border_alignment": "inside",
        "fill": true, "fill_color": "#8B5E3C40"
      }
    },
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
    "new_window_placement_override": {},  // per space id
    "space": { "icon": { "2": "envelope" } }  // per space id
  },
  "space_modes": { "1": "stack", "2": "bsp" },
  // Optional sparse keybinding override (see Config
  // cascade): only the modes/rows this profile changes.
  // Omit the key entirely to inherit the base shortcuts.
  "modes": [
    {
      "name": "default",
      "bindings": [
        { "combo": "alt+h", "lua": "KiwiDesk.focus(\"left\")",
          "kind": "custom", "label": "" }
      ]
    }
  ]
}
```

### Native macOS Spaces (Mission Control)

KiwiDesk's spaces above are *virtual* workspaces, independent of
Mission Control. On top of that, each native macOS Space (desktop)
can carry its own profile via `bind_profile_to_native_space` (see
above).

When you switch desktops (Ctrl+arrow, Mission Control, …), KiwiDesk
loads the bound profile — its virtual workspaces, layouts, and
settings. Unsure which number you're on? Check `KiwiDesk
get_state` (field `native_space`), or subscribe to the
`native_space_change` event.

KiwiDesk never moves windows between native Spaces — windows stay on
their desktop, and KiwiDesk manages the ones on the desktop you're
looking at.

Each desktop also remembers which *virtual* space it was showing:
switch away and back, and you land on the same virtual space with the
same windows hidden. A desktop you haven't visited yet starts on the
first virtual space.

## Animations, Sleep & Wake

### animations.set_duration

**Expects:** a number (milliseconds, clamped 50–1000).

**Does:** sets the general animation duration for window moves and
layout reflowing. **Persisted per-profile** since issue #51.

**Example:**

```lua
animations.set_duration(250)
```

### animations.set_scroll_speed

**Expects:** a number (milliseconds, clamped 50–1000).

**Does:** sets the scrolling-layout focus-shift speed (independent
knob, also persisted per-profile).

**Example:**

```lua
animations.set_scroll_speed(250)
```

### animations.set_on_space_change

**Expects:** `true` or `false` (default `false`).

**Does:** enables or disables animation when switching virtual spaces.
Off (the default) is faster: flying many windows in from the hiding
corner at once stutters on slow apps. Opt in if you like the effect
anyway.

**Example:**

```lua
animations.set_on_space_change(false)
```

### animations.set_on_scrolling

**Expects:** `true` or `false` (default `true`).

**Does:** enables or disables the layout slide as focus moves within a
Scrolling space.

**Example:**

```lua
animations.set_on_scrolling(true)
```

### animations.set_on_window_resize

**Expects:** `true` or `false` (default `true`).

**Does:** enables or disables animation on window resizes (split-ratio
changes, mouse-resize settle).

**Example:**

```lua
animations.set_on_window_resize(true)
```

### animations.set_on_window_swap

**Expects:** `true` or `false` (default `true`).

**Does:** enables or disables animation when swapping two tiles.

**Example:**

```lua
animations.set_on_window_swap(true)
```

### animations.set_on_relayout

**Expects:** `true` or `false` (default `true`).

**Does:** enables or disables animation on the layout reflow when a
window opens/closes, the mode switches, or a gap/layout parameter
changes.

**Example:**

```lua
animations.set_on_relayout(true)
```

### enable_wake_restore, set_wake_restore_delay

**Expects:**

- `enable_wake_restore(bool)` — `true` or `false`.
- `set_wake_restore_delay(ms)` — a number (milliseconds).

**Does:** when `true`, restores window positions and focus after the
machine wakes from sleep, after the specified delay (default 1500 ms).

**Example:**

```lua
KiwiDesk.enable_wake_restore(true)
KiwiDesk.set_wake_restore_delay(1500)
```

### Animation Cascade

**Profiles own all animation settings.** Like every other tiling
setting, `animations.*` — including the duration knobs — is saved in a
profile. When a profile is bound to a native macOS Space
(`bind_profile_to_native_space`), switching to that Space loads the
profile and **replaces** the live settings — so `animations.*` calls in
`init.lua` apply only until a bound profile activates. To make a value
stick on a bound Space, set it and re-save that profile (or edit the
profile JSON).

### Quit & Restart

Quitting KiwiDesk saves the current arrangement — window order per
virtual space, focus, and the active space — and restores it on the
next launch, so tiles do not shuffle across restarts. After the
restore, KiwiDesk lands on the virtual space of the window that has
focus *right now*, falling back to the space that was active at quit.
This works within one login session (macOS window ids reset on
logout/reboot; after that, windows are re-tiled fresh). Crashes
restore from the last autosave (30 s interval) instead.

On quit or restart, KiwiDesk moves each managed tiled window back onto
the monitor its virtual space is assigned to and staggers them
diagonally within the display's visible area, so every window is
individually findable. Floating windows are left wherever they are.
Because KiwiDesk keeps all managed windows on the single visible native
Space (inactive virtual spaces are parked off-screen at the peek
corner — not on a different native macOS Space), every reachable window
lands there staggered together.

When AX permission is revoked mid-session, KiwiDesk pauses window
management but cannot gather windows — `setFrame` calls return
`kAXErrorAPIDisabled` and are silent no-ops. Windows stay wherever the
WM left them; re-enabling Accessibility in System Settings resumes
management.

## Debugging

### debug_log

**Expects:** a string message.

**Does:** prints the message to the application log (viewable in
Console.app).

**Example:**

```lua
KiwiDesk.debug_log("hello from init.lua")
```

### get_state

**Expects:** nothing.

**Does:** returns a table with the current window and space state.
Fields: `active_space` (current space id or `nil`), `spaces` (array of
space objects), `windows` (array of window objects), `monitor_count`,
`native_space`, `exec_running` (count of `KiwiDesk.exec` children
still running).

Each space object has: `id`, `mode`, `windows` (array of window ids),
`focused` (focused window id or `nil`).

Each window object has: `id`, `app`, `title`, `floating` (boolean).

**Example:**

```lua
local state = KiwiDesk.get_state()
print(state.active_space)
print(state.native_space)

for _, window in ipairs(state.windows) do
    if window.floating then
        print("Floating: " .. window.app)
    end
end
```

### help

**Expects:** nothing.

**Does:** logs all available KiwiDesk commands (for debugging a
typo'd function name).

**Example:**

```lua
KiwiDesk.help()
```

## Recipes

For integration recipes and advanced patterns, see the
[recipes](recipes/index.md).


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
and re-read on `kiwidesk reload_config`. The embedded
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

### What coexists with the Settings app, and what doesn't

Whether the Settings app or `init.lua` owns your configuration
depends on **what your `init.lua` declares** — not merely on
whether the file exists.

**Coexists — stays GUI-managed.** Anything that isn't a setting
runs happily alongside `gui.json`. On first launch KiwiDesk still
seeds the default profile, spaces, and shortcuts, and your code
still runs:

```lua
-- Event hooks, control flow, helpers, print, locals — all fine.
for _, event in ipairs({ "space_change", "focus_change" }) do
  KiwiDesk.on(event, function()
    KiwiDesk.exec("sketchybar --trigger kiwidesk_update")
  end)
end
```

**Makes `init.lua` the owner — Lua-managed.** Declaring any
*setting* hands ownership to the file: KiwiDesk will **not** seed a
`gui.json` over it (that would silently override your Lua), and the
Settings app offers **Adopt into the GUI** instead. Settings are:

- Any `set_*` verb on the `KiwiDesk` table — `set_mode`,
  `set_gap_global`, `set_min_window_size`, …
- Any namespaced layout setter — `bsp.set_ratio_h`,
  `stack.set_master_ratio`, `scroll.set_slot_size`,
  `grid.set_type`, `monocle.*`, `track.*`, `drag.*`, `border.*`,
  `app_bar.*`, `animations.*`, `mouse.*`, `quit.*` — plus
  `border.fit_gaps`.
- Window-rule tables — `app_rules`, `float_rules`, `ignore_rules`.
- Keybindings — `KiwiDesk.bind`, `KiwiDesk.define_mode`,
  `KiwiDesk.bind_profile_to_native_space`.

```lua
-- Any one of these makes init.lua the config owner:
KiwiDesk.set_mode(1, "stack")
bsp.set_ratio_h(0.6)
float_rules = { "com.apple.calculator" }
```

To keep the GUI in charge, put settings like these in the Settings
app (or **Adopt** an existing file), and reserve `init.lua` for
hooks and custom Lua.

## Navigation & Movement

The verbs you bind to shortcuts to move focus and windows
around. Direction arguments are `"left"`, `"right"`, `"up"`,
or `"down"`.

### focus

**Expects:** a direction (`"left"`, `"right"`, `"up"`, or
`"down"`).

**Does:** moves keyboard focus to the neighboring window in
that direction, following the active layout's geometry. In
monocle and scrolling layouts, directions on the layout's
orientation axis follow the window order instead: monocle
cycles (wrapping at the ends), scrolling steps to the
previous/next window and stops at the row's ends — unless
`scroll.set_wrap_focus(true)` is set, which wraps scrolling
focus at the ends too. Cross-axis directions keep the
geometric search. The track layout steps in window order on
both axes: along the axis within the focused track, across it
to the neighboring track (same relative position); both stop
at the ends unless `track.set_wrap_focus(true)` is set, which
wraps within the track along the axis and last ↔ first track
across it.

The search is two-tier: **tiled windows always win**, and only
when no tiled window lies in the pressed direction are the
space's *floating* windows (including floating sticky windows
shown on the space) considered, by their live frames — so a
float parked beside the layout is reachable at the edge, while
tile-to-tile navigation never detours through a hovering
float. On an axis with `wrap_focus` on, the wrap wins over the
float tier — a float past that edge is reachable on the cross
axis only (with a single tiled window there is nothing to wrap
among, so the float is reachable on both axes). Transient
panels (Spotlight-style launchers) and
fullscreen windows are never focus targets. A float parked
*exactly* on a tiled slot shares that tile's center, so no
direction points at it — see Accepted Limitations; click it or
cycle to it instead. `swap` stays tiled-only: a floating
window has no slot to trade.

**Example:**

```lua
KiwiDesk.focus("left")
```

### swap

**Expects:** a direction (`"left"`, `"right"`, `"up"`, or
`"down"`).

**Does:** swaps the focused window with its neighbor in that
direction, reordering the flat window array — the two windows
trade slots in the layout. The neighbor is found the same way
`focus` finds it, including the window-order stepping on a
monocle or scrolling orientation axis and in track spaces
(where a cross-axis swap trades the two windows between their
tracks — the track boundaries stay put). `swap` never wraps at
the ends, even with a wrap-focus toggle on.

**Example:**

```lua
KiwiDesk.swap("right")
```

### focus_space

**Expects:** a space identifier (number or string).

**Does:** switches to that virtual space, hiding the current
space's tiled windows and revealing the target's. Keyboard
focus follows: the target's focused window (or its first
window when none is stamped) is raised and its app activated;
switching to an **empty** space hands focus to the desktop
instead, so keystrokes never keep flowing into a now-hidden
window. If macOS drops the activation, the post-switch settle
(~300 ms) detects the unchanged frontmost app and re-raises
once.

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

If the target space is shown on **another monitor**, a floating
window is re-anchored onto that display — it keeps its
*proportional* position (a bottom-right float stays bottom-right
on a differently-sized screen), clamped inside the target's
usable area. Tiled windows arrive through the layout — except
into a **floating-mode space**, whose layout assigns no frames:
any window moved there is re-anchored the same proportional
way, so it physically arrives on that monitor too.

A quick drag-and-drop of a window onto a Space item in the Space
Bar performs this same move (see the user guide), re-anchoring a
float the same way — the pointer released over the *bar item*,
not at a chosen position. Only when the drag dwells long enough
to **spring** the space open and you place the window yourself
does it stay exactly where you released it.

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

### move_space_to_display

**Expects:** a space identifier, then a display reference — a
**number** (1-based position: `1` is the main display,
`2` the next left-to-right) or a **string** matching a connected
monitor's fingerprint (as printed by `list_monitors`) or name.

**Does:** moves the whole space to that monitor **now** and shows
it there (each monitor shows one space at a time). This is a
runtime move: a later monitor change (dock/undock) re-resolves
placement from the pins, so use `pin_space_to_display` to make it
stick. Creates the space if it does not exist yet. Floating
members travel too: each is re-anchored onto the new monitor,
keeping its relative position.

**Example:**

```lua
KiwiDesk.move_space_to_display("mail", 2)      -- second monitor
KiwiDesk.move_space_to_display(3, "DELL U2723QE:3840x2160")
```

### pin_space_to_display

**Expects:** a space identifier, then a display reference (same
forms as `move_space_to_display`).

**Does:** pins the space to that monitor by the monitor's
fingerprint, so the assignment survives dock/undock — and, when
declared in `init.lua`, a relaunch. Overrides any Main-role
assignment for the space. Creates the space if new.

Under a GUI-managed config the Settings **Canvas** stays the
persistent owner of pins, so a pin set from Lua is a session
override there; under a Lua-managed config the pin persists
because `init.lua` re-runs on launch.

**Example:**

```lua
KiwiDesk.pin_space_to_display("mail", 2)
```

### create_space

**Expects:** a space identifier, and optionally a layout mode
(`"bsp"`, `"stack"`, `"scrolling"`, `"grid"`, `"monocle"`,
`"track"`).

**Does:** brings a space into existence and resolves it onto a
display. Spaces otherwise appear implicitly the first time you
reference one (`focus_space`, `move_to_space`, a keybinding), so
this is mainly for declaring a space — and its mode — up front in
`init.lua`. A no-op beyond the mode set if the space already
exists.

**Example:**

```lua
KiwiDesk.create_space("scratch", "monocle")
```

### delete_space

**Expects:** a space identifier.

**Does:** removes the space after moving its windows to the
fallback space (or the first surviving space), so nothing is
orphaned, and clears the space from the placement pins, Main
role, and per-space settings. Refuses to delete the only space.
Runtime only — a space still declared in `init.lua` or the GUI
config reappears on the next config load.

**Example:**

```lua
KiwiDesk.delete_space("scratch")
```

> **Renaming a space** has no Lua verb by design. Rename in the
> Settings app (which also rewrites every keybinding that targets
> the space and persists the change), or — with a Lua config —
> change the id in `init.lua` and reload. A runtime rename could
> only do a partial, non-persistent remap, so it is deliberately
> omitted.

### move_to_track

**Expects:** `"prev"` or `"next"` (exactly these — no
`previous` alias).

**Does:** in a track-layout space, moves the focused window
into the adjacent track in the sequence (joining it at its
end). The track verbs speak **prev/next**, not compass
directions: tracks form a one-dimensional sequence, and the
same binding keeps working when the axis flips. What that
means on screen:

| Axis | `"prev"` | `"next"` |
|---|---|---|
| `vertical` (columns, default) | the column to the **left** | the column to the **right** |
| `horizontal` (rows) | the row **above** | the row **below** |

Formally: prev = the lower array index (toward the sequence
start), next = the higher. Past the first or last track it
opens a **new** track at that edge — the keyboard way to open
tracks, matching what `own_track` spawning does. Refused when
the space is not in track mode, when `track.set_limit` already
caps the tracks, or when the window already forms the edge
track alone (nothing would change). Never wraps. Focus and
window `swap` keep their
spatial left/right/up/down vocabulary — only the two track
sequence verbs (this and [`track.swap`](#trackswap)) use
prev/next.

**Example:**

```lua
KiwiDesk.move_to_track("next")
```

## Layouts & Gaps

### set_mode

**Expects:**

- A space identifier (number or string).
- A layout mode: `bsp`, `stack`, `scrolling`, `monocle`, `grid`,
  `track`, or `floating`.

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
catalog authors all four per-axis bindings as
`resize("x"|"y", ±step)` from this value, and importing a config
reads a recovered magnitude back into it. Does not move any window on its own — it only sizes the
Grow/Shrink presets — so it takes effect the next time such a
binding fires.

**Example:**

```lua
KiwiDesk.set_resize_step(75)
```

### set_swap_skips_cascade

**Expects:** `true` or `false` (default `true`).

**Does:** a power-user toggle for how a directional `swap`
behaves when the focused window sits in an overflow
[cascade](#when-windows-run-out-of-space). When `true` (the
default), the swap skips the other windows piled with it and
trades with the tiled neighbor *outside* the pile in that
direction — doing nothing when there is none — instead of
reordering the cascade. Set `false` to restore the raw
behavior, where a swap trades with whichever piled window lies
that way. Global (per profile, all spaces); `focus` is never
affected. There is no Settings toggle — a pile is a corner
case, so this lives in config only.

**Example:**

```lua
KiwiDesk.set_swap_skips_cascade(true)
```

### set_float_nudge

**Expects:** `true` or `false` (default `true`).

**Does:** whether toggling a window from tiled to floating gives
it a small nudge toward the screen center. A window keeps its
exact frame when it floats, so without the nudge the toggle looks
like it did nothing; a fixed shove (up to 24 pt, tapering to zero
for a window already near the center) acknowledges the state
change. Fires on the float direction only — `make_floating` and a
`toggle_floating` that lands on floating — never on `make_tiled`,
which already animates a real move back into the layout. The
magnitude is fixed, not scaled by window size, so a maximized
window does not leap across the screen and a tiny one still
moves; the target is always kept fully on screen and clear of the
menu bar and any App/Space Bar. Global (per profile, all spaces);
a niche polish toggle, so it lives in config only, with no
Settings toggle.

**Example:**

```lua
KiwiDesk.set_float_nudge(true)
```

### set_float_scale_on_display_change

**Expects:** `true` or `false` (default `true`).

**Does:** whether a floating window re-anchored across displays
also scales its **size** to keep the same relative footprint. By
default (`true`) a float that crosses to a differently sized
display is scaled by the per-axis ratio of the two displays — a
window that filled half of a 4K screen fills half of a 1080p one
— as well as re-anchored to the same relative spot (bottom-right
stays bottom-right). This keeps an oversized float from arriving
half off-screen: when the target display is smaller, macOS clamps
a too-tall window's height but lets its width overflow the edge,
so keeping the exact size lands the window partly off the screen.
Applies wherever a float crosses displays (move-to-space, moving
a space to another display, a display-change sweep) and to
windows that are floating only because their space is in floating
mode, not just explicitly floated ones. The result is still
confined fully on screen and clear of any App/Space Bar. Set
`false` to keep the exact pixel size across displays instead — a
deliberate multi-monitor choice (screen recording, pixel-matched
capture windows) that accepts the overflow and avoids the slight
aspect-ratio change the per-axis scale introduces between
displays of different aspect ratios (e.g. 16:9 → 16:10). Global
(per profile, all spaces); a power-user knob, so it lives in
config only, with no Settings toggle.

**Example:**

```lua
-- keep a float's exact pixel size across displays
KiwiDesk.set_float_scale_on_display_change(false)
```

### set_resize_feedback

**Expects:** `true` or `false` (default `true`).

**Does:** whether a resize hotkey that cannot act in the active
layout (monocle, grid, a floating space) plays the system alert
sound (#184). The no-op itself is correct — those layouts have
no resize target — but silent failure at the keyboard reads as
"KiwiDesk ignored me"; the beep is the standard macOS answer.
Only hotkey fires cue; the same command over CLI/IPC stays
silent (scripted callers branch on the error JSON). The GUI
twin lives under Shortcuts ▸ Size & float.

**Example:**

```lua
KiwiDesk.set_resize_feedback(false)
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
active — instantly by default; with
`animations.set_on_space_change` the whole switch animates as a
coordinated slide, out to the corner and in from it (see
Animations). Focusing a hidden window (cmd+tab) pulls its
space forward automatically. Floating windows — including
picture-in-picture — are never stashed and stay visible across all
virtual spaces.

Sending a window elsewhere with
[`move_to_space`](#move_to_space) makes it that
space's focused window, so the first time you switch there it is
the window you land on — even without `_and_follow`.

**Minimizing** a window removes it from its space entirely.
Restoring it — from the Dock, or via
[`pull_or_spawn`](#pull_or_spawn) when the app has nothing left on
screen — opens it in the virtual space you are
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

**Expects:** `"longest_side"` or `"alternating"`.

**Does:** sets the BSP split strategy. `longest_side` cuts the
longer side of each region (keeps windows square-ish);
`alternating` alternates horizontal then vertical by depth.

**Example:**

```lua
bsp.set_strategy("longest_side")
```

### bsp.set_ratio_h

**Expects:** a number between 0 and 1 (default 0.5).

**Does:** sets the first window's share of every **side-by-side**
BSP split. `resize("x", …)` nudges this value; the stacked splits
keep their own ratio (#56).

**Example:**

```lua
bsp.set_ratio_h(0.5)
```

### bsp.set_ratio_v

**Expects:** a number between 0 and 1 (default 0.5).

**Does:** sets the first window's share of every **stacked**
(top/bottom) BSP split. `resize("y", …)` nudges this value,
independently of the side-by-side ratio (#56).

**Example:**

```lua
bsp.set_ratio_v(0.5)
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

### bsp.set_ratio_h_override

**Expects:**

- A space identifier.
- A ratio number.

**Does:** overrides the global side-by-side BSP ratio for one
space.

**Example:**

```lua
bsp.set_ratio_h_override("3", 0.6)
```

### bsp.set_ratio_v_override

**Expects:**

- A space identifier.
- A ratio number.

**Does:** overrides the global stacked BSP ratio for one space.

**Example:**

```lua
bsp.set_ratio_v_override("3", 0.4)
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

**Does:** sets the master zone's share of the split axis — the
width with a left/right stack zone, the height with a top/bottom
one (`stack.set_stack_position`). At layout time the *effective*
ratio is clamped so both zones keep `min_window_size` (#44) —
the stored value stays untouched and is honored again on a wider
display; the cascade fallback only triggers when two min-size
zones cannot coexist at any ratio.

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

### stack.set_stack_position

**Expects:** `"top"`, `"right"` (default), `"bottom"`, or
`"left"`.

**Does:** sets which side of the space the stack zone takes; the
master zone gets the rest. `left`/`right` split the width,
`top`/`bottom` the height. The stack zone's lineup derives from
the position — a left/right zone stacks its windows vertically,
a top/bottom zone lines them up side by side (there is no
separate stack orientation knob). Overflow piles always cascade
downward regardless. When the stack leads (`left`/`top`) and the
masters line up along the split axis, the master zone fills from
the stack seam instead of the screen edge, so a promoted window
appears beside the stack it just left rather than teleporting to
the far edge.

**Example:**

```lua
stack.set_stack_position("bottom")
```

### stack.set_master_orientation

**Expects:** `"vertical"` or `"horizontal"` (default).

**Does:** sets how the master zone lines up its windows when
`master_count` is more than one: stacked top to bottom, or side
by side.

**Example:**

```lua
stack.set_master_orientation("vertical")
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

### stack.set_stack_position_override

**Expects:**

- A space identifier.
- A position string (`"top"`, `"right"`, `"bottom"`, `"left"`).

**Does:** overrides the global stack position for one space.

**Example:**

```lua
stack.set_stack_position_override("3", "bottom")
```

### stack.set_master_orientation_override

**Expects:**

- A space identifier.
- An orientation string (`"vertical"`, `"horizontal"`).

**Does:** overrides the global master orientation for one space.

**Example:**

```lua
stack.set_master_orientation_override("3", "vertical")
```

### scroll.set_slot_size

**Expects:** a number (macOS points), `"NN%"` (fraction of
available axis), or `0` (auto, default).

**Does:** sets the size of columns (horizontal) or rows (vertical)
in scrolling layouts. Auto is 80% of the available width
(horizontal) or height (vertical). Any resolved size is floored
at the global
minimum window size (`set_min_window_size`) and capped at the
axis length — so a small percentage on a narrow display falls
back to the minimum rather than tiling windows smaller than it.
Accepted values: `%` clamps to 5–100%, points to ≥100.

**Example:**

```lua
scroll.set_slot_size(0)            -- auto
scroll.set_slot_size(400)          -- 400 pt
scroll.set_slot_size("50%")        -- half of available
```

### scroll.set_anchor

**Expects:** `"center"`, `"start"`, `"end"`, or `"follow"`.

**Does:** sets where the focused window rests in the viewport,
applied on *every* focus change.

- **`center`** — the focused window centers in the viewport.
- **`start`** / **`end`** — the focused window sits flush against
  the leading or trailing edge of the scroll axis. These are
  axis-relative: `start` is the left edge when scrolling
  horizontally, the top edge when vertical; `end` is the right or
  bottom edge. (The Settings picker shows the concrete edge —
  Left/Right or Top/Bottom — for the current orientation; the
  stored value stays axis-neutral.)
- **`follow`** (default) — the viewport holds its position and
  pans only the minimum needed to bring the focused window fully
  into view (Niri/PaperWM scroll-into-view). Moving focus up and
  down scroll symmetrically, an already-visible window does not
  move the viewport at all, and the side you came from stays open.

The three fixed anchors re-seat the focus on every focus change;
only `follow` remembers the prior scroll position. Focusing a
*floating* window leaves the viewport where it is under any anchor
— a floating window has no slot in the row, so there is nothing
to place.

**Example:**

```lua
scroll.set_anchor("follow")
```

### scroll.set_orientation

**Expects:** `"horizontal"` or `"vertical"`.

**Does:** sets the scroll direction. Horizontal: columns scroll
left/right. Vertical: rows scroll up/down.

Vertical rows overflow only at the bottom: macOS refuses to place
any window above the top screen border, so a row scrolled past the
top stays pinned at the border with its upper strip peeking behind
the focused row, instead of tucking above the screen. See the
[accepted limitations](accepted-limitations.md)
table. On the other edges, a slot scrolled far offscreen keeps a
small fixed sliver visible — macOS refuses fully offscreen
placement, so KiwiDesk pins at a deterministic sliver instead of
letting the OS clamp unpredictably.

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

### scroll.set_wrap_focus

**Expects:** a boolean.

**Does:** when `true`, stepping `focus` past either end of the
row wraps to the far end (right off the last window lands on the
first, and vice versa). Default is `false` — focus stops at the
ends, matching the physical-strip feel of the layout. Applies to
`focus` only; `swap` never wraps (it would teleport a window
across the whole row). Monocle has the same toggle
(`monocle.set_wrap_focus`), with the same **off** default.

**Example:**

```lua
scroll.set_wrap_focus(true)
```

### scroll.set_slot_size_override

**Expects:**

- A space identifier.
- A slot size in macOS points (same shape as
  `scroll.set_slot_size`).

**Does:** overrides the global slot size for one space. Editable
in the GUI from the space's **Overrides…** popover (check the
slot-size box to override; leave it unchecked to inherit the
Layout Defaults value).

**Example:**

```lua
scroll.set_slot_size_override("3", 400)   -- 400 pt in space "3"
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

**Does:** sets the grid fill order for both grid types (#217):
`horizontal` (Columns first) fills across a row then wraps down;
`vertical` (Rows first) fills down a column then wraps across. For
a dynamic grid it also sets which way the grid grows.

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

### grid.set_auto_size

**Expects:** `true` or `false` (default `false`).

**Does:** when true, derives the grid's dimensions from the
display — as many columns and rows as fit at `min_window_size`
(`floor(usable / (min_window_size + gap))` per axis, at least 1)
— instead of the typed `columns`/`rows`. Orthogonal to the grid
type: it caps a dynamic grid and fixes a rigid one alike. On a
landscape monitor this yields more columns than rows. Windows
past the resulting capacity cascade in the last cell.

**Example:**

```lua
grid.set_auto_size(true)
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

### grid.set_auto_size_override

**Expects:**

- A space identifier.
- A boolean.

**Does:** overrides the global auto-size flag for one space.

**Example:**

```lua
grid.set_auto_size_override("3", true)
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

### monocle.set_wrap_focus

**Expects:** `true` or `false` (default `false`).

**Does:** whether the focus cycle wraps past the ends. Defaults
**off**, matching the scrolling and track wraps — the same default
across all three array-order layouts. Turn it on and `focus` past
the last window returns to the first, and vice versa; off, focus
stops at the first/last window. `swap` never wraps.

**Example:**

```lua
monocle.set_wrap_focus(false)
```

### monocle.set_new_window_placement

**Expects:** `"first"`, `"last"`, `"before_focused"`, or
`"after_focused"`.

**Does:** sets where a new window lands in the monocle cycle.
Since monocle shows one window at a time, this is also where the
window appears in the focus order. Defaults to `"first"` so a new
window comes to the front of the carousel rather than being
buried at the back.

**Example:**

```lua
monocle.set_new_window_placement("first")
```

### track.swap

**Expects:** `"prev"` or `"next"` (the
[`move_to_track`](#move_to_track) sequence vocabulary — see
its table for what prev/next means per axis: left/right for
columns, above/below for rows).

**Does:** swaps the focused window's **entire track** — the
contiguous slice, with its windows, sizes, and in-track shares —
with the adjacent track in the sequence. The whole-structure
companion to the window-level `swap` (which is untouched and
stays spatial), following the
`stack.promote`/`stack.demote` precedent for layout-specific
verbs. Never wraps; refused when the space is not in
track mode, no tiled window is focused, or no track lies that
way (a single track has no neighbor). Also refused when the
swap would touch the **overflow track** while it is folding two
or more tracks together — the merged slices are a read-time
view with no marker identity to exchange, so the swap would
scramble which windows land in which track. This covers the
fold under a fixed limit (`track.set_limit` with automatic
tracks off) *and* the geometric fold on a display too narrow to
fit the tracks at `min_window_size`. Swapping two normal tracks
is unaffected — only a swap into the folded slot is refused, so
raise the limit or widen the display to reorder the overflow.

**Example:**

```lua
track.swap("next")
```

### track.set_axis

**Expects:** `"vertical"` (default) or `"horizontal"`.

**Does:** sets which way tracks run. Vertical tracks are
columns side by side (windows stack top-to-bottom inside one);
horizontal tracks are rows. The axis also decides which
`resize` axis trades track space and which pair of directions
`move_to_track` accepts.

**Example:**

```lua
track.set_axis("vertical")
```

### track.set_limit

**Expects:** an integer ≥ 0.

**Does:** sets how many **normal** tracks a space can hold. `0`
restores the **automatic** track limit (the default — tracks open and
collapse as windows come and go; see `track.set_auto_tracks`).
A positive value pins the limit *and turns automatic off*, so
`set_limit(3)` takes effect on its own. Beyond the limit, one
extra **overflow track** opens at the far edge and collects the
surplus (#192): a new `own_track` window past the limit opens
that overflow track, and further windows fold into it (rendered
per `track.set_overflow_style`). `move_to_track` can open the
overflow track but refuses to go past it. The limit is
display-agnostic — if a monitor can't fit the columns at
`min_window_size`, the layout shows fewer at render time. The
last positive value is remembered, so flipping automatic back
off restores it.

**Example:**

```lua
track.set_limit(3)
```

### track.set_auto_tracks

**Expects:** `true` or `false` (default `true`).

**Does:** whether the track limit is managed automatically. On
(the default), tracks open and collapse as windows come and go —
no cap. Off pins the cap to the value set by `track.set_limit`.
The track twin of `grid.set_auto_size`. `track.set_limit(0)` is
the shorthand for turning this on; `track.set_limit(n)` for
turning it off with a cap of `n`.

**Example:**

```lua
track.set_auto_tracks(false)
```

### track.set_new_window

**Expects:** `"focused_track"` (default) or `"own_track"`.

**Does:** decides where a new window lands in a track space.

- `focused_track` (**fill-then-spill**, the default): the window
  **joins** the focused window's track — placed among its windows
  by [`track.set_new_window_position`](#trackset_new_window_position)
  — until that track can't fit another window at
  `min_window_size`, when the window instead **spills into a new
  track** immediately beside the focused one. Focus follows the
  new window, so the next one fills that track and spills again.
  With no other track to spill to it piles in the focused track
  instead: under a fixed [`track.set_limit`](#trackset_limit) cap
  with no room for another track, or for a window an explicit
  `move_to_space` drops onto a full track (an explicit placement,
  never relocated).
- `own_track`: each new window opens its **own** new track,
  positioned among the others by
  [`track.set_new_window_position`](#trackset_new_window_position)
  — the "one full-width app per column" (ultrawide) choice. Falls
  back to joining once `track.set_limit` is reached.

Track spaces use this pair instead of the flat
`new_window_placement` vocabulary — a flat index cannot say "own
track". The fill-then-spill boundary is display-dependent (how
many windows fit at `min_window_size`), so the same window count
spills sooner on a smaller display.

**Example:**

```lua
track.set_new_window("own_track")
```

### track.set_new_window_position

**Expects:** `"first"` (default), `"last"`, `"before_focused"`,
or `"after_focused"`.

**Does:** places the new window within the
[`track.set_new_window`](#trackset_new_window) choice, reusing
the shared placement vocabulary. For `own_track` it positions the
**new track** among the others (`first` = leftmost column /
topmost row, `last` = the far edge, `before`/`after_focused` =
beside the focused track). For `focused_track` it positions the
window among that **track's windows** (`first`/`last` = the
track's ends, `before`/`after_focused` = around the focused
window). Defaults to `first` so a new window lands at the visible
front, never buried in the overflow.

**Example:**

```lua
track.set_new_window_position("after_focused")
```

### track.set_overflow_style

**Expects:** `"cascade_all"` (default) or `"cascade_overflow"`.

**Does:** shapes only the **overflow track** — the single
far-edge track that collects the surplus when more tracks exist
than fit side by side at `min_window_size`. `cascade_all` (the
default) piles all its windows from the top as a title-bar
cascade; `cascade_overflow` keeps as many full windows as fit
and cascades only the rest. Reuses stack's overflow vocabulary.

Every **normal** track (one that fits) always uses
`cascade_overflow` for its own internal overflow — this setting
does not change that. And the fitting tracks always stay tiled;
only the merged surplus in the overflow track is affected.

**Example:**

```lua
track.set_overflow_style("cascade_overflow")
```

### track.set_wrap_focus

**Expects:** a boolean (default `false`).

**Does:** the track twin of `scroll.set_wrap_focus` (#168):
with it on, stepping `focus` past an end wraps — within the
focused track along the axis, last ↔ first track across it.
Off, focus stops at the ends. `swap` and `move_to_track` never
wrap. Each layout owns its toggle; this one only affects track
spaces.

**Example:**

```lua
track.set_wrap_focus(true)
```

### track.set_axis_override

**Expects:**

- A space identifier.
- An axis string.

**Does:** overrides the global axis for one space.

**Example:**

```lua
track.set_axis_override("code", "horizontal")
```

### track.set_limit_override

**Expects:**

- A space identifier.
- An integer ≥ 0.

**Does:** overrides the global track cap for one space. Like the
global setter, a positive value also turns automatic off for that
space, and `0` turns it back on.

**Example:**

```lua
track.set_limit_override("code", 2)
```

### track.set_auto_tracks_override

**Expects:**

- A space identifier.
- A boolean.

**Does:** overrides the auto-track-limit flag for one space.

**Example:**

```lua
track.set_auto_tracks_override("code", false)
```

### track.set_overflow_style_override

**Expects:**

- A space identifier.
- An overflow style string (`cascade_all` or
  `cascade_overflow`).

**Does:** overrides the global track overflow style for one
space.

**Example:**

```lua
track.set_overflow_style_override("code", "cascade_overflow")
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
resolved per layout from `start`/`end` values — `start` resolves
to the top edge on horizontal-axis layouts or the left edge on
vertical-axis layouts; `end` resolves to the bottom or right. The
bar always renders on the edge the position names, so no clamp or
mismatch can occur.

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

### app_bar.set_edge

**Expects:** `"top"`, `"bottom"`, `"left"`, or `"right"`
(default `"bottom"`).

**Does:** sets the screen edge the bar occupies, for every layout
that shows a bar. The edge is absolute — it no longer follows the
layout's orientation (#293) — so one value places the bar on the
same edge everywhere. Per-layout overrides can change it.

**Example:**

```lua
app_bar.set_edge("top")
```

### app_bar.set_alignment

**Expects:** `"start"`, `"center"`, or `"end"`
(default `"center"`).

**Does:** places the item group along the bar while it fits.
Values are edge-relative, so they stay correct on every edge —
a left bar's `start` is its top, a top bar's `start` is its
left. Once the items overflow and scroll, all three values
behave the same (the group follows the scroll offset).
Per-layout overrides can change it
(`monocle.set_app_bar_alignment`, `scroll.set_app_bar_alignment`).

**Example:**

```lua
app_bar.set_alignment("start")
```

### app_bar.set_thickness

**Expects:** a positive number (points).

**Does:** sets the bar's thickness, carved out of the layout.

**Example:**

```lua
app_bar.set_thickness(32)
```

### app_bar.set_background_style

**Expects:** `"boxed"` or `"plain"` (default `"plain"`).

**Does:** sets WHERE the background is drawn:
- **boxed** — a box per item honoring the corner roundness
  (0% = square, 100% = full capsule).
- **plain** — no per-item box; names sit on one shared
  translucent strip that spans the whole bar.

Liquid Glass is no longer an option here — it is a separate
finish toggle, `set_liquid_glass` (below), that lays over
either style.

**Example:**

```lua
app_bar.set_background_style("plain")
```

### app_bar.set_liquid_glass

**Expects:** a boolean.

**Does:** lays a macOS 26 Liquid Glass material over the item
backgrounds (the boxes or the plate) — an orthogonal finish, so
it combines with either shape. `fill_color` tints the glass: a
solid colored layer sits behind the glass and the glass refracts
it (an `NSGlassEffectView`'s own tint reads near-colorless on
macOS 26.5.2 — it shifts luminance, not hue — so the color is
supplied behind it, the way the Dock tints its glass). A fully
transparent `fill_color` leaves the glass clear. Ignored below
macOS 26, where
the Settings toggle is hidden (an OS-capability gate, absent not
greyed); the stored value still round-trips so a profile stays
portable. Per-layout override:
`monocle.set_app_bar_liquid_glass` /
`scroll.set_app_bar_liquid_glass`.

**Example:**

```lua
app_bar.set_liquid_glass(true)
```

### app_bar.set_background_fit

**Expects:** `"full"` or `"hug"` (default `"hug"`).

**Does:** sets how far the shared background plate reaches
under `plain` (and the Liquid Glass finish over it): `hug` wraps
the item run plus one item gap of breathing room per end (the
Dock's read), `full` spans the whole strip. Hug falls back to
full while the items overflow and scroll. Inert under `boxed`,
which draws a box per item instead of a shared plate (the
Settings control greys there). Per-layout override:
`monocle.set_app_bar_background_fit` /
`scroll.set_app_bar_background_fit`.

**Example:**

```lua
app_bar.set_background_fit("full")
```

### app_bar.set_active_indicator

**Expects:** `"outline"`, `"edge_mark"`, or `"gap"`.

**Does:** how the focused window is marked. This is orthogonal to
`background_style` — the two combine freely:
- **outline** — an outlined border around the active item.
- **edge_mark** — an accent bar on the active item's
  window-facing edge.
- **gap** — the active item's slot is left empty.

**Example:**

```lua
app_bar.set_active_indicator("outline")
```

### app_bar.set_item_size

**Expects:** a number (points); `0` means auto (default).

**Does:** sets the width (horizontal) or height (vertical) of each
item. Auto measures each item's rendered width (icon + name at the
effective font) and sizes the uniform slot to fit the widest, so
long names don't truncate and short ones don't waste space.

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

**Does:** sets what each item displays. Vertical bars (edge
`left`/`right`) always render icon-only — names would need
stacked or rotated text; the stored preference returns when the
bar moves back to a horizontal edge.

**Example:**

```lua
app_bar.set_content("icon_and_name")
```

### app_bar.set_icon_source

**Expects:** `"app_image"` or `"app_font"`.

**Does:** sets how app icons are drawn. `app_image` (default)
shows the app's icon as macOS provides it — including whatever
system-wide Icon & widget style the user picked. `app_font`
shows a monochrome glyph from the bundled [SketchyBar App
Font](https://github.com/kvndrsslr/sketchybar-app-font)
instead, colored by the bar's item colors (Item / Active item /
Hover item); apps without a glyph keep their icon. Styled icon
variants (the system's Dark/Clear/Tinted renderings) cannot be
fetched by apps — no public API hands them out.

**Example:**

```lua
app_bar.set_icon_source("app_font")
```

### app_bar.set_font_size

**Expects:** a number (points); `0` means auto (default).

**Does:** if `0`, text scales with bar thickness; any positive
value pins the font size.

**Example:**

```lua
app_bar.set_font_size(0)
```

### app_bar.set_corner_roundness

**Expects:** a number 0–100 (percentage; default 50).

**Does:** sets the corner rounding of boxed items as a percentage,
where 0 = square and 100 = a full capsule (radius = thickness/2).
It only affects `boxed` items (ignored for `plain`). The percentage
cannot exceed the maximum, so items never render as pointed.

**Example:**

```lua
app_bar.set_corner_roundness(50)
```

### app_bar.set_dim_factor

**Expects:** a number 0.05–1 (default 0.4).

**Does:** sets the opacity of an inactive item's untinted icon — the
dim that carries "not focused" for content that takes no state color.
Lua-only (no GUI); values are clamped to a legible range. Lower = a
stronger inactive cue.

**Example:**

```lua
app_bar.set_dim_factor(0.4)
```

### app_bar.set_group_adjacent_windows

**Expects:** `true` or `false`.

**Does:** if true, collapses adjacent same-app windows into one
item with a count badge.

**Example:**

```lua
app_bar.set_group_adjacent_windows(true)
```

### app_bar.set_item_color

**Expects:** a hex color (`#RRGGBB` or `#RRGGBBAA`).

**Does:** sets the item's text and glyph color (default
`#EAF3EE`).

**Example:**

```lua
app_bar.set_item_color("#EAF3EE")
```

### app_bar.set_fill_color

**Expects:** a hex color.

**Does:** sets the fill under the items — a box per item
(`boxed`) or one shared plate (`plain`). Default `#14201CCC`,
dark moss at 80% opacity. With the `liquid_glass` finish on, it
also tints the glass: the color sits behind the glass, which
refracts it into its hue (see `app_bar.set_liquid_glass`). Under
glass the backdrop's opacity is held at ~65 % so the blur stays
visible; the stored value is unchanged (Boxed/Plain use it in
full).

**Example:**

```lua
app_bar.set_fill_color("#14201CCC")
```

### app_bar.set_active_item_color

**Expects:** a hex color.

**Does:** sets the text and glyph color of the active item — the
focused item (default `#8DB354`, kiwi green).

**Example:**

```lua
app_bar.set_active_item_color("#8DB354")
```

### app_bar.set_highlight_color

**Expects:** a hex color.

**Does:** sets the highlight color of the active indicator (the
outline or the edge mark).

**Example:**

```lua
app_bar.set_highlight_color("#8DB354")
```

### app_bar.set_hover_fill_color

**Expects:** a hex color.

**Does:** sets the hover feedback on clickable items (default
`#AACB5D80`, light translucent green).

**Example:**

```lua
app_bar.set_hover_fill_color("#AACB5D80")
```

### app_bar.set_hover_item_color

**Expects:** a hex color.

**Does:** sets the text color during hover.

**Example:**

```lua
app_bar.set_hover_item_color("#EAF3EE")
```

### app_bar.set_group_badge_color

**Expects:** a hex color.

**Does:** sets the count badge background color.

**Example:**

```lua
app_bar.set_group_badge_color("#B00020")
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

- `monocle.set_app_bar_enabled`, `monocle.set_app_bar_edge`,
  `monocle.set_app_bar_thickness`, etc.
- `scroll.set_app_bar_enabled`, `scroll.set_app_bar_background_style`,
  `scroll.set_app_bar_active_indicator`,
  `scroll.set_app_bar_corner_roundness`, etc.

**Example:**

```lua
monocle.set_app_bar_enabled(true)
scroll.set_app_bar_enabled(true)
scroll.set_app_bar_background_style("plain")  -- override for scrolling
```

## Space Bar

The Space Bar (#293) is an always-visible overview of your
Spaces: one bar per display, listing that display's Spaces in
profile order — each item shows the Space's identifier
(configured icon, else the plain digits for numeric ids or a
two-letter monogram for named ones), a thin divider, then a
compact glyph per window in that Space. Adjacent windows of
the same app collapse
into one glyph wearing a count badge (non-adjacent duplicates
stay separate); past the configured glyph cap
(`space_bar.set_glyph_cap`, default 5, range 1–12) the rest fold
into a `+n` badge counting the hidden windows. Badges use the
configured badge colors on the active Space and render muted on
inactive ones. Clicking a Space switches to it. App glyphs are
informational — not click targets, and a group holding the
focused window stays collapsed (it just takes the focused
accent).

The bar is **layout-independent** and reserves real screen area
on its edge before any layout runs. It may share an edge with
the App Bar: the Space Bar always sits at the screen edge, the
App Bar next to the windows, and the insets add. All settings
are global — there are no per-layout overrides.

Two accents distinguish states: `item_color` paints inactive
Spaces, `active_item_color` the active Space, and
`focused_item_color` the focused window's glyph inside the
active Space. Untinted content — emoji identifiers and native
app images — dims to half strength on inactive Spaces instead.

### space_bar.set_enabled

**Expects:** boolean (default `true`).

**Does:** shows or hides the Space Bar. A disabled bar reserves
no area.

**Example:**

```lua
space_bar.set_enabled(true)
```

### space_bar.set_edge

**Expects:** `"top"`, `"bottom"`, `"left"`, or `"right"`
(default `"top"`).

**Does:** sets the screen edge the bar occupies. Sharing an
edge with the App Bar is supported: the Space Bar stays
screen-facing, the App Bar window-facing.

**Example:**

```lua
space_bar.set_edge("left")
```

### space_bar.set_alignment

**Expects:** `"start"`, `"center"`, or `"end"`
(default `"center"`).

**Does:** places the Space items (and the front-app segment)
along the bar. Values are edge-relative — a left bar's
`start` is its top.

**Example:**

```lua
space_bar.set_alignment("center")
```

### space_bar.set_thickness

**Expects:** thickness in points (default `32`).

**Does:** sets the bar's thickness, carved out of the layout.

**Example:**

```lua
space_bar.set_thickness(28)
```

### space_bar.set_item_size

**Expects:** length in points; `0` (default) = auto.

**Does:** pins every Space item to one length along the bar.
Auto sizes each item to its content (identifier + glyphs).

**Example:**

```lua
space_bar.set_item_size(0)
```

### space_bar.set_item_gap

**Expects:** points (default `6`).

**Does:** sets the spacing between Space items.

**Example:**

```lua
space_bar.set_item_gap(6)
```

### space_bar.set_font_size

**Expects:** points; `0` (default) = auto (scales with
thickness).

**Does:** pins the identifier / glyph text size.

**Example:**

```lua
space_bar.set_font_size(0)
```

### space_bar.set_glyph_cap

**Expects:** an integer `1`–`12` (default `5`); out-of-range
values clamp.

**Does:** sets how many app-group glyphs a Space item shows before
the rest collapse into the trailing `+n` badge. Grouping runs
first, so the cap counts app *groups* (adjacent same-app windows
share one glyph), while `+n` counts the hidden *windows*. This is
the per-Space glyph limit only — it does not change how many
Spaces the whole bar shows.

**Example:**

```lua
space_bar.set_glyph_cap(8)
```

### space_bar.set_icon_source

**Expects:** `"app_image"` or `"app_font"` (default
`"app_image"`).

**Does:** how app glyphs are drawn — the native app image, or a
monochrome App Font glyph following the bar's item colors. An
app with no image falls back to the App Font either way.

**Example:**

```lua
space_bar.set_icon_source("app_font")
```

### space_bar.set_background_style

**Expects:** `"boxed"` or `"plain"` (default `"plain"`).

**Does:** boxes each Space item, or draws all items on one
shared strip — same vocabulary as the App Bar. Liquid Glass is a
separate finish, `space_bar.set_liquid_glass`.

**Example:**

```lua
space_bar.set_background_style("boxed")
```

### space_bar.set_liquid_glass

**Expects:** a boolean.

**Does:** lays the macOS 26 Liquid Glass finish over the Space
items — see `app_bar.set_liquid_glass` for the full behavior
(orthogonal to the background style, `fill_color` tints the
glass via a
colored backdrop behind it, hidden and inert below macOS 26).

**Example:**

```lua
space_bar.set_liquid_glass(true)
```

### space_bar.set_background_fit

**Expects:** `"full"` or `"hug"` (default `"hug"`).

**Does:** how far the shared plate reaches under `plain` (and the
Liquid Glass finish) — see `app_bar.set_background_fit`; same
vocabulary, same boxed inertness and overflow fallback.

**Example:**

```lua
space_bar.set_background_fit("hug")
```

### space_bar.set_active_indicator

**Expects:** `"outline"`, `"edge_mark"`, or `"gap"` (default
`"outline"`).

**Does:** how the active Space is marked. `gap` draws no shape
marker (colors alone carry the state) — unlike the App Bar, the
active Space's item is never hidden.

**Example:**

```lua
space_bar.set_active_indicator("outline")
```

### space_bar.set_corner_roundness

**Expects:** percent 0–100 (default `50`).

**Does:** corner rounding as a percentage of the maximum, like
the App Bar.

**Example:**

```lua
space_bar.set_corner_roundness(50)
```

### space_bar.set_dim_factor

**Expects:** a number 0.05–1 (default 0.4).

**Does:** sets the opacity of everything on an **inactive** Space —
the outer dim tier. Lua-only (no GUI), clamped to a legible range.

**Example:**

```lua
space_bar.set_dim_factor(0.4)
```

### space_bar.set_active_dim_factor

**Expects:** a number 0.05–1 (default 0.6).

**Does:** sets the opacity of an **unfocused window's glyph on the
active Space** — the middle dim tier, between the focused window (1.0)
and inactive Spaces (`set_dim_factor`). Lua-only, clamped. Independent
of `set_dim_factor`: no ordering is enforced, so setting it below the
outer tier will invert the ladder — the GUI is the curated gate, Lua
the open one.

**Example:**

```lua
space_bar.set_active_dim_factor(0.6)
```

### space_bar.set_show_front_app

**Expects:** boolean (default `false`).

**Does:** shows a trailing front-app segment after the last
Space item — a divider, then the glyph and name of the focused
window of the Space **this display currently shows** (per
display, not the globally frontmost app — one bar per display,
per-display content). On vertical (left/right) bars the
segment is icon-only; the divider flips to a horizontal rule.

**Example:**

```lua
space_bar.set_show_front_app(false)
```

### space_bar.set_hide_empty

**Expects:** boolean (default `false`).

**Does:** hides Spaces with no windows from the bar — except
the Space you are currently on, which always stays (so a cold
start never collapses the strip). Hidden Spaces remain
reachable by shortcut.

**Example:**

```lua
space_bar.set_hide_empty(true)
```

### space_bar.set_sticky_badge

**Expects:** boolean (default `true`).

**Does:** shows or hides the window-state badges on Space Bar
items: sticky windows wear a badge on their glyph's top-left
corner, floating windows on the bottom-left (the top-right
stays the group count). A grouped glyph aggregates its
windows' states — the badge means "at least one". Lua-only; the
Settings app offers no toggle for these badges.

**Example:**

```lua
space_bar.set_sticky_badge(false)
```

### space_bar.set_spring_delay

**Expects:** milliseconds (default `1500`, clamped to
`1000`–`4000`).

**Does:** sets how long a window dragged onto a Space item must
hover before the view springs to that Space (the "hold to place"
half of the drag-drop gesture — see the user guide). A quicker
drop, before this delay, moves the window without switching. The
ring sweep around the item fills over the same duration.

**Example:**

```lua
space_bar.set_spring_delay(1000)
```

### Space Bar colors

Same `#RRGGBB` / `#RRGGBBAA` grammar as every other color
setting. The three-state ladder is the bar's signature:

- `space_bar.set_item_color` — inactive Spaces (default
  `#EAF3EE66`).
- `space_bar.set_active_item_color` — the active Space's
  identifier and glyphs (default `#8DB354`).
- `space_bar.set_focused_item_color` — the focused window
  wherever it shows: its glyph inside the active Space and the
  front-app segment (default `#C2790A`, a deliberately different
  hue **and a step darker**, so "focused window" never washes
  into the active-Space green — including for a red-green
  colour-blind reader, for whom hue alone would not separate the
  two). If you retune it, keep a lightness gap from
  `active_item_color`; a lighter amber loses the distinction
  again.
- `space_bar.set_hover_fill_color` / `space_bar.set_hover_item_color`
  — hover tint on non-active items.
- `space_bar.set_fill_color` / `space_bar.set_highlight_color` —
  as the App Bar (`fill_color` is the box / plate / glass tint).
- `space_bar.set_group_badge_color` /
  `space_bar.set_group_badge_text_color` — the count and `+n`
  overflow badges (active Space; inactive Spaces mute them
  from `item_color`).

**Example:**

```lua
space_bar.set_active_item_color("#8DB354")
space_bar.set_focused_item_color("#C2790A")
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
- **Monocle** `first` — the new window comes to the front of the
  carousel.

Each layout also has its own global setter (e.g.
`bsp.set_new_window_placement`, `stack.set_new_window_placement`,
`monocle.set_new_window_placement`).

The **track** layout is the exception: it follows
`track.set_new_window` (`own_track` / `focused_track`) plus
`track.set_new_window_position` (`first` default / `last` /
`before_focused` / `after_focused`) instead, and this per-space
placement override does not apply to track spaces — a flat index
cannot express "opens its own track".

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

### drag.set_ghost_border_width

**Expects:** a non-negative number (points).

**Does:** sets the border width of the ghost.

**Example:**

```lua
drag.set_ghost_border_width(5)
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

**Does:** sets the ghost border color (default `#347957`,
deep emerald — the ghost, drag's origin, is all-green; a
bluer green than the focus ring since #511, so it separates
from the drop zone's amber under red-green vision loss).

**Example:**

```lua
drag.set_ghost_border_color("#347957")
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

**Does:** sets the ghost fill color (default `#34795740`,
deep emerald with 25% alpha).

**Example:**

```lua
drag.set_ghost_fill_color("#34795740")
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

### drag.set_drop_zone_border_width

**Expects:** a non-negative number (points).

**Does:** sets the border width of the drop zone.

**Example:**

```lua
drag.set_drop_zone_border_width(5)
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

**Does:** sets the drop zone border color (default `#C2790A`,
amber — the drop zone, drag's target, is all-amber so it reads
apart from the green ghost).

**Example:**

```lua
drag.set_drop_zone_border_color("#C2790A")
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

**Does:** sets the drop zone fill color (default `#C2790A40`,
amber with 25% alpha).

**Example:**

```lua
drag.set_drop_zone_fill_color("#C2790A40")
```

### drag.set_corner_radius

**Expects:** a non-negative number (points).

**Does:** sets the corner rounding of both visuals (default 16).

**Example:**

```lua
drag.set_corner_radius(16)
```

## Focus Border

KiwiDesk can draw a thin border around the focused window so it is
unmistakable in a gapped layout — the feedback keyboard-driven
focus otherwise lacks. It is **on by default** and marks only the
focused window; it can optionally show one on every other window
too.

The border is a pure overlay: it never changes where windows tile
(no gap coupling). The configured width is the thickness drawn
outward into the gap — the value `border.fit_gaps` sizes gaps from.
By default the border is stacked **behind** its window: a flicker-free
placement that holds steady even when a window redraws rapidly (some
browsers repaint on every keystroke) and hugs each window's real
corner radius. The trade is that the window's drop-shadow falls
across the border's lower reach and the corner meets the window with a
filled seam rather than a floating hairline.
`border.set_draw_order("front")` switches to an in-front placement
that is crisper and shadowless but can flicker on those browsers —
a power-user opt-in (see below). Rounded corners match the real
macOS window radius (queried per window); square draws sharp
corners. The border is pinned to its window's stacking level, so
popovers, sheets, and other windows the system places above the
target still stay above its border.

Overflow piles and monocle show a border only on the visible
top window; set gaps at least as wide as the border to avoid
neighbouring borders touching.

### border.set_enabled

**Expects:** a boolean.

**Does:** turns the focus border on or off (default `true`).

**Example:**

```lua
border.set_enabled(true)
```

### border.set_width

**Expects:** a number (points). Out-of-range values are clamped
to `0.5`–`20`.

**Does:** sets the border width (default `5`). 5 pt is the widest
that still tiles cleanly when unfocused borders are on — each border
reaches its width into the 10 pt gap, so two of them exactly fill
it without overlapping.

**Example:**

```lua
border.set_width(5)
```

### border.set_focused_color

**Expects:** a hex color string (`"#RRGGBB"` or `"#RRGGBBAA"`) —
the same format as every other KiwiDesk color.

**Does:** sets the focused window's border color (default
`"#4A9816"`, the Kiwi theme's bright-green focus accent).

**Example:**

```lua
border.set_focused_color("#4A9816")
```

### border.set_unfocused_enabled

**Expects:** a boolean.

**Does:** when `true`, also draws a border on the unfocused
windows (default `false`). Ignored in monocle, where only the
focused window shows.

**Example:**

```lua
border.set_unfocused_enabled(false)
```

### border.set_unfocused_color

**Expects:** a hex color string (`"#RRGGBB"` or `"#RRGGBBAA"`).

**Does:** sets the unfocused windows' border color (default
`"#8E8E93CC"`, a neutral grey at 80% opacity).

**Example:**

```lua
border.set_unfocused_color("#8E8E93CC")
```

### border.set_corner_style

**Expects:** `"rounded"` or `"square"`.

**Does:** `rounded` (default) matches the real window corner
radius; `square` draws sharp corners — seamless on windows that
are already square (some Electron/utility windows), an intentional
squared frame on rounded ones.

**Example:**

```lua
border.set_corner_style("rounded")
```

### border.set_glow

**Expects:** a boolean.

**Does:** when `true`, wraps the **focused** border in a soft colored
bloom — a zero-offset blurred halo, the JankyBorders "glow" look
(default `false`). A render trait like width and corners: it adds no
color choice and never touches the unfocused windows (a bloom on
every dim border would undo the point of making the focused one
stand out).
The bloom is a **brightened** derivative of `focused_color` (a halo
is a fill, not a legibility-bound stroke, so it reads more vivid than
the darkened border, in its own hue) — set only `focused_color`
and the glow follows. Its reach **scales with the border width**
(clamped to a legible band), so a hairline border gets a subtle
rim and a thick one a proportional aura — override it with
`set_glow_size` below. The soft edge is allowed to bleed into
the layout gap, so `fit_gaps` is unaffected. One interaction: a
glowing ring renders on the behind-order fallback renderer, so
`draw_order("front")` is inert while glow is on (see
[Accepted limitations](accepted-limitations.md)).

**Example:**

```lua
border.set_glow(true)
```

### border.set_glow_size

**Expects:** a size in points, or `0` for automatic (the
default). A value above the renderable ceiling of 40 clamps
silently, like the other border magnitudes; a negative or
non-numeric argument fails — switching back to automatic takes
an explicit `0`, never a clamp.

**Does:** sets the glow bloom's blur radius. `0` keeps the
automatic behavior — the width-scaled formula that gives a
hairline border a subtle rim and a thick one a proportional
aura — while an explicit size pins the reach regardless of the
border width. The GUI slider offers 1–20 pt behind an **Auto
glow size** toggle; larger values up to 40 stay a Lua
fine-tune. No effect while `glow` is off.

**Example:**

```lua
border.set_glow(true)
border.set_glow_size(8)   -- a fixed, wider bloom
border.set_glow_size(0)   -- back to automatic
```

### border.set_draw_order

**Expects:** `"behind"` or `"front"`.

**Does:** chooses where the border stacks relative to windows.
`behind` (default) draws it below the window — flicker-free, hugs
the real corner radius, but carries the window's drop-shadow on its
lower reach and a filled corner seam. `front` draws it above the
window — a crisp, shadowless hairline — but can flicker on windows
that repaint rapidly (Firefox/Zen and other Gecko browsers emit a
compositor reorder on every keystroke). There is no GUI control for
this: `behind` is the right default for everyone, and `front` is a
niche preference exposed to Lua only. Changing it re-draws every
border immediately.

While `border.glow` is on, the focused ring renders on the
behind-order renderer regardless of this setting — `"front"`
takes effect again the moment glow turns off (see
[Accepted limitations](accepted-limitations.md)).

**Example:**

```lua
border.set_draw_order("front")
```

### border.fit_gaps

**Expects:** an optional remaining gap in whole points, 0–100
(default 0). An out-of-range value clamps into that range (like
the other border magnitudes); a non-numeric argument fails.

**Does:** sizes the global layout gaps so borders never touch a
neighbour, keeping `remaining` points of deliberate whitespace
past the border's reach. Every outer edge becomes
`reach + remaining`; each inner axis becomes `reach + remaining`,
or `2 × reach + remaining` when `unfocused_enabled` is on (both
neighbouring borders need clearance; the whitespace sits between
them once). The reach is simply the configured border width; the
renderer’s hidden overlap is behind the window and does not count.
The action deliberately
normalizes asymmetric global gaps. A one-shot convenience that
writes `gap.global` — the remaining gap is command input, never a
persisted setting, and the layout math itself stays free of any
border coupling, so this never runs automatically. The GUI's
**Fit layout gaps → Set Gap Values** action previews and stages the
same calculation.

**Example:**

```lua
border.set_width(10)
border.fit_gaps()   -- width 10: outer gaps 10, inner gaps 10
                    -- (20 if unfocused borders are on)
border.fit_gaps(6)  -- leave 6 pt after the reach: outer 16,
                    -- inner 16 (26 if unfocused borders are on)
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

## Mouse Behaviour

### mouse.set_follows_focus

**Expects:** a boolean.

**Does:** when `true`, a focus change warps the mouse pointer to
the center of the newly-focused window, so the next click,
scroll, or hover lands on the window the keyboard is working in —
the standard companion behaviour in i3/sway/yabai. Default is
**`false`** (off), matching those WMs. The pointer never moves
while a mouse button is held down or when it is already inside
the focused window, and is held while KiwiDesk performs its own
z-order maintenance raises. When focus lands on a window in an inactive virtual
space (cmd+tab into a stashed window), the warp waits until
KiwiDesk follows focus and pulls that space forward. Clicking
an app-bar item warps too — the click targets the bar, not
the window it focuses. Also togglable in the Settings app
under **Behavior ▸ Mouse**.

**Example:**

```lua
mouse.set_follows_focus(true)
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
full window fits does the whole zone cascade. Track behaves the
same way on both axes — the fitting prefix of tracks (or of a
track's windows) stays tiled and only the remainder cascades.
This is built into the layout, not a setting.

For a cascade to read correctly, upper windows must sit *behind*
lower ones. KiwiDesk restores this z-order whenever a window
crosses the master/stack boundary (drag swap, directional `swap`,
`stack.promote` / `stack.demote`). Focusing a window still raises it
to the front — that override is deliberate and lasts until the next
boundary crossing re-stacks the zone.

## Window Rules

### float_rules

**Expects:** a Lua table of strings (bundle-id or
bundle-id:title matchers).

**Does:** windows matching any entry always float. An app is
named by its **bundle identifier** (e.g. `com.apple.finder`),
not its display name — the identifier is stable across system
language and app renames. `"id"` matches every window of the
app; `"id:Title"` matches when the title contains the fragment.
The bundle id is matched case-insensitively; the title fragment
is case-sensitive. See [Finding a bundle
identifier](#finding-a-bundle-identifier). Dialogs, sheets, and
picture-in-picture
windows float automatically. Detection is re-checked as windows
come and go — and when a title changes, so an "App:Title" rule
catches windows whose titles load late (Electron/WebKit apps) or
change into a match later. A window that reported wrong metadata
while launching corrects itself the same way. A manual
`make_floating` override is never reverted by these re-checks.

Panels and overlays that live above the normal window layer also
float automatically, no rule needed. Windows belonging to apps that
remain accessory processes are tracked but forced floating. If an app
promotes itself to a regular process, its standard windows follow the
normal float-or-tile rules.

This table is the global base. A profile may add rules or remove
inherited ones with its sparse `float_rules` object (`true` adds,
`null` removes). The same profile diff resolves whether the base is
owned by `gui.json` or this hand-written `init.lua`.

**Ghostty's quick terminal** is not managed at all — no space
assignment, no window events. KiwiDesk simply pretends it does not
exist.

Transient macOS input-source menus and switcher overlays are likewise
ignored, so pressing the Globe key never creates a managed window or
KiwiDesk focus border. Auxiliary AX proxy windows with no matching
WindowServer window are ignored by the same policy.

**KiwiDesk's Settings window** is tracked as a floating window, so
window-list integrations can see it and the top App Bar clamp keeps
its title bar reachable. KiwiDesk's own panels — drag/drop overlays,
App Bar overlays, and focus borders — remain fully ignored.

**Example:**

```lua
float_rules = {
    "com.apple.calculator",
    "com.apple.finder:Get Info",
}
```

### ignore_rules

**Expects:** a Lua table of app bundle identifiers.

**Does:** KiwiDesk never manages any window belonging to a matching
app: no state entry, tiling or floating verdict, virtual-space
assignment, or window events. Use this for HUDs, menu-bar utilities,
or apps that misbehave when AX-tracked. Use `float_rules` when an app
should remain tracked and visible but never tile.

Matching is case-insensitive and app-wide; title fragments are not
supported. This table is the global base. In `gui.json` it lives at
the root as `ignore_rules`. A profile may add rules or tombstone
inherited ones through its sparse `ignore_rules` object. There is
deliberately no Settings control and no session-only
`make_unmanaged` command; GUI profile saves preserve that hidden
override unchanged.

**Example:**

```lua
ignore_rules = {
    "com.1password.1password",
    "eu.exelban.Stats",
}
```

After editing `init.lua`, run `kiwidesk reload_config`. Newly ignored
apps leave KiwiDesk state, and apps removed from the list are
discovered again. Ghostty's quick terminal remains a built-in
layer-specific exception because only its panel — not normal Ghostty
windows — must be ignored.

**Command bars are ignored automatically.** A Spotlight/Raycast-style
launcher is a menu-bar (accessory) app whose bar is a raised-layer
overlay; KiwiDesk never manages such a window, so the bar is not
tiled, stashed, or pulled along on a space switch. The rule is
generic — accessory app **and** raised window layer — so any
launcher or HUD qualifies without a rule; the app's normal windows
(settings, pickers) stay managed as floats. Raycast's command bar is
additionally recognized by bundle id for setups where Raycast shows
a dock icon and loses the accessory policy. `ignore_rules` remains
the whole-app escape hatch for anything the heuristic misses.

Invisible helper windows are ignored automatically: a raised-layer
window that is fully transparent or sits entirely off-screen (the
lifecycle keepalive some menu-bar apps create) is never tracked,
so the app doesn't read as an open app with a Space assignment and
an App Bar slot. No rule needed — `ignore_rules` remains the
whole-app escape hatch for anything the heuristic misses.

### app_rules

**Expects:** a Lua table mapping app **bundle identifiers** to
space identifiers.

**Does:** new windows of listed apps go to their assigned space.
As with `float_rules`, an app is named by its bundle identifier
(case-insensitive), not its display name. See [Finding a bundle
identifier](#finding-a-bundle-identifier).

**Example:**

```lua
app_rules = {
    ["com.spotify.client"] = "music",
    ["com.apple.mail"]     = "mail",
}
```

The global base lives in `gui.json` when GUI-managed, or in this
`init.lua` otherwise. A stored profile may carry a **sparse per-app
override** (`app_rules` in
the profile JSON): a listed app takes the profile's space while
that profile is active, a `null` entry un-pins an app the base
pins, and unlisted apps inherit the base rule. Edit it from the
Settings app's App Rules section while editing a stored profile.
Profile overrides resolve the same way over a Lua-owned base.

### Finding a bundle identifier

App rules and `pull_or_spawn` identify an app by its bundle
identifier. The Settings app's pickers handle this for you —
they list installed apps by name and store the identifier
behind the scenes. To find one by hand:

- Run `kiwidesk get_state` (or the `get_state` command over
  IPC): every window carries a `bundle_id` field alongside its
  display `app` name. Focus a window of the app and read it off.
- Or ask macOS directly:
  `osascript -e 'id of app "Safari"'` →  `com.apple.Safari`.
- Or `mdls -name kMDItemCFBundleIdentifier /Applications/Safari.app`.

Identifiers are matched case-insensitively, so the case you
write does not matter. An app with no bundle identifier (a rare
unbundled helper process) cannot be targeted by a rule.

## Making Windows Floating or Tiled

### make_floating

**Expects:** nothing.

**Does:** marks the focused window as floating. It is no longer
tiled: it keeps whatever frame you give it, on the virtual
space it belongs to — like a tiled window, it hides with its
space and reappears where you left it when you switch back. (A
window that should stay visible on *every* space is a [sticky
window](#sticky-windows), not a floating one.) A floating
window is always kept **above** the tiled plane: focusing or
cmd-tabbing to a tiled window no longer buries the float behind
it, and two overlapping floats stack most-recently-focused on
top. (To exclude a window from tiling *without* pinning it
above others, use `ignore_rules` — KiwiDesk then leaves its
z-order untouched.) The override
survives the window closing and reopening (matched by app name
and title; a window that closes while untitled has no identity
to match and loses it) and applies only to that window — use
`float_rules` to float every window of an app.

**Example:**

```lua
KiwiDesk.make_floating()
```

### make_tiled

**Expects:** nothing.

**Does:** marks the focused window as tiled. It returns to its
space's tiling layout. Like `make_floating`, the override
survives the window closing and reopening.

**Example:**

```lua
KiwiDesk.make_tiled()
```

### make_auto

**Expects:** nothing.

**Does:** clears the focused window's manual override — the
third state of the float tri-state (floating-manual /
tiled-manual / auto). The window returns to detection control:
`float_rules` and the built-in dialog/panel detection apply
again, including future rule edits, and the close/reopen
memory of the window's current identity is forgotten. (A
remembered intent stored under an *older* title can still
resurface after a reopen — run `make_auto` again once the
window shows the wrong state and it is purged for good.) Use
it when a window "sticks" floating or tiled after a
`make_floating`/`make_tiled` you no longer want.

**Example:**

```lua
KiwiDesk.make_auto()
```

### toggle_floating

**Expects:** nothing.

**Does:** flips the focused window between floating and tiled in
one verb — if it is effectively floating it becomes tiled, and
vice versa. Like `make_floating`/`make_tiled`, it writes an
explicit manual override (which survives close/reopen); it never
produces the `auto` state, so `make_auto` stays the way back to
detection control. This is the everyday float shortcut (bound to
`control+option+f` by default and the only float verb offered in the
Settings shortcut list); the explicit `make_*` verbs remain for
scripts that need a specific direction.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+f", function()
    KiwiDesk.toggle_floating()
end)
```

## Sticky Windows

A **sticky** window stays present on every virtual space
instead of hiding with its home space when you switch — the
macOS-native analog is Mission Control's "Assign To → All
Desktops". Stickiness is a per-window flag, flipped on a
specific live window after it spawns; there is no app-matcher
rule list. It is orthogonal to floating: a floating sticky
window keeps its own frame everywhere, while a tiled sticky
window tiles into every space's layout — on whichever space is
active it joins the tiled members at a position derived from
its position among its home space's tiles (clamped to the
target space's count; nothing is stored). The flag survives
the window closing and reopening (matched by app name and
title, like the float override), and the window remains a real
member of exactly one space — its home; presence everywhere is
derived. Reordering the window on its home space therefore
moves its derived slot on every space, while reordering it on
a foreign space is not supported: a swap or bar drag targeting
it there does nothing. On a crowded space a tiled sticky
window keeps a fully visible slot instead of falling into the
overflow cascade — a non-sticky window overflows in its place.

Sticky comes in two scopes:

- **Sticky** (`make_sticky` / `toggle_sticky`) — present on
  every space of **every** monitor. Wears the `infinity` (∞)
  mark.
- **Display sticky** (`make_display_sticky` /
  `toggle_display_sticky`) — present on every space of **one**
  monitor: the display its home space lives on. Wears the
  `pin.fill` (📌) mark.

Both share one off-switch (`make_unsticky`), and each verb sets
its own scope outright — `make_sticky` on a display-sticky window
turns it global, and vice versa. On a single monitor the two
scopes coincide (one monitor is every monitor).

Moving a sticky window with `move_to_space` is guarded, since its
whole point is to stay put: a **global** sticky refuses any
target (it is already everywhere); a **display** sticky refuses a
target on the *same* monitor but accepts one on *another* monitor,
which re-homes it to that display. A refused move surfaces a brief
pill on the window rather than silently doing nothing.

Because a sticky window can look identical to a normal one,
KiwiDesk marks it: a mark in the window's top-right corner
(toggleable — see `sticky.set_mark`; `infinity` for global,
`pin.fill` for display) and the same per-scope badge on its Space
Bar glyph — which travels with you, listed under whichever space
is current (see `space_bar.set_sticky_badge`).

Prefer sticky over an `ignore_rules` entry for "keep this
visible everywhere": an ignored window loses tracking, focus
navigation, borders, and its bar tile; a sticky window stays
fully managed.

### make_sticky

**Expects:** nothing.

**Does:** marks the focused window **globally** sticky — it stays
visible on every virtual space of every monitor. No mode
argument: the window keeps its existing floating or tiled state.
Overrides display sticky if the window already had it.

**Example:**

```lua
KiwiDesk.make_sticky()
```

### make_display_sticky

**Expects:** nothing.

**Does:** marks the focused window sticky to its **current
monitor** — it stays visible on every space of that one display,
but not on other monitors. Moving it to a space on another
monitor re-homes it there. Overrides global sticky if the window
already had it.

**Example:**

```lua
KiwiDesk.make_display_sticky()
```

### make_unsticky

**Expects:** nothing.

**Does:** clears the focused window's sticky flag — it hides
with its home space again like any other window.

**Example:**

```lua
KiwiDesk.make_unsticky()
```

### toggle_sticky

**Expects:** nothing.

**Does:** flips the focused window between **global** sticky and
off in one verb. This is an everyday sticky command, offered as a
bindable row in the Settings shortcut list; the explicit `make_*`
verbs remain for scripts that need a specific direction. Toggling
global on a display-sticky window switches it to global.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+s", function()
    KiwiDesk.toggle_sticky()
end)
```

### toggle_display_sticky

**Expects:** nothing.

**Does:** flips the focused window between **display** sticky (its
current monitor only) and off in one verb. The coarse-to-fine
peer of `toggle_sticky`, also offered in the Settings shortcut
list. Toggling display on a global-sticky window switches it to
display.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+d", function()
    KiwiDesk.toggle_display_sticky()
end)
```

### sticky.set_mark

**Expects:** boolean (default `true`).

**Does:** shows or hides the on-window sticky mark — the small
glyph at a sticky window's top-right corner. Applies exactly
what you set: turning it off while the Space Bar is also off
leaves sticky state with no mark at all, which is a valid
power-user choice from Lua (the Settings app, by contrast,
keeps the mark forced on while the Space Bar is off).

**Example:**

```lua
sticky.set_mark(false)
```

### sticky.set_color

**Expects:** a hex color string `#RRGGBB` or `#RRGGBBAA`, or an
empty string `""` for **Automatic** (default `""`).

**Does:** tints the sticky mark — both the on-window mark and the
Space Bar sticky badge read this one value, so the mark is the
same color everywhere. The mark becomes a filled disc in the
color with a legible auto-contrast glyph. `""` is Automatic: the
badge keeps the count-badge fill and the mark is a neutral glyph
on glass that flips black/white with light and dark mode (the
shipped look). Any non-empty value must parse as a hex color.

**Example:**

```lua
sticky.set_color("#3D6FE8")  -- a blue sticky mark
sticky.set_color("")          -- back to Automatic
```

### floating.set_color

**Expects:** a hex color string `#RRGGBB` or `#RRGGBBAA`, or an
empty string `""` for **Automatic** (default `""`).

**Does:** tints the Space Bar floating badge — a filled disc in
the color with an auto-contrast glyph. Floating windows have no
on-window mark (they float above the tiles, so they are
self-evident), so this affects the Space Bar mark only. `""` is
Automatic (the badge keeps the count-badge fill); any non-empty
value must parse as a hex color.

**Example:**

```lua
floating.set_color("#8E5DE0")
```

## Launching Apps

### pull_or_spawn

**Expects:** an app bundle identifier (e.g. `com.apple.safari`).
See [Finding a bundle identifier](#finding-a-bundle-identifier).

**Does:** if the app is already running, focuses its window. If it
is not running, launches a new instance. Matching and launching
are keyed on the bundle id, so it finds apps anywhere on disk
(including Finder and apps outside `/Applications`) regardless of
system language.

Pressing again while one of the app's windows is focused advances
to the app's **next** window — space order (the order spaces were
created, the same order the Space Bar lists them), then slot
order within a space, wrapping around — so repeat presses cycle
through all of the app's windows. With a single window a repeat
press changes nothing. The cycle covers the windows KiwiDesk
currently tracks; the app's windows on another native macOS
desktop are untracked while you are away and rejoin the cycle
when you return to their desktop — see
[Accepted limitations](accepted-limitations.md).

If the app has **nothing on screen** — typically every one of its
windows minimized — the shortcut restores exactly one and brings
the app forward. It picks the window you minimized most recently;
when KiwiDesk was not running to see the minimize (the windows
were already parked before it launched, say) there is no such
record and the app's own window order decides. While any window
is still visible, minimized windows are left alone: the shortcut
focuses and cycles the visible ones and never pulls a window back
out of the Dock. A window on another native macOS desktop does
not count as on screen — see
[Accepted limitations](accepted-limitations.md).

**Example:**

```lua
KiwiDesk.bind("ctrl+return", function()
    KiwiDesk.pull_or_spawn("com.apple.safari")
end)
```

### spawn_new

**Expects:** an app bundle identifier (e.g. `com.apple.Terminal`).
See [Finding a bundle identifier](#finding-a-bundle-identifier).

**Does:** always launches a new instance of the app, even if one is
already running. Matching is keyed on the bundle id, exactly like
`pull_or_spawn`.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+return", function()
    KiwiDesk.spawn_new("com.apple.Terminal")
end)
```

Both launch verbs are also reachable from the Settings app: an Open
applications shortcut carries a per-row **Launch behavior** menu —
*Open or Focus* (`pull_or_spawn`, the default) or *Open New*
(`spawn_new`).

## User Interface

### show_shortcuts

**Expects:** nothing.

**Does:** opens the read-only **shortcuts reference** panel — a
live glance at the active mode's bindings — or closes it if it is
already open (the verb toggles). Bind it to a hotkey to summon the
reference from anywhere. This is the same panel reached from the
menu bar's *View Shortcuts…* row; the bound combo also shows beside
the menu row and in the panel's own close hint. It is seeded to
**⌃⌥K** by default, in the base mode and in every mode you create,
so the reference is reachable from the keyboard out of the box.

It is also offered as a bindable preset in the Settings app under
**Shortcuts ▸ General** ("Show shortcuts panel"), where you can
rebind or clear it per mode without hand-writing Lua.

**Example:**

```lua
KiwiDesk.bind("alt+space", function()
    KiwiDesk.show_shortcuts()
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
    ["j"]      = function() KiwiDesk.resize("y", -50) end,
    ["k"]      = function() KiwiDesk.resize("y", 50) end,
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

**Does:** grows or shrinks the focused window. A **floating**
focused window resizes itself directly, in every layout mode:
`"x"` changes its width by the delta, `"y"` its height, top-left
corner anchored, floored at `min_window_size` (a window already
smaller than that just shrinks no further). Tiled windows
only resize in bsp, stack, scrolling, and track layouts —
monocle, grid, and the floating layout report "not supported",
and when that failure comes from a **hotkey** press KiwiDesk
plays the system alert sound so the no-op is perceivable at
the keyboard (the Cmd+Z-with-nothing-to-undo idiom; #184).
Mute it with `set_resize_feedback(false)` — CLI and IPC
callers never hear it, they read the error JSON. What the
`delta` actually adjusts depends on the layout:

- **bsp** — per-axis (#56): `"x"` nudges the side-by-side split
  ratio (`bsp.set_ratio_h`), `"y"` the stacked one
  (`bsp.set_ratio_v`) — genuinely independent width and height.
  Focus-aware in direction (#122): a positive delta grows the
  *focused* window's region, so with a right/bottom window
  focused it lowers the shared ratio — the same side rule a
  mouse drag of that window's edge uses. All same-orientation
  splits still share the one ratio; with no focused window the
  delta moves the left/top region, as before. Like the stack,
  the write stops at the bound that keeps both regions at
  `min_window_size` within the area the layout fills (#383) —
  the display minus any Space Bar strip — so a resize no longer
  suddenly collapses the split into an overlap pile.
- **stack** — focus-aware (#67). `"x"` moves the master/stack
  split *in the direction that grows the focused window*: with
  a master focused, a positive delta raises the master ratio;
  with a stack window focused, it lowers the ratio (the column
  grows). The write stops at the bound that keeps both zones
  at `min_window_size` within the area the layout fills (#44).
  `"y"`
  grows or shrinks the focused window's vertical
  share of its column via per-window weights — session-scoped,
  never saved to a profile, and reset when a window leaves the
  space or KiwiDesk restarts. If the focused window is alone in
  its column, `"y"` reports an error.
- **scrolling** — it adjusts the slot size in real points along
  the layout's own scroll axis (columns for horizontal, rows for
  vertical), regardless of which `axis` you pass — the `x`/`y`
  argument does not steer it.
- **track** — every resize has one true target (#128, the
  point of the layout). The axis **across** the tracks (`"x"`
  for columns, `"y"` for rows) grows or shrinks the focused
  window's whole *track*; the axis **along** them grows the
  focused window's *share within its track* — the same
  per-window weights as the stack's `"y"` path, with the same
  session-scoped lifetime and `min_window_size` cap. A single
  track cannot trade cross-axis space, and a window alone in
  its track has no share to grow; both report an error.

**Where the ratio write lands (#458):** a space with an authored
per-space override of the field (`bsp.set_ratio_h_override`, the
Settings override editor) keeps editing that override. A space
*without* one stores the value in a **session layer scoped to
that space** — the shared global never moves, so resizing one
space no longer visibly resizes every other no-override space,
and no override is silently authored on your behalf. Session
values behave like the stack's per-window weights: never saved
to a profile, gone on restart, reseeded from config on a real
mode change, `reload_config`, `load_profile` (or any other
explicit profile/preset/GUI apply), and dropped for a field the
moment you set its global explicitly (`bsp.set_ratio_h`,
`stack.set_master_ratio`, `scroll.set_slot_size` — an explicit
write always shows everywhere). This covers the BSP split
ratios, the stack master ratio, and the scrolling slot size —
the three interactive-resize knobs — consistently.

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
| `focus_change` | `window_id`, `app`, `bundle_id` |
| `monitor_change` | `monitor_count` |
| `native_space_change` | `native_space` (desktop number) |
| `window_created` | `window_id`, `app`, `space`, `reason`, `bundle_id` |
| `window_destroyed` | `window_id`, `app`, `space`, `reason`, `bundle_id` |
| `window_moved_to_space` | `window_id`, `app`, `from`, `to`, `bundle_id` |

The window lifecycle events fire even when focus does not change (a
background window opening or closing), so status bars stay current
without polling. `space` is always the space the window lives in —
for `window_destroyed`, the one it disappeared from, even when that
space is not active. In the CLI event stream the key is `space_id`
(matching `space_change`) and an unknown space is JSON `null`; the
Lua callback receives `""` instead, since a positional `nil` would
truncate the argument list.

Every window event also carries the owning app's `bundle_id` — the
stable identity key that app rules (`float_rules`, `app_rules`) and
`pull_or_spawn` match on, unlike the locale-dependent display `app`
name. It is the trailing Lua argument (skip it if you don't need
it), `""` for unbundled processes; in the CLI event stream the key
is `bundle_id`, JSON `null` when unknown.

`window_moved_to_space` fires on an explicit `move_to_space`
(with or without follow) when the target differs from the window's
current space. Bulk reassignments — profile loads, session restore —
stay silent. JSON keys: `from_space_id` (null if unknown) and
`to_space_id`.

The lifecycle events track the *visible window set*, not app
lifecycle — windows also *appear to* come and go: deminiaturizing
surfaces as `window_created`, and switching native macOS Spaces
makes every managed window on the old desktop vanish from the
accessibility tree and reappear on return. The `reason` argument
says which kind of change fired:

- `window_created` — `"new"` (a genuinely new window),
  `"returned"` (back from another native desktop or a session
  restore), `"restored"` (deminiaturized).
- `window_destroyed` — `"closed"` (a real close), `"minimized"`
  (it will come back as `"restored"`), `"vanished"` (its native
  desktop was switched away; it comes back as `"returned"`).

So a bar callback that only cares about real lifecycle filters in
one line:

```lua
KiwiDesk.on("window_destroyed",
    function(id, app, space, reason)
        if reason ~= "closed" then return end
        KiwiDesk.exec("sketchybar", {
            "--trigger", "window_closed",
        })
    end)
```

One caveat: a window closed *while its native desktop is
off-screen* already emitted `"vanished"` at switch time and never
gets a corrective `"closed"`. If you filter on reasons, also
refresh on `native_space_change` — the re-query pattern in the
sketchybar recipe does this already.

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

- `timeout` — an optional number of seconds. If the command has
  not exited by then, it receives SIGTERM and the callback is
  still invoked with the termination code. **Defaults to 30 s**
  when omitted, so a wedged hook command can never accumulate
  without bound — hook commands finish in milliseconds, so the
  deadline only bites a genuine hang. Pass `0` (or a negative
  number) for *no* limit, for a deliberately long-running command.
- `dedup` — an optional boolean, **default `true`**. While an
  identical `command` string is already running, a second `exec`
  of it is skipped (returns `nil`) rather than spawning again. For
  trigger-style pokes — `sketchybar --trigger …`, where the
  handler re-reads full state anyway — this is the correct
  semantics: a second poke while one is pending adds nothing, and
  it caps a wedged receiver at one stuck child per command instead
  of a per-event pile-up. Pass `false` for commands you genuinely
  want to run in parallel with an identical copy of themselves.
  Note a skipped call **does not invoke its callback** — no child
  ran — so don't rely on a callback firing for a command that may
  still be in flight.

**Does:** starts the command in the background and returns
immediately — KiwiDesk never waits for it. Returns the child's pid
(a number), or `nil` when the command could not be started **or was
skipped as a duplicate** (see `dedup`). If the config reloads before
the command finishes, the callback is dropped silently.

**Output cap:** stdout and stderr are each capped at ~1 MB. Output
beyond the cap is still read (so the child never blocks writing), but
the string delivered to the callback is truncated and ends with
`[output truncated at 1 MB]`.

**Quit policy:** exec children are fire-and-forget. When KiwiDesk
exits, running children are re-parented to launchd and finish
naturally — a `sketchybar --notify` hook will complete even if
KiwiDesk quits first. The 30 s default `timeout` still bounds each
one; pass `timeout = 0` for a command that must be allowed to run
indefinitely.

**Hanging hooks:** when the number of outstanding children crosses
20, KiwiDesk logs a warning (`N exec children outstanding — a hook
command may be hanging`). The live count is also on
`get_state().exec_running`. With the default `timeout` and `dedup`,
even a permanently wedged receiver leaves at most one stuck child
per distinct command, reaped every 30 s.

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

-- No limit (deliberately long-running), and opt out of dedup so
-- two identical copies can run at once:
KiwiDesk.exec("long-running-tool", nil, 0, false)
```

### os.execute

**Expects:** a command string, like standard Lua. Calling it with no
argument keeps its stdlib meaning ("is a shell available?") and
returns `true`.

**Does:** forwards the command to `KiwiDesk.exec` and returns `true`
**immediately** — it does *not* wait, and the return value says
nothing about whether the command succeeded. When you need the exit
code or output, use `KiwiDesk.exec` with a callback instead.

Because it routes through `KiwiDesk.exec`, `os.execute` inherits its
defaults: a 30 s timeout and identical-command dedup. A genuinely
long-running `os.execute` is killed at 30 s — call `KiwiDesk.exec`
directly with `timeout = 0` for one that must run unbounded.

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
termination. If you want to restart KiwiDesk use `kiwidesk service restart` from a terminal or a keybinding via `KiwiDesk.exec`.

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
assignments — plus, optionally, **sparse keybinding and window-rule
overrides** that shadow the base only while the profile is active.
The global declarations live in `gui.json` when GUI-managed, or in
your hand-written `init.lua` otherwise. `app_rules`, `float_rules`,
and `ignore_rules` all have a per-profile tier; profile bindings do
not, because they select the profile itself.

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
`gap.override`, `bsp.set_ratio_h` becomes `layout.bsp.ratio_h`.

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
        "border_color": "#347957", "border_width": 5,
        "border_alignment": "inside",
        "fill": true, "fill_color": "#34795740"
      },
      "drop_zone": {
        "enabled": true, "border": true,
        "border_color": "#C2790A", "border_width": 5,
        "border_alignment": "inside",
        "fill": true, "fill_color": "#C2790A40"
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
        "ratio_h": 0.5,
        "ratio_v": 0.5,
        "strategy": "longest_side"
      },
      "grid": { "columns": 3, "rows": 2, "type": "dynamic",
                "fill_empty_space": true,
                "split_direction": "horizontal",
                "new_window_placement": "last" },
      "monocle": { "orientation": "horizontal",
                   "app_bar": { "enabled": true,
                                "edge": "top",
                                "background_style": "boxed",
                                "item_size": 0 } },
      "scroll": { "anchor": "follow", "slot_size": 0,
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
settings. Unsure which number you're on? Check
`kiwidesk get_state` (field `native_space`), or subscribe to the
`native_space_change` event.

KiwiDesk resolves one active native Desktop number and one active
profile across the whole display setup. For predictable bindings on
multiple displays, turn off macOS's "Displays have separate Spaces"
option and log out and back in. Basic tiling still works when the
option remains on, but independent Desktop choices on each display
cannot map unambiguously to the single active profile.

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
animations.set_duration(150)
```

### animations.set_scroll_speed

**Expects:** a number (milliseconds, clamped 50–1000).

**Does:** sets the scrolling-layout focus-shift speed (independent
knob, also persisted per-profile).

**Example:**

```lua
animations.set_scroll_speed(150)
```

### animations.set_size_policy

**Expects:** `"smooth"` (default) or `"mid_slide"`.

**Does:** picks how a window's size is applied while it animates
(issues #47, #593). Engine-only and **not persisted** to a profile
— an expert knob (like the bars' `dim_factor`), Lua-only and absent
from Settings. Set it from `init.lua` to make an override stick
across launches.

- `"smooth"` (default) — a growing axis follows the animation
  continuously. By default the size updates **per display tick**
  (matching the position channel, on any refresh rate), so slow-AX
  apps (Electron/WebKit: VS Code, Slack, Discord, Chrome) reflow
  once per frame. `animations.set_size_rate` can throttle that.
- `"mid_slide"` — the legacy fallback: a growing axis holds its
  start size, then grows in a single frame at halfway, where the
  ongoing slide masks the jump. Slow-AX apps reflow exactly once.
  Drop to this for an app that can't keep pace with `"smooth"`.

Shrinking splits by *what else is moving*, and only under
`"smooth"`:

- When every window in the change is being animated — a `resize`
  press, a ratio, gap or `min_window_size` edit — a shrinking axis
  follows the animation too, so the edge two panes share slides
  instead of jumping. Both panes travel on the same clock, so
  there is nothing for a gradual shrink to expose.
- When something is placed at its final size in one frame, it
  still takes its target on the first frame. A window that just
  opened is full size immediately, so a sibling that gave up its
  room gradually would sit *underneath* it for the length of the
  animation. This covers window open and close, mode and space
  changes — and a **mouse resize**, where the window you dragged
  is already where you left it when the rest catches up.

Under `"mid_slide"` a shrinking axis always takes the first frame.
Either way the exact target lands on the settle frame.

**Example:**

```lua
-- fall back to the legacy sizing for a stubborn app
animations.set_size_policy("mid_slide")
```

### animations.set_size_rate

**Expects:** a number (hertz, clamped 1–120). `0` or negative
restores the default **per-tick** behavior (no throttle).

**Does:** caps how often the `"smooth"` policy emits a size-set,
bounding a slow-AX app's reflow load. By default the size follows
the display refresh (per-tick); set a lower rate only if a heavy app
falls behind. It caps both directions — a plain resize that shrinks
one pane while growing another is where the load is highest. No
effect under `"mid_slide"`. Engine-only, not persisted (#47, #593).

**Example:**

```lua
animations.set_size_rate(30)   -- throttle a heavy app
animations.set_size_rate(0)    -- back to per-tick default
```

### animations.set_on_space_change

**Expects:** `true` or `false` (default `false`).

**Does:** enables or disables the coordinated animation when
switching virtual spaces: the outgoing windows slide out to the
hiding corner while the incoming ones slide in from it — one
toggle drives both directions. Off (the default) is faster: a
coordinated switch animates *both* spaces' windows at once, and
slow-responding apps (Electron/WebKit) can fall behind on the
extra per-frame window moves and stutter. Opt in if you like
the effect anyway.

Native macOS Space switches are never animated in either
direction — macOS stops reporting an inactive desktop's windows
to Accessibility, so there is nothing to fly around (see
[Accepted limitations](accepted-limitations.md)).

**Example:**

```lua
animations.set_on_space_change(false)
```

### animations.set_on_scrolling

**Expects:** `true` or `false` (default `true`).

**Does:** enables or disables the layout slide as focus moves within a
Scrolling space.

While the slide runs, a window focused *backward* (up/left)
toward the row pinned behind the leading edge is brought to the
front only when the pan settles — raising it first would pop
that pinned row over the whole screen before the slide starts.
Forward (down/right) focus moves and the focus handoff after
closing a window raise immediately, laying the target on top as
it slides in. The trade: during a backward slide (one animation
length, 50–1000 ms) keystrokes still reach the previously
focused app, as in other scroll-style window managers. Global
hotkeys are unaffected (they reach KiwiDesk regardless of the
key app), and with the slide disabled focus transfers
instantly. See the
[accepted limitations](accepted-limitations.md)
table.

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
machine wakes from sleep or the screen unlocks, after the specified
delay (default 1500 ms). The restore is skipped when the display set
changed while the machine was away (undock, monitor power-off): the
captured frames belong to the old displays, so the monitor-change
profile resolution wins instead. A restore that does run finishes
with a full retile, like any space switch.

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
the monitor its virtual space is assigned to and arranges them per
`quit.layout` (see `quit.set_layout` below), so the desktop is usable
the moment KiwiDesk exits. Floating windows are left wherever they are.
Because KiwiDesk keeps all managed windows on the single visible native
Space (inactive virtual spaces are parked off-screen at the peek
corner — not on a different native macOS Space), every reachable window
lands there together. Windows on a display's background native Spaces
cannot be repositioned without disabling SIP, which KiwiDesk never
does — the visible Space per display is the arranged scope.

### quit.set_layout

**Expects:** the string `"grid"` (the only strategy today; future
strategies will accept more values).

**Does:** picks how remaining managed windows are spread on quit.
`grid` builds a per-display grid and round-robin fills it — window 1
into cell 1, window 2 into cell 2, wrapping back to cell 1 and
stacking. Windows sharing a cell cascade vertically like
`overflow_all`, in **every** cell, so each title bar stays reachable.
After placing, KiwiDesk raises every window in a fixed circle —
cell 1 through the last cell, each pile top slot first and deepest
slot last — so within a pile every title bar stays visible and
later cells sit above earlier ones (one window is exempt; see
below). It waits for each raise to actually land before issuing
the next, because macOS reports a raise as accepted well before
the app performs it, and a circle fired off in one go settles in
whatever order the apps get to it.

The whole restack is capped at one second across every display, so
a wedged app cannot delay your quit past that. The cap is a hard
stop rather than a slow lane: once it is reached, nothing further
is raised — not the rest of the display being restacked, and not a
display the restack never got to. Those windows keep whatever
stacking the moves left them in. Quitting promptly is worth more
here than a perfect arrangement, because nothing runs afterwards
that could fix either one.

One window is exempt: **the key window of whichever app is
frontmost when KiwiDesk stops** — normally the window you were
last working in. No quiet raise can lift another window above it
(measured on device, not inferred), so KiwiDesk leaves it out of
the circle instead of spending the budget failing to move it. It
keeps the top of its pile, and that is the one place a title bar
can end up covered: the pile-mates the circle would have stacked
above it stay behind it instead. Every other window lands where
the circle puts it regardless of the z-order at quit — and if the
frontmost window when KiwiDesk stops is one of KiwiDesk's own, no
grid window is exempt at all.

A pile's windows also shrink so the cascade ends at its own cell's
bottom edge (floored at `min_window_size`), keeping piles from
spilling into the row below.
Each display sizes its own grid from its window count `N` and the
density target `T` (see `quit.set_grid_target_depth` below):
`ceil(sqrt(N / T))`, clamped between 2×2 and 4×4 — at the standard
target 5, up to 20 windows get 2×2, up to 45 get 3×3, beyond that
4×4. One-shot teardown placement: windows stay on their own display,
and nothing is managed afterwards. Profile JSON key: `quit.layout`.
Default: `grid`.

**Example:**

```lua
quit.set_layout("grid")
```

### quit.set_grid_target_depth

**Expects:** an integer between 1 and 20 (whole windows per cell).

**Does:** sets the quit grid's density target — the stack depth a
cell aims for before the grid grows a row and a column. Grid
dimensions stay automatic, calculated per display from that
display's window count, and stay hard-clamped between 2×2 and 4×4;
the target only moves the growth thresholds (2×2 through `4×T`
windows, 3×3 through `9×T`, 4×4 above). It is not a hard maximum:
past 4×4, additional windows keep cascading in its cells. Profile
JSON key: `quit.grid_target_depth`. Default: `5`.

**Example:**

```lua
quit.set_grid_target_depth(10)  -- denser piles, later growth
```

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
`focused` (focused window id or `nil`), and — only while a stack
column carries an uneven `resize("y")` split — `stack_weights`
(window id → session weight, #67). Track spaces additionally
carry `track_breaks` (ids of the windows that start a track,
#128) and, while a track holds an uneven cross-axis split,
`track_weights` (head window id → session weight).

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

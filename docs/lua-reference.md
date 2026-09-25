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

- Any single call into the VM is aborted after **500 ms**, so an
  accidental `while true do end` cannot freeze KiwiDesk.
- A callback (event handler or keybinding) that errors or
  times out is **disabled** and logged; everything else keeps
  working until the next `reload_config`.
- A typo'd function name on `KiwiDesk` or a layout table
  (`scroll.set_width(…)` for `scroll.set_slot_size(…)`) does
  **not** abort the config: the call becomes a no-op that logs
  a did-you-mean hint, and everything below it still runs.
  During a config load the typo is also reported in the menu
  bar's **Config Issues** window.

## Settings app vs init.lua

The Settings app stores its settings in
`~/.config/KiwiDesk/gui.json` plus profile JSON files.
**Saving never rewrites `init.lua`**: the file is yours, for
event hooks and custom Lua. For the GUI workflow, see the
[user guide](user-guide.md).

### What coexists with the Settings app, and what doesn't

Whether the Settings app or `init.lua` owns your configuration
depends on **what your `init.lua` declares**, not on whether the
file exists.

**Coexists — stays GUI-managed.** Anything that is not a setting
runs alongside `gui.json`: on first launch KiwiDesk seeds the
default profile, spaces and shortcuts, and your code runs too:

```lua
-- Event hooks, control flow, helpers, print, locals — all fine.
for _, event in ipairs({ "space_change", "focus_change" }) do
  KiwiDesk.on(event, function()
    KiwiDesk.exec("sketchybar --trigger kiwidesk_update")
  end)
end
```

**Makes `init.lua` the owner — Lua-managed.** Declaring any
*setting* hands ownership to the file: KiwiDesk does **not** seed
a `gui.json` over it, and the Settings app offers **Adopt into
the GUI** instead. Settings are:

- Any `set_*` verb on the `KiwiDesk` table — `set_mode`,
  `set_gap_global`, `set_min_window_size`, …
- Any namespaced layout setter — `bsp.set_ratio_h`,
  `stack.set_master_ratio`, `scroll.set_slot_size`,
  `grid.set_type`, `monocle.*`, `track.*`, `drag.*`, `border.*`,
  `app_bar.*`, `space_bar.*`, `animations.*`, `mouse.*`,
  `quit.*` — plus `border.fit_gaps`.
- Window-rule tables — `app_rules`, `float_rules`, `ignore_rules`.
- Keybindings — `KiwiDesk.bind`, `KiwiDesk.define_layer`,
  `KiwiDesk.bind_profile_to_desktop`.

:::unreleased
A [`kiwishelf.*`](#kiwishelf) setter counts as a setting too.
:::

```lua
-- Any one of these makes init.lua the config owner:
KiwiDesk.set_mode(1, "stack")
bsp.set_ratio_h(0.6)
float_rules = { "com.apple.calculator" }
```

To keep the GUI in charge, put settings like these in the
Settings app, or **Adopt** an existing file.

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
cycles, wrapping at the ends; scrolling steps to the
previous/next window and stops at the row's ends unless
`scroll.set_wrap_focus` is on. Cross-axis directions keep the
geometric search. The track layout steps in window order on
both axes: along the axis within the focused track, across it
to the neighboring track (same relative position); both stop
at the ends unless `track.set_wrap_focus` is on.

The search is two-tier: **tiled windows always win**, and only
when no tiled window lies in the pressed direction are the
space's *floating* windows (including floating sticky windows
shown on the space) considered, by their live frames. On an
axis with `wrap_focus` on, the wrap wins over the float tier: a
float past that edge is reachable on the cross axis only,
except with a single tiled window, when it is reachable on both
axes. Transient panels (Spotlight-style launchers) and
fullscreen windows are never focus targets. A float parked
*exactly* on a tiled slot is reached by no direction — click it
or cycle to it instead
([Accepted limitations](accepted-limitations.md)). `swap` is
tiled-only.

**Example:**

```lua
KiwiDesk.focus("left")
```

### swap

**Expects:** a direction (`"left"`, `"right"`, `"up"`, or
`"down"`).

**Does:** swaps the focused window with its neighbor in that
direction; the two trade slots in the layout. The neighbor is
found the way `focus` finds it, including the window-order
stepping on a monocle or scrolling orientation axis and in
track spaces, where a cross-axis swap trades the two windows
between their tracks and the track boundaries stay put. `swap`
never wraps at the ends, even with a wrap-focus toggle on.

**Example:**

```lua
KiwiDesk.swap("right")
```

### focus_space

**Expects:** a space identifier (number or string).

**Does:** switches to that space, hiding the current space's
tiled windows and revealing the target's. Keyboard focus
follows: the target's focused window (or its first window when
none is stamped) is raised and its app activated; switching to
an **empty** space hands focus to Finder. If macOS drops the
activation, the post-switch settle (~300 ms) detects the
unchanged frontmost app and re-raises once.

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
window is re-anchored onto that display: it keeps its
*proportional* position (a bottom-right float stays
bottom-right), clamped inside the target's usable area. Tiled
windows arrive through the layout; into a **floating-mode
space** every window is re-anchored the same proportional way.

A drop of a window onto a Space item in the Space Bar performs
the same move, re-anchoring a float the same way. Only a drag
that dwells long enough to **spring** the space open, where you
place the window yourself, keeps it where you released it (see
the user guide).

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

### focus_desktop

**Expects:** a macOS Desktop number — the number Mission Control
shows, the same one `bind_profile_to_desktop` keys on.

**Does:** switches to that Desktop — the *macOS* Desktop, not a
KiwiDesk Space — as a swipe would: the screen that Desktop
belongs to switches, and the bound profile, the remembered
Space and the `desktop_change` event all follow as they do for
a swipe.

**Returns** a table with `switched` — `true` when the screen
moved, `false` when that Desktop was already the one it showed,
with a `note` saying so. Either way the command succeeds; read
`switched` to tell the two apart.

Needs macOS's own window-management bridge, looked up at
runtime: present on macOS 26.6.1, and no earlier build has been
checked. It works on stock settings with SIP on. Where the
bridge is absent the command does nothing and logs why; from
the CLI it prints the error instead.

**Example:**

```lua
KiwiDesk.focus_desktop(2)
```

### move_to_desktop

**Expects:** a macOS Desktop number, and optionally a space
identifier — the KiwiDesk Space the window should join when it
gets there.

**Does:** moves the focused window to that Desktop **without
following** it. The window leaves KiwiDesk's view: the Desktop
you stayed on re-tiles without it, and the window is reported
gone with `reason: vanished`, the value a Desktop swipe
produces. When that Desktop is next shown the window rejoins
the **KiwiDesk Space it was in**.

:::unreleased
That Space is not always the one you arrive on: `focus_desktop`
opens a Desktop on the Space it remembers for it, and when that
Space is empty a focused-window verb refuses by name —
`the active Space 2 is empty; the focused window (Finder) is in
Space 1 — focus_space 1 first` — the window being parked in its
own Space until you focus that Space.
:::

When that Desktop lives on **another screen**, the window
instead joins the KiwiDesk Space that screen is showing when
the window lands there — for a hidden Desktop, the Space shown
at the moment you reveal it
([#1010](https://github.com/KiwiCanopy/KiwiDesk/issues/1010)).

**Given only a Desktop number**, a Desktop on the same screen
leaves the window's Space unchanged, and a **floating** or
**sticky** window keeps its Space on any screen
(`move_to_space` guards a sticky window the same way). With
**Stay visible across Desktops** on (the default), a sticky
window's move holds only until your screen next switches
Desktop, when it is carried back onto its own screen's current
Desktop; `override_sticky_reach("off")` first if you mean it to
stay. Same requirement as `focus_desktop`.

**Naming the Space**: `move_to_desktop(3, "mail")` sends the
window to Desktop 3 and files it into the `mail` Space, created
if it does not exist. When Desktop 3 is hidden, the window
rejoins `mail` when that Desktop is next shown; `mail` need not
be the Space that screen is showing, so the window may sit
parked until you switch to it. When Desktop 3 is already on
screen, the window joins `mail` at once, as
`move_to_space("mail")` would. A **floating** window is filed
too, and on a Desktop already on screen it is re-anchored onto
that screen the way `move_to_space` re-anchors one. A Space
**assigned to another screen** than that Desktop's is refused
([#1150](https://github.com/KiwiCanopy/KiwiDesk/issues/1150)).
A Space on **no screen yet** can be named only while one screen
is connected; with more, name a Space that lays out on that
Desktop's screen, or `pin_space_to_display` one there first. A
**sticky** window takes the guard `move_to_space` does: a
window sticky *everywhere* refuses any Space, and one sticky
*to a screen* refuses a Space on that screen while a Space on
another screen re-homes it
([#445](https://github.com/KiwiCanopy/KiwiDesk/issues/445));
where it refuses, the whole command is refused and the window
does not change Desktop. The second argument is Lua's and the
CLI's; the Shortcuts editor's Desktop rows bind the
one-argument form.

**Example:**

```lua
KiwiDesk.move_to_desktop(3)
KiwiDesk.move_to_desktop(3, "mail")
```

### move_to_desktop_and_follow

**Expects:** a macOS Desktop number, and optionally a space
identifier, as `move_to_desktop` takes.

**Does:** moves the focused window to that Desktop **and**
switches you there with it.

Keyboard focus ends on the window you sent. The pointer moves
only with *mouse follows focus* on.

If the target Desktop is **hidden**, focus lands a beat after
the switch, when the window reappears there
([#1007](https://github.com/KiwiCanopy/KiwiDesk/issues/1007)).
If it is already **shown**, focus stays with the window.

With more than one screen, a Desktop its own screen already
shows switches nothing; the window still moves, focus goes with
it, and the return table's `switched` is `false`, describing
the switch alone.

The window is placed as `move_to_desktop` places it, a named
Space included, and the focus you are handed is in that Space.
Same requirement as `focus_desktop`.

**Example:**

```lua
KiwiDesk.move_to_desktop_and_follow(3)
KiwiDesk.move_to_desktop_and_follow(3, "mail")
```

### move_space_to_display

**Expects:** a space identifier, then a display reference — a
**number** (1-based position: `1` is the main display,
`2` the next left-to-right) or a **string** matching a connected
monitor's fingerprint (as printed by `list_monitors`) or name.

**Does:** moves the whole space to that monitor **now** and
shows it there (each monitor shows one space at a time). A
later monitor change (dock/undock) re-resolves placement from
the pins; `pin_space_to_display` makes it stick. Creates the
space if it does not exist. Floating members are re-anchored
onto the new monitor, keeping their relative position.

**Example:**

```lua
KiwiDesk.move_space_to_display("mail", 2)      -- second monitor
KiwiDesk.move_space_to_display(3, "DELL U2723QE:3840x2160")
```

### pin_space_to_display

**Expects:** a space identifier, then a display reference (same
forms as `move_space_to_display`).

**Does:** pins the space to that monitor by the monitor's
fingerprint, so the assignment survives dock/undock. Overrides
any Main-role assignment for the space. Creates the space if
new.

Under a GUI-managed config the Settings **Canvas** owns pins,
and a pin set from Lua is a session override; under a
Lua-managed config the pin persists across a relaunch.

A screen this pin leaves with no space is seeded one — see
[Profile Monitor Sets](#profile-monitor-sets).

**Example:**

```lua
KiwiDesk.pin_space_to_display("mail", 2)
```

### create_space

**Expects:** a space identifier, and optionally a layout mode
(`"bsp"`, `"stack"`, `"scrolling"`, `"grid"`, `"monocle"`,
`"track"`, `"floating"`).

**Does:** creates the space and resolves it onto a display.
Spaces also appear the first time you reference one
(`focus_space`, `move_to_space`, a keybinding); this verb
declares one, and its mode, up front. If the space already
exists, only the mode is set.

**Example:**

```lua
KiwiDesk.create_space("scratch", "monocle")
```

### delete_space

**Expects:** a space identifier.

**Does:** removes the space after moving its windows to the
fallback space (or the first surviving space), and clears the
space from the placement pins, Main role, and per-space
settings. Refuses to delete the only space. Runtime only: a
space still declared in `init.lua` or the active profile
reappears on the next config load.

:::unreleased
**Returns** `nil` for a space nothing declares (and for a refused
delete, which is logged). When the space comes back on the next
config load, it returns a table whose `declared_in` array names
every source that re-creates it: `profile:<name>` (the active
profile — save it to make the removal last), `standard:<name>`
(the built-in layout resolving while no saved profile fits —
save a profile), `init.lua` (a verb there references it — remove
the call). Test the return, not the status (#1509).
:::

A screen this leaves with no space is seeded one — see
[Profile Monitor Sets](#profile-monitor-sets).

**Example:**

```lua
KiwiDesk.delete_space("scratch")
```

> **Renaming a space** has no Lua verb. Rename in the Settings
> app ([Space Identity](#space-identity)), or — with a Lua
> config — change the id in `init.lua` and reload.

### move_to_track

**Expects:** `"prev"` or `"next"` (exactly these — no
`previous` alias).

**Does:** in a track-layout space, moves the focused window
into the adjacent track in the sequence, joining it at its end.
The track verbs take **prev/next**, so the same binding keeps
working when the axis flips. On screen:

| Axis | `"prev"` | `"next"` |
|---|---|---|
| `vertical` (columns, default) | the column to the **left** | the column to the **right** |
| `horizontal` (rows) | the row **above** | the row **below** |

`prev` is the lower array index, `next` the higher. Past the
first or last track it opens a **new** track at that edge, as
`own_track` spawning does. Refused when the space is not in
track mode, when `track.set_limit` already caps the tracks, or
when the window already forms the edge track alone. Never
wraps. `focus` and `swap` keep left/right/up/down; only this
verb and [`track.swap`](#trackswap) take prev/next.

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

Switching to `floating` while any window sits partly or fully
outside the screen's visible bounds less any bar strips on that
space, or entirely inside another window's frame (a monocle
stack), lays the space's windows out in the quit grid
(`quit.set_layout`, sized by `quit.set_grid_target_depth`);
otherwise nothing moves.

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

**Does:** sets gaps for all spaces, carved out of the layout;
bars and windows never overlap. An auto-hiding menu bar's strip
is reclaimed. On MacBooks with a notch, the camera housing
stays reserved.

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
[cascade](#when-windows-no-longer-fit) instead of shrinking
further.

**Example:**

```lua
KiwiDesk.set_min_window_size(300)
```

### set_resize_step

**Expects:** a number (points).

**Does:** sets the magnitude the **Grow** / **Shrink**
keybindings nudge the layout by (default 50). The Shortcuts
catalog authors the four per-axis bindings as
`resize("x"|"y", ±step)` from this value, and importing a
config reads a recovered magnitude back into it. Moves no
window on its own; it takes effect the next time such a binding
fires.

**Example:**

```lua
KiwiDesk.set_resize_step(75)
```

### reset_layout_sizing

:::unreleased
**Expects:** optionally a space id, or `"all"`. Nothing means
the active space.

**Does:** returns the space's **sizing** — what `resize` and
mouse resizes accumulate — to what your profile (or `init.lua`)
set; `"all"` does it on every space at once. Cleared: the BSP
split ratios, the stack master ratio and the scrolling slot
size (the session layer described under [resize](#resize)),
the stack column's per-window weights and the track weights.
Kept: everything you configured — a per-space override's ratio
or slot size (`bsp.set_ratio_h_override`, the Settings override
editor) is what the space returns to, and a space with no
override lands on the global — and everything that is
structure: the layout mode, the BSP strategy, the master count,
orientation and stack position, the overflow style, the
scrolling anchor and orientation, the track axis and limit, a
grid's columns and rows, new-window placement. Where a window's
own minimum binds, the next retile's floor heal moves the ratio
back off that value by as much. Retiles at once. Unbound by
default; bind it from `init.lua` or the Shortcuts ▸ Lua
bindings drawer.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+equal", function()
    KiwiDesk.reset_layout_sizing()
end)
KiwiDesk.reset_layout_sizing("mail")
KiwiDesk.reset_layout_sizing("all")
```
:::

### set_swap_skips_cascade

**Expects:** `true` or `false` (default `true`).

**Does:** how a directional `swap` behaves when the focused
window sits in an overflow
[cascade](#when-windows-no-longer-fit). `true`: the swap skips
the windows piled with it and trades with the tiled neighbor
*outside* the pile in that direction, doing nothing when there
is none. `false`: the swap trades with whichever piled window
lies that way. Global (per profile, all spaces); `focus` is not
affected. No Settings toggle.

**Example:**

```lua
KiwiDesk.set_swap_skips_cascade(true)
```

### set_float_nudge

**Expects:** `true` or `false` (default `true`).

**Does:** whether toggling a window from tiled to floating
nudges it toward the screen center: up to 24 pt, tapering to
zero for a window already near the center, the same for every
window size. A window keeps its exact frame when it floats.
Fires on `make_floating` and a `toggle_floating` that lands on
floating, never on `make_tiled`. The target stays fully on
screen and clear of the menu bar and any App/Space Bar. Global
(per profile, all spaces); no Settings toggle.

**Example:**

```lua
KiwiDesk.set_float_nudge(true)
```

### set_float_scale_on_display_change

**Expects:** `true` or `false` (default `true`).

**Does:** whether a floating window re-anchored across displays
also scales its **size**. `true`: a float that crosses to a
differently sized display is scaled by the per-axis ratio of
the two displays — half of a 4K screen becomes half of a 1080p
one — as well as re-anchored to the same relative spot. Applies
wherever a float crosses displays (`move_to_space`, moving a
space to another display, a display-change sweep), and to
windows floating only because their space is in floating mode.
The result stays fully on screen and clear of any App/Space
Bar. `false` keeps the exact pixel size across displays: a
too-wide window then overflows the edge of a smaller display
(macOS clamps a window's height but not its width), and the
window keeps its aspect ratio between displays of different
aspect ratios (16:9 → 16:10). Global (per profile, all spaces);
no Settings toggle.

**Example:**

```lua
-- keep a float's exact pixel size across displays
KiwiDesk.set_float_scale_on_display_change(false)
```

### set_refusal_sound

**Expects:** `true` or `false` (default `false`).

**Does:** whether a blocked action's on-window message also
plays the system alert sound (#184, #1255). Every refusal draws
— a size limit reached, a layout with nothing to resize, a zone
with no such axis, a sticky window that cannot be swapped. A
refusal that could not draw — a sticky mark switched off, a
window with no overlay — stays silent.

Only hotkey fires cue; the same command over CLI/IPC stays
silent, and a held chord sounds once per hold. The GUI twin is
Behaviour ▸ When an action can't apply.

Stored as `refusal.sound`; the retired `resize.feedback` key is
dropped by the one-shot migration, its value not carried
across.

**Example:**

```lua
KiwiDesk.set_refusal_sound(true)
```

### set_shortcut_panel_liquid_glass

**Expects:** `true` or `false` (default `true`).

**Does:** lays a macOS&nbsp;26 Liquid Glass material over the
shortcuts panel, the one ⌃⌥K opens (#1307). Off, or below
macOS&nbsp;26, the panel draws `.regularMaterial`. The panel's
glass is untinted: it draws `.regular` where the bars draw
`.clear`, and no Fill reaches it (#1295).

Stored as `shortcut_panel.liquid_glass` in the profile, so a
profile switch can change the panel's material.

Also stood down while macOS's Reduce transparency is on, the
stored value untouched
([Liquid Glass](#kiwishelfset_liquid_glass)).

:::unreleased
The GUI twin is the one **Liquid Glass** switch on Colours
&amp; Animations;
[kiwishelf.set_liquid_glass](#kiwishelfset_liquid_glass) says
what it writes.
:::

**Example:**

```lua
KiwiDesk.set_shortcut_panel_liquid_glass(true)
```

### Space Identity

Spaces are identified by **strings or numbers** — `1` and `"1"`
are the same space, `"code"` and `"Code"` are not. Monitors
carry no layout; windows live in spaces, and spaces are mapped
to monitors (see *Profiles & Monitors* below). A space is
renamed in place from the Settings app's **Spaces** section; the
rename is persisted and follows the id everywhere it is used —
its layout mode, app rules, monitor pins, and any keybindings.

### How inactive spaces hide their windows

Switching spaces parks the other spaces' tiled windows in a
corner of their screen — [Parking is not a Desktop
move](spaces-and-desktops.md#parking-is-not-a-desktop-move)
owns the model. The switch is instant by default; with
`animations.set_on_space_change` it animates as a coordinated
slide, out to the corner and in from it (see Animations).
Focusing a hidden window (cmd+tab) pulls its space forward.
Floating windows, picture-in-picture included, are never parked
and stay visible across all spaces.

**Minimizing** a window removes it from its space. Restoring it
— from the Dock, or via [`pull_or_spawn`](#pull_or_spawn) when
the app has nothing left on screen — opens it in the space you
are on at that moment, as a new window (an `app_rules` entry
for its app still wins). **Hiding** an app (cmd+H, or an app
that hides itself on the red X) releases its tiles, and
unhiding returns its windows to the space they came from.

With **multiple monitors**, arrange your displays so no monitor
sits directly right of or below another one's bottom-right
corner, or the parked windows peek onto the neighbor
(illustrated in AeroSpace's [proper monitor arrangement
guide](https://nikitabobko.github.io/AeroSpace/guide#proper-monitor-arrangement)).

## Per-Layout Tuning

### bsp.set_strategy

**Expects:** `"longest_side"` or `"alternating"` (default
`alternating`).

**Does:** sets the BSP split strategy. `alternating` alternates
horizontal then vertical by depth; `longest_side` cuts the
longer side of each region, which keeps windows square-ish.

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

### bsp.set_new_window_placement

**Expects:** `"first"`, `"last"`, `"before_focused"`, or
`"after_focused"`.

**Does:** sets where a new window enters the BSP order. Default
`"after_focused"`: the new window takes the split right after
the focused window, which keeps its frame; the windows after it
move one split deeper.

**Example:**

```lua
bsp.set_new_window_placement("after_focused")
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

**Does:** sets which side of the space the stack zone takes;
the master zone gets the rest. `left`/`right` split the width,
`top`/`bottom` the height. The stack zone's lineup derives from
the position — a left/right zone stacks its windows vertically,
a top/bottom zone lines them up side by side; there is no
separate stack orientation knob. Overflow piles always cascade
downward. When the stack leads (`left`/`top`) and the masters
line up along the split axis, the master zone fills from the
stack seam, so a promoted window appears beside the stack it
left.

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

**Does:** sets where new windows enter the stack's order.
Default `"first"`: a new window becomes master.

**Example:**

```lua
stack.set_new_window_placement("last")
```

### stack.set_fill_when_alone

**Expects:** a boolean.

**Does:** `true` (the default): a single window takes the whole
usable area and starts sharing when a second window opens.
`false`: a lone window keeps the master zone it would have
beside a stack zone — the master ratio's share, on the master's
side of the split — and the stack zone stays empty; which
window holds that zone once a second opens is
`stack.set_new_window_placement`'s. On a screen too small to
hold two zones at `min_window_size` the lone window fills. Two
or more windows with no stack zone (every one a master) take
the whole area, so with a master count of two or more the kept
zone widens to the full area when the second window opens. The
Settings row is **If one window, fill the screen**; Scrolling
has the same toggle (`scroll.set_fill_when_alone`).

**Example:**

```lua
stack.set_fill_when_alone(false)
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

**Expects:** a number (macOS points), `"NN%"` (a percentage),
or `0` (auto, default).

**Does:** sets the size of columns (horizontal) or rows
(vertical) in scrolling layouts. Auto is 95%, horizontal and
vertical alike. Any resolved size is floored at the global
minimum window size (`set_min_window_size`) and capped at the
axis length.

A percentage is a share of the **pitch**, one window plus one
inner gap: `"50%"` is two windows, gaps included, `"33.33%"`
three. Points are absolute.

A row shorter than the axis keeps each slot at its size and
leaves the rest of the axis empty. A lone window fills the
available width or height unless its app refuses that size
([Accepted limitations](accepted-limitations.md)) or
`scroll.set_fill_when_alone` is off, when it keeps this slot
size. Accepted values: `%` clamps to 5–100%, points to ≥100.

**Example:**

```lua
scroll.set_slot_size(0)            -- auto
scroll.set_slot_size(400)          -- 400 pt
scroll.set_slot_size("50%")        -- two windows, gaps included
```

An interactive `resize` stops at both ends: it will not take
the slot below `min_window_size` (or an app's own learned
minimum), nor grow it past what fits on screen, nor past a
*maximum* the focused window's app enforces once KiwiDesk has
learned it (#1055). The app-maximum refusal bounces and pills;
the fits-on-screen stop stays wordless. The pill names the app
("This app won't go bigger", #1261); no setting caps a window's
maximum, and lowering `min_window_size` does not move it.

A size set *here* is not clamped: a slot wider than the screen
keeps that width and the layout draws what fits. A grow press
then does nothing; a shrink counts from what is *drawn*, not
from the stored number (#1057), and that resize rewrites the
stored value. When the focused window's app pins its size, a
press its bound blocks refuses in place with the pill and does
not resize the rest of the row.

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

Focusing a *floating* window leaves the viewport where it is
under any anchor.

The three fixed anchors are **absolute**: the focused window
rests where the anchor says, whatever the row's extent, so under
`start` the windows before it in the row leave the screen on
that side, and a lone window kept at its slot
(`scroll.set_fill_when_alone`) leaves the rest of the screen
empty. Only `follow` keeps the row's extent on screen: a row
shorter than the axis sits flush at the leading edge under it.

`follow` remembers where the *focused window* rested, not how
far the row was pushed. One slot size serves every slot, so
resizing one (`resize`, `scroll.set_slot_size`, a mouse edge
drag) moves every window along the row, and the focused window
keeps its place on screen while the row rearranges around it;
the same holds when a window opens or closes ahead of the focus.
On a reorder — `swap`, a window dropped onto another, a drag on
the App Bar — the two windows trade places, and the view pans
only when the moved window's new slot would fall outside it.
Under `follow` the row never reveals empty margin past its
ends; near a row end the focus re-anchors only as far as it can.

A window resting flush against the **trailing** edge of the
viewport keeps that edge when the row rearranges around it, and
the space it gives up reveals more of the window behind it; a
window filling the whole viewport keeps its leading edge.

**Example:**

```lua
scroll.set_anchor("follow")
```

### scroll.set_orientation

**Expects:** `"horizontal"` or `"vertical"`.

**Does:** sets the scroll direction. Horizontal: columns scroll
left/right. Vertical: rows scroll up/down.

Vertical rows overflow only at the bottom: a row scrolled past
the top stays pinned at the border with its upper strip peeking
behind the focused row
([Blocked by macOS (SIP)](design-decisions.md#blocked-by-macos-sip)).
On an edge with no screen beyond it, a slot scrolled far
offscreen keeps a small fixed sliver visible. An edge with
another screen beyond it is a wall: a scrolled-out slot stops
flush at the border, fully on its own screen, stacked behind
the visible ones, never resized and never rendered on the
neighbor screen. Which edges are walls follows your screen
arrangement, updated as a screen is plugged in or out.

**Example:**

```lua
scroll.set_orientation("horizontal")
```

### scroll.set_new_window_placement

**Expects:** `"first"`, `"last"`, `"before_focused"`, or
`"after_focused"`.

**Does:** sets where new windows land. Default
`"after_focused"`.

**Example:**

```lua
scroll.set_new_window_placement("after_focused")
```

### scroll.set_wrap_focus

**Expects:** a boolean (default `false`).

**Does:** `true`: stepping `focus` past either end of the row
wraps to the far end. `false`: focus stops at the ends. Applies
to `focus` only. Monocle has the same
toggle (`monocle.set_wrap_focus`), default off.

**Example:**

```lua
scroll.set_wrap_focus(true)
```

### scroll.set_fill_when_alone

**Expects:** a boolean (default `true`).

**Does:** `true`: a single window in a scrolling space takes
the whole width or height and starts sharing when a second
window opens. `false`: a lone window keeps the slot size
(`scroll.set_slot_size`) it would have beside a neighbour, and
the rest of the axis stays empty; where along the axis it rests
is `scroll.set_anchor`'s. The Settings row is **If one window,
fill the screen**; Stack has the same toggle
(`stack.set_fill_when_alone`).

**Example:**

```lua
scroll.set_fill_when_alone(false)
```

### scroll.set_slot_size_override

**Expects:**

- A space identifier.
- A slot size in macOS points (same shape as
  `scroll.set_slot_size`).

**Does:** overrides the global slot size for one space. In the
GUI: the space's **Customize…** override editor, slot-size
**Override** box (unchecked inherits the Layout Defaults value).

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

### grid.set_fill_empty_cells

**Expects:** `true` or `false`.

**Does:** if true, resizes windows to fill empty cells.

**Example:**

```lua
grid.set_fill_empty_cells(true)
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
(`floor(usable / (min_window_size + gap))` per axis, at least
1) — over the typed `columns`/`rows`. It caps a dynamic grid
and fixes a rigid one alike. Windows past the resulting
capacity cascade in the last cell.

**Example:**

```lua
grid.set_auto_size(true)
```

### grid.set_new_window_placement

**Expects:** `"first"`, `"last"`, `"before_focused"`, or
`"after_focused"`.

**Does:** sets where a new window enters the grid order. Default
`"last"`: appending keeps the existing cells in place.

**Example:**

```lua
grid.set_new_window_placement("last")
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

### grid.set_fill_empty_cells_override

**Expects:**

- A space identifier.
- A boolean.

**Does:** overrides the global fill behavior for one space.

**Example:**

```lua
grid.set_fill_empty_cells_override("3", false)
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
cycles through windows. Vertical: `focus("up"/"down")` cycles.

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

### monocle.set_hide_style

**Expects:** `"stack"` or `"park"` (default `"stack"`).

**Does:** sets how the unfocused monocle windows are hidden.
`"stack"` keeps them all at the full monocle frame behind the
focused one. `"park"` moves them to the corner of the screen
the space stash uses (a ~1 pt sliver stays visible per parked
window), and the focus switch snaps without animating.

Pick `"park"` when the stack shows through a window with a
transparent or blurred background, or through the side gaps
around a window that cannot fill the monocle frame
([Accepted limitations](accepted-limitations.md) on
app-enforced sizes). Mission Control shows the parked windows
at the corner.

**Example:**

```lua
monocle.set_hide_style("park")
```

### monocle.set_wrap_focus

**Expects:** `true` or `false` (default `false`).

**Does:** whether the focus cycle wraps past the ends. On,
`focus` past the last window returns to the first, and vice
versa; off, focus stops at the first/last window. `swap` never
wraps.

**Example:**

```lua
monocle.set_wrap_focus(false)
```

### monocle.set_new_window_placement

**Expects:** `"first"`, `"last"`, `"before_focused"`, or
`"after_focused"`.

**Does:** sets where a new window lands in the monocle cycle,
which is also its place in the focus order. Default `"first"`:
a new window comes to the front of the carousel.

**Example:**

```lua
monocle.set_new_window_placement("first")
```

### track.swap

**Expects:** `"prev"` or `"next"` (the
[`move_to_track`](#move_to_track) sequence vocabulary — see
its table for what prev/next means per axis: left/right for
columns, above/below for rows).

**Does:** swaps the focused window's **entire track** — its
windows, sizes and in-track shares — with the adjacent track in
the sequence; the window-level `swap` stays spatial. Never
wraps; refused when the space is not in track mode, no tiled
window is focused, or no track lies that way. Also refused when
the swap would touch the **overflow track** while it is folding
two or more tracks together — under a fixed limit
(`track.set_limit` with automatic tracks off) or on a display
too narrow to fit the tracks at `min_window_size`; raise the
limit or widen the display to reorder the overflow.

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

**Expects:** `0`, or an integer ≥ 2 (default `3`).

**Does:** sets how many tracks a space shows, the **overflow
track** counted. `0` restores the **automatic** track limit
(`track.set_auto_tracks`); a positive value pins the limit and
turns automatic off. The last track is the overflow track at
the far edge, which collects the surplus (#192): a new
`own_track` window past the normal tracks opens it, and further
windows fold into it, rendered per `track.set_overflow_style`.
`move_to_track` can open the overflow track but not go past it.
A monitor that cannot fit the tracks at `min_window_size` shows
fewer at render time. The last positive value is remembered and
restored when automatic is turned off again. A limit of 1 is
refused (#1354).

**Example:**

```lua
track.set_limit(3)
```

### track.set_auto_tracks

**Expects:** `true` or `false` (default `true`).

**Does:** whether the track limit is managed automatically. On,
tracks open and collapse as windows come and go, with no cap;
off pins the cap to `track.set_limit`'s value. The automatic
count honours the minimum sizes the windows' apps enforce once
KiwiDesk has learned them; a limit you set stays your number.

The track twin of `grid.set_auto_size`. `track.set_limit(0)`
turns this on; `track.set_limit(n)` turns it off with a cap of
`n`.

**Example:**

```lua
track.set_auto_tracks(false)
```

### track.set_new_window

**Expects:** `"focused_track"` (default) or `"own_track"`.

**Does:** decides where a new window lands in a track space.

- `focused_track` (**fill-then-spill**, the default): the window
  **joins** the focused window's track, placed among its windows
  by [`track.set_new_window_position`](#trackset_new_window_position),
  until that track cannot fit another window at
  `min_window_size`, when it **spills into a new track** beside
  the focused one. Focus follows the new window. With no room
  for another track under a fixed
  [`track.set_limit`](#trackset_limit) cap, or for a window
  `move_to_space` drops onto a full track, it piles in the
  focused track.
- `own_track`: each new window opens its **own** new track,
  positioned among the others by
  [`track.set_new_window_position`](#trackset_new_window_position).
  Falls back to joining once `track.set_limit` is reached.

The fill-then-spill boundary is how many windows fit at
`min_window_size`, so a smaller display spills sooner.

**Example:**

```lua
track.set_new_window("own_track")
```

### track.set_new_window_position

**Expects:** `"first"` (default), `"last"`, `"before_focused"`,
or `"after_focused"`.

**Does:** places the new window within the
[`track.set_new_window`](#trackset_new_window) choice. For
`own_track` it positions the **new track** among the others
(`first` = leftmost column / topmost row, `last` = the far edge,
`before`/`after_focused` = beside the focused track). For
`focused_track` it positions the window among that **track's
windows** (`first`/`last` = the track's ends,
`before`/`after_focused` = around the focused window). Default
`first`: a new window lands at the visible front.

**Example:**

```lua
track.set_new_window_position("after_focused")
```

### track.set_overflow_style

**Expects:** `"cascade_all"` (default) or `"cascade_overflow"`.

**Does:** shapes the **overflow track** only — the far-edge
track that collects the surplus when more tracks exist than fit
side by side at `min_window_size`. `cascade_all` piles all its
windows from the top as a title-bar cascade; `cascade_overflow`
keeps as many full windows as fit and cascades the rest. Every
**normal** track uses `cascade_overflow` for its own internal
overflow and stays tiled.

**Example:**

```lua
track.set_overflow_style("cascade_overflow")
```

### track.set_wrap_focus

**Expects:** a boolean (default `false`).

**Does:** the track twin of `scroll.set_wrap_focus` (#168): on,
stepping `focus` past an end wraps — within the focused track
along the axis, last ↔ first track across it; off, focus stops
at the ends. `swap` and `move_to_track` never wrap. Affects
track spaces only.

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
- `0`, or an integer ≥ 2.

The overflow track is counted, as in `track.set_limit`, and 1 is
refused.

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

## KiwiShelf

:::unreleased
**KiwiShelf** is the one screen edge both bars sit on — the
[App Bar](#app-bar) and the [Space Bar](#space-bar).
`kiwishelf.set_*` sets where the shelf hangs, how the two bars
share it, and the look, colours and app symbol style they share;
each bar keeps its own content and the shape of its active
indicator. Stored as `settings.kiwishelf` in a profile.

The shelf reserves its edge in a layout where a bar draws: in
every layout while the Space Bar is on, and otherwise only in
the layouts whose App Bar is on (monocle and scrolling show one
by default). With the Space Bar off, switching a Space between a
layout that shows an App Bar and one that does not moves its
windows by the strip.

While both bars show they are one plate with two sections, in
the order `set_order` gives them, placed along the edge as one
run by `set_alignment`, `set_item_gap` apart with a thin divider
between them. Each section is as long as its items need while
both fit. When they need more than the edge holds, the Space Bar
shrinks, never below its [minimum](#kiwishelfset_minimum), and
the App Bar takes the rest.

A section whose items overflow fades its content on each side
that cuts an item, with a count of the items not wholly shown
there; click the count to page, and a side at its end shows
nothing. The mouse wheel (either axis, tilt or shift-wheel) and
the trackpad scroll a section along the edge, natural scrolling
respected; a scroll or a page holds until the active Space or
the focus changes. While the shelf is full, drag the divider to
change the Space Bar minimum, as `set_minimum` does, and
double-click it to restore the default.
:::

### kiwishelf.set_edge

:::unreleased
**Expects:** `"top"`, `"bottom"`, `"left"`, or `"right"`
(default `"top"`).

**Does:** sets the screen edge the shelf occupies, for both bars
and every layout. The edge is absolute — it does not follow a
layout's orientation (#293).

**Example:**

```lua
kiwishelf.set_edge("bottom")
```
:::

### kiwishelf.set_alignment

:::unreleased
**Expects:** `"start"`, `"center"`, or `"end"`
(default `"center"`).

**Does:** places the shelf's run along the edge — a lone bar, or
both bars as one run. Values are edge-relative: a left edge's
`start` is its top, a top edge's `start` its left. Once the run
overflows, all three values behave the same.

When an App Bar section appears or leaves, the run grows or
shrinks, so the Space Bar moves unless the alignment anchors the
run at the Space Bar's end: `start` under `spaces_first`, `end`
under `apps_first`.

**Example:**

```lua
kiwishelf.set_alignment("start")
```
:::

### kiwishelf.set_order

:::unreleased
**Expects:** `"spaces_first"` or `"apps_first"` (default
`"spaces_first"`).

**Does:** sets which bar's section comes first in the run while
both show. Edge-relative, like `set_alignment`.

**Example:**

```lua
kiwishelf.set_order("apps_first")
```
:::

### kiwishelf.set_minimum

:::unreleased
**Expects:** a percentage of the edge, 20–80 (default `30`);
values outside the range are clamped.

**Does:** sets how much of the edge the Space Bar keeps once both
bars together need more than the edge holds: the Space Bar
shrinks to it and no further, and the App Bar scrolls instead.
A floor on shrinking, never a length the Space Bar is padded up
to — a Space Bar needing less keeps its own length and the App
Bar gets the rest. Whatever the minimum, the Space Bar keeps its
active Space and a fade each side in view.

**Example:**

```lua
kiwishelf.set_minimum(40)
```
:::

### kiwishelf.set_thickness

:::unreleased
**Expects:** thickness in points (default `40`; anything below
`20` is raised to it).

**Does:** sets the shelf's thickness — both bars' — carved out of
the layout.

**Example:**

```lua
kiwishelf.set_thickness(32)
```
:::

### kiwishelf.set_outer_margin

:::unreleased
**Expects:** points (default `0`; a negative value is raised to
it).

**Does:** sets the shelf's distance from the screen border; `0`
is flush. From the border inwards: outer margin, the strip, inner
margin, then the windows' own outer gap.

**Example:**

```lua
kiwishelf.set_outer_margin(10)
```
:::

### kiwishelf.set_inner_margin

:::unreleased
**Expects:** points (default `0`; a negative value is raised to
it).

**Does:** adds room on the shelf's window side, on top of the
windows' outer gap. The outer gap alone keeps the focus ring's
clearance, so `0` means the gap governs.

**Example:**

```lua
kiwishelf.set_inner_margin(4)
```
:::

### kiwishelf.set_background_style

:::unreleased
**Expects:** `"boxed"` or `"plain"` (default `"plain"`).

**Does:** sets WHERE the background is drawn, for both bars:
- **boxed** — a box per item honoring the corner roundness
  (0% = square, 100% = full capsule).
- **plain** — no per-item box; the items sit on a shared
  translucent plate, whose reach is `set_background_fit`.

Liquid Glass is a separate finish toggle, `set_liquid_glass`
(below), that lays over either style.

**Example:**

```lua
kiwishelf.set_background_style("plain")
```
:::

### kiwishelf.set_liquid_glass

:::unreleased
**Expects:** a boolean (default `true`).

**Does:** lays a macOS 26 Liquid Glass material over both bars'
item backgrounds (the boxes or the plate); it combines with
either shape. The shelf's
[`fill_color`](#kiwishelf-colours) tints the glass: a colored
layer sits behind the glass and the glass refracts it, strongest
at the shelf's screen edge and fading to an eighth of that
strength toward your windows.
The material's light or dark variant follows the fill too: a
dark `fill_color` pins the dark glass. A light `fill_color` pins
nothing — only the dark variant can be pinned — and the glass
follows KiwiDesk's Appearance setting instead: dark glass under
Dark, and under Light or System macOS's own choice, which the
bright tint normally holds at light. A fully transparent
`fill_color` leaves the glass clear. Ignored below macOS 26,
where the Settings toggle is hidden; the stored value still
round-trips so a profile stays portable.

Stood down, live, while macOS's Reduce transparency is on: the
bars draw their Boxed or Plain shape with the `fill_color` at
full alpha, the panel its plain material, and the drag visuals
and the sticky mark their flat look. The stored values are
untouched, so the glass and the alpha return the moment the
setting goes off (#1374).

Settings has no KiwiShelf row for this (#1307): one **Liquid
Glass** switch on Colours &amp; Animations writes this leaf, the
shortcuts panel's
([set_shortcut_panel_liquid_glass](#set_shortcut_panel_liquid_glass)),
the drag visuals' ([drag.set_liquid_glass](#dragset_liquid_glass))
and the sticky mark's
([sticky.set_liquid_glass](#stickyset_liquid_glass)) together,
and shows on only when all of them are on. This verb sets the
bars alone; setting them apart is a Lua-only state, and the
Settings switch then reads off and says so in its `?`.

**Example:**

```lua
kiwishelf.set_liquid_glass(true)
```
:::

### kiwishelf.set_background_fit

:::unreleased
**Expects:** `"full"` or `"hug"` (default `"hug"`).

**Does:** sets how far the one plate reaches under `plain` (and
the Liquid Glass finish over it). `hug` wraps the run — both
sections while both show — plus one item gap per end. `full`
spans the whole edge. A section whose items overflow fills its
part of the edge, so the plate reaches across it either way.
Inert under `boxed` (the Settings control greys there).

**Example:**

```lua
kiwishelf.set_background_fit("full")
```
:::

### kiwishelf.set_corner_roundness

:::unreleased
**Expects:** a number 0–100 (percentage; default `50`).

**Does:** sets the corner rounding of the plates and item boxes
of both bars, where 0 = square and 100 = a full capsule
(radius = thickness/2). Values above `100` render as `100`.

**Example:**

```lua
kiwishelf.set_corner_roundness(50)
```
:::

### kiwishelf.set_item_gap

:::unreleased
**Expects:** points (default `6`; a negative value is raised to
`0`).

**Does:** sets the gap between items, Space items and App Bar
items alike, and between the two bars while both show.

**Example:**

```lua
kiwishelf.set_item_gap(6)
```
:::

### kiwishelf.set_font_size

:::unreleased
**Expects:** points; `0` (default) means auto.

**Does:** if `0`, each bar's text scales with the thickness; any
positive value pins the font size for both bars.

**Example:**

```lua
kiwishelf.set_font_size(0)
```
:::

### kiwishelf.set_icon_source

:::unreleased
**Expects:** `"app_image"` or `"app_font"` (default
`"app_image"`).

**Does:** sets how app icons are drawn on both bars and in the
shortcuts panel's Apps band. `app_image` shows the app's icon as
macOS provides it, which follows the system-wide Icon & widget
style the user picked; the system's Dark, Clear and Tinted looks
are not separate choices
([Accepted limitations](accepted-limitations.md)). `app_font`
shows a monochrome glyph from the bundled [SketchyBar App
Font](https://github.com/kvndrsslr/sketchybar-app-font) instead,
colored by the shelf's item colours; apps without a glyph keep
their icon. On the Space Bar, an app with no image falls back to
the App Font either way.

**Example:**

```lua
kiwishelf.set_icon_source("app_font")
```
:::

### kiwishelf.set_dim_factor

:::unreleased
**Expects:** a number 0.05–1 (default `0.4`); out-of-range
values clamp.

**Does:** sets the opacity of untinted idle content on both bars
— an emoji identifier or app image on a Space you are not on, an
inactive App Bar item's icon; tinted content takes the item
colour instead. The Space Bar's middle tier is
[`space_bar.set_active_dim_factor`](#space_barset_active_dim_factor).
Lua-only (no GUI).

**Example:**

```lua
kiwishelf.set_dim_factor(0.4)
```
:::

### KiwiShelf colours

:::unreleased
Same `#RRGGBB` / `#RRGGBBAA` grammar as every other color
setting. One set of colours serves both bars; only the colour of
the focused window's glyph is the Space Bar's own
([`space_bar.set_focused_item_color`](#space_barset_focused_item_color)).

- `kiwishelf.set_fill_color` — the plate's one fill, or each
  item's box under `boxed` (default `#14201CB3`, dark moss at 70%
  opacity; every bundled palette's fill carries that same alpha).
  With the `liquid_glass` finish on it tints the glass, and a
  dark fill selects the dark glass variant
  ([Liquid Glass](#kiwishelfset_liquid_glass)). Under glass its
  opacity at the shelf's edge is held under a ceiling: a fill
  below it renders as you picked it, a more opaque one is capped,
  and the stored value is unchanged either way (Boxed/Plain use
  it in full, flat). While macOS's Reduce transparency is on,
  Boxed/Plain draw it at full alpha instead.
- `kiwishelf.set_item_color` — the items' text and glyphs
  (default `#EAF3EE`). An identifier on a Space you are not on
  draws it at 60% of its own alpha, and the divider between the
  two bars draws it at a fixed alpha of its own.
- `kiwishelf.set_active_item_color` — the active item: the
  current Space's identifier and glyphs, the focused window's
  App Bar item (default `#8DB354`, kiwi green).
- `kiwishelf.set_highlight_color` — both bars' active indicator,
  the outline or the edge mark (default `#8DB354`).
- `kiwishelf.set_hover_fill_color` /
  `kiwishelf.set_hover_item_color` — hover feedback on clickable
  items (defaults `#AACB5D80` and `#EAF3EE`); the App Bar's
  active item shows no hover and ignores clicks.
- `kiwishelf.set_group_badge_color` /
  `kiwishelf.set_group_badge_text_color` — the count and `+n`
  overflow badges (defaults `#636366` and `#FFFFFF`); on a Space
  you are not on they take [`dim_factor`](#kiwishelfset_dim_factor).

**Example:**

```lua
kiwishelf.set_fill_color("#14201CB3")
kiwishelf.set_active_item_color("#8DB354")
```
:::

### Retired bar verbs

:::unreleased
These verbs are retired. A call in `init.lua` is reported in
Config Issues, naming what replaces it where something does;
over the CLI it fails with
`<verb> was retired — use <replacement>`, or, for
`space_bar.set_item_size`, `…: a Space item's length follows its
content`.

- `space_bar.set_<field>`, `app_bar.set_<field>`,
  `monocle.set_app_bar_<field>` and `scroll.set_app_bar_<field>`
  for `edge`, `alignment`, `thickness`, `outer_margin`,
  `inner_margin`, `background_style`, `liquid_glass`,
  `background_fit`, `corner_roundness`, `item_gap`, `font_size`,
  `icon_source`, `dim_factor`, and the colours `item_color`,
  `active_item_color`, `highlight_color`, `hover_fill_color`,
  `hover_item_color`, `fill_color`, `group_badge_color` and
  `group_badge_text_color` → `kiwishelf.set_<field>`.
- `app_bar.set_item_size`, `monocle.set_app_bar_item_size` and
  `scroll.set_app_bar_item_size` → that bar's `title_cap`
  ([`app_bar.set_title_cap`](#app_barset_title_cap)): an App Bar
  slot is as wide as the widest title, so the title length is
  its one width control.
- `space_bar.set_item_size` → nothing: a Space item's length
  follows its content.
- `space_bar.set_title_cap` →
  [`space_bar.set_front_app_title_cap`](#space_barset_front_app_title_cap).

The `gap` active indicator is removed: `set_active_indicator`
and its per-layout twins refuse it, naming the values that
remain.

`init.lua` is not rewritten; a saved profile is, once, the first
time 2.0 reads it: the shelf takes the Space Bar's values,
colours and app symbol style included — the App Bar's where the
Space Bar is off, keeping the App Bar's old `bottom` edge where
it stored none — and every other copy is dropped, per-layout
App Bar colours with them, as is every stored `item_size`. Where
the Space Bar's item colour is the App Bar's at a lower alpha,
the shelf takes the App Bar's full colour, since an idle Space
identifier now dims it for you. A stored `gap` indicator becomes
`outline`, and an App Bar that names no indicator is given
`outline`, so only a fresh setup starts on the App Bar's new
`edge_mark` default. The Space Bar's stored `title_cap` becomes
its `front_app_title_cap`. Saved palettes are rewritten the same
way, and a palette file exported before 2.0 is converted as it
is imported. A profile, bundle or palette library 2.0 has
written is left as it is, and no longer opens in 1.x.
:::

## App Bar

The **App Bar** lists the windows of the current space in the two
layouts that can hide one — **monocle** and **scrolling**. Click
an item to focus its window, drag it to reorder; a window in
native fullscreen has no item until it returns. With several
monitors each display shows its own bar, on that display, for the
space it is showing, and dragging an item reorders that display's
space.

:::unreleased
The bar sits on [KiwiShelf](#kiwishelf), which sets its edge,
thickness, margins, background, colours and app symbol style.
Everything else about it is **global**: `app_bar.set_*` sets
every layout's bar. Each layout decides whether it shows one and
may override the App Bar's own fields for itself ([Per-Layout
App Bar Overrides](#per-layout-app-bar-overrides)).
:::

### app_bar.set_active_indicator

:::unreleased
**Expects:** `"outline"` or `"edge_mark"` (default
`"edge_mark"`).

**Does:** how the focused window is marked, in KiwiShelf's
[`highlight_color`](#kiwishelf-colours). It combines freely with
`background_style`:
- **outline** — an outlined border around the active item.
- **edge_mark** — an accent bar on the active item's
  window-facing edge.

**Example:**

```lua
app_bar.set_active_indicator("outline")
```
:::

### app_bar.set_content

**Expects:** `"icon"`, `"title"`, or `"icon_and_title"`
(default `icon_and_title`).

**Does:** sets what each item displays. The text is the
window's own **title**, not its app name. The app name appears,
never shortened, in two places:

- a **grouped** item (its members show titles once it expands);
- a window whose title is **empty** — some apps (Electron and
  WebKit ones especially) report no title until well after the
  window opens.

Vertical bars (edge `left`/`right`) always render icon-only; the
stored preference returns when the bar moves back to a
horizontal edge.

**Example:**

```lua
app_bar.set_content("icon_and_title")
```

### app_bar.set_title_cap

**Expects:** a character count, 8–80 (default `10`). Values
outside the range are clamped.

**Does:** sets how much of a window's title an item shows;
longer titles are cut at the end and marked with an ellipsis. A
title is also cut where it does not fit its slot; with
`icon_and_title` only the title shrinks, never the icon.

:::unreleased
Every slot is as wide as the widest item, at least the icon
square and at most a quarter of the whole KiwiShelf edge, so
the cap is the App Bar's one size control; items that then do
not fit scroll instead of shrinking.
:::

**Example:**

```lua
app_bar.set_title_cap(25)
```

### app_bar.set_group_adjacent_windows

**Expects:** `true` or `false` (default `true`).

**Does:** if true, collapses adjacent same-app windows into one
item with a count badge; same-app windows that are not adjacent
stay separate. Clicking a grouped item focuses its first window
and expands the group into its members; focus leaving the group
collapses it again.

**Example:**

```lua
app_bar.set_group_adjacent_windows(true)
```

### Per-Layout App Bar Overrides

:::unreleased
Each bar-hosting layout (monocle, scrolling) can override the
App Bar's own fields for itself — `enabled`, `active_indicator`,
`content`, `title_cap` and `group_adjacent_windows`. Only these
two layouts show a bar, so only they expose `set_app_bar_*`.
Unset fields inherit the global value.
[KiwiShelf](#kiwishelf)'s fields — its colours, symbol style and
`dim_factor` included — take no per-layout override. The
overrides are the same setters prefixed with the layout name:

- `monocle.set_app_bar_enabled`, `monocle.set_app_bar_content`,
  `monocle.set_app_bar_title_cap`, etc.
- `scroll.set_app_bar_enabled`,
  `scroll.set_app_bar_active_indicator`,
  `scroll.set_app_bar_group_adjacent_windows`, etc.

**Example:**

```lua
monocle.set_app_bar_enabled(true)
scroll.set_app_bar_enabled(true)
scroll.set_app_bar_content("icon")  -- override for scrolling
```
:::

## Space Bar

The Space Bar (#293) lists, per display, that display's Spaces
in profile order: each item shows the Space's identifier (its
configured icon, else the plain digits of a numeric id or a
two-letter monogram of a named one), a divider, then a glyph per
window. Adjacent windows of the same app share one glyph with a
count badge (non-adjacent duplicates stay separate); past the
glyph cap (`space_bar.set_glyph_cap`, default 5, range 1–12) the
rest fold into a `+n` badge counting the hidden windows. Clicking
a Space switches to it; glyphs are not click targets, and a group
holding the focused window stays collapsed and takes the focused
accent. The user guide's [Space Bar](user-guide.md#space-bar)
section covers the badges and the drag-onto-a-Space gesture.

:::unreleased
The bar is layout-independent and sits on
[KiwiShelf](#kiwishelf), which sets its edge, thickness, margins,
background, colours and app symbol style; every `space_bar.*`
setting is global, with no per-layout override. While a native-fullscreen app holds the
screen the bar hides; it returns with the Desktop.
:::

### space_bar.set_enabled

**Expects:** boolean (default `true`).

**Does:** shows or hides the Space Bar.

:::unreleased
With the Space Bar off, [KiwiShelf](#kiwishelf) reserves its
edge only in the layouts whose App Bar is on, and nowhere when
none is.
:::

**Example:**

```lua
space_bar.set_enabled(true)
```

### space_bar.set_glyph_cap

**Expects:** an integer `1`–`12` (default `5`); out-of-range
values clamp.

**Does:** sets how many app-group glyphs a Space item shows before
the rest collapse into the trailing `+n` badge. Grouping runs
first, so the cap counts app *groups* (adjacent same-app windows
share one glyph), while `+n` counts the hidden *windows*. It
limits glyphs per Space only, not how many Spaces the bar shows.

**Example:**

```lua
space_bar.set_glyph_cap(8)
```

### space_bar.set_active_indicator

:::unreleased
**Expects:** `"outline"` or `"edge_mark"` (default
`"outline"`).

**Does:** how the active Space is marked, in KiwiShelf's
[`highlight_color`](#kiwishelf-colours).

**Example:**

```lua
space_bar.set_active_indicator("outline")
```
:::

### space_bar.set_active_dim_factor

**Expects:** a number 0.05–1 (default 0.6).

:::unreleased
**Does:** sets the opacity of an **unfocused window's glyph on the
active Space** — the middle dim tier, between the focused window
(1.0) and inactive Spaces
([`kiwishelf.set_dim_factor`](#kiwishelfset_dim_factor)).
Lua-only, clamped. Independent of the shelf's `dim_factor`: no
ordering is enforced, so a value below the outer tier inverts
the ladder.
:::

**Example:**

```lua
space_bar.set_active_dim_factor(0.6)
```

### space_bar.set_show_front_app

**Expects:** boolean (default `false`).

**Does:** shows a trailing front-app segment after the last
Space item — a divider, then the glyph and the **title** of the
focused window of the Space **this display currently shows**
(per display, not the globally frontmost app). A window with no
title yet falls back to its app's name. On vertical (left/right)
bars the segment is icon-only and the divider flips to a
horizontal rule.

:::unreleased
The segment shows only while no App Bar is shown on that screen.
:::

**Example:**

```lua
space_bar.set_show_front_app(false)
```

### space_bar.set_front_app_title_cap

:::unreleased
**Expects:** a character count, 8–80 (default `10`). Values
outside the range are clamped.

**Does:** sets how much of the focused window's title the
front-app segment shows. The segment always ellipsizes at the
bar's edge; its length feeds the bar's alignment, so under
`center` or `end` an uncapped title slides the run of Space
items sideways every time the title changes. Inert while
`show_front_app` is off — nothing else on the Space Bar draws a
title.

**Example:**

```lua
space_bar.set_front_app_title_cap(25)
```
:::

### space_bar.set_hide_empty

**Expects:** boolean (default `false`).

**Does:** hides Spaces with no windows from the bar, except the
Space you are currently on, which always stays. Hidden Spaces
remain reachable by shortcut.

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
half of the gesture — [Space Bar](user-guide.md#space-bar) in
the user guide). A quicker drop, before this delay, moves the
window without switching. The ring sweep around the item fills
over the same duration.

**Example:**

```lua
space_bar.set_spring_delay(1000)
```

### space_bar.set_focused_item_color

:::unreleased
**Expects:** a hex color (`#RRGGBB` or `#RRGGBBAA`).

**Does:** sets the color of the focused window wherever the
Space Bar shows it: its glyph inside the active Space and the
front-app segment (default `#C2790A`, a different hue **and a
step darker** than the active-Space green). The rest of the
bar's three-state ladder is [KiwiShelf's](#kiwishelf-colours):
a Space you are not on draws `item_color` dimmed, the active
Space `active_item_color`. If you retune this, keep a lightness
gap from `active_item_color`; a lighter amber loses the
distinction.

**Example:**

```lua
space_bar.set_focused_item_color("#C2790A")
```
:::

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

- **BSP** `after_focused` — the new window takes the split right
  after the focused window, which keeps its frame.
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
placement override does not apply to track spaces.

## Drag & Drop Rearranging

Dragging a tiled window over another window's slot and releasing
swaps the two; dropping anywhere else snaps the window back.
While you drag, KiwiDesk draws two visuals:

- **Ghost** (`drag.set_ghost_*`): the dragged window's slot —
  where it snaps back, and where the displaced window would
  move.
- **Drop zone** (`drag.set_drop_zone_*`): the slot under the
  window's center, the window a drop would swap with.

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

**Does:** sets the border width of the ghost. Lua-only per
stroke: the Settings app's shared **Width** writes this, the
drop zone's and the focus ring's together, and the three are
never clamped against each other.

**Example:**

```lua
drag.set_ghost_border_width(5)
```

### drag.set_ghost_border_alignment

**Expects:** `"inside"` or `"outside"` (default `"inside"`).

**Does:** positions the border inside or outside the slot
boundary; at `inside` the marker's outer edge is the slot
boundary itself. Lua-only — the Settings app offers no control
for it (see [design decisions](design-decisions.md)).

**Example:**

```lua
drag.set_ghost_border_alignment("outside")
```

### drag.set_ghost_border_color

**Expects:** a hex color.

**Does:** sets the ghost border color (default `#347957`, deep
emerald).

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

**Does:** sets the border width of the drop zone. Lua-only per
stroke: the Settings app's shared **Width** writes this, the
ghost's and the focus ring's together.

**Example:**

```lua
drag.set_drop_zone_border_width(5)
```

### drag.set_drop_zone_border_alignment

**Expects:** `"inside"` or `"outside"` (default `"inside"`).

**Does:** positions the border inside or outside the slot boundary.
Lua-only, and independent of the ghost's alignment — see
`drag.set_ghost_border_alignment`.

**Example:**

```lua
drag.set_drop_zone_border_alignment("outside")
```

### drag.set_drop_zone_border_color

**Expects:** a hex color.

**Does:** sets the drop zone border color (default `#C2790A`,
amber).

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

**Does:** sets the corner rounding of both visuals (default 16,
the system window radius). The full range is Lua-only: the
Settings app offers **Square** / **Rounded**, which writes this
and the focus ring's corner style together. It reads any value
above zero as Rounded, so a radius set here is displayed rather
than overwritten, and re-picking Rounded leaves it alone — that
segment writes the system radius only from 0. Square writes 0.
Set this to disagree with `border.set_corner_style` and the
picker shows no segment selected until you choose one; either
segment then sets both.

**Example:**

```lua
drag.set_corner_radius(16)
```

### drag.set_liquid_glass

:::unreleased
**Expects:** a boolean (default `true`).

**Does:** draws the ghost and the drop zone as macOS 26 Liquid
Glass. Each is tinted by its own fill color, strongest at the top
and fading downward, and keeps its border solid on top; with the
fill off the glass is clear. Both use a thinner glass, so the
window a drop would swap with stays readable through it.
While you drag, both sit just below the window you are holding,
so the glass never covers it. Off,
below macOS 26, or while macOS's Reduce transparency is on, they
draw flat: the border over the fill color, floating above the
windows. Settings writes this through the one **Liquid Glass**
switch ([kiwishelf.set_liquid_glass](#kiwishelfset_liquid_glass)).

**Example:**

```lua
drag.set_liquid_glass(false)
```
:::

## Focus Border

KiwiDesk draws a thin border around the focused window. It is
**on by default** and marks only the focused window;
`border.set_unfocused_enabled` adds one on every other window.
The border is a pure overlay: it never changes where windows
tile (no gap coupling), and the configured width is the
thickness drawn outward into the gap. It is pinned to its
window's stacking level, so popovers, sheets, and other windows
the system places above the target stay above its border.
Overflow piles and monocle show a border only on the visible top
window.

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

**Does:** sets the border width (default `5`). Keep gaps at
least as wide as the border so neighbouring borders do not
touch: each border reaches its width into the gap, so with
unfocused borders on, 5 pt is the widest width at which two of
them fill the 10 pt gap without overlapping.

**Example:**

```lua
border.set_width(5)
```

### border.set_focused_color

**Expects:** a hex color string (`"#RRGGBB"` or `"#RRGGBBAA"`).

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
focused window shows. Floating windows — one you floated, or any
window in a space set to the floating layout — get the unfocused
border too.

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

**Does:** `rounded` (default) matches the real macOS window
corner radius, queried per window; `square` draws sharp corners.
The Settings app's shared **Corners** control writes this and
`drag.set_corner_radius` together and reads both back; see that
verb for how the picker treats a pair that disagrees.

**Example:**

```lua
border.set_corner_style("rounded")
```

### border.set_glow

**Expects:** a boolean.

**Does:** when `true`, wraps the **focused** border in a soft
colored bloom — a zero-offset blurred halo (default `false`). It
adds no color choice and never touches the unfocused windows:
the bloom is a **brightened** derivative of `focused_color`, so
set only `focused_color` and the glow follows. Its reach
**scales with the border width**, clamped to a legible band, so
a hairline border gets a subtle rim and a thick one a
proportional aura — override it with `set_glow_size` below. A
glowing ring renders on the behind-order renderer, so
`draw_order("front")` is inert while glow is on (see
[Accepted limitations](accepted-limitations.md)).

The bloom counts as part of the ring's reach: `border.fit_gaps`
sizes for it, and a floating window keeps that much off bars and
screen edges as well as the stroke. A hand-set gap smaller than
that lets the bloom bleed onto the neighbour.

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
width-scaled automatic reach; an explicit size pins the reach
regardless of the border width. The GUI slider offers 1–20 pt
behind an **Auto glow size** toggle; larger values up to 40 stay
a Lua fine-tune. No effect while `glow` is off.

**Example:**

```lua
border.set_glow(true)
border.set_glow_size(8)   -- a fixed, wider bloom
border.set_glow_size(0)   -- back to automatic
```

### border.set_draw_order

**Expects:** `"behind"` or `"front"`.

**Does:** chooses where the border stacks relative to windows.
`behind` (default) draws it below the window — flicker-free and
hugging the real corner radius, but the window's drop-shadow
falls across its lower reach and the corner meets the window
with a filled seam. `front` draws it above the window — a crisp,
shadowless hairline — but can flicker on windows that repaint
rapidly (Firefox/Zen and other Gecko browsers emit a compositor
reorder on every keystroke). Lua-only, with no GUI control.
Changing it re-draws every border immediately.

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
neighbour, keeping `remaining` points of whitespace past the
border's reach. Every outer edge becomes `reach + remaining`;
each inner axis becomes `reach + remaining`, or
`2 × reach + remaining` when `unfocused_enabled` is on. With the
glow off, the reach is the configured border width; the
renderer's hidden overlap is behind the window and does not
count. The action normalizes asymmetric global gaps. It is a
one-shot that writes `gap.global` — the remaining gap is command
input, never a persisted setting — and it never runs
automatically. The GUI's **Fit layout gaps → Set Gap Values**
action previews and stages the same calculation.

With `glow` on, the focused ring's reach is the width plus the
glow's resolved blur, rounded up to whole points and added once:
every outer edge and each inner axis grow by it, and an
unfocused ring adds its width alone (it has no bloom). The
Settings action's preview line shows the values before the
press.

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
give or take the difference. What changes depends on the layout —
Master/Stack maps a drag along the split to the master ratio, BSP
steers its split ratio toward the dragged side, Scrolling adjusts
the column width. Axes a layout has no parameter for (grid,
monocle, and a master zone lined up along the split — see
[Accepted limitations](accepted-limitations.md)) animate back into
place. Floating windows resize freely.

:::unreleased
In Master/Stack a drag along the zone's own axis — a stack
window's height beside a left or right stack, its width beside a
top or bottom one — moves the dragged window's share of its zone,
as `resize` does.
:::

Only edges **shared with a neighbor** trade area — pulling a
window's outer, screen-side edge has nobody to trade with and
snaps back.

The layout follows the size the window actually reached when you
release. If you flick faster than a slow app resizes its window
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

**Expects:** a boolean (default `false`).

**Does:** when `true`, a focus change warps the mouse pointer to
the center of the newly-focused window. The pointer never moves
while a mouse button is held down or when it is already inside
the focused window. While KiwiDesk performs its own z-order
maintenance raises the warp is held, and it fires once they
settle, for the window focus finally landed on. When focus lands
on a window in an inactive space (cmd+tab into a stashed window),
the warp waits until KiwiDesk follows focus and pulls that space
forward. Clicking an app-bar item warps too. Also togglable in
the Settings app under **Behavior ▸ Mouse**.

**Example:**

```lua
mouse.set_follows_focus(true)
```

## When Windows No Longer Fit

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
`stack.promote` / `stack.demote`). Focusing a window still raises
it to the front, and it stays there until the next boundary
crossing re-stacks the zone.

## Window Rules

### float_rules

**Expects:** a Lua table of strings (bundle-id or
bundle-id:title matchers).

**Does:** windows matching any entry always float. An app is
named by its **bundle identifier** (e.g. `com.apple.finder`),
not its display name. `"id"` matches every window of the app;
`"id:Title"` matches when the title contains the fragment. The
bundle id is matched case-insensitively; the title fragment is
case-sensitive. See [Finding a bundle
identifier](#finding-a-bundle-identifier). Dialogs, sheets, and
picture-in-picture windows float automatically. Detection is
re-checked as windows come and go and when a title changes, so
an "App:Title" rule catches windows whose titles load late
(Electron/WebKit apps) or change into a match later, and a
window that reported wrong metadata while launching corrects
itself the same way. A manual `make_floating` override is never
reverted by these re-checks.

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
assignment, no window events.

Transient macOS input-source menus and switcher overlays are
likewise ignored, so pressing the Globe key never creates a
managed window or KiwiDesk focus border. Auxiliary AX proxy
windows with no matching WindowServer window are ignored by the
same policy.

**KiwiDesk's Settings window** is tracked and **tiled like any
other window** — it takes a layout slot, appears in the App Bar,
and answers `make_floating` / `toggle_floating` and the other
window verbs. Its float rules work the same way yours do, so a
`float_rules` entry can keep it out of the layout permanently.
KiwiDesk's *other* windows are not managed: the setup tour and
the Config Issues window are tracked but always floating, and its
panels — the ⌃⌥K shortcuts panel, drag/drop overlays, App Bar
overlays and focus borders — are ignored outright and appear in
no bar and no window list KiwiDesk publishes.

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
app: no state entry, tiling or floating verdict, space
assignment, or window events. Use this for HUDs, menu-bar utilities,
or apps that misbehave when AX-tracked. Use `float_rules` when an app
should remain tracked and visible but never tile.

Matching is case-insensitive and app-wide; title fragments are not
supported. This table is the global base. In `gui.json` it lives at
the root as `ignore_rules`. A profile may add rules or tombstone
inherited ones through its sparse `ignore_rules` object. There is
no Settings control and no session-only `make_unmanaged` command;
GUI profile saves preserve the override unchanged.

**Example:**

```lua
ignore_rules = {
    "com.1password.1password",
    "eu.exelban.Stats",
}
```

After editing `init.lua`, run `kiwidesk reload_config`. Newly ignored
apps leave KiwiDesk state, and apps removed from the list are
discovered again. Ghostty's quick terminal is a built-in exception:
only its panel, not normal Ghostty windows, is ignored.

**Command bars are ignored automatically.** A Spotlight/Raycast-style
launcher is a menu-bar (accessory) app whose bar is a raised-layer
overlay; KiwiDesk never manages such a window, so the bar is not
tiled, stashed, or pulled along on a space switch. The rule is
generic — accessory app **and** raised window layer — so any
launcher or HUD qualifies without a rule; the app's normal windows
(settings, pickers) stay managed as floats. Raycast's command bar is
additionally recognized by bundle id for setups where Raycast shows
a dock icon and loses the accessory policy.

Invisible helper windows are ignored automatically: a raised-layer
window that is fully transparent or sits entirely off-screen (the
lifecycle keepalive some menu-bar apps create) is never tracked.
`ignore_rules` remains the whole-app escape hatch for anything
either heuristic misses.

### app_rules

**Expects:** a Lua table mapping app **bundle identifiers** to
space identifiers.

**Does:** new windows of listed apps go to their assigned space.
An app is named by its bundle identifier (case-insensitive), not
its display name. See [Finding a bundle
identifier](#finding-a-bundle-identifier).

:::unreleased
Opening a listed app takes you with it: when you launch it,
reopen it with no window showing, or restore its minimized
window yourself — a Dock click, Spotlight, `pull_or_spawn` —
and the window goes to a space other than the one you are on,
KiwiDesk switches to that space and focuses the window. A
window an app opens on its own while another of its windows is
showing, the windows macOS reopens at login or KiwiDesk finds
when it starts, and the windows a Desktop switch shows you stay
in their space
([#1599](https://github.com/KiwiCanopy/KiwiDesk/issues/1599)).
:::

:::unreleased
A popup menu the app opens — a window above the normal window
layer — is not filed by the rule: it opens in the space you are
in. The app's dialogs and panels follow the rule like its other
windows.
:::

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
identifier. The Settings app's pickers list installed apps by
name and store the identifier for you. To find one by hand:

- Run `kiwidesk get_state` (or the `get_state` command over
  IPC): every window carries a `bundle_id` field alongside its
  display `app` name. Focus a window of the app and read it off.
- Or ask macOS directly:
  `osascript -e 'id of app "Safari"'` →  `com.apple.Safari`.
- Or `mdls -name kMDItemCFBundleIdentifier /Applications/Safari.app`.

Identifiers are matched case-insensitively. An app with no bundle
identifier (a rare unbundled helper process) cannot be targeted
by a rule.

## Making Windows Floating or Tiled

### make_floating

**Expects:** nothing.

**Does:** marks the focused window as floating. It is no longer
tiled: it keeps whatever frame you give it, on the space it
belongs to — it hides with its space and reappears where you
left it when you switch back. (A window that should stay visible
on *every* space is a [sticky window](#sticky-windows), not a
floating one.) A floating window is always kept **above** the
tiled plane: focusing or cmd-tabbing to a tiled window never
buries the float behind it, and two overlapping floats stack
most-recently-focused on top. (To exclude a window from tiling
*without* pinning it above others, use `ignore_rules` — KiwiDesk
then leaves its z-order untouched.) The override survives the
window closing and reopening (matched by app name and title; a
window that closes while untitled has no identity to match and
loses it) and applies only to that window — use `float_rules` to
float every window of an app.

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
again, including future rule edits, and the close/reopen memory
of the window's current identity is forgotten. (A remembered
intent stored under an *older* title can still resurface after a
reopen — run `make_auto` again once the window shows the wrong
state and it is purged for good.) Use it when a window "sticks"
floating or tiled after a `make_floating`/`make_tiled` you no
longer want.

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
detection control. It is bound to `control+option+f` by default
and is the only float verb offered in the Settings shortcut
list; the explicit `make_*` verbs remain for scripts that need a
specific direction.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+f", function()
    KiwiDesk.toggle_floating()
end)
```

## Sticky Windows

A **sticky** window stays present on every space instead of
hiding with its home space — KiwiDesk's own analog of Mission
Control's "Assign To → All Desktops". The user guide's [Sticky
Windows](user-guide.md#sticky-windows) section covers the
everyday behavior; what follows is the Lua-facing model.

Stickiness is a per-window flag on a live window; there is no
app-matcher rule list. The flag survives the window closing and
reopening, matched by app name and title like the float
override. It is orthogonal to floating: a floating sticky
window keeps its own frame everywhere, and a tiled sticky
window tiles into every space's layout at a slot derived from
its rank among its home space's tiles, clamped to the target
space's count — nothing is stored. The window is a member of
exactly one space, its home; reordering it there moves its
derived slot on every space, while a swap or bar drag targeting
it on a foreign space does nothing. On a crowded space a tiled
sticky window keeps a fully visible slot and a non-sticky window
overflows in its place.

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
scopes coincide.

`move_to_space` is guarded: a **global** sticky refuses any
target; a **display** sticky refuses a target on the *same*
monitor and accepts one on *another* monitor, which re-homes it
to that display. A refused move shows a brief pill on the
window.

A sticky window is marked in its top-right corner
(`sticky.set_mark`; `infinity` for global, `pin.fill` for
display), and the same per-scope badge rides its Space Bar
glyph, listed under whichever space is current
(`space_bar.set_sticky_badge`).

Prefer sticky over an `ignore_rules` entry for "keep this
visible everywhere": an ignored window loses tracking, focus
navigation, borders, and its bar tile; a sticky window stays
fully managed.

Where macOS exposes the window-management bridge, sticky also
reaches across **macOS Desktops** (`sticky.set_desktop_reach`,
default on; `override_sticky_reach` pins one window against it).
Mission Control shows a carried window on one Desktop at a
time: the one you are on.

### make_sticky

**Expects:** nothing.

**Does:** marks the focused window **globally** sticky — visible
on every space of every monitor. No mode argument: the window
keeps its existing floating or tiled state. Overrides display
sticky if the window already had it.

**Example:**

```lua
KiwiDesk.make_sticky()
```

### make_display_sticky

**Expects:** nothing.

**Does:** marks the focused window sticky to its **current
monitor** — visible on every space of that one display, not on
other monitors. Moving it to a space on another monitor re-homes
it there. Overrides global sticky if the window already had it.

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
off. Offered as a bindable row in the Settings shortcut list;
the `make_*` verbs set a specific direction. Toggling global on
a display-sticky window switches it to global.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+s", function()
    KiwiDesk.toggle_sticky()
end)
```

### toggle_display_sticky

**Expects:** nothing.

**Does:** flips the focused window between **display** sticky
(its current monitor only) and off. Also offered in the Settings
shortcut list. Toggling display on a global-sticky window
switches it to display.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+d", function()
    KiwiDesk.toggle_display_sticky()
end)
```

### override_sticky_reach

**Expects:** one of `on`, `off`, `auto`.

**Does:** pins the focused window's Desktop reach against the
global `sticky.set_desktop_reach` toggle — `on` keeps this
window following you across macOS Desktops even with the toggle
off, `off` leaves it on the Desktop it lives on even with the
toggle on, and `auto` clears the pin so the toggle rules again.
Session state: the pin does not survive the window closing.
Without the window-management bridge the pin is recorded but
nothing is carried.

**Example:**

```lua
-- The player follows me everywhere, whatever the toggle says.
KiwiDesk.override_sticky_reach("on")
```

### sticky.set_mark

**Expects:** boolean (default `true`).

**Does:** shows or hides the on-window sticky mark — the small
glyph at a sticky window's top-right corner, and the carrier
for sticky's refusal pills (home-space, can't-pile,
move-blocked), which go silent with it. Off while the Space Bar
is also off leaves sticky state with no mark at all; neither
this setting nor the Settings app's toggle refuses that.

**Example:**

```lua
sticky.set_mark(false)
```

### sticky.set_color

**Expects:** a hex color string `#RRGGBB` or `#RRGGBBAA`, or an
empty string `""` for **Automatic** (default `""`).

**Does:** tints the sticky mark — the on-window mark and the
Space Bar sticky badge read this one value. The mark becomes a
filled disc in the color with a legible auto-contrast glyph.
`""` is Automatic: the badge keeps the count-badge fill and the
mark is a neutral glyph on glass that flips black/white with
light and dark mode. Any non-empty value must parse as a hex
color.

:::unreleased
On [Liquid Glass](#stickyset_liquid_glass) the color tints the
mark's glass instead, and the disc goes.
:::

**Example:**

```lua
sticky.set_color("#3D6FE8")  -- a blue sticky mark
sticky.set_color("")          -- back to Automatic
```

### sticky.set_desktop_reach

**Expects:** boolean (default `true`).

**Does:** extends the sticky promise across **macOS Desktops**:
on, every sticky window of either scope is carried along when
its screen switches Desktop, and is already there when you
arrive. A single window can be pinned the other way with
`override_sticky_reach`. Off, a sticky window stays on the
Desktop it lives on and follows only KiwiDesk's own Spaces
there. Inert on a macOS without the window-management bridge.

**Example:**

```lua
sticky.set_desktop_reach(false)
```

### sticky.set_liquid_glass

:::unreleased
**Expects:** a boolean (default `true`).

**Does:** draws the on-window sticky mark as macOS 26 Liquid
Glass, tinted by [`sticky.set_color`](#stickyset_color),
strongest at the top and fading downward; with no color it is
clear glass. The glyph drops its filled disc and takes the
system label color: light on a dark color, which pins the glass
dark, and otherwise as KiwiDesk's Appearance sets it. Off, below
macOS 26, or while macOS's Reduce transparency is on, the mark
is the badge `sticky.set_color` describes: a filled disc in the
color, or the bare glyph on Automatic. Settings writes this
through the one **Liquid Glass** switch
([kiwishelf.set_liquid_glass](#kiwishelfset_liquid_glass)).

**Example:**

```lua
sticky.set_liquid_glass(false)
```
:::

### floating.set_color

**Expects:** a hex color string `#RRGGBB` or `#RRGGBBAA`, or an
empty string `""` for **Automatic** (default `""`).

**Does:** tints the Space Bar floating badge — a filled disc in
the color with an auto-contrast glyph. Floating windows have no
on-window mark, so this affects the Space Bar badge only. `""`
is Automatic (the badge keeps the count-badge fill); any
non-empty value must parse as a hex color.

**Example:**

```lua
floating.set_color("#8E5DE0")
```

## Launching Apps

### pull_or_spawn

**Expects:** an app bundle identifier (e.g. `com.apple.safari`).
See [Finding a bundle identifier](#finding-a-bundle-identifier).

**Does:** if the app is already running, focuses its window; if
not, launches a new instance. Matching and launching are keyed
on the bundle id, so it finds apps anywhere on disk (Finder,
apps outside `/Applications`) regardless of system language.

Pressing again while one of the app's windows is focused
advances to the app's **next** window — space order (the order
spaces were created, as the Space Bar lists them), then slot
order within a space, wrapping around. With a single window a
repeat press changes nothing. The ring includes the app's
windows on other macOS Desktops, each at the rank it holds in
its Space's row; cycling onto one switches to that Desktop and
focuses it. That switch needs the Desktop bridge — without it
the ring is the windows KiwiDesk currently tracks, see
[Accepted limitations](accepted-limitations.md).

If the app has **nothing on screen** — typically every window
minimized — the shortcut restores exactly one and brings the app
forward: the window you minimized most recently; when KiwiDesk
was not running to see the minimize there is no such record and
the app's own window order decides. While any window is still
visible, minimized windows are left alone. A window up on
another macOS Desktop counts: the shortcut switches to that
Desktop and focuses it instead of un-parking anything, and the
restore runs only when nothing is up anywhere. Without the
Desktop bridge, or where the per-Desktop window list cannot be
read, other Desktops are not consulted — see
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

**Does:** always launches a new instance of the app, even if one
is already running. Matching is keyed on the bundle id, like
`pull_or_spawn`.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+return", function()
    KiwiDesk.spawn_new("com.apple.Terminal")
end)
```

Both launch verbs are also reachable from the Settings app: an
Open applications shortcut carries a per-row **Launch behavior**
menu — *Open or Focus* (`pull_or_spawn`, the default) or *Open
New* (`spawn_new`).

## User Interface

### show_shortcuts

**Expects:** nothing.

**Does:** opens the read-only **shortcuts panel** — a live glance
at the active layer's bindings — or closes it if it is already
open. It is the panel behind the menu bar's *View Shortcuts…*
row; the bound combo shows beside that row and in the panel's
close hint. Seeded to **⌃⌥K** in the base layer and in every
layer you create, and offered under **Shortcuts ▸ General**
("Show shortcuts panel"), where you can rebind or clear it per
layer.

**Example:**

```lua
KiwiDesk.bind("alt+space", function()
    KiwiDesk.show_shortcuts()
end)
```

### open_settings

**Expects:** nothing.

**Does:** opens the **Settings** window and brings it to the
front. It never closes the window: pressing the key with
Settings already open returns it to **Home**, the same as
opening Settings from the menu bar. Unsaved edits survive that;
only the place you were reading resets.

Seeded on **`⌃⌥,`** in the base layer and in every layer you
create in Settings, and offered under **Shortcuts ▸ General**
("Open Settings"), where you can rebind it per layer.

**Example:**

```lua
-- A second chord beside the seeded one.
KiwiDesk.bind("ctrl+alt+shift+comma", function()
    KiwiDesk.open_settings()
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

**The numeric keypad.** Its ten digits are the **same key** as
their number-row twin — a binding written `control+option+4`
fires from either, and the two cannot be bound apart. Every
other keypad key is its own key: `keypadplus`, `keypadminus`,
`keypadmultiply`, `keypaddivide`, `keypaddecimal`,
`keypadequals`, `keypadenter`, `keypadclear`.
`keypad0`–`keypad9` are accepted as spellings of the plain
digits and resolve to them, so the recorder writes `4` whichever
of the two keys you press.

Keypad digits work whenever the keypad sends digits. Apple
keypads always do (a Clear key sits where PC keyboards put Num
Lock); a third-party PC keyboard with Num Lock **off** sends
navigation keys from the keypad instead, and no keypad shortcut
fires.

The Settings app's shortcut recorder writes the long forms
(`command`, `option`, `semicolon`, …); every alias round-trips.

A combo is any set of modifiers plus **exactly one key**.
Multi-key chords (`cmd+j+k`) are not expressible; a hand-written
combo that doesn't parse is never registered, and the Shortcuts
section flags the row with ⚠ *"isn't a recognized shortcut"*.

### Shortcut Layers

Define vim-style layers; only the active layer's bindings
fire:

```lua
KiwiDesk.define_layer("resize", {
    ["h"]      = function() KiwiDesk.resize("x", -50) end,
    ["l"]      = function() KiwiDesk.resize("x", 50) end,
    ["j"]      = function() KiwiDesk.resize("y", -50) end,
    ["k"]      = function() KiwiDesk.resize("y", 50) end,
    ["escape"] = function() KiwiDesk.switch_layer("default") end,
})

KiwiDesk.bind("ctrl+alt+r", function()
    KiwiDesk.switch_layer("resize")
end)
```

#### resize

**Expects:**

- An axis: `"x"` or `"y"`.
- A delta (points; positive = grow, negative = shrink).

**Does:** grows or shrinks the focused window. A **floating**
focused window resizes itself directly, in every layout mode:
`"x"` changes its width by the delta, `"y"` its height, floored
at its **effective minimum** — `min_window_size`, raised by a
larger minimum the app itself enforces once KiwiDesk has learned
it (#677). A window already smaller than that shrinks no
further.

"Floating" here is the window's *effective* float (#1184): its
own float flag — set by a toggle, `make_floating`, a
`float_rules` entry or KiwiDesk's own detection — **or**
membership of a space set to the floating layout.

The delta is split between **both** edges (#1091), so a float
grows and shrinks around its own centre. An edge already against
the boundary is *pinned* and the whole delta goes to the other
side; the boundary is the screen's visible bounds less any bar
strips on that space, so a float cannot be grown underneath a
bar, and when both edges are against it a grow refuses and
flashes a pill. Shrinking pins the same way.

Tiled windows resize only in bsp, stack, scrolling, and track
layouts; monocle and grid report "not supported" and flash a
pill on the focused window saying the layout has no resizing
(#1255). `set_refusal_sound(true)` adds the system alert sound
to that pill; only a hotkey fire sounds, so CLI and IPC callers
see the pill and read the error JSON without hearing anything.

A focused window in **native full screen** — floating or tiled,
whatever the space's layout — is refused ahead of both routes
(#1298): the press writes nothing, moves no other window, and
flashes a pill on the full-screen window saying full-screen
windows can't be resized; CLI and IPC callers read `the focused
window is fullscreen`.

A resize a size limit **truncates** (#933) — a shrink reaching
the focused window's effective minimum, a grow stopped where a
neighbor would drop below its own, or a grow reaching the
focused window's learned app maximum (scrolling, #1055; cued on
the resized window alone) — still applies the part that fits and
cues the refusal on the first truncated attempt. On a scrolling
space, a press the focused window's own learned bound blocks
outright (grow at its maximum, shrink at its minimum) refuses in
place: nothing applied, no neighbor moved, same bounce and pill
(#1057). The focus ring gives the rubber-band bounce of a
dead-end focus move (#436), and a pill names the reason on the
window that cannot shrink; on a refused grow the resized window
also names the reason while the blocking neighbor marks itself
at its minimum. Keyboard and mouse resizes share these clamps
and cues.

The pill says *whose* minimum it was (#1261): "Minimum window
size reached" and "Neighboring window at its minimum size" mean
the `min_window_size` bound, and lowering it helps; "This app
won't go smaller" and "Neighboring app won't go smaller" mean
the app's own learned floor, which no setting moves.

In **bsp**, the window that cannot shrink is often not the one
you are resizing (#1259). A window holding the whole height —
the first window, when the layout splits side by side — cannot
change height; that press moves the split *between its
neighbours*, and when one of them reaches its minimum the pill
goes on that neighbour while the focused window reads
"Neighboring window at its minimum size". Where the arrangement
has no split on that axis — two windows side by side, asked for
height — the press says so on the first try ("This zone divides
widths, not heights"); the stored ratio still records what a
later split on that axis will open at. Where the group an axis
divides holds only ONE member, the press says so instead
(#1258): "Nothing to divide here — try the other axis" where
the other axis does divide, and "This zone has nothing to
divide" where neither does. That covers a stack window alone in
its column, a stack space with an empty stack zone, a space
whose windows share one track, a window that fills its own
track, and a bsp space of one. In the stack and track cases the
press returns an error and CLI and IPC callers get the longer,
layout-specific text; the two ratio cases report success, since
the ratio is stored either way.

**Held, the chord glides (#1056, #1082).** A hotkey whose press
ran exactly one command — a successful `resize` — keeps applying
while you hold it: one step on the press, then, after your Mac's
own key-repeat delay, a continuous **glide** on the display's
frame clock. Each frame moves a fraction of *that binding's own
delta*, at a speed in steps per second that starts gently and
ramps up over a second or two. The amount moved is the frame's
elapsed time × that speed, so the same hold travels the same
distance on a 60 Hz display, a 120 Hz one, and a ProMotion panel
changing rate mid-hold.

The glide re-issues the **`resize` command your press ran**,
with a scaled delta — never the binding's Lua body, which runs
exactly once, on the press. Whether a binding glides is decided
by what its press **did**: a body that runs two commands, or a
different verb, fires once per press, and `focus`/`swap` never
glide. A body that rebuilds its own bindings (`bind` inside the
body) arms nothing.

A refusal that cues (#933/#1055) ends the run, so a held shrink
parked on a minimum flashes its pill once; scrolling's wordless
out-of-screen stop keeps gliding harmlessly until release.
Releasing the chord, switching layers, or arming a Settings
shortcut recorder ends the run immediately.

A glide writes each frame instantly, on every layout and on a
floating window alike, whatever `animations.set_on_window_resize`
says and under system **Reduce Motion** (#1082/#1090).

A floating resize accumulates against what was last
*commanded* — the in-flight animation's target where one exists
(#129), and the glide's own record where none does — rather than
the lagging AX echo. That record is readable only by a glide
frame and is retired at the start of the next press. A fast run
of separate **presses** still re-reads the echo between them and
can come up short; see
[accepted limitations](accepted-limitations.md).

What the `delta` adjusts depends on the layout:

- **bsp** — per-axis (#56): `"x"` nudges the side-by-side split
  ratio (`bsp.set_ratio_h`), `"y"` the stacked one
  (`bsp.set_ratio_v`). Focus-aware in direction (#122): a
  positive delta grows the *focused* window's region, so with a
  right/bottom window focused it lowers the shared ratio — the
  same side rule a mouse drag of that window's edge uses. All
  same-orientation splits share the one ratio; with no focused
  window the delta moves the left/top region. The write stops
  at the bound that keeps both regions at their effective
  minimums (per side, #933) within the area the layout fills
  (#383) — the display minus any Space Bar strip.
- **stack** — focus-aware (#67). `"x"` moves the master/stack
  split *in the direction that grows the focused window*: with
  a master focused, a positive delta raises the master ratio;
  with a stack window focused, it lowers the ratio. The write
  stops at the bound that keeps both zones at their effective
  minimums (per zone, #933) within the area the layout fills
  (#44). `"y"` grows or shrinks the focused window's vertical
  share of its column via per-window weights — session-scoped,
  never saved to a profile, and reset when a window leaves the
  space or KiwiDesk restarts. If the focused window is alone in
  its column, `"y"` reports an error.

  A bsp ratio or the master ratio that presses moved past an
  app's minimum before that minimum was learned heals back at
  the next layout pass, and a window arriving into a region
  narrower than its minimum gets the same move — the
  split-layout row of
  [accepted limitations](accepted-limitations.md) has what
  remains.
- **scrolling** — adjusts the slot size in real points along
  the layout's own scroll axis (columns for horizontal, rows for
  vertical), whichever `axis` you pass — the `x`/`y` argument
  does not steer it.
- **track** — every resize has one target (#128). The axis
  **across** the tracks (`"x"` for columns, `"y"` for rows)
  grows or shrinks the focused window's whole *track*; the axis
  **along** them grows the focused window's *share within its
  track* — the same per-window weights as the stack's `"y"`
  path, with the same session-scoped lifetime and
  effective-minimum cap (#933). A single track cannot trade
  cross-axis area, and a window alone in its track has no share
  to grow; both report an error. In the track layout — and only
  there — session weights are also **healed** whenever the
  arrangement changes around them (#944): once another track
  opens or a member joins a track, the next layout pass shaves
  the largest weights just enough that every track and share
  can still hold `min_window_size`. Weights that still fit are
  never touched. A stack column's per-window weights keep only
  the write-time clamp (see the accepted limitations).

:::unreleased
The area a layout fills, which every bound above is taken
within, is the display minus the [KiwiShelf](#kiwishelf) strip
wherever a bar draws in that layout (#1517).
:::

:::unreleased
**Where the ratio write lands (#458):** in a **session layer
scoped to that space** — never the shared global, so resizing
one space does not visibly resize every other space, and never
a per-space override, authored or not, so what
`bsp.set_ratio_h_override` or the Settings override editor set
stays the number you wrote and
[`reset_layout_sizing`](#reset_layout_sizing) can return to it.
Session values behave like the stack's per-window weights:
never saved to a profile, gone on restart, reseeded from config
on a real mode change, `reload_config`, `load_profile` (or any
other explicit profile/preset/GUI apply), a Desktop switch or
monitor change that loads a *different* profile, and dropped
for a
field the moment you set it explicitly — its global
(`bsp.set_ratio_h`, `stack.set_master_ratio`,
`scroll.set_slot_size`) drops it on every space, its `_override`
twin on that space — so an explicit write always shows. This
covers the BSP split ratios, the stack master ratio, and the
scrolling slot size — the three interactive-resize knobs —
consistently.
:::

**Example:**

```lua
KiwiDesk.resize("x", -50)
KiwiDesk.resize("y", 50)
```

A layer switch is also an event: `KiwiDesk.on("layer_change",
function(from, to) … end)` hears every change of the active
layer — `switch_layer`, or a profile switch returning you to
`default` — and nothing for a switch to the layer already
active ([Events](#events)). A config reload returns you to
`default` too, but it also replaces every Lua callback, so only
the CLI event stream hears that one.

#### Layer Icons

An optional third argument to `define_layer` sets the layer's
icon — an SF Symbol name or a flat emoji. While the layer is
active, the KiwiDesk status item swaps to it, and the Space Bar
shows it as one item ahead of the Spaces; a layer without an
icon shows the first two characters of its name there,
uppercased. The default layer (`KiwiDesk.bind`) never takes an
icon — the status item shows the standard KiwiDesk glyph.

:::unreleased
With the Space Bar off, the status item shows the Space each
screen is showing instead ([User Guide ▸ Space
Bar](user-guide.md#space-bar)), led by the layer's icon — or
the two-character cut of its name — the way the bar is.
:::

**Example:**

```lua
KiwiDesk.define_layer("resize", { --[[ bindings ]] },
    { icon = "arrow.left.and.right" })
KiwiDesk.define_layer("service", { --[[ bindings ]] },
    { icon = "⚙️" })
```

### Config Cascade (Per-Profile Keybindings)

Keybindings resolve through a two-level cascade, like tiling
(global settings ← profile):

> **The base config is the seed; the profile wins.** The base
> shortcuts (the app's `gui.json`, or your Lua-declared binds
> in a hand-written config) apply first. When the loaded
> profile carries a `"layers"` override, each of its rows
> shadows the base row with the same combo in the same layer;
> everything the profile does not mention stays active.
> Event hooks fire on their event — they are never a cascade
> layer.

The override is **sparse and soft**:

- A profile stores only the layers and rows that diverge; a
  profile without a `"layers"` key inherits the base shortcuts
  completely.
- Rebinding the same combo differently per profile stays
  possible. A base layer's icon a profile clears reverts to the
  base icon.
- Keybindings live in ONE home: the structured config (gui.json +
  profiles) when GUI-managed, or your `init.lua` otherwise —
  never merged. Hand-written binds that evade the managed-
  vocabulary detection are silently unregistered on every reload
  while GUI-managed.

:::unreleased
A profile can also leave a base binding out: its layer entry
lists the combo under `"removed"`, and that base row is not
registered while the profile is loaded. That includes your
profile-switch shortcut — leave it in, or switch from the menu
bar.
:::

Profiles re-resolve their bindings whenever they apply: on
`load_profile`, on a monitor change, and on a Desktop binding
switch. Switching profiles also returns you to the default
layer.

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
| `desktop_change` | `desktop` (Desktop number now current on the screen that switched), `monitor` (that screen's positional number; 1 is the main screen) |
| `window_created` | `window_id`, `app`, `space`, `reason`, `bundle_id` |
| `window_destroyed` | `window_id`, `app`, `space`, `reason`, `bundle_id`, `desktop` (the Desktop number holding a `vanished` window, else `nil`) |
| `window_moved_to_space` | `window_id`, `app`, `from`, `to`, `bundle_id` |
| `layer_change` | `from`, `to` (layer names, `default` included; fires only when the layer actually changed) |

The window lifecycle events fire even when focus does not change
(a background window opening or closing). `space` is always the
space the window lives in — for `window_destroyed`, the one it
disappeared from, even when that space is not active. In the
CLI event stream the key is `space_id` (matching `space_change`)
and an unknown space is JSON `null`; the Lua callback receives
`""` instead.

Every window event also carries the owning app's `bundle_id` —
the identity key that app rules (`float_rules`, `app_rules`) and
`pull_or_spawn` match on; the display `app` name is
locale-dependent. It is the trailing Lua argument (skip it if
you don't need it), `""` for unbundled processes; in the CLI
event stream the key is `bundle_id`, JSON `null` when unknown.

:::unreleased
When the number of screens changes, `monitor_change` fires once
the screens have stopped changing for a second (at most five
seconds after the first change), with the count they settled on. macOS briefly reports an in-between layout on
some changes, such as disconnecting an Apple Vision Pro, and the
profile is chosen only for the settled one.
:::

`window_moved_to_space` fires on an explicit `move_to_space`
(with or without follow) when the target differs from the
window's current space. Bulk reassignments — profile loads,
session restore — stay silent. JSON keys: `from_space_id` (null
if unknown) and `to_space_id`.

The lifecycle events track the *visible window set*, not app
lifecycle: deminiaturizing surfaces as `window_created`, and
switching macOS Desktops makes every managed window on the old
Desktop vanish from the accessibility tree and reappear on
return. The `reason` argument says which kind of change fired:

- `window_created` — `"new"` (a genuinely new window),
  `"returned"` (back from another macOS Desktop, from an app that
  was unhidden, or from a session restore), `"restored"`
  (deminiaturized).
- `window_destroyed` — `"closed"` (a real close), `"minimized"`
  (it will come back as `"restored"`), `"hidden"` (its app was
  hidden, with cmd+H or by hiding itself as its last window
  closed; the window is untouched and comes back as
  `"returned"`), `"vanished"` (the window is on a macOS Desktop
  no screen is showing; it comes back as `"returned"`, and the
  sixth argument, `desktop`, names the Desktop holding it where
  the Desktop can be read — `nil` on a Mac without SkyLight).

A bar callback that only cares about real lifecycle filters in
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

A fast app that folds its windows before the switch is noticed
still reports `"vanished"`. A window closed *while its macOS
Desktop is off-screen* is reported `"closed"` when KiwiDesk next
reads the Desktops — at the next Desktop switch, or within about
five seconds while any window is away — so such a window fires
two destroys, `"vanished"` then `"closed"`. A consumer that
keeps its own list re-queries on `desktop_change` (the pattern
in the sketchybar recipe).

## External Commands

Config callbacks run on KiwiDesk's main thread, so external
commands always run in the background.

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
  when omitted. Pass `0` (or a negative number) for *no* limit.
- `dedup` — an optional boolean, **default `true`**. While an
  identical `command` string is already running, a second `exec`
  of it is skipped (returns `nil`) rather than spawning again —
  the shape a trigger-style poke such as `sketchybar --trigger …`
  wants. Pass `false` for commands that may run in parallel with
  an identical copy of themselves. A skipped call **does not
  invoke its callback** — no child ran.

**Does:** starts the command in the background and returns
immediately. Returns the child's pid (a number), or `nil` when
the command could not be started **or was skipped as a
duplicate** (see `dedup`). If the config reloads before the
command finishes, the callback is dropped silently.

**Output cap:** stdout and stderr are each capped at ~1 MB.
Output beyond the cap is still read (so the child never blocks
writing), but the string delivered to the callback is truncated
and ends with `[output truncated at 1 MB]`.

**Quit policy:** exec children are fire-and-forget. When
KiwiDesk exits, running children are re-parented to launchd and
finish naturally — a `sketchybar --notify` hook completes even
if KiwiDesk quits first. The 30 s default `timeout` still bounds
each one; pass `timeout = 0` for a command that must run
indefinitely.

**Hanging hooks:** when the number of outstanding children
crosses 20, KiwiDesk logs a warning (`N exec children
outstanding — a hook command may be hanging`). The live count is
on `get_state().exec_running`. With the default `timeout` and
`dedup`, a permanently wedged receiver leaves at most one stuck
child per distinct command, reaped every 30 s.

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

**Expects:** a command string, like standard Lua. Calling it with
no argument keeps its stdlib meaning ("is a shell available?")
and returns `true`.

**Does:** forwards the command to `KiwiDesk.exec` and returns
`true` **immediately** — it does *not* wait, and the return value
says nothing about whether the command succeeded. For the exit
code or output, use `KiwiDesk.exec` with a callback.

It inherits `KiwiDesk.exec`'s defaults: a 30 s timeout and
identical-command dedup. A long-running `os.execute` is killed
at 30 s — call `KiwiDesk.exec` directly with `timeout = 0` for
one that must run unbounded.

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

**Does:** returns `nil` plus an explanatory message instead of a
file handle. `KiwiDesk.exec` with a callback delivers the same
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

**Does:** nothing. To restart KiwiDesk use `kiwidesk service restart` from a
terminal or a keybinding via `KiwiDesk.exec`.

Unlike the real `os.exit`, the stub **returns** — code after the
call keeps running. Halt a script with an explicit `return` or
`if/else`, never `os.exit()`.

## Startup Scripts

Commands at `init.lua` top level run on load and on reload; see
[External Commands](#external-commands) for `KiwiDesk.exec`
semantics. Any tiling commands at top level are applied before
profiles load, as base state.

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
- `load_profile` switches to the named profile and makes its space
  list the authority (see *Space Reconciliation*).
- `delete_profile` removes the profile; deleting the last profile of
  a count reverts that count to its built-in Standard.
- `set_default_profile` marks a profile as the fallback for its
  monitor count.

:::unreleased
`save_profile` and `load_profile` also hand the connected monitor
set to that profile, and `set_default_profile` refuses a profile
that holds no set (see [Profile Monitor
Sets](#profile-monitor-sets)).
:::

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
assignments — plus, optionally, **sparse keybinding and
window-rule overrides** that shadow the base only while the
profile is active. The global declarations live in `gui.json`
when GUI-managed, or in your hand-written `init.lua` otherwise.
`app_rules`, `float_rules`, and `ignore_rules` all have a
per-profile tier; profile bindings do not, since they select the
profile itself.

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

### bind_profile_to_desktop

**Expects:**

- A Desktop number, as Mission Control counts them (1-based;
  fullscreen apps don't count).
- A profile name.
- Optionally, the fingerprint of every screen in one screen
  setup, as `list_monitors` prints them.

**Does:** when that Desktop becomes current **on the main
display** (the screen with the menu bar), KiwiDesk loads the
bound profile — its spaces, layouts, and settings — provided
the profile is saved for the connected screen count; otherwise
the binding stands aside, the current profile stays, and a
screen change picks by the connected screens instead. Desktops
without a binding keep whatever profile is active. A binding
takes effect when that Desktop next activates. With "Displays
have separate Spaces" off, or with a single screen, the main
display's Desktop is *the* Desktop. In a hand-written config
the call lives in `init.lua`; when the config is GUI-managed,
bindings are stored in `gui.json` (`profile_bindings`) and
edited in the Profiles section instead.

A call binds the profile for all screen setups of its screen
count, and a Desktop holds one such profile per count: a second
call with a profile saved for another count adds beside the
first, and the one saved for as many screens as are connected
loads; a call with a profile of the same count replaces it. A
profile not saved yet replaces any other not saved yet.

```lua
-- Desktop 3 docked and undocked: one profile per screen count,
-- for all setups.
KiwiDesk.bind_profile_to_desktop(3, "Laptop")
KiwiDesk.bind_profile_to_desktop(3, "Dual")
```

:::unreleased
**Screen arguments bind a profile for one screen setup.** After
the profile, pass the fingerprint of every screen in that setup,
as `list_monitors` prints them; the binding then loads only while
exactly those screens are connected. A call replaces the entry of
the same screen count **and** the same scope, so per count a
Desktop holds one profile for all screen setups and one for each
setup named, each of the profile's own screen count. Which entry
loads, and that either loads over the profile that holds the
connected setup, is the binding rung of [Profile Monitor
Sets](#profile-monitor-sets).

```lua
-- Desktop 3 on two screens: "Dual" anywhere, "Studio" at the desk.
KiwiDesk.bind_profile_to_desktop(3, "Dual")
KiwiDesk.bind_profile_to_desktop(3, "Studio",
  "Built-in Retina Display:1512x982", "LG UltraFine:2560x1440")
```
:::

**The number names the Desktop; it does not key the binding.**
KiwiDesk resolves the number you pass to the Desktop it
currently names and files the binding against that Desktop —
[Spaces and Desktops](spaces-and-desktops.md) has how a binding
survives Mission Control's renumbering. A number naming no
Desktop yet is remembered as a number and attaches when that
Desktop appears. A call in `init.lua` is re-resolved on every
load: if the Desktop you meant has moved, edit the number to
match what Mission Control shows.

**Example:**

```lua
KiwiDesk.bind_profile_to_desktop(1, "Developer Rig")
KiwiDesk.bind_profile_to_desktop(2, "Creator Studio")
```

### Space Reconciliation

**Every profile owns its own spaces.** Two profiles can each
define a space called `1` — or `Work` — and they are different
spaces, each with its own windows. The name is still how you
address a space (`focus_space 1` means "space 1 of the profile
I'm in"); the profile is the scope that name resolves in.

**Switching profiles remembers where your windows were.** When
you switch away, KiwiDesk files which space each window was in
under the profile you are leaving; when you switch back, it puts
them back.

A window the incoming profile has never seen — opened while
another profile was up — stays where it is when that profile
declares the space it is sitting in, and lands in the profile's
**fallback space** (`set_fallback_space`) when it does not.

This happens on any profile CHANGE — an explicit `load_profile`,
a Desktop binding swapping profiles under you, or a monitor
change that resolves a different profile. Re-applying the
profile that is *already* live changes nothing, so a reconnect
that lands on the same profile leaves your layout alone.

The record is per session and is not written to disk.

:::unreleased
**A monitor change holds a gone screen's spaces.** When a monitor
change resolves a different profile, a space that lived on a
monitor no longer connected — pinned there, or placed there by
the Main role or by KiwiDesk — and still holds windows on any
Desktop is *held* instead of pruned: it stays live on a remaining
monitor under its own name, or under the next number past the
highest live one where the incoming profile declares that name. A
profile or Standard that later applies and declares a held
space's current number moves it past the highest live number
again. A held space keeps its icon and mode — `reload_config`
does not reset its mode — and wears an asterisk badge in the
Space Bar
([#1507](https://github.com/KiwiCanopy/KiwiDesk/issues/1507)).

Once its monitor is back, a held space goes home when the
arrangement then live is the one it left — the same profile, or
the same Standard — and declares its original name: everything in
it moves into that space, which takes the returning arrangement's
mode, and the hold ends. This includes a reconnect that keeps the
live profile. With a different arrangement, or the name
undeclared, it stays held, pinned back to its monitor. With a
hand-written `init.lua` and no profile for the connected
monitors, a reconnect only places spaces, and a held space stays
held.

A held space is dropped once no window is left in it on any
Desktop, by `delete_space`, and on an explicit `load_profile`,
whose prune forwards it to the fallback space like any undeclared
space. `save_profile`, the `gui.json` space list and pins and the
per-profile record above never include one. A Desktop binding
switch holds nothing, and held spaces do not survive a restart
([#1646](https://github.com/KiwiCanopy/KiwiDesk/issues/1646)).
:::

### Profile Monitor Sets

A profile covers concrete **monitor sets** of one screen count — each a list
of monitor fingerprints plus the space→monitor pins valid for that
arrangement. Updating a profile while a new combination is connected
teaches it that combination. When displays change, KiwiDesk resolves
in this order:

1. **Desktop binding** — a profile bound to the Desktop your main
   screen is on and saved for the connected screen count
   ([bind_profile_to_desktop](#bind_profile_to_desktop)); a binding
   that cannot fire stands aside.
2. **Exact match** — a profile stores exactly the connected monitors
   → loaded clean.
3. **Count default** — the profile marked `default` for that screen
   count → loaded with the dirty flag.
4. **Built-in Standard** — no saved profile for that count → a built-in
   positional layout composes silently; screens beyond its plan each
   get one monocle space, so no screen is ever blank.

   The Standard only *owns tiling* when the config is GUI-managed: a
   `gui.json` sidecar exists *and* `init.lua` holds no code touching
   the managed vocabulary. With a hand-written — or hybrid — config,
   your Lua-declared tiling stays authoritative and the Standard
   merely steers the space→screen placement.

:::unreleased
Within the binding rung, a profile bound for exactly the connected
screen setup comes before one bound for all screen setups.
:::

Every space always resolves to a screen: an explicit fingerprint pin
wins, then the **Main** role (the space follows whatever display is
currently main — dock and undock without stale fingerprints), then
the built-in positional default.

And every screen keeps at least one space: whatever leaves a
screen empty — a pin, a moved or deleted space, a profile loaded
onto screens it was not saved for — KiwiDesk seeds one numbered
space there, in the layout the starter setup would open that
screen in. No file learns the seed until you save; `init.lua`
never does.

Explicitly loading a profile whose stored sets don't cover the
connected monitors works, but the state loads *dirty* until you
update the profile on this hardware or return to a covered set.

:::unreleased
A monitor set belongs to one profile. `save_profile` (unless
another profile owns the set), `load_profile` of a profile saved
for as many screens, and creating a profile hand the connected set
to that profile and remove it from every other
profile with that count; the set keeps the pins its previous owner
held for the Spaces the new owner declares. When that took the set
from another profile, the command returns the names and why:
`{"taken_from": ["Work"], "reason": "…"}`; otherwise it returns
nothing. The first start after updating, and restoring a
backup, settle every set several profiles hold onto the one that
loads it today (the alphabetically first); if that leaves the
count's default without a set, the default moves to the profile
that kept it. After that, start-up, a
monitor change and a Desktop binding never move a set, so two
hand-edited profiles that hold the same set still resolve as
before. A profile left with no set is *dormant*:
its file keeps `"monitor_sets": []` beside `"monitor_count"`, it is
never picked by its screens (a Desktop binding still loads it), it
still loads by name, and it takes a set back on its next load. A
dormant profile loses its default flag; the profile that took its
set becomes the default unless the count already has another.
:::

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
        "strategy": "alternating"
      },
      "grid": { "columns": 3, "rows": 2, "type": "dynamic",
                "fill_empty_cells": true,
                "split_direction": "horizontal",
                "new_window_placement": "last" },
      "monocle": { "orientation": "horizontal",
                   "app_bar": { "enabled": true,
                                "content": "icon",
                                "active_indicator": "edge_mark" } },
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
  // cascade): only the layers/rows this profile changes.
  // Omit the key entirely to inherit the base shortcuts.
  "layers": [
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

### macOS Desktops (Mission Control)

KiwiDesk's spaces are its own, independent of Mission Control's
Desktops; how the two nest, which screen chooses the profile,
what a Desktop remembers and how a binding survives renumbering
are in [Spaces and Desktops](spaces-and-desktops.md). The Lua
verbs: `bind_profile_to_desktop` (above) gives a Desktop its
own profile, and a switch by `focus_desktop` or
`move_to_desktop_and_follow` loads a bound profile like a swipe
does; `move_to_desktop` and `move_to_desktop_and_follow` are the
only KiwiDesk verbs that move a window between Desktops.

The Desktop you are on is `kiwidesk get_state`'s `desktop`
field, and a switch reports on the `desktop_change` event; a
secondary screen's own switch reports with `monitor` ≥ 2 and
never selects a profile. A remembered space the (possibly just
swapped) profile no longer has takes the exit of a Desktop
never visited ([Every Desktop keeps its own
Space](spaces-and-desktops.md#every-desktop-keeps-its-own-space-and-its-own-windows)).

## Animations, Sleep & Wake

### animations.set_duration

**Expects:** a number (milliseconds, clamped 50–1000).

**Does:** sets the general animation duration for window moves
and layout reflowing. Persisted per profile.

**Example:**

```lua
animations.set_duration(150)
```

### animations.set_scroll_duration

**Expects:** a number (milliseconds, clamped 50–1000).

**Does:** sets the scrolling-layout focus-shift duration, an
independent knob, also persisted per profile.

**Example:**

```lua
animations.set_scroll_duration(150)
```

### animations.set_size_policy

**Expects:** `"smooth"` (default) or `"mid_slide"`.

**Does:** picks how a window's size is applied while it animates
(#47, #593). Engine-only and **not persisted** to a profile — an
expert knob like the bars' `dim_factor`, Lua-only and absent
from Settings. Set it from `init.lua` to make an override stick
across launches.

- `"smooth"` (default) — a growing axis follows the animation
  continuously. By default the size updates **per display
  tick** (matching the position channel, on any refresh rate),
  so slow-AX apps (Electron/WebKit: VS Code, Slack, Discord,
  Chrome) reflow once per frame; `animations.set_size_rate` can
  throttle that.
- `"mid_slide"` — a growing axis holds its start size, then
  grows in a single frame at halfway, where the ongoing slide
  masks the jump. Slow-AX apps reflow exactly once. Drop to this
  for an app that can't keep pace with `"smooth"`.

Shrinking splits by *what else is moving*, and only under
`"smooth"`:

- When every window in the change is being animated — a
  `resize` press, a ratio, gap or `min_window_size` edit — a
  shrinking axis follows the animation too, so the edge two
  panes share slides instead of jumping.
- When something is placed at its final size in one frame, a
  shrinking axis takes its target on the first frame. This
  covers window open and close, mode and space changes, and a
  **mouse resize**, where the window you dragged is already
  where you left it when the rest catches up.

Under `"mid_slide"` a shrinking axis always takes the first
frame. Either way the exact target lands on the settle frame.

**Example:**

```lua
-- fall back to the legacy sizing for a stubborn app
animations.set_size_policy("mid_slide")
```

### animations.set_size_rate

**Expects:** a number (hertz, clamped 1–120). `0` or negative
restores the default **per-tick** behavior (no throttle).

**Does:** caps how often the `"smooth"` policy emits a size-set,
bounding a slow-AX app's reflow load. By default the size
follows the display refresh (per-tick); set a lower rate only if
a heavy app falls behind. It caps both directions. No effect
under `"mid_slide"`. Engine-only, not persisted (#47, #593).

**Example:**

```lua
animations.set_size_rate(30)   -- throttle a heavy app
animations.set_size_rate(0)    -- back to per-tick default
```

### animations.set_on_space_change

**Expects:** `true` or `false` (default `false`).

**Does:** enables or disables the coordinated animation when
switching spaces: the outgoing windows slide out to the hiding
corner while the incoming ones slide in from it — one toggle
drives both directions. Off (the default) is faster: a
coordinated switch animates *both* spaces' windows at once, and
slow-responding apps (Electron/WebKit) can fall behind on the
extra per-frame window moves and stutter.

macOS Desktop switches are never animated in either direction —
macOS stops reporting an inactive Desktop's windows to
Accessibility (see
[Accepted limitations](accepted-limitations.md)).

**Example:**

```lua
animations.set_on_space_change(false)
```

### animations.set_on_scrolling

**Expects:** `true` or `false` (default `true`).

**Does:** enables or disables the layout slide as focus moves
within a Scrolling space.

While the slide runs, a window the pan merely *reveals* — one
already sitting at its final frame, pinned at the top screen
border or at an edge walled by a neighboring screen — is brought
to the front only when the pan settles. A window whose own frame
moves — sliding in from an open edge's void, or traveling to its
resting position under a `start`/`center`/`end` anchor — and the
focus handoff after closing a window raise immediately, riding
in on top. The trade: during a stationary reveal (one animation
length, 50–1000 ms) keystrokes still reach the previously
focused app. Global hotkeys are unaffected (they reach KiwiDesk
regardless of the key app), and with the slide disabled focus
transfers instantly. See the
[accepted limitations](accepted-limitations.md) table.

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

### animations.set_on_monocle_focus

**Expects:** `true` or `false` (default `true`).

**Does:** enables or disables the card flip when focus moves
between the windows of a Monocle Space. The window blurs and a
plate turns from the outgoing app's icon to the incoming one's;
the focus swaps beneath it as soon as the blur covers it, so the
keyboard reaches the new window at once. Further presses during
the turn land instantly, the card showing the newest window's
icon and the blur lifting a quarter second after you pause. The
plate turns forward for the next window in the Space's order
and back for the previous one — the way the key pointed, on a
`focus` step — about the vertical axis in a horizontal Monocle
and the horizontal one in a vertical Monocle. It plays only for
a focus change KiwiDesk itself commands — a `focus` step, an App
Bar click, `pull_or_spawn` — never for one macOS made (⌘Tab, the
Dock), and never onto a floating window. A plate whose next
window is smaller (an app that refuses the full slot) lands on
that window's own frame. macOS's Reduce Motion keeps the flip
off regardless.

**Example:**

```lua
animations.set_on_monocle_focus(false)
```

### animations.set_monocle_flip_duration

**Expects:** a number (milliseconds, clamped 100–1000; default
`450`).

**Does:** sets how long the Monocle flip's turn takes; the blur
fades in and out around it on fixed times. It has no effect
while `set_on_monocle_focus` is off.

**Example:**

```lua
animations.set_monocle_flip_duration(300)
```

### enable_wake_restore, set_wake_restore_delay

**Expects:**

- `enable_wake_restore(bool)` — `true` or `false`.
- `set_wake_restore_delay(ms)` — a number (milliseconds).

**Does:** when `true`, restores window positions and focus after
the machine wakes from sleep or the screen unlocks, after the
specified delay (default 1500 ms). The restore is skipped when
the display set changed while the machine was away (undock,
monitor power-off); the monitor-change profile resolution wins
instead. A restore that does run finishes with a full retile,
like any space switch, and focuses the remembered window —
raises it and activates its app — so shortcuts act on it
immediately. If that window is gone, focus follows whatever
macOS brought to the front at unlock.

**Example:**

```lua
KiwiDesk.enable_wake_restore(true)
KiwiDesk.set_wake_restore_delay(1500)
```

### Animation Cascade

**Profiles own all animation settings.** Like every other tiling
setting, `animations.*` — the duration knobs included — is saved
in a profile. When a profile is bound to a macOS Desktop
(`bind_profile_to_desktop`), switching to that Desktop loads the
profile and **replaces** the live settings, so `animations.*`
calls in `init.lua` apply only until a bound profile activates.
To make a value stick on a bound Desktop, set it and re-save
that profile (or edit the profile JSON).

### Quit & Restart

Quitting KiwiDesk saves the current arrangement — window order
per space, focus, and the active space — and restores it on the
next launch. After the restore, KiwiDesk lands on the space of
the window that has focus *right now*, falling back to the space
that was active at quit. This works within one login session
(macOS window ids reset on logout/reboot; after that, windows
are re-tiled fresh). Crashes restore from the last autosave
(30 s interval) instead.

On quit or restart, KiwiDesk moves each managed tiled window
back onto the monitor its space is assigned to and arranges them
per `quit.layout` (see `quit.set_layout` below). Floating
windows are left wherever they are. KiwiDesk keeps all managed
windows on the single visible macOS Desktop (inactive spaces are
parked off-screen at the peek corner, not on a different
Desktop), so every reachable window lands there together.
Windows on a display's background Desktops cannot be
repositioned without disabling SIP, which KiwiDesk never does —
the visible Desktop per display is the arranged scope.

### quit.set_layout

**Expects:** the string `"grid"`.

**Does:** picks how remaining managed windows are spread on quit.
`grid` builds a per-display grid and round-robin fills it —
window 1 into cell 1, window 2 into cell 2, wrapping back to
cell 1 and stacking. Windows sharing a cell cascade vertically
like `overflow_all`, in **every** cell, so each title bar stays
reachable. After placing, KiwiDesk raises every window in a
fixed circle — cell 1 through the last cell, each pile top slot
first and deepest slot last — so within a pile every title bar
stays visible and later cells sit above earlier ones (one window
is exempt; see below). It waits for each raise to land before
issuing the next.

The whole restack is capped at one second across every display.
The cap is a hard stop: once reached, the restack stops after at
most one more raise — it does not carry on through the rest of
the display it was on, and it does not start a display it had
not reached. Those windows keep whatever stacking the moves left
them in.

**The window you were last working in gets a slot chosen for
it** — the last one in its cell, so it sits in front of that
cell's pile — and is left out of the raise circle: no quiet
raise can lift another window above the frontmost app's key
window, so it is in front whatever the circle does. Every other
window lands where the circle puts it regardless of the z-order
at quit. If the frontmost app has no window in the grid, the
circle is followed exactly. KiwiDesk's own Settings window
tiles, so quitting with it frontmost places it last like any
other window.

A pile's windows also shrink so the cascade ends at its own
cell's bottom edge (floored at `min_window_size`), keeping piles
from spilling into the row below. Each display sizes its own
grid from its window count `N` and the density target `T` (see
`quit.set_grid_target_depth` below): `ceil(sqrt(N / T))`,
clamped between 2×2 and 4×4 — at the standard target 5, up to 20
windows get 2×2, up to 45 get 3×3, beyond that 4×4. One-shot
teardown placement: windows stay on their own display, and
nothing is managed afterwards. Profile JSON key: `quit.layout`.
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
display's window count, and stay hard-clamped between 2×2 and
4×4; the target only moves the growth thresholds (2×2 through
`4×T` windows, 3×3 through `9×T`, 4×4 above). It is not a hard
maximum: past 4×4, additional windows keep cascading in its
cells. Profile JSON key: `quit.grid_target_depth`. Default: `5`.

**Example:**

```lua
quit.set_grid_target_depth(10)  -- denser piles, later growth
```

When AX permission is revoked mid-session, KiwiDesk pauses window
management but cannot gather windows — `setFrame` calls return
`kAXErrorAPIDisabled` and are silent no-ops. Windows stay wherever
the WM left them; re-enabling Accessibility in System Settings
resumes management.

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
space objects), `windows` (array of window objects), `away_windows`
(array of the windows on Desktops no screen shows, each with `id`,
`app`, `bundle_id`, `space_id` — `nil` for a window found at boot
that no Space has filed yet — and `desktop`, its Mission Control
number), `monitor_count`,
`desktop` (the main screen's current Desktop — the number
bindings fire on), `exec_running` (count of `KiwiDesk.exec`
children still running).

Each space object has: `id`, `mode`, `windows` (array of window ids),
`focused` (focused window id or `nil`), `away_windows` (ids of the
space's windows that are on a Desktop no screen shows, in the order
they will return in), and — only while a stack
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
print(state.desktop)

for _, window in ipairs(state.windows) do
    if window.floating then
        print("Floating: " .. window.app)
    end
end
```

### help

**Expects:** nothing, or one command name.

**Does:** returns the API surface as a table. With no argument
you get every command grouped by its Lua table, each carrying its
arguments and a one-line summary:

```lua
{
  commands = <how many there are>,
  groups = {
    { name = "KiwiDesk", commands = { … } },
    { name = "app_bar",  commands = { … } },
    …
  }
}
```

Naming one command returns just its record — `name`,
`qualified_name`, `group`, `command`, `channel`, `summary`,
`aliases`, and an `arguments` list. An enum-valued argument also
carries `values` (its legal spellings) and `value_type` (the
Swift type they are read from).

An unknown name is an error carrying a did-you-mean suggestion.

`KiwiDesk.list_commands` is the same command under another name.
The terminal equivalents are `kiwidesk list_commands` and
`kiwidesk help <name>`, which render this for a human — see the
[CLI reference](cli.md#discovering-commands).

**Example:**

```lua
KiwiDesk.help()                     -- the whole surface
KiwiDesk.help("scroll.set_anchor")  -- one command
```

## Recipes

For integration recipes and advanced patterns, see the
[recipes](recipes/index.md).

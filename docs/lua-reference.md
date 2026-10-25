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

A migrated file's previous version is kept in
`~/Library/Application Support/KiwiDesk/migration-backups/` — see
the [user guide](user-guide.md#the-guijson-file).

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

A [`kiwishelf.*`](#kiwishelf) setter counts as a setting too.

:::unreleased
A [`kiwihub.set_key`](#kiwihubset_key) call counts as a setting too.
:::

```lua
-- Any one of these makes init.lua the config owner:
KiwiDesk.set_mode(1, "stack")
bsp.set_ratio_h(0.6)
float_rules = { "com.apple.systempreferences" }
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
cycles and scrolling steps to the previous/next window.
Cross-axis directions keep the geometric search. The track
layout steps in window order on both axes: along the axis
within the focused track, across it to the neighboring track
(same relative position).

:::unreleased
What happens past the last window that way is
[`set_focus_wrap`](#set_focus_wrap)'s.
:::

The search is two-tier: **tiled windows always win**, and only
when no tiled window lies in the pressed direction are the
space's *floating* windows (including floating sticky windows
shown on the space) considered, by their live frames. Transient
panels (Spotlight-style launchers) and fullscreen windows are
never focus targets. A float parked
*exactly* on a tiled slot is reached by no direction — click it
or cycle to it instead
([Accepted limitations](accepted-limitations.md)). `swap` is
tiled-only.

:::unreleased
A float past the last window that way is reached before focus
wraps or leaves the screen, except under `"this_screen"` in
Scrolling, Monocle and Track, where the wrap wins: there a float
past that edge is reachable on the cross axis only, except with a
single tiled window, when it is reachable on both axes.
:::

While a KiwiVision lens is on with
[`keep_focus`](#kiwivisiondefine_lens), `focus` and `swap` skip
the windows the lens leaves out.

**Example:**

```lua
KiwiDesk.focus("left")
```

### focus_window

**Expects:** a window id, as `list_windows` and `get_state` report
it.

**Does:** focuses that window. One on another Space switches to
that Space, landing on it, as clicking it in the Space Bar does. A
window in native full screen, on a Desktop no screen shows, or
unknown to KiwiDesk is refused.

**Example:**

```lua
KiwiDesk.focus_window(1234)
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
never wraps at the ends, whatever
[`set_focus_wrap`](#set_focus_wrap) says.

**Example:**

```lua
KiwiDesk.swap("right")
```

A window id in place of the direction, as
[`list_windows`](#list_windows) reports it, swaps the focused
window with that window, and focus goes with your window wherever
it lands — onto another screen, or into a Space no screen shows,
which `swap` then switches to. A second id swaps the two named
windows, neither of which needs the focus; focus stays where it
is unless one of them lands in the Space you are on, which then
focuses it. Two windows in different Spaces, on one screen or
two, trade places: each takes the other's slot. A floating
window, a window in native full screen and a sticky window that
cannot change Space are refused. A direction followed by a window
id swaps that window with its neighbour in that direction, in the
Space you are on, and moves no focus.

```lua
KiwiDesk.swap(1234)
KiwiDesk.swap(1234, 5678)
KiwiDesk.swap("left", 1234)
```

### swap_here

**Expects:** a window id, as [`list_windows`](#list_windows)
reports it.

**Does:** brings that window into the focused window's slot and
focuses it; you stay where you are, and the focused window takes
the other window's place, in its Space or on its screen. Refused
as for [`swap`](#swap).

**Example:**

```lua
KiwiDesk.swap_here(1234)
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

:::unreleased
When the target Space is on another screen, the pointer moves
there too, whether or not
[*mouse follows focus*](#mouseset_follows_focus) is on: onto the
focused window, or to the centre of that screen's usable area
when the Space is empty. It stays put when it is already on that
screen or a mouse button is held. A move-and-follow onto another screen's Space
does the same.
:::

**Example:**

```lua
KiwiDesk.focus_space(2)
KiwiDesk.focus_space("mail")
```

### focus_space_previous / focus_space_next

**Expects:** nothing.

**Does:** switches the focused window's screen to the previous or
next Space in that screen's order — the Space Bar's, an empty
Space included where the bar hides it. It never creates a Space.
The ⌃⌥⌘ + scroll gesture takes the same step on the screen under
the pointer.

:::unreleased
Past the last Space it wraps to the first, and past the first to
the last, on the same screen — never onto another one. With
[Wrap focus](#set_focus_wrap) `off` it stops there instead: the
focused window's ring bumps toward the step, as at the end of a
row, and nothing switches. A screen with one Space stops there
too. A wrap slides in the key's direction.
:::

Seeded on `⌃⌥⌘←` and `⌃⌥⌘→` for a new setup; an existing one
gets them through **Restore Defaults…**.

**Example:**

```lua
KiwiDesk.focus_space_next()
```

### focus_space_back / focus_space_forward

**Expects:** nothing.

**Does:** goes back to the Space you were on before this one, and
forward again — a browser's back and forward over the Spaces you
visited, never over the Space order. Every arrival counts as a
visit: a key, a Space Bar click, a move-and-follow, a macOS
Desktop switch that brings a bound profile's Space. Back and
forward only move along what you visited; visiting a Space any
other way clears the forward half.

[`set_space_history`](#set_space_history) says whose visits they
walk: each screen's own (the default, acting on the focused
window's screen) or one history across every screen. A visit to a
Space that has since gone is skipped, and a held Space renumbered
on a screen change keeps its visits. At the end of the history
the focused window's ring bumps and nothing switches. The history
starts fresh each time KiwiDesk starts.

Seeded on `⌥⌘Tab` (back) and `⌥⌘⇧Tab` (forward) for a new setup;
an existing one gets them through **Restore Defaults…**.

**Example:**

```lua
KiwiDesk.focus_space_back()
```

:::unreleased
### focus_display_last / focus_display

**Expects:** nothing for `focus_display_last`; a direction
(`"left"`, `"right"`, `"up"` or `"down"`) for `focus_display`.

**Does:** moves focus to another screen, switching to the Space
that screen shows — its last focused window comes forward and
the pointer follows. Neither changes which Space a screen shows;
an empty one still becomes the focused screen, so the next press
acts from it.

- `focus_display_last` goes to the screen you were on before, like
  ⌘Tab for screens: with two screens one key toggles between them,
  with three or more it returns to the one you were on just before.
  Every arrival on a screen counts — a key, a click, hover focus,
  a focus key past the last window, a move-and-follow, a Space Bar
  click. The record starts fresh each time
  KiwiDesk starts; with two screens and nothing recorded it goes to
  the other one.
- `focus_display` goes to the nearest screen in that direction, by
  the arrangement in System Settings ▸ Displays. A screen counts
  only where it overlaps the focused screen across that direction,
  so a diagonal one is no neighbour, and focus stops at the edge.

With one screen, or with nothing recorded among three or more, the
focused window's ring bumps and the command fails with `no other screen`;
`focus_display` at an edge bumps toward it and fails with
`no screen <direction> of focus`. Each visit also counts in the
[Space history](#focus_space_back--focus_space_forward).

`focus_display_last` is **Go to last screen** under Settings ▸
Shortcuts & Gestures ▸ Focus, with no default chord; `focus_display` is
Lua and CLI only.

**Example:**

```lua
KiwiDesk.focus_display_last()
KiwiDesk.focus_display("right")
```
:::

### move_to_space

**Expects:** a space identifier.

**Does:** moves the focused window to that space **without
following** it — you stay on the current space. The moved
window becomes the target space's focused window, so the first
time you switch there it is the window you land on.

If the target space is shown on **another screen**, a floating
window is re-anchored onto that screen: it keeps its
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

`move_to_space` and `move_to_space_and_follow` take an optional
window id from [`get_state`](#get_state) after the space, and
then move that window rather than the focused one:
`KiwiDesk.move_to_space("mail", 4711)`. An id no managed window
carries is refused. A window moved into the current Space takes
focus there; one moved between other Spaces leaves the current
Space's focus where it is.

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

That Space is not always the one you arrive on: `focus_desktop`
opens a Desktop on the Space it remembers for it, and when that
Space is empty a focused-window verb refuses by name —
`the active Space 2 is empty; the focused window (Finder) is in
Space 1 — focus_space 1 first` — the window being parked in its
own Space until you focus that Space.

When that Desktop lives on **another screen**, the window
instead joins the KiwiDesk Space that screen is showing when
the window lands there — for a hidden Desktop, the Space shown
at the moment you reveal it
([#1010](https://github.com/KiwiCanopy/KiwiDesk/issues/1010)).

**Given only a Desktop number**, a Desktop on the same screen
leaves the window's Space unchanged, and a **floating** or
**sticky** window keeps its Space on any screen
(`move_to_space` guards a sticky window the same way). With
**Keep sticky windows visible across Desktops** on (the default), a sticky
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
CLI's; the Shortcuts & Gestures page's Desktop rows bind the
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

:::unreleased
A follow onto a Desktop on another screen moves the pointer there
too, whether or not *mouse follows focus* is on
([`focus_space`](#focus_space)).
:::

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

**Expects:** a space identifier, then a screen reference — a
**number** (1-based position: `1` is the main screen,
`2` the next left-to-right) or a **string** matching a connected
screen's fingerprint (as printed by `list_monitors`) or name.

**Does:** moves the whole space to that screen **now** and
shows it there (each screen shows one space at a time). A
later screen change (dock/undock) re-resolves placement from
the pins; `pin_space_to_display` makes it stick. Creates the
space if it does not exist. Floating members are re-anchored
onto the new screen, keeping their relative position.

**Example:**

```lua
KiwiDesk.move_space_to_display("mail", 2)      -- second screen
KiwiDesk.move_space_to_display(3, "DELL U2723QE:3840x2160")
```

### pin_space_to_display

**Expects:** a space identifier, then a screen reference (same
forms as `move_space_to_display`).

**Does:** pins the space to that screen by the screen's
fingerprint, so the assignment survives dock/undock. Overrides
any Main-role assignment for the space. Creates the space if
new.

Under a GUI-managed config the Settings **Canvas** owns pins,
and a pin set from Lua is a session override; under a
Lua-managed config the pin persists across a relaunch.

A screen this pin leaves with no space is seeded one — see
[Profile Screen Setups](#profile-screen-setups).

**Example:**

```lua
KiwiDesk.pin_space_to_display("mail", 2)
```

### create_space

**Expects:** a space identifier, optionally a layout mode
(`"bsp"`, `"stack"`, `"scrolling"`, `"grid"`, `"monocle"`,
`"track"`, `"floating"`), and optionally a scope: `"session"`
(the default) or `"profile"`. The scope may stand in the mode's
place.

**Does:** creates the space and resolves it onto a screen.
Spaces also appear the first time you reference one
(`focus_space`, `move_to_space`, a keybinding); this verb
creates one, and its mode, up front. If the space already
exists, only the mode is set.

Run from `init.lua`, the space is declared by the script. Run
any other way — a keybinding, the CLI — it is **temporary**: a
switch to another profile holds it while it has windows and drops
it when it has none, it is deleted when its last window leaves,
and Keep and a Settings Save never write it —
only
[`save_profile`](#save_profile-load_profile-delete_profile-set_default_profile)
does. With `"profile"` the space is added to the live profile's
file at once — its place, layout, screen pin and icon — which is
what **Add Space ‹name› to this profile** in Settings ▸ Spaces
does. It is
refused while no profile is live, and for a space `init.lua` or
a built-in layout declares.

**Example:**

```lua
KiwiDesk.create_space("scratch", "monocle")
```

### delete_space

**Expects:** a space identifier, and optionally a scope:
`"session"` (the default) or `"profile"`, which also removes
the space from the live profile's file. `"profile"` is refused
while no profile is live, and for a space `init.lua` or a
built-in layout declares.

**Does:** removes the space after moving its windows to the
fallback space (or the first surviving space), and clears the
space from the placement pins, Main role, and per-space
settings. Refuses to delete the only space. Runtime only: a
space still declared in `init.lua` or the active profile
reappears on the next config load.

**Returns** `nil` for a space nothing declares (and for a refused
delete, which is logged). When the space comes back on the next
config load, it returns a table whose `declared_in` array names
every source that re-creates it: `profile:<name>` (the active
profile — save it to make the removal last), `standard:<name>`
(the built-in layout resolving while no saved profile fits —
save a profile), `init.lua` (a verb there references it — remove
the call). Test the return, not the status (#1509).

A screen this leaves with no space is seeded one — see
[Profile Screen Setups](#profile-screen-setups).

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

### cycle_mode

**Expects:** optionally a direction: `"prev"` or `"next"` (the
default) — exactly these, no `previous` alias, as `move_to_track`.

**Does:** moves the focused Space to the next layout in your
layout cycle list (see [`set_mode_cycle`](#set_mode_cycle)), or
to the previous one, the same way `set_mode` would. The list
wraps: after the last layout comes the first. A Space whose
layout is not in the list goes to the first layout on Next and
to the last on Previous. It never creates a Space.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+c", function()
    KiwiDesk.cycle_mode()
end)
```

### set_mode_cycle

**Expects:** a table of layout modes, in order — at least two,
each at most once.

**Does:** sets the layouts `cycle_mode` walks. The default is
`{ "bsp", "scrolling", "floating" }`.

It is stored like the shortcuts: `mode_cycle` in `gui.json` is
the list every profile uses, and a profile may keep its own,
which the **Layouts to cycle** row's **Applies to** writes. The
verb sets the shared list for the running session and never
reaches a file; a profile's own list still wins.

**Example:**

```lua
KiwiDesk.set_mode_cycle({ "bsp", "stack", "monocle" })
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

The one exception is a bar set not to reserve its strip
([`space_bar.set_reserve`](#space_barset_reserve) and
[`app_bar.set_reserve`](#app_barset_reserve)), which draws over the windows.

A revealed `auto` or `hidden` bar draws over the windows too
([`space_bar.set_visibility`](#space_barset_visibility),
[Per-Layout App Bar Overrides](#per-layout-app-bar-overrides)).

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

**Expects:** a width in points, then optionally a height in
points and a layout: `stack`, `grid`, `track`, `bsp`,
`scrolling` or `floating`. Without a height the width serves
both; a layout may stand in the height's place.

**Does:** no window is shrunk below this width or height
([When windows no longer fit](#when-windows-no-longer-fit)). Without a layout it sets every layout; with one, only
that layout. Scrolling applies only the axis it scrolls along,
and Floating's value bounds every floating window. Monocle
keeps no minimum.

**Example:**

```lua
KiwiDesk.set_min_window_size(300)            -- every layout
KiwiDesk.set_min_window_size(220, 160, "grid")
KiwiDesk.set_min_window_size(480, "scrolling")
```

### set_min_window_size_override

**Expects:** a space identifier, a width in points, then
optionally a height in points. Without a height the width serves
both.

**Does:** gives one Space its own minimum window size, which
replaces whatever value its layout has in
[`set_min_window_size`](#set_min_window_size), floating windows
included. The value stays with the Space when the Space moves to
another screen. Monocle still keeps no minimum. The quit gather
lays windows out per screen and keeps Floating's value.

**Example:**

```lua
KiwiDesk.set_min_window_size_override("monitoring", 220, 160)
```

### set_resize_step

**Expects:** a number (points).

**Does:** sets the magnitude the **Grow** / **Shrink**
keybindings nudge the layout by (default 50). The Shortcuts &
Gestures page authors the four per-axis bindings as
`resize("x"|"y", ±step)` from this value, and importing a
config reads a recovered magnitude back into it. Moves no
window on its own; it takes effect the next time such a binding
fires.

**Example:**

```lua
KiwiDesk.set_resize_step(75)
```

### reset_layout_sizing

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
orientation and stack position, the
scrolling anchor and orientation, the track axis and limit, a
grid's columns and rows, new-window placement. Where a window's
own minimum binds, the next retile's floor heal moves the ratio
back off that value by as much. Retiles at once. Bind it from
`init.lua` or the Shortcuts & Gestures ▸ Lua bindings drawer.

A grid's column and row sizes from `resize` are sizing too, and
return to the weights `grid.set_column_weight` and
`grid.set_row_weight` set.

`⌃⌥R` runs it on the active space by default, listed as **Reset
sizes in this Space** under Shortcuts & Gestures ▸ Size & float.
`"all"` has no default key.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+equal", function()
    KiwiDesk.reset_layout_sizing("all")
end)
KiwiDesk.reset_layout_sizing("mail")
KiwiDesk.reset_layout_sizing("all")
```

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

### set_float_placement

**Expects:** `"center"` (default) or `"keep"`.

**Does:** where a window lands when `make_floating` or a
`toggle_floating` that lands on floating turns it from tiled to
floating, or when a move command (`move_to_space`, a quick drop
on the Space Bar, a Desktop move that re-files it) moves a tiled
window into a floating-mode Space, or when a `float_rules` entry
you add starts floating a window that was tiled (a window a rule
floats as it opens keeps the frame its app gave it); a window
still being dragged
lands where you drop it. `"center"`: it
is centered in the area of its screen
clear of the menu bar and any App/Space Bar, at a size measured
from that area: two thirds of the short side, and along the long
side a third, at least 800 pt but never more than 1.25 times the
short-side span (so under 800 pt on a short screen). A landscape
screen gets a tall window; a portrait one gets a wide one. An app
that will not go that small, or that large, keeps its own limit.
Where another floating window on that Space already sits at the
center, the new one steps down and to the right, like a stack of
cards, as long as the step still fits on the screen.
A window floated again after you tiled it returns to the frame it
last floated at, while that frame is still on the same screen;
KiwiDesk forgets it when the window closes, its app quits or
KiwiDesk quits.
`"keep"`: the window keeps the frame it had in the layout. Never fires on `make_tiled`
or a window already floating, including one on a
floating-mode Space. Global (per profile, all spaces); no Settings
toggle. Replaces `set_float_nudge`: a saved setting that had the
nudge off becomes `"keep"`, while an `init.lua` call to
`set_float_nudge` fails naming this verb and must be renamed.

**Example:**

```lua
KiwiDesk.set_float_placement("keep")
```

### set_float_scale_on_display_change

**Expects:** `true` or `false` (default `true`).

**Does:** whether a floating window re-anchored across screens
also scales its **size**. `true`: a float that crosses to a
differently sized screen is scaled by the per-axis ratio of
the two screens — half of a 4K screen becomes half of a 1080p
one — as well as re-anchored to the same relative spot. Applies
wherever a float crosses screens (`move_to_space`, moving a
space to another screen, a screen-change sweep), and to
windows floating only because their space is in floating mode.
The result stays fully on screen and clear of any App/Space
Bar. `false` keeps the exact pixel size across screens: a
too-wide window then overflows the edge of a smaller screen
(macOS clamps a window's height but not its width), and the
window keeps its aspect ratio between screens of different
aspect ratios (16:9 → 16:10). Global (per profile, all spaces);
no Settings toggle.

**Example:**

```lua
-- keep a float's exact pixel size across screens
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
silent, and a held chord sounds once per hold.

A refusal only the app can give — [`new_window`](#new_window)
finding no New Window, [`close_window`](#close_window) no close
button — draws without the sound: it arrives after the app
answers, when the hotkey fire is over.

The retired `resize.feedback` key is dropped by the one-shot
migration, its value not carried across.

The GUI twin is **General ▸ Play a sound when an action is
blocked**. The setting is app-wide: it is stored in
`gui.json` as `refusal.sound`, no profile carries it, and
loading a profile never changes it. A GUI-managed setup takes
it once from the first saved profile loaded after the upgrade,
and then removes it from every profile file
([#1741](https://github.com/KiwiCanopy/KiwiDesk/issues/1741)).

The verb changes the running value only: it never reaches
`gui.json`, so the General row's value returns the next time
KiwiDesk loads its config. In a Lua-owned setup, `init.lua` is
where it is kept, and the General row is greyed. **Adopt into
the GUI** keeps the value `init.lua` set.

**Example:**

```lua
KiwiDesk.set_refusal_sound(true)
```

### set_space_history

**Expects:** `"per_screen"` or `"all_screens"` (default
`"per_screen"`).

**Does:** which visits [`focus_space_back` and
`focus_space_forward`](#focus_space_back--focus_space_forward)
walk. `per_screen` keeps one history per screen and steps the
screen the focused window is on; `all_screens` keeps one history
across every screen, so going back may move you to another
screen. With one screen the two are the same.

It is stored like the shortcuts: `space_history` in `gui.json` is
the value every profile uses, and a profile may keep its own,
which the Settings row's **Applies to** writes. The verb sets the
shared value for the running session and never reaches a file; a
profile's own value still wins.

**Example:**

```lua
KiwiDesk.set_space_history("all_screens")
```

:::unreleased
### set_focus_wrap

**Expects:** `"off"`, `"this_screen"` or `"all_screens"`
(default `"all_screens"`).

**Does:** what [`focus`](#focus) does at the last window in the
pressed direction, in every layout. `swap` never wraps.

- `off`: focus stops there; the ring bumps toward the edge and
  the command fails with `no window <direction> of focus`.
- `this_screen`: focus wraps to the window at the opposite edge
  of the same screen — in BSP, Stack and Grid the nearest one in
  the same row or column; in Scrolling, Monocle and Track the
  far end of the order. A Floating Space stops at its last
  window.
- `all_screens`: focus continues to the window nearest the
  entering edge on the next screen that way, switching to the
  Space that screen shows. Past the last screen it wraps to the
  farthest screen on the other side. A screen counts only where
  it overlaps the focused window's row (←/→) or column (↑/↓); a
  screen showing no window is skipped. With one screen it works
  like `this_screen`.

In Scrolling and Monocle the edge is the end of the window
order, not the screen edge, and a Stack or Track run that hides
windows is walked to its end first. A wrap within the screen
that lands back in the same run goes to the run's far end, even
a window the run hides. The pointer follows the
crossing like any
[Space switch onto another screen](#focus_space).

It also decides whether
[`focus_space_previous` / `focus_space_next`](#focus_space_previous--focus_space_next)
and the ⌃⌥⌘ + scroll step wrap at a screen's first and last
Space.

It is stored like the Space history: `focus_wrap` in `gui.json`
is the value every profile uses, and a profile may keep its own,
which the **Wrap focus** row's **Applies to** under Shortcuts &
Gestures ▸ Focus writes. The verb sets the
shared value for the running session and never reaches a file; a
profile's own value still wins.

It replaces the retired `scroll.set_wrap_focus`,
`monocle.set_wrap_focus` and `track.set_wrap_focus`; a call to
one is reported in Config Issues naming this verb.

**Example:**

```lua
KiwiDesk.set_focus_wrap("this_screen")
```
:::

### set_desktop_cue

**Expects:** `true` or `false` (default `true`).

**Does:** whether a Desktop switch KiwiDesk performs — such as
[`focus_desktop`](#focus_desktop) or
[`move_to_desktop_and_follow`](#move_to_desktop_and_follow) —
shows a plate in the middle of the screen that switched: the
Desktop's Mission Control number, a dot for each Desktop on that
screen with the current one filled, and the profile a
[Desktop binding](#bind_profile_to_desktop) loaded, if one did
(#2142). It takes no focus or click, fades after about a
second, and stays away from a screen showing a full-screen app
or a presentation. A swipe or Mission Control switch shows nothing; macOS
animates those itself.

The GUI twin is **Profiles ▸ Profiles per macOS Desktop ▸ Show
the Desktop's number after a switch**. Like
[`set_refusal_sound`](#set_refusal_sound), the setting is
app-wide, stored in `gui.json` as `desktop.cue`; the verb
changes the running value only.

**Example:**

```lua
KiwiDesk.set_desktop_cue(false)
```

### set_hyper_key

**Expects:** a key name, or `off` (default `off`): `caps_lock`,
`left_command` / `right_command`, `left_option` /
`right_option`, `left_control` / `right_control`, `left_shift`
/ `right_shift`, or `f1` … `f20`.

**Does:** turns that key into the Hyper modifier, `hyper` in a
combo (`"hyper+h"`), drawn ✦ (#1870). KiwiDesk remaps the key
while it manages your windows and gives it back when it stops or
quits, so the key stops doing its own job meanwhile — Caps Lock
types no capitals, Right ⌘ is no longer ⌘. Left and right are different keys here. Hyper
needs no Input Monitoring, and a shortcut on Hyper alone collides
with nothing; combined with ⌘, ⌥ or ⌃, an enabled macOS shortcut on
the same keys still wins. If a key mapping KiwiDesk did not set is already in place
(another remapping tool, `hidutil` by hand), the verb refuses
and leaves it alone.

When that mapping is exactly the one KiwiDesk would write for the
chosen key, the Hyper key row's **Take Over** and
[`take_over_hyper_remap`](cli.md#commands) make it KiwiDesk's.

While no shortcut in the active layer uses `hyper`, pressing the
key does nothing and draws a short note saying so.

The GUI twin is the **Hyper key** row in **Shortcuts & Gestures ▸
Modifier keys**, a recorder that takes one key — left and right
apart. Like
[`set_desktop_cue`](#set_desktop_cue), the setting is app-wide,
stored in `gui.json` as `hyper.key`; the verb changes the running
value only.

**Example:**

```lua
KiwiDesk.set_hyper_key("caps_lock")
KiwiDesk.bind("hyper+h", function() KiwiDesk.focus("left") end)
```

:::unreleased
### set_modifier_sides

**Expects:** `true` or `false` (default `false`).

**Does:** `true` makes a shortcut written with a side keep that
side: `rcmd+h` fires from the right ⌘ alone, `lcmd+h` from the left
one; the spellings are under [Modifiers and Keys](#modifiers-and-keys).
A shortcut without a side fires from either. A shortcut with a side
and one without it on the same keys both work: the sided one on its
side, the other on the other side.

`false` fires every shortcut from either side, sides written or
not. Nothing is rewritten, so turning it on again brings the sides
back. Two shortcuts that then fall on the same keys, such as
`lcmd+h` and `rcmd+h`, are a conflict, and only one of them works.

To tell the sides apart, KiwiDesk reads key presses, but only while
this is `true` and at least one shortcut keeps a side, and it acts
only on the shortcuts on those keys. If macOS refuses that
(Accessibility not granted), those shortcuts fire from either side,
as with `false`. They fire once per press when held
([resize](#resize)).

The GUI twin is **Tell left and right modifiers apart** in
**Shortcuts & Gestures ▸ Modifier keys**. Like
[`set_hyper_key`](#set_hyper_key), the setting is app-wide, stored
in `gui.json` as `modifier.sides`; the verb changes the running
value only.

**Example:**

```lua
KiwiDesk.set_modifier_sides(true)
KiwiDesk.bind("lalt+space", function()
    KiwiDesk.focus_or_spawn("com.mitchellh.ghostty")
end)
KiwiDesk.bind("ralt+space", function()
    KiwiDesk.focus_or_spawn("com.apple.Safari")
end)
```
:::

:::unreleased
### set_space_transition

**Expects:** `"slide"`, `"show"` or `"none"` (default `"slide"`).

**Does:** sets how an explicit Space switch —
[`focus_space`](#focus_space) and the Space history and order
steps, the [scroll Space step](#scroll_gestureset_space_step), a
[move-and-follow](#move_to_space_and_follow), Open or Focus onto
another Space or a launch follow — shows itself on the screen that
switched:

- `"slide"`: the plate slide. A plate with its app's icon fades in
  over each window on that screen, the plates slide as one strip
  one screen toward the new Space — across when the Space Bar's
  edge is the top or bottom, up or down when it is a side — and
  fade out over the windows that arrive. The windows themselves
  move once each, under the plates. The plates wear KiwiHub's
  glass
  ([`set_shortcut_panel_liquid_glass`](#set_shortcut_panel_liquid_glass)),
  tinted by the shelf's fill as
  [`kiwishelf.set_tint_hub_and_plates`](#kiwishelfset_tint_hub_and_plates)
  says, and otherwise dark where Settings' Appearance is.
  With Reduce Motion on, a switch shows the Space as `"show"`
  does, the stored value staying `"slide"`. Over a full-screen app
  or a presentation the screen changes at once, with no plate.
- `"show"`: the screen changes at once, and a plate in its middle
  shows the Space's name or number and its layout's symbol, whether
  or not that screen draws a Space Bar, and never over a
  full-screen app or a presentation. A switch picked on the Space
  Bar — a Space, a glyph or a list row — shows no plate; `"slide"`
  still slides there (#2591). It takes no focus or click
  and fades after about a second; with Reduce Motion on it appears
  and leaves without the fade.
- `"none"`: the screen changes at once.

The GUI twin is **Looks &amp; Animations ▸ Animations ▸ Space
switches**, which neither Reduce Motion nor the **Animate
windows** switch greys. Like [`set_desktop_cue`](#set_desktop_cue),
the setting is app-wide, stored in `gui.json` as
`space.transition`; the verb changes the running value only. It
replaces `set_space_cue`, `animations.set_space_change` and
`animations.set_on_space_change`, which are refused, naming it; a
stored `space.cue` that was on becomes `"slide"`, and one that was
off `"none"`.

macOS Desktop switches are never animated in either direction (see
[Accepted limitations](accepted-limitations.md)).

**Example:**

```lua
KiwiDesk.set_space_transition("show")
```
:::

:::unreleased
### set_space_slide_duration

**Expects:** a number (milliseconds, clamped 150–1000; default
`300`).

**Does:** sets the pace of the plate slide
([`set_space_transition`](#set_space_transition)): how long the
plates take to slide to the new Space. Their fades keep fixed
lengths whatever the pace: 80 ms in, 300 ms out. It has
no effect unless the transition is `"slide"`, nor while Reduce
Motion is on. Window motion keeps its own pace
([animations.set_duration](#animationsset_duration)). Read at the
next switch.

The GUI twin is **Looks &amp; Animations ▸ Animations ▸ Slide
duration**, grey while **Space switches** is not on Slide or
Reduce Motion is on. The
setting is app-wide, stored in `gui.json` as
`space.slide_duration`; the verb changes the running value only.
It replaces `animations.set_space_change_duration`, which is
refused, naming it.

**Example:**

```lua
KiwiDesk.set_space_slide_duration(450)
```
:::

### set_mode_cue

**Expects:** `true` or `false` (default `true`).

**Does:** whether [`cycle_mode`](#cycle_mode) shows a plate in
the middle of the focused Space's screen: your layout cycle list
(see [`set_mode_cycle`](#set_mode_cycle)) as a ring of layout
symbols, the first at the top and the rest clockwise, with the
layout the Space landed on large in the centre and its name
under it (#2144). Pressing again while the plate is up moves the
next layout from its place on the ring into the centre and the
previous one back out; with Reduce Motion on, it jumps. It takes
no focus or click, fades after about a second, and stays away
from a screen showing a full-screen app or a presentation. Only
`cycle_mode` shows it — [`set_mode`](#set_mode) and the Layout
menu do not.

Like [`set_desktop_cue`](#set_desktop_cue), the setting is
app-wide, stored in `gui.json` as `mode.cue`; the verb changes
the running value only.

**Example:**

```lua
KiwiDesk.set_mode_cue(false)
```

### set_shortcut_panel_liquid_glass

**Expects:** `true` or `false` (default `true`).

**Does:** lays a macOS&nbsp;26 Liquid Glass material over the
shortcuts panel, the one ⌃⌥K opens (#1307). Off, or below
macOS&nbsp;26, the panel draws `.regularMaterial`. The panel's
glass is untinted: it draws `.regular` where the bars draw
`.clear`, and no Fill reaches it (#1295).

:::unreleased
That holds while
[`kiwishelf.set_tint_hub_and_plates`](#kiwishelfset_tint_hub_and_plates)
is off. On, its default, KiwiHub draws `.clear` glass wearing the
shelf's fill (#2569). The Space, Desktop and layout plates read
this leaf too, and draw `.regularMaterial` while it is off.
:::

The shortcuts panel is a side of [KiwiHub](#kiwihubshow), so this
leaf sets the material of all of KiwiHub — the window switcher,
the shortcuts panel and the view picker.

Stored as `shortcut_panel.liquid_glass` in the profile, so a
profile switch can change the panel's material.

The slow-boot notice reads this leaf too: it draws its capsule
in the same material (#1715).

:::unreleased
The plates a Space switch slides
([`set_space_transition`](#set_space_transition)) read this leaf
too, and keep it untinted while
[`kiwishelf.set_tint_hub_and_plates`](#kiwishelfset_tint_hub_and_plates)
is off; `set_space_switch_liquid_glass` is
refused, since they have no leaf of their own.
:::

Also stood down while macOS's Reduce transparency is on, the
stored value untouched
([Liquid Glass](#kiwishelfset_liquid_glass)).

The GUI twin is the one **Liquid Glass** switch on Colours
&amp; Animations;
[kiwishelf.set_liquid_glass](#kiwishelfset_liquid_glass) says
what it writes.

**Example:**

```lua
KiwiDesk.set_shortcut_panel_liquid_glass(true)
```

### Space Identity

Spaces are identified by **strings or numbers** — `1` and `"1"`
are the same space, `"code"` and `"Code"` are not. Screens
carry no layout; windows live in spaces, and spaces are mapped
to screens (see *Profiles & Screens* below). A space is
renamed in place from the Settings app's **Spaces** section; the
rename is persisted and follows the id everywhere it is used —
its layout mode, app rules, screen pins, and any keybindings.

### How inactive spaces hide their windows

Switching spaces parks the other spaces' tiled windows in a
corner of their screen — [Parking is not a Desktop
move](spaces-and-desktops.md#parking-is-not-a-desktop-move)
owns the model.

:::unreleased
How the switch shows itself — the plate slide, at once with a
plate naming the Space, or at once — is
[`set_space_transition`](#set_space_transition).
:::

Focusing a hidden window (cmd+tab) pulls its space forward.
Floating windows, picture-in-picture included, are never parked
and stay visible across all spaces.

**Minimizing** a window removes it from its space. Restoring it
— from the Dock, or via [`focus_or_spawn`](#focus_or_spawn) when
the app has nothing left on screen — opens it in the space you
are on at that moment, as a new window (an `app_rules` entry
for its app still wins). **Hiding** an app (cmd+H, or an app
that hides itself on the red X) releases its tiles, and
unhiding returns its windows to the space they came from.

With **multiple screens**, arrange them so no screen
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
screen; the cascade fallback only triggers when two min-size
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

### stack.set_stack_position

**Expects:** `"top"`, `"right"` (default), `"bottom"`, or
`"left"`.

**Does:** sets which side of the space the stack zone takes;
the master zone gets the rest. `left`/`right` split the width,
`top`/`bottom` the height. The stack zone's lineup derives from
the position — a left/right zone stacks its windows vertically,
a top/bottom zone lines them up side by side; there is no
separate stack orientation knob. A pile always cascades
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
vertical alike.

Any resolved size is floored at Scrolling's minimum window size
([`set_min_window_size`](#set_min_window_size)) on the axis it
scrolls along — its width when it scrolls horizontally, its
height when it scrolls vertically — and capped at the axis
length.

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

**Does:** sets the grid's columns and rows: a rigid grid lays
these, and a dynamic grid balances up to them.

:::unreleased
The columns and rows are a limit: where a cell would fall under
the grid's [minimum window size](#set_min_window_size), the grid
lays as many as fit, as [auto-size](#gridset_auto_size) does,
and the windows past its cells scroll through its last track
([When windows no longer fit](#when-windows-no-longer-fit)).
:::

**Example:**

```lua
grid.set_dimensions(3, 2)
```

### grid.set_auto_size

**Expects:** `true` or `false` (default `false`).

**Does:** when true, derives the grid's dimensions from the
screen over the typed `columns`/`rows`. It caps a dynamic grid
and fixes a rigid one alike. Windows past the resulting
capacity overflow as
[When windows no longer fit](#when-windows-no-longer-fit)
describes.

The grid takes as many columns as fit at Grid's minimum window
width and as many rows as fit at its minimum height
([`set_min_window_size`](#set_min_window_size)):
`floor(usable width / (min width + horizontal inner gap))`
columns and `floor(usable height / (min height + vertical inner
gap))` rows, at least 1 each.

**Example:**

```lua
grid.set_auto_size(true)
```

### grid.set_column_weight

**Expects:**

- A column number, counting from 1 at the left.
- A positive number: that column's share of the width, `1` being
  an equal share.

**Does:** sets one column's width relative to the others (#763).
`grid.set_column_weight(1, 2)` in a three-column grid makes the
first column twice as wide as each of the other two. A column
with no weight set takes `1`, so a column the grid adds later
takes an ordinary share.

The weights belong to **positions, not windows**, like a
spreadsheet's column widths: a grid fills in arrangement order,
so when a window closes the windows after it move forward into
columns that keep their sizes. A grid that shows fewer columns
than you have weights for — a dynamic grid with fewer windows,
an auto-size grid on a smaller screen — uses the first ones and
keeps the rest for when the columns come back. With
[`fill_empty_cells`](#gridset_fill_empty_cells) on, the last
window of a short row spans the columns left in its row, so the
columns stay lined up in every row.

A column is never drawn narrower than the grid's minimum window
width ([`set_min_window_size`](#set_min_window_size)), or the
minimum its app enforces: it takes the room from the other
columns by their weights. `resize` and mouse resizes write a
session layer over this value, which this setter clears on every
space.

**Example:**

```lua
grid.set_column_weight(1, 2)
```

### grid.set_row_weight

**Expects:**

- A row number, counting from 1 at the top.
- A positive number: that row's share of the height.

**Does:** the row twin of
[`grid.set_column_weight`](#gridset_column_weight).

**Example:**

```lua
grid.set_row_weight(1, 1.5)
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

### grid.set_column_weight_override

**Expects:**

- A space identifier.
- A column number, counting from 1.
- A positive weight.

**Does:** sets one column's weight for one space, starting from
the weights that space had, and clears that space's resize
session layer for the columns.

**Example:**

```lua
grid.set_column_weight_override("3", 2, 1.5)
```

### grid.set_row_weight_override

**Expects:**

- A space identifier.
- A row number, counting from 1.
- A positive weight.

**Does:** the row twin of
[`grid.set_column_weight_override`](#gridset_column_weight_override).

**Example:**

```lua
grid.set_row_weight_override("3", 1, 2)
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
(`track.set_limit` with automatic tracks off) or on a screen
too narrow to fit the tracks at `min_window_size`; raise the
limit or widen the screen to reorder the overflow.

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
windows fold into it.
`move_to_track` can open the overflow track but not go past it.
A screen that cannot fit the tracks at `min_window_size` shows
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
  `move_to_space` drops onto a full track, it joins the
  focused track
  ([When windows no longer fit](#when-windows-no-longer-fit)).
- `own_track`: each new window opens its **own** new track,
  positioned among the others by
  [`track.set_new_window_position`](#trackset_new_window_position).
  Falls back to joining once `track.set_limit` is reached.

The fill-then-spill boundary is how many windows fit at
`min_window_size`, so a smaller screen spills sooner.

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

## KiwiShelf

**KiwiShelf** is where both bars are managed — the
[App Bar](#app-bar) and the [Space Bar](#space-bar), on one edge
or each on its own.
`kiwishelf.set_*` sets how deep the shelf is, where the bars sit
along their edge, how the two share one, and the styling, colours and app glyph style they share;
each bar keeps its own content and the shape of its active
indicator. Stored as `settings.kiwishelf` in a profile.

The shelf reserves its edge in a layout where a bar draws at
rest ([`space_bar.set_visibility`](#space_barset_visibility)):
in every layout while the Space Bar does, and otherwise only in
the layouts whose App Bar does (monocle and scrolling show one
by default). Where the Space Bar draws nothing at rest,
switching a Space between a layout that shows an App Bar and one
that does not moves its windows by the strip.

A bar can also show without reserving:
[`space_bar.set_reserve`](#space_barset_reserve) and
[`app_bar.set_reserve`](#app_barset_reserve) draw it over the windows instead, and an edge
stays reserved while either bar on it reserves.

Both bars hide on a screen showing a native-fullscreen app and
return with the Desktop.

They also hide on a screen whose front window — one KiwiDesk
manages — fills that whole screen, such as a slide show or a
borderless-fullscreen game or player, and return when another
window comes in front or that window stops filling the screen.
KiwiDesk leaves such a window where its app put it and never
moves it clear of the bars.

Each bar sets its own edge —
[`space_bar.set_edge`](#space_barset_edge) and
[`app_bar.set_edge`](#app_barset_edge). On the same edge the two
share one shelf, as described here; on different edges each bar
is its own, with its own plate, and `set_order`, `set_minimum` and
the divider do nothing until they share an edge again. Everything
else on this page applies to both bars wherever they sit, and
`set_alignment` places each bar along its own edge. Each edge is
reserved where its bar draws at rest: the Space Bar's in every
layout, the App Bar's only in the layouts where it does — so with
the bars split, switching a Space into or out of such a layout
moves its windows by the App Bar's strip. Where the two edges
meet at a corner, the Space Bar runs the whole edge and the App
Bar stops at it.

A bar's edge may also differ per screen — `set_edge`'s optional
screen argument — and each screen reserves the edges its own
bars sit on, so the bars may share one shelf on one screen and
sit apart on another.

An edge whose every bar has `reserve` off is not reserved
([`space_bar.set_reserve`](#space_barset_reserve)): its bar
draws over the windows.

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

### kiwishelf.set_alignment

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

### kiwishelf.set_order

**Expects:** `"spaces_first"` or `"apps_first"` (default
`"spaces_first"`).

**Does:** sets which bar's section comes first in the run while
both show. Edge-relative, like `set_alignment`.

**Example:**

```lua
kiwishelf.set_order("apps_first")
```

### kiwishelf.set_minimum

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

### kiwishelf.set_thickness

**Expects:** thickness in points (default `40`; anything below
`20` is raised to it).

**Does:** sets the shelf's thickness — both bars' — carved out of
the layout.

The starter setup seeds `32` when the main screen is shorter than
1000 pt.

**Example:**

```lua
kiwishelf.set_thickness(32)
```

### kiwishelf.set_glyph_size

**Expects:** points; `0` (default) means auto. A negative value
is raised to `0`.

**Does:** sets how large both bars' content draws across the
shelf — app icons and glyphs, Space identifiers and counts. `0`
fills the thickness. A positive value draws that size and leaves
the rest of the thickness as room around each item; the thickness
stays what the shelf reserves, and item boxes and plates keep it.
The content never draws thinner than a `20` pt shelf's nor
thicker than the shelf, and the stored value is kept, so a thicker
shelf later brings back a larger size. An automatic
[`font_size`](#kiwishelfset_font_size) follows it. Automatic
equals the thickness, so `thickness − 2 × room` leaves that room
on each side: `28` on a `40` pt shelf leaves `6` pt.

**Example:**

```lua
kiwishelf.set_glyph_size(16)
```

### kiwishelf.set_outer_margin

**Expects:** points (default `0`; a negative value is raised to
it).

**Does:** sets the shelf's distance from the screen border; `0`
is flush. From the border inwards: outer margin, the strip, inner
margin, then the windows' own outer gap.

**Example:**

```lua
kiwishelf.set_outer_margin(10)
```

### kiwishelf.set_inner_margin

**Expects:** points (default `0`; a negative value is raised to
it).

**Does:** adds room on the shelf's window side, on top of the
windows' outer gap. The outer gap alone keeps the focus ring's
clearance, so `0` means the gap governs.

**Example:**

```lua
kiwishelf.set_inner_margin(4)
```

### kiwishelf.set_background_style

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

### kiwishelf.set_liquid_glass

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

:::unreleased
The colored layer is drawn on the glass, beneath the items,
rather than behind it, and the bars, the overflow marks, their
list and the hover peek draw glass with the bright edge of a
focused window (#2569). How far the fill fades is
[`set_fill_fade`](#kiwishelfset_fill_fade). The hover peek and
the overflow mark's list fade from the shelf's edge too, but
never so far that their text stops reading.

A fill with no color is covered under
[KiwiShelf colours](#kiwishelf-colours).
:::

Stood down, live, while macOS's Reduce transparency is on: the
bars draw their Boxed or Plain shape with the `fill_color` at
full alpha, the panel its plain material, and the drag visuals
and the sticky mark their flat look. The stored values are
untouched, so the glass and the alpha return the moment the
setting goes off (#1374).

:::unreleased
The Space switch's plates draw their material then too.
:::

:::unreleased
A hidden bar's Space dots and line wear the glass too, tinted by
the same fill, and draw that fill flat when the glass is off or
stood down.
:::

Settings has no KiwiShelf row for this (#1307): one **Liquid
Glass** switch on Looks &amp; Animations writes this leaf, the
shortcuts panel's
([set_shortcut_panel_liquid_glass](#set_shortcut_panel_liquid_glass)),
the drag visuals' ([drag.set_liquid_glass](#dragset_liquid_glass))
and the sticky mark's
([sticky.set_liquid_glass](#stickyset_liquid_glass)) together,
and shows on only when all of them are on.

The slow-boot notice follows the shortcuts panel's.

:::unreleased
So do the plates a Space switch slides.
:::

This verb sets the
bars alone; setting them apart is a Lua-only state, and the
Settings switch then reads off and says so in its `?`.

**Example:**

```lua
kiwishelf.set_liquid_glass(true)
```

:::unreleased
### kiwishelf.set_fill_fade

**Expects:** a number 0–100 (percentage; default `100`);
out-of-range values clamp.

**Does:** sets how far the shelf's
[`fill_color`](#kiwishelf-colours) fades across Liquid Glass
(#2569). `100` fades to an eighth of the fill's strength at the
far end. `0` draws one even color. The glass is never fully clear
at the far end. It sets the fill of the bars, a hidden shelf's
handle, the overflow marks and their list, the hover peek, and the
panels
[`set_tint_hub_and_plates`](#kiwishelfset_tint_hub_and_plates)
tints. The drag visuals and the sticky mark keep their own fade.
The hover peek, the overflow mark's list, KiwiHub and the Space,
Desktop and layout plates stop fading where their text would stop
reading, at a higher floor while macOS's Increase contrast is on.
No effect while the glass is off or the fill has no color.
Stored as `kiwishelf.fill_fade`.

The GUI twin is **Fill fade** under the **Liquid Glass** switch
on Looks &amp; Animations, reading **Off** at `0`; it is hidden
below macOS 26 and greys while glass is off or stood down, or
while the fill has no color.

**Example:**

```lua
kiwishelf.set_fill_fade(40)
```
:::

:::unreleased
### kiwishelf.set_tint_hub_and_plates

**Expects:** `true` or `false` (default `true`).

**Does:** `true` gives [KiwiHub](#kiwihubshow), the Space,
Desktop and layout plates, and the plates a Space switch slides
the shelf's [`fill_color`](#kiwishelf-colours) on clear Liquid
Glass, fading top to bottom as
[`set_fill_fade`](#kiwishelfset_fill_fade) says, with the bright
edge of a focused window (#2569). KiwiHub and the Space, Desktop
and layout plates then draw their text in the shelf's
`item_color`, dimmer for secondary text. KiwiHub's selected row takes `highlight_color` with
black or white text, whichever reads on it, and a hovered row
takes `hover_fill_color` and `hover_item_color`. A light fill
keeps the glass of KiwiHub and those plates light, and a dark
fill keeps it dark, whatever Settings' Appearance says.
They draw as with `false` while the fill has no color, while
their glass is off or stood down by Reduce transparency, and
below macOS 26.
`false` draws them in frosted, untinted glass that follows
Settings' Appearance, with KiwiHub's kiwi-green selection. The
glass itself turns on and off with
[`set_shortcut_panel_liquid_glass`](#set_shortcut_panel_liquid_glass).
Stored as `kiwishelf.tint_hub_and_plates`.

The GUI twin is **Tint KiwiHub and plates** under the **Liquid
Glass** switch on Looks &amp; Animations; it is hidden below
macOS 26 and greys while glass is off or stood down, or while the
fill has no color.

**Example:**

```lua
kiwishelf.set_tint_hub_and_plates(false)
```
:::

### kiwishelf.set_background_fit

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

### kiwishelf.set_corner_roundness

**Expects:** a number 0–100 (percentage; default `50`).

**Does:** sets the corner rounding of the plates and item boxes
of both bars, where 0 = square and 100 = a full capsule
(radius = thickness/2). Values above `100` render as `100`.

**Example:**

```lua
kiwishelf.set_corner_roundness(50)
```

### kiwishelf.set_border

**Expects:** `true` or `false` (default `false`).

**Does:** strokes a line around the plate, or around each item's
box under `boxed` (the Space Bar's front-app segment included),
on the same rounded corners. It sits exactly on the edge, never
inset, so under Liquid Glass it strengthens the glass's own rim;
it takes no tint and stays under Reduce transparency. The width
and the [`border_color`](#kiwishelf-colours) are kept while it is
off.

The active item's box drops it under the `outline` indicator,
which already strokes that edge.

**Example:**

```lua
kiwishelf.set_border(true)
```

### kiwishelf.set_border_width

**Expects:** points, 1–4 (default `1`); values outside the range
are clamped.

**Does:** sets the width of the
[border](#kiwishelfset_border).

**Example:**

```lua
kiwishelf.set_border_width(2)
```

### kiwishelf.set_highlight_width

**Expects:** points, 1–6 (default `2`); values outside the range
are clamped.

**Does:** sets how heavy both bars' active indicator draws: the
outline's stroke width, and the edge mark in proportion (half as
thick again, so the default draws a 3 pt mark). Which of the two
each bar uses is its own `set_active_indicator`, and its colour
is the [`highlight_color`](#kiwishelf-colours).

**Example:**

```lua
kiwishelf.set_highlight_width(3)
```

### kiwishelf.set_item_gap

**Expects:** points (default `6`; a negative value is raised to
`0`).

**Does:** sets the gap between items, Space items and App Bar
items alike, and between the two bars while both show.

**Example:**

```lua
kiwishelf.set_item_gap(6)
```

### kiwishelf.set_font_size

**Expects:** points; `0` (default) means auto.

**Does:** if `0`, each bar's text scales with the thickness; any
positive value pins the font size for both bars.

An automatic font size follows the
[`glyph_size`](#kiwishelfset_glyph_size) where one is set: Space
numbers draw at about half of it and titles at about 0.42 of it.

**Example:**

```lua
kiwishelf.set_font_size(0)
```

### kiwishelf.set_font_family

**Expects:** a font family name (default `"System"`).
`"System"` and `"System Monospaced"` name the system's own faces;
any other name is an installed family, as Font Book lists it.

**Does:** sets the typeface of both bars' text — Space
identifiers, window titles and counts. App icons and App Font
glyphs keep their own. A chosen family draws counts with digits
of one width where it has them; the system families keep their
own figures. A
family that is not installed draws `"System"` and is reported in
Config Issues; the stored name is kept, so installing the family
brings it back.

**Example:**

```lua
kiwishelf.set_font_family("Menlo")
```

### kiwishelf.set_font_weight

**Expects:** a weight from `100` to `900` (default `400`), or one
of the names `"ultralight"` (100), `"thin"`, `"light"`,
`"regular"`, `"medium"`, `"semibold"`, `"bold"`, `"heavy"` and
`"black"` (900), in any case; a number outside the range is
clamped.

**Does:** sets how heavy both bars' text draws. A variable family
(the system's own among them) draws the exact weight; one without
a weight axis draws its installed face nearest to it. The weight
is kept as set, so switching to another family and back restores
it.

**Example:**

```lua
kiwishelf.set_font_weight("semibold")
```

### kiwishelf.set_icon_source

**Expects:** `"app_image"` or `"app_font"` (default
`"app_image"`).

**Does:** sets how app icons are drawn on both bars and in the
shortcuts panel's Apps section. `app_image` shows the app's icon as
macOS provides it, which follows the system-wide Icon & widget
style the user picked; the system's Dark, Clear and Tinted looks
are not separate choices
([Accepted limitations](accepted-limitations.md)). `app_font`
shows a monochrome symbol from the bundled [SketchyBar App
Font](https://github.com/kvndrsslr/sketchybar-app-font) instead,
colored by the shelf's item colours; apps without a symbol keep
their icon. On the Space Bar, an app with no image falls back to
the App Font either way.

**Example:**

```lua
kiwishelf.set_icon_source("app_font")
```

### kiwishelf.set_dim_factor

**Expects:** a number 0.05–1 (default `0.4`); out-of-range
values clamp.

**Does:** sets the opacity of untinted idle content on both bars
— an emoji identifier or app image on a Space you are not on, an
App Bar item's icon and count badge; tinted content
takes the item
colour instead. The Space Bar's middle tier is
[`space_bar.set_active_dim_factor`](#space_barset_active_dim_factor).
Lua-only (no GUI).

On the App Bar the dim marks a window that is not fully on screen
— in monocle every window but the one shown, in scrolling a column
cut by the screen's edge or stacked behind another, and a float the
screen's edge cuts or the focused window covers. A fully visible
item stays undimmed whether or not it holds the focus. A float or a
window KiwiDesk does not manage covering a tile does not count.

**Example:**

```lua
kiwishelf.set_dim_factor(0.4)
```

### kiwishelf.set_reveal_timeout

**Expects:** seconds, 0–60 (default `0`); out-of-range values
clamp.

**Does:** how long a shelf
[`space_bar.toggle_reveal`](#space_bartoggle_reveal) or
[`app_bar.toggle_reveal`](#app_bartoggle_reveal) revealed stays
shown. `0` keeps it until the next call; above `0` it hides after
that many seconds, or at once on the next call. A shelf the
pointer is over when the time runs out stays until the pointer
leaves.

**Example:**

```lua
kiwishelf.set_reveal_timeout(5)
```

### kiwishelf.set_reveal_style

**Expects:** `"slide"`, `"grow"`, `"unfold"` or `"fade"`
(default `"slide"`).

**Does:** how an `"auto"` or `"hidden"` bar comes onto an edge
that shows nothing else. `"slide"` brings the whole bar in from
the screen's edge — out from under the menu bar where it shows —
and back out; `"grow"` grows the bar out of its mark — from the
screen edge where it has none — and back into it; `"unfold"`
stretches the mark along the edge to the bar's length, then
deepens it to the bar, and back; `"fade"` fades the bar in
where it stands, and out. A `"hidden"` bar has no mark, so
`"grow"` and `"unfold"` start from the middle of its screen edge.
A bar shown beside an `"always"` bar joins it instead, whichever
style. Each plays with Reduce Motion on too. On a `"boxed"` shelf
`"unfold"` springs each box out of the mark to its place.

:::unreleased
On a `"boxed"` shelf `"grow"` plays as `"unfold"`.
:::

**Example:**

```lua
kiwishelf.set_reveal_style("grow")
```

### KiwiShelf colours

Same `#RRGGBB` / `#RRGGBBAA` grammar as every other color
setting. One set of colours serves both bars; the focused
window's colour is the Space Bar's own
([`space_bar.set_focused_item_color`](#space_barset_focused_item_color)).


So is the front-app segment's indicator colour
([`space_bar.set_focused_highlight_color`](#space_barset_focused_highlight_color)),
which follows the focused window's colour until you set it.


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

:::unreleased
A `fill_color` with no color — 0% opacity, an empty string or a
value that does not parse — draws no plate on the solid path,
so the items sit on the wallpaper even under Reduce
transparency, and plain clear glass with nothing pinned under
[Liquid Glass](#kiwishelfset_liquid_glass), never a fallback
color, and leaves KiwiHub and the plates
[`set_tint_hub_and_plates`](#kiwishelfset_tint_hub_and_plates)
tints untinted. Settings' **No Color**, on the Fill well's menu,
sets the fill's opacity to 0 and keeps its hue.
:::

An App Bar window not fully on screen draws its title and glyph in
the same idle ink as an identifier on a Space you are not on:
`kiwishelf.set_item_color` at 60% of its own alpha. A fully visible
one draws them in the item colour, and the focused one in
`active_item_color`.

`kiwishelf.set_border_color` sets the
[border](#kiwishelfset_border)'s colour (default `#EAF3EE59`, the
item colour at 35% opacity). Every bundled palette carries one.

**Example:**

```lua
kiwishelf.set_fill_color("#14201CB3")
kiwishelf.set_active_item_color("#8DB354")
```

### Retired bar verbs

These verbs are retired. A call in `init.lua` is reported in
Config Issues, naming what replaces it where something does;
over the CLI it fails with
`<verb> was retired — use <replacement>`, or, for
`space_bar.set_item_size`, `…: a Space item's length follows its
content`.

- `space_bar.set_<field>`, `app_bar.set_<field>`,
  `monocle.set_app_bar_<field>` and `scroll.set_app_bar_<field>`
  for `alignment`, `thickness`, `outer_margin`,
  `inner_margin`, `background_style`, `liquid_glass`,
  `background_fit`, `corner_roundness`, `item_gap`, `font_size`,
  `icon_source`, `dim_factor`, and the colours `item_color`,
  `active_item_color`, `highlight_color`, `hover_fill_color`,
  `hover_item_color`, `fill_color`, `group_badge_color` and
  `group_badge_text_color` → `kiwishelf.set_<field>`.
- `app_bar.set_item_size`, `monocle.set_app_bar_item_size` and
  `scroll.set_app_bar_item_size` → that bar's `title_cap`
  ([`app_bar.set_title_cap`](#app_barset_title_cap)): an App Bar
  slot's width follows the title cap, its one width control.
- `space_bar.set_item_size` → nothing: a Space item's length
  follows its content.
- `space_bar.set_title_cap` →
  [`space_bar.set_front_app_title_cap`](#space_barset_front_app_title_cap).

`kiwishelf.set_edge` is retired too → `space_bar.set_edge`: each
bar sets its own edge again, and `app_bar.set_edge` is the App
Bar's. `monocle.set_app_bar_edge` and `scroll.set_app_bar_edge`
stay retired and now name `app_bar.set_edge`, since no layout
sets the App Bar's edge for itself. A saved profile or backup is
rewritten once, and every setup keeps its bars where they were: a
stored KiwiShelf edge becomes both bars' edge, and a profile from
before KiwiShelf keeps each bar's own edge — the App Bar at the
bottom where it stored none.

`app_bar.set_content`, `monocle.set_app_bar_content` and
`scroll.set_app_bar_content` are retired → nothing: the App Bar
always draws each item's icon and title, and a vertical one its
icon alone. Over the CLI each fails with `…: the App Bar always
draws each item's icon and title`. A saved profile drops its
stored `content` once, and a backup as it is read, so a bar that
showed only titles gains its icons, and one that showed only icons
gains its titles.

The `gap` active indicator is removed: `set_active_indicator`
and its per-layout twins refuse it, naming the values that
remain.

`init.lua` is not rewritten; a saved profile is, once, the first
time 2.0 reads it: the shelf takes the Space Bar's values,
colours and app glyph style included — the App Bar's where the
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

## App Bar

The **App Bar** lists the windows of the current space in the two
layouts that can hide one — **monocle** and **scrolling**. Click
an item to focus its window, drag it to reorder; a window in
native fullscreen has no item until it returns. With several
screens each screen shows its own bar, on that screen, for the
space it is showing, and dragging an item reorders that screen's
space.

The space's floating windows follow the row, past a thin line and
the floating symbol; they focus on a click, cannot be dragged, and
are never grouped.

The bar sits on [KiwiShelf](#kiwishelf), which sets its
thickness, margins, background, colours and app glyph style.
Everything else about it is **global**: `app_bar.set_*` sets
every layout's bar. Each layout decides whether it shows one and
may override the App Bar's own fields for itself ([Per-Layout
App Bar Overrides](#per-layout-app-bar-overrides)).

Each item shows its window's icon and **title** — the window's
own title, not its app name; on a `left` or `right` edge it shows
the icon alone. The app name appears, never shortened, in two
places:

- a **grouped** item (its members show titles once it expands);
- a window whose title is **empty** — some apps (Electron and
  WebKit ones especially) report no title until well after the
  window opens.

### app_bar.set_edge

**Expects:** `"top"`, `"bottom"`, `"left"`, or `"right"`
(default `"top"`; the starter setup seeds `"bottom"`).

Then, optionally, a screen, named as
[`space_bar.set_edge`](#space_barset_edge) names one.

**Does:** sets the screen edge the App Bar sits on, for every
layout — no layout sets its own. On the Space Bar's edge the two
share one [KiwiShelf](#kiwishelf); on another edge each bar is
its own, reserved as KiwiShelf describes. The edge is absolute —
it does not follow a layout's orientation.

**Example:**

```lua
app_bar.set_edge("bottom")
```

With a screen, the edge is that screen's alone, as
[`space_bar.set_edge`](#space_barset_edge) describes.

```lua
app_bar.set_edge("right", "LG HDR 4K:3840x2160")
```

### app_bar.set_reserve

**Expects:** boolean (default `true`).

**Does:** sets whether the layout gives up the App Bar's strip.
With `false` the bar still shows but draws over the windows:
tiled windows and floats use the strip as free room, and showing
or hiding the bar no longer moves a window.

The cost: the bar's panel spans its whole strip and takes the
mouse there, so what lies under the strip can no longer be
clicked through it — title bars under a top bar, status and
scroll bars under a bottom one, the window edges under a left or
right one.

On an edge the two bars share, the strip stays reserved while
either bar reserves it, so `false` frees it only when the
Space Bar on that edge reserves nothing either — hidden, or
its own [`space_bar.set_reserve`](#space_barset_reserve) off.

Global only: no layout sets its own.

**Example:**

```lua
app_bar.set_reserve(false)
```

### app_bar.toggle_reveal

**Expects:** nothing.

**Does:** as [`space_bar.toggle_reveal`](#space_bartoggle_reveal),
for the App Bar of the active Space's layout. Fails where that
layout carries no App Bar, or where its App Bar is `"always"`.

:::unreleased
It fails with a pill too where the Space holds no window, so the
App Bar has nothing to show.
:::

**Example:**

```lua
app_bar.toggle_reveal()
```

### app_bar.set_active_indicator

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

### app_bar.set_title_cap

**Expects:** a character count, 8–80 (default `10`). Values
outside the range are clamped.

**Does:** sets how much of a window's title an item shows;
longer titles are cut at the end and marked with an ellipsis. A
title is also cut where it does not fit its slot; only the
title shrinks, never the icon.

:::unreleased
Every slot is as long as this many characters of the bar's font
beside the icon, whatever the titles read — at least the icon
square and at most a quarter of the whole KiwiShelf edge — so a
longer title ends in "…", a shorter one starts right after the icon,
and a change of title never moves the App Bar or the shelf
beside it. The cap is the App Bar's one size control; items that
do not fit scroll instead of shrinking.
:::

**Example:**

```lua
app_bar.set_title_cap(25)
```

### app_bar.set_group_adjacent_windows

**Expects:** `true` or `false` (default `true`).

**Does:** if true, collapses adjacent same-app windows into one
item with a count badge; same-app windows that are not adjacent
stay separate.

:::unreleased
Clicking a grouped item lists its windows. Picking one focuses it
and expands the group into its members; focus leaving the group
collapses it again.
:::

**Example:**

```lua
app_bar.set_group_adjacent_windows(true)
```

### Per-Layout App Bar Overrides

Each bar-hosting layout (monocle, scrolling) sets its own App
Bar `visibility` — `"always"`, `"auto"` or `"hidden"`, as
[`space_bar.set_visibility`](#space_barset_visibility) — and can
override the App Bar's own fields for itself: `active_indicator`,
`title_cap` and `group_adjacent_windows`. Only these two layouts
show a bar, so only they expose `set_app_bar_*`. Unset fields
inherit the global value.
[KiwiShelf](#kiwishelf)'s fields — its colours, glyph style and
`dim_factor` included — take no per-layout override. The
overrides are the same setters prefixed with the layout name:

- `monocle.set_app_bar_visibility`,
  `monocle.set_app_bar_title_cap`, etc.
- `scroll.set_app_bar_visibility`,
  `scroll.set_app_bar_active_indicator`,
  `scroll.set_app_bar_group_adjacent_windows`, etc.

The App Bar's edge ([`app_bar.set_edge`](#app_barset_edge)) takes
no per-layout override either.

**Example:**

```lua
monocle.set_app_bar_visibility("always")
scroll.set_app_bar_visibility("hidden")
scroll.set_app_bar_title_cap(20)  -- override for scrolling
```

`monocle.set_app_bar_enabled` and `scroll.set_app_bar_enabled`
are retired: `false` is `"hidden"`. An `auto` App Bar hides to a
short line, which grows when the pointer comes near and opens as
the Space dots do.

:::unreleased
Grown, the line shows how many windows the App Bar lists for the
Space on that screen, beside a window symbol. On a side edge the
number stands above the symbol; past 99 a stacked-windows symbol
shows there alone. VoiceOver reads the count at rest too.
:::

## Space Bar

The Space Bar (#293) lists, per screen, that screen's Spaces
in profile order: each item shows the Space's identifier (its
configured icon, else the plain digits of a numeric id or a
two-letter monogram of a named one), a divider, then a glyph per
window. Adjacent windows of the same app share one glyph with a
count badge (non-adjacent duplicates stay separate); past the
glyph span ([`space_bar.set_glyph_span`](#space_barset_glyph_span))
the rest fold into a `+n` badge on each side, counting the hidden
windows. Clicking
a Space switches to it, and a group holding the focused window
stays collapsed and takes the focused accent. The user guide's
[Space Bar](user-guide.md#space-bar) section covers the badges,
what a click on a glyph does and the drag-onto-a-Space gesture.

Turning
[`space_bar.set_group_adjacent_windows`](#space_barset_group_adjacent_windows)
off gives each window its own glyph.

The bar is layout-independent and sits on
[KiwiShelf](#kiwishelf), which sets its thickness, margins,
background, colours and app glyph style; every `space_bar.*`
setting is global, with no per-layout override.

### space_bar.set_reserve

**Expects:** boolean (default `true`).

**Does:** sets whether the layout gives up the Space Bar's strip.
With `false` the bar still shows but draws over the windows:
tiled windows and floats use the strip as free room, and showing
or hiding the bar no longer moves a window.

The cost: the bar's panel spans its whole strip and takes the
mouse there, so what lies under the strip can no longer be
clicked through it — title bars under a top bar, status and
scroll bars under a bottom one, the window edges under a left or
right one.

On an edge the two bars share, the strip stays reserved while
either bar reserves it, so `false` frees it only when the
App Bar on that edge reserves nothing either — hidden, or
its own [`app_bar.set_reserve`](#app_barset_reserve) off.

**Example:**

```lua
space_bar.set_reserve(false)
```

### space_bar.set_visibility

**Expects:** `"always"`, `"auto"` or `"hidden"` (default
`"always"`). Replaces the retired `space_bar.set_enabled`:
`false` is `"hidden"`.

:::unreleased
The starter setup seeds `"auto"` for the Space Bar and for the
App Bar in monocle and scrolling.
:::

**Does:**

- `"always"` keeps the bar shown and reserves its strip.
- `"auto"` hides it to a row of Space dots at its edge — one dot
  per Space, the current one wide, a Space holding windows
  brighter, at most six: past six Spaces the dots follow the
  current Space, and an end with more Spaces beyond it draws a
  small dot — and the edge keeps only a sliver: `outer_margin`,
  the dots' depth and `inner_margin`, with the windows' outer gap
  below it. The pointer within about 40 points of the dots grows
  the plate behind them, rims it as the bars draw their active
  item and, on a top or bottom edge, shows the current Space's
  icon, number or first two letters in its dot. Resting a moment in the dots' band — 64
  points along the edge, centred on the dots, from a few points
  past the shelf to where the windows start — brings the bar in
  as [`kiwishelf.set_reveal_style`](#kiwishelfset_reveal_style)
  says, as the dots fade; at once when the pointer pushes against
  the screen's edge inside that band. It goes back the same way
  0.5 s after the
  pointer leaves the bar and its band, and stays while a bar menu
  or a peek it opened is up.
- `"hidden"` draws nothing and reserves nothing; only
  [`space_bar.toggle_reveal`](#space_bartoggle_reveal) shows it,
  in the same reveal style. The menu bar then shows the Space each
  screen is on.

A shown `auto` or `hidden` bar draws over the windows, so a
reveal moves no window; setting the value moves the windows at
most once. A bar set not to reserve
([`space_bar.set_reserve`](#space_barset_reserve)) reserves
nothing in any mode.

Each bar keeps its own value. On an edge the two bars share, the
edge reserves for its more present bar: beside an `"always"` bar
an `"auto"` one stays shown, while a `"hidden"` one still shows
only on its shortcut. Two `"auto"` bars on one edge draw two handles
side by side — the Space dots and the App Bar's line, in the
shelf's [order](#kiwishelfset_order), where a lone bar would sit
— each with its own 64-point band, the two meeting between the
handles. The pointer opens one bar at a time: while a bar is shown,
the other's handle and band go away. A second bar's shortcut shows
it beside the first. A look never carries the value.

:::unreleased
The Space dots and the App Bar's line wear the bars'
[Liquid Glass](#kiwishelfset_liquid_glass).
:::

**Example:**

```lua
space_bar.set_visibility("auto")
```

### space_bar.toggle_reveal

**Expects:** nothing.

**Does:** shows or hides the Space Bar over the windows on the
screen the active Space lays out on, and no other bar. A shown bar
stays until the next call, or for
[`kiwishelf.set_reveal_timeout`](#kiwishelfset_reveal_timeout)
seconds where that is above 0. Fails, with a pill beside the bar,
where the Space Bar is `"always"`. VoiceOver's press on the Space
dots runs it too.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+b", function()
    space_bar.toggle_reveal()
end)
```

### space_bar.set_edge

**Expects:** `"top"`, `"bottom"`, `"left"`, or `"right"`
(default `"top"`).

Then, optionally, a screen, in the forms
[`move_space_to_display`](#move_space_to_display) takes — a
number, or a screen's fingerprint or name — or the fingerprint
of a screen that is not connected, kept for when it is.

**Does:** sets the screen edge the Space Bar sits on. On the App
Bar's edge the two share one [KiwiShelf](#kiwishelf); on another
edge each bar is its own, reserved as KiwiShelf describes. The
edge is absolute — it does not follow a layout's orientation.

**Example:**

```lua
space_bar.set_edge("left")
```

**Per screen:** with a screen, the bar takes that edge on that
screen alone. A screen with no edge of its own uses the bar's,
so a new screen needs no setup. Naming the bar's own edge
returns a screen to it. The screens judged together are the
active profile's screens, the connected ones and every screen
with an edge of its own: once all of them sit on one edge, that
edge becomes the bar's and the screens' own edges go, which
moves no screen; a screen on another edge keeps them apart. A
call without a screen sets the bar on every screen, clearing
their own edges. A look sets the bars' edges and leaves each
screen's own untouched. The edges are stored per profile, under
`space_bar.edge_override` and `app_bar.edge_override`, keyed by
fingerprint.

```lua
space_bar.set_edge("top")
space_bar.set_edge("left", "LG HDR 4K:3840x2160")
```

### space_bar.set_glyph_span

**Expects:** an integer `1`–`12` (default `5`); out-of-range
values clamp.

**Does:** sets how many glyphs a Space item shows
around its focused app — the Space's system focus while it is
active, else the window it last focused. The rest sit behind a
`+n` badge on each side, and at either end of the row the badge
that side does not need becomes one more glyph, so the item keeps
one length as the focus moves. The span counts glyphs — windows,
or app *groups* while grouping is on — while each `+n` counts
its hidden *windows*. It limits glyphs per
Space only, not how many Spaces the bar shows. Replaces
`set_glyph_cap`, which now fails naming it.

A `+n` hides two glyphs or more: a side that would hide one
draws that glyph in the badge's place, so a row of span + 2
glyphs shows whole.

**Example:**

```lua
space_bar.set_glyph_span(8)
```

### space_bar.set_glyph_gap

**Expects:** points (default `0`; a negative value is raised to
`0`).

**Does:** sets the room between app glyphs inside a Space item,
and before its `+n` badge. `0` sets them side by side. The gap
between Space items themselves is the shelf's
[`item_gap`](#kiwishelfset_item_gap).

**Example:**

```lua
space_bar.set_glyph_gap(4)
```

### space_bar.set_inactive_content

**Expects:** `"apps"` or `"count"` (default `"apps"`).

**Does:** sets what a Space item draws while its screen shows
another Space. `"apps"` draws its app glyphs, like the shown
Space. `"count"` draws its identifier alone, with its window
count in a small disc on the identifier's corner (`9+` past
nine). Either way an empty Space draws no glyphs or disc, and its
identifier dimmer than an occupied one's, where the palette
leaves room for the step; a colour emoji icon keeps its colours. The
Space each screen shows always draws its glyphs, capped by
[`set_glyph_span`](#space_barset_glyph_span), and a collapsed Space
drops its sticky and floating badges.

**Example:**

```lua
space_bar.set_inactive_content("count")
```

### space_bar.set_item_label

**Expects:** `"identifier"` or `"layout"` (default
`"identifier"`).

**Does:** sets what names each Space item. `"identifier"` draws
the Space's icon, else its name, shortened to fit (up to three
digits of a number, the first two letters of a word). `"layout"` draws the symbol of the layout the Space uses
now — the one the Layout menu shows — and changes with it. The
app glyphs are unaffected, and VoiceOver still reads the Space's
name.

**Example:**

```lua
space_bar.set_item_label("layout")
```

### space_bar.set_active_indicator

**Expects:** `"outline"` or `"edge_mark"` (default
`"outline"`).

**Does:** how the active Space is marked, in KiwiShelf's
[`highlight_color`](#kiwishelf-colours).


The front-app segment wears the same indicator, in its own
[`focused_highlight_color`](#space_barset_focused_highlight_color).


**Example:**

```lua
space_bar.set_active_indicator("outline")
```

### space_bar.set_active_dim_factor

**Expects:** a number 0.05–1 (default 0.6).

**Does:** sets the opacity of an **unfocused window's glyph on the
active Space** — the middle dim tier, between the focused window
(1.0) and inactive Spaces
([`kiwishelf.set_dim_factor`](#kiwishelfset_dim_factor)).
Lua-only, clamped. Independent of the shelf's `dim_factor`: no
ordering is enforced, so a value below the outer tier inverts
the ladder.

**Example:**

```lua
space_bar.set_active_dim_factor(0.6)
```

### space_bar.set_show_front_app

**Expects:** boolean (default `false`).

**Does:** shows a trailing front-app segment after the last
Space item — a divider, then the glyph and the **title** of the
focused window of the Space **this screen currently shows**
(per screen, not the globally frontmost app). A window with no
title yet falls back to its app's name. On vertical (left/right)
bars the segment is icon-only and the divider flips to a
horizontal rule.

The segment shows only while no App Bar is shown on that screen.

**Example:**

```lua
space_bar.set_show_front_app(false)
```

### space_bar.set_front_app_title_cap

**Expects:** a character count, 8–80 (default `10`). Values
outside the range are clamped.

**Does:** sets how much of the focused window's title the
front-app segment shows. Inert while `show_front_app` is off —
nothing else on the Space Bar draws a title.

The segment is always as long as this many characters of the
bar's font: a longer title ends in "…", so a change of focus or
title never moves the Space Bar or the shelf beside it.

:::unreleased
A shorter title starts right after the icon, the rest of the
segment left empty.
:::

**Example:**

```lua
space_bar.set_front_app_title_cap(25)
```

### space_bar.set_group_adjacent_windows

**Expects:** boolean (default `true`).

**Does:** collapses adjacent windows of one app in a Space item
into one glyph with a count badge; clicking it focuses its
windows in turn and lists them beside the bar, each row focusing
its window. Off, each window
draws its own glyph and one click focuses it. `glyph_span` counts
glyphs either way.

**Example:**

```lua
space_bar.set_group_adjacent_windows(false)
```

### space_bar.set_hide_empty

**Expects:** boolean (default `false`).

**Does:** hides Spaces with no windows from the bar, except the
Space you are currently on, which always stays. Hidden Spaces
remain reachable by shortcut and by the
[Space step](#scroll-gestures).

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

### space_bar.set_focused_highlight_color

**Expects:** a hex color (`#RRGGBB` or `#RRGGBBAA`), or `""`.

**Does:** sets the color of the front-app segment's active
indicator, the outline or edge mark that
[`space_bar.set_active_indicator`](#space_barset_active_indicator)
picks. `""`, the default, follows
[`focused_item_color`](#space_barset_focused_item_color), so the
segment's text and indicator share one color, the way the active
Space's do.

**Example:**

```lua
space_bar.set_focused_highlight_color("")
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

### drag.set_liquid_glass

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

### Retired drag verbs

These verbs are retired. A call in `init.lua` is reported in
Config Issues, naming what replaces it; over the CLI it fails
with `<verb> was retired — use <replacement>`.

- `drag.set_ghost_border_width` and
  `drag.set_drop_zone_border_width` →
  [`border.set_width`](#borderset_width).
- `drag.set_corner_radius` →
  [`border.set_corner_style`](#borderset_corner_style).

A saved profile's `drag.corner_radius` and each visual's
`border_width` are no longer read.

## Focus Border

KiwiDesk draws a thin border around the focused window. It is
**on by default** and marks only the focused window;
`border.set_unfocused_enabled` adds one on every other window.
The border is a pure overlay: it never changes where windows
tile (no gap coupling), and the configured width is the
thickness drawn outward into the gap. It is stacked directly
against its window, so popovers, sheets, and other windows the
system places above the target stay above its border.
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

The drag ghost and the drop zone draw their stroke at this width
too.

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

The drag ghost and the drop zone take this style too: `rounded`
draws them at the system window radius, `square` with no
rounding.

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
proportional aura — override it with `set_glow_size` below.

A glowing ring keeps the `draw_order` you chose, `"front"`
included.

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

### border.set_sheen

**Expects:** a number from `-1` to `1` (default `0.5`). A value
outside the range is clamped into it, like the other border
magnitudes; a non-number fails.

**Does:** paints a sheen on the top of the focused border, the
shelf's [highlight](#kiwishelfset_highlight_width) and
[border](#kiwishelfset_border), and the drag borders. A positive
value lightens the top toward white, a negative one darkens it
toward black, each fading into the colour, which holds to the
bottom; `0` draws none. `1` moves the top 90% of the way. Only
the lightness moves, so each keeps its own colour; it is a
painted highlight, not glass, so it draws whether or not Liquid
Glass is on, under Reduce transparency, and on any macOS. Below
the top each stroke keeps its colour exactly, so the colour's own
contrast still holds there. The unfocused border never takes it.

Settings shows it as **Sheen**, a slider beneath the **Liquid
Glass** switch on Looks &amp; Animations, reading `+50%`,
`−50%` or **Off**. The Liquid Glass switch does not change it.

**Example:**

```lua
border.set_sheen(-0.3)   -- a slightly darker top
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

## KiwiVision

KiwiVision keeps the focused window clear and dims every screen
around it, the wallpaper included unless `set_clear_wallpaper`
keeps it clear; the menu bar, the Dock and KiwiShelf stay clear.
It is off at every launch.

Its settings are app-wide: they are stored in `gui.json` as the
`kiwivision` group (`dim`, `blur`, `appearance`,
`clear_wallpaper`, `clear_app`, `never_dimmed`, `lenses`), no profile
carries them, and loading a profile never changes them. Their GUI
twin is Settings ▸ **KiwiVision**. The `set_*` verbs below change
the running value only, never `gui.json`; in a Lua-owned setup,
`init.lua` is where they are kept, and the KiwiVision rows are
greyed.

### kiwivision.toggle

**Expects:** nothing, or a lens name.

**Does:** turns KiwiVision on or off. The window kept clear follows
the focus — a click, ⌘-Tab or a Space switch moves it — and a
screen showing a native full-screen window or a presentation stands
the dim down. The KiwiVision line of KiwiHub's
[view picker](#kiwihubshow) does the same, and ⌃⌥V is its default
shortcut.

With a lens name (any case), it turns that lens on — from off, or
from another lens — and turns KiwiVision off when that lens is the
one on. A lens with no apps, or a name no lens has, is refused.

A saved profile can leave a lens out through its
[`lens_reach`](#profile-json-format). While that profile is live,
turning the lens on is refused: "Writing does not reach Studio". A
built-in Standard, and a Lua-owned setup, reach every lens. A
profile switch (a load, a screen change or a Desktop binding) into
a profile that leaves out the lens that is on turns KiwiVision off.
A pill on the focused window says "Writing is off: it does not
reach Studio.", and VoiceOver says the same. Switching back
leaves KiwiVision off. Plain KiwiVision, with no lens — Default
in Settings and KiwiHub — stays on across every switch.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+v", function()
    kiwivision.toggle()
end)
KiwiDesk.bind("ctrl+alt+w", function()
    kiwivision.toggle("Writing")
end)
```

### kiwivision.current

**Expects:** nothing.

**Does:** returns `on`; `lens`, the lens that is on (null for plain
KiwiVision or off); `settings`, the plain KiwiVision values under
the `kiwivision` group's keys, without its lenses; and `lenses`,
one entry per lens. An entry carries `lens`, its
[`define_lens`](#kiwivisiondefine_lens) table; `saved`, whether
`gui.json` holds that lens as it is (absent in a Lua-owned setup);
and, where it cannot turn on, `refusal`: `{reason = "no_apps"}`,
or `{reason = "out_of_reach", profile = "Studio"}` for the live
profile that leaves it out. `kiwivision.toggle` returns the same
`on` and `lens`.

### kiwivision.define_lens

**Expects:** a table: `name` (at most 40 characters, unique
ignoring case), `apps` (bundle ids, or the process name of an app
without one), and optionally `titles`, `keep_focus`, `clear_delay`,
`reminder` and any of `dim`, `blur`, `appearance`,
`clear_wallpaper` and `clear_app`.

**Does:** adds a lens, or replaces the one of its name. While the
lens is on, every window of its apps stays clear beside the focused
one. `titles` maps an app to text its window titles contain: only
those of its windows stay clear, and only windows KiwiDesk manages,
whose titles it can read.

With `keep_focus` on (the default), [`focus`](#focus) and
[`swap`](#swap) — from a key, the CLI or Lua — and a
[scroll gesture](#scroll-gestures) skip every window the lens leaves
out, in every layout: other apps' windows — never-dimmed ones
included — and a member's windows its `titles` do not match. A
click, the bars and hover focus skip nothing.

With `keep_focus` on, a window the lens leaves out that still
takes the focus — through ⌘-Tab, the Dock, a notification, a bar
item or the window switcher — stays under the haze for
`clear_delay` seconds (default 2; 0 clears it at once) with a pill
centred on it, then clears. A click
on the window clears it at once; typing does not. The pill shows
`reminder`, or "🥝 Keep the vision juicy 🥝" where it is blank, and
VoiceOver reads it once. Never-dimmed apps, KiwiDesk's own windows,
overlays such as a launcher palette, and a dialog of the window
that was clear never wait.

A setting the lens leaves out follows the
plain KiwiVision one, and never-dimmed apps stay clear under every
lens. Like the `set_*` verbs, it changes the running lenses only;
`init.lua` defines them on every load. A lens defined here lasts
until a config reload or restart and is not listed on Settings ▸
KiwiVision; a lens made there is stored in `gui.json` and saved
with Save, and `define_lens` never writes there.

**Example:**

```lua
kiwivision.define_lens({
    name = "Writing",
    apps = { "com.apple.Notes", "com.apple.Safari" },
    titles = { ["com.apple.safari"] = { "Docs" } },
    clear_delay = 3,
    reminder = "Back to the draft",
    dim = 80,
})
```

### kiwivision.delete_lens

**Expects:** a lens name.

**Does:** removes the lens for this session; KiwiVision turns off
if it was the one on.

### kiwivision.set_dim

**Expects:** a percentage, 0–100. Default 60.

**Does:** sets how far KiwiVision darkens everything but the
focused window. 0 leaves only the blur, or nothing while the blur
is off.

### kiwivision.set_blur

**Expects:** `true` or `false`. Default `true`.

**Does:** blurs what KiwiVision dims, beneath the dim, with
Liquid Glass (a plain blur on macOS 14 and 15).
With Reduce transparency on in macOS, the blur stands down and the
dim stays.

### kiwivision.set_fade_duration

**Expects:** milliseconds, 0–1000. Default 300.

**Does:** sets how long the window focus leaves takes to dim and
blur; the window you focus clears at once. 0 makes the change
instant, as Reduce Motion in macOS does. A Space switch is always
instant. Stored as `fade_duration` in the `kiwivision` group, and a
lens table takes it too.

### kiwivision.set_fade_curve

**Expects:** `"ease_out"`, `"ease_in_out"`, `"ease_in"` or
`"linear"`. Default `"ease_out"`.

**Does:** sets how that fade is paced: `"ease_out"` dims fastest at
the start, `"ease_in"` slowest, `"linear"` evenly. Stored as
`fade_curve` in the `kiwivision` group, and a lens table takes it
too.

### kiwivision.set_appearance

**Expects:** `"unchanged"`, `"opposite"`, `"dark"` or `"light"`.
Default `"unchanged"`.

**Does:** switches macOS to dark or light while KiwiVision is on —
`"opposite"` to whichever it is not showing —
and back when it turns off — only if the system was showing the
other one, and not if you changed the appearance yourself in the
meantime. If KiwiDesk quits or crashes while it is on, the next
start switches back. Automatic (light by day, dark at night) is
turned back on where it was on.

### kiwivision.set_clear_wallpaper

**Expects:** `true` or `false`. Default `false`.

**Does:** leaves the wallpaper clear, so KiwiVision dims and blurs
only the windows behind the focused one; the gaps between them stay
clear too. A window another app opens or moves joins the haze when
the next layout pass settles.

### kiwivision.set_clear_app

**Expects:** `true` or `false`. Default `false`.

**Does:** keeps every window of the focused app clear, not only the
focused one — the part of each you can see; where another app's
window covers it, that window stays dimmed. Focus a window of
another app and its windows become the clear ones.

### kiwivision.set_never_dimmed

**Expects:** a list of apps, as a table or as separate strings —
each a bundle id, or the process name of an app without one, such
as `"sketchybar"`. Nothing clears the list.

**Does:** keeps every window of these apps clear, focused or not —
the part you can see. A window drawn beneath all others, such as
SketchyBar's bar, shows through the haze. Settings ▸ KiwiVision ▸
**Never dimmed** edits the same list.

**Example:**

```lua
kiwivision.set_dim(30)
kiwivision.set_blur(false)
kiwivision.set_appearance("dark")
kiwivision.set_clear_wallpaper(true)
kiwivision.set_clear_app(true)
kiwivision.set_never_dimmed({ "sketchybar", "com.apple.Music" })
```

## Looks

A look is the bars' styling, Liquid Glass, the focus border's
shape, the global gaps and the colors they wear, as on Settings ▸
Looks & Animations; a look you saved carries the animations too. These verbs reach the same library
from Lua, the CLI and an AI app. The global `look` table holds
them; an `init.lua` that assigns its own global `look` replaces
it for that config.

### look.list

**Expects:** nothing.

**Does:** returns `looks`, every look by `name`, the bundled ones
first, each with `bundled` and, where it is worn, `worn`:
`"applied"`, or `"other_colors"` when its styling is worn with
other colors.

### look.current

**Expects:** nothing.

**Does:** returns the worn look's `style` and `colors` by path,
`setters` naming the command that sets each path, the live
`profile` (null when none is saved), `follows_shared_look`, and the
profiles wearing the shared look (`followers`, empty when the
screen does not). A setter takes its own argument
form, which `help` gives — `set_gap_global` reads its table
differently from the stored `gap.global`, and a bar's `set_edge`
clears its per-screen edges, which a look keeps.

### look.apply

**Expects:** a look's name.

**Does:** wears that look on screen and writes no file; a saved
look carries its animations, a bundled one none. `save_profile`
stores it, in the shared look where the profile wears it; over the
CLI or an AI app, [`keep_settings`](cli.md#raw-ipc-protocol) keeps
it instead.

### look.save

**Expects:** a new name.

**Does:** saves the look on screen to your library. A name a
bundled or saved look already has is refused; to replace a saved
look, delete it first.

### look.delete

**Expects:** a saved look's name.

**Does:** deletes it. A bundled look cannot be deleted.

**Example:**

```lua
look.apply("Glass")
border.set_width(4)
look.save("Glass, thin border")
```

## Mouse Resizing

Resizing a tiled window with the mouse adjusts the layout the same
way the `resize` command does, applied when you release: neighbors
give or take the difference. What changes depends on the layout —
Master/Stack maps a drag along the split to the master ratio, BSP
steers its split ratio toward the dragged side, Scrolling adjusts
the slot size. Axes a layout has no parameter for (grid,
monocle, and a master zone lined up along the split — see
[Accepted limitations](accepted-limitations.md)) animate back into
place. Floating windows resize freely.

In Master/Stack a drag along the zone's own axis — a stack
window's height beside a left or right stack, its width beside a
top or bottom one — moves the dragged window's share of its zone,
as `resize` does.

Only edges **shared with a neighbor** trade area — pulling a
window's outer, screen-side edge has nobody to trade with and
snaps back.

Scrolling is the exception: one slot size serves the whole row,
so any edge of a column resizes it, including the outer edge of
the first or last column.

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
the focused window, nor for a [scroll gesture](#scroll-gestures).
While KiwiDesk performs its own z-order
maintenance raises the warp is held, and it fires once they
settle, for the window focus finally landed on. When focus lands
on a window in an inactive space (cmd+tab into a stashed window),
the warp waits until KiwiDesk follows focus and pulls that space
forward. Clicking an app-bar item warps too.

:::unreleased
A Space switch onto another screen moves the pointer even with
the setting off ([`focus_space`](#focus_space)); the setting
governs focus changes within a screen.
:::

Also togglable in the Settings app under **Shortcuts & Gestures ▸
Mouse & trackpad**.

**Example:**

```lua
mouse.set_follows_focus(true)
```

### mouse.set_hover_focus

**Expects:** a boolean (default `false`).

**Does:** when `true`, the window the mouse pointer comes to rest
on takes the focus and comes to the front, as a click on it
would. The pointer has to move and then rest for 200 ms; a focus
change made while it rests, or during those 200 ms, is never taken
back. Nothing happens while a mouse button is held, within a
second of a Desktop switch, over a full-screen window, or where
something other than a managed window is in front under the
pointer: a menu, the Dock, a bar, a panel. KiwiDesk's Settings
window is focused like any other; its dialogs are not. A window
whose focus would move the layout —
a scrolling row that would pan, a parked monocle window — is not
focused. A window on another screen makes that screen's Space
the active one. The pointer is never warped by it, so it works
beside [`mouse.set_follows_focus`](#mouseset_follows_focus).

Also togglable in the Settings app under **Shortcuts & Gestures ▸
Mouse & trackpad**.

**Example:**

```lua
mouse.set_hover_focus(true)
```


### mouse.set_hover_focus_delay

**Expects:** milliseconds, `0` or more (default `200`).

**Does:** sets how long the pointer has to rest before
[`mouse.set_hover_focus`](#mouseset_hover_focus) focuses the
window under it. `0` focuses as soon as the pointer stops moving;
a longer delay keeps a window you cross on the way to another from
taking the focus. Settings offers it under Shortcuts & Gestures ▸
Mouse & trackpad, up to 2000 ms.

**Example:**

```lua
mouse.set_hover_focus_delay(80)
```


## Scroll Gestures

Hold **⌃⌥** (the default; [`set_pan`](#scroll_gestureset_pan)
changes it) and scroll — a two-finger swipe on a trackpad or the
mouse wheel, along either axis — and focus moves one window on
the Space shown on the screen under the pointer, menu bar and
Dock included. That Space becomes the active one. The pointer
does not move, even with `mouse.follows_focus` on.

- **Scrolling:** focus moves along the row through the same step
  as [`focus`](#focus) in the row's direction, with the ordinary
  focus animation and border, wrapping at the ends as the focus
  keys do.
- **Monocle:** it steps through the windows, wrapping the same
  way.
- **Any other layout:** it steps to the next or previous window
  in the Space's window order, floating windows included,
  wrapping at the ends.

:::unreleased
The gesture never leaves its screen: under
[`set_focus_wrap("all_screens")`](#set_focus_wrap) it wraps there
as `"this_screen"` does.
:::

A swipe on a trackpad or Magic Mouse moves one window, and a
notch of a mouse wheel moves one — a fast roll or a
free-spinning wheel moves one for the whole burst, and each notch
counts again once the wheel pauses between notches; the glide
after the fingers lift never counts. Where there is no window to
move to, the focused window's border bumps toward the step. With
[long swipes](#scroll_gestureset_long_swipes) on, a swipe moves
its first window as it starts and one more every
[step distance](#scroll_gestureset_step_distance) of further
travel, which macOS's own Scrolling speed scales. The direction
follows KiwiDesk's own
[Natural scrolling](#scroll_gestureset_natural_scrolling), per
input, whatever macOS's is set to.

Hold **⌃⌥⌘** (the default;
[`set_space_step`](#scroll_gestureset_space_step) changes it) and
scroll to switch to the next or previous Space on the screen under
the pointer, in that screen's Space order — the Space Bar's, empty
Spaces included. A swipe steps one Space, and so does a notch of a
mouse wheel; a fast roll or a free-spinning wheel steps one for the
whole burst, and each notch counts again once the wheel pauses
between notches. The pointer does not move.

:::unreleased
Past the first or last Space it wraps or stops as
[`focus_space_next`](#focus_space_previous--focus_space_next)
does; where it stops, the focused window's border, if the shown
Space has one, bumps toward the step.
:::

The direction follows
[Natural scrolling](#scroll_gestureset_natural_scrolling), as
the window step's does.

The keys must be exactly the ones set: ⌃⌥⌘ + scroll is not
⌃⌥ + scroll. While they are held, KiwiDesk takes the scroll on
every Space, so the window under the pointer does not scroll; a
scroll that began before the keys went down stays the window's.
It needs only the Accessibility permission, never Input
Monitoring.

The settings are stored in `gui.json` as the `scroll_gesture`
object — `pan`, `space_step`, `natural_scrolling` (`trackpad`,
`mouse`), `long_swipes`, `step_distance` — the base every
profile starts with. A profile file may carry a sparse
`scroll_gesture` object that overrides any of them. A
single-modifier chord in either file turns that gesture off, a
`space_step` equal to `pan` turns the Space step off, and a
`step_distance` outside 10–1000 is clamped to the range. In the
Settings app they are the **Scroll gestures** group under
**Shortcuts & Gestures ▸ Mouse & trackpad**, where
each row's **Applies to** checklist writes the base or chosen
profiles' overrides.

The verbs below change the running base only: a profile's own
override still wins, nothing reaches `gui.json`, and the value
lasts until KiwiDesk next loads its config. In a Lua-owned setup
`init.lua` is where it is kept, and **Adopt into the GUI** keeps
the base it set.

### scroll_gesture.set_pan

**Expects:** modifiers joined by `+` — `control` (`ctrl`),
`option` (`opt`, `alt`), `shift`, `command` (`cmd`) — default
`"control+option"`; `""` turns the gesture off.

**Does:** sets the keys held with a scroll to move focus window
by window. It takes two or more modifiers: one alone fails, as
does an unknown or repeated name, and so does the chord
[`set_space_step`](#scroll_gestureset_space_step) holds, whether
in the base or in the live profile's override.

**Example:**

```lua
scroll_gesture.set_pan("control+option+shift")
scroll_gesture.set_pan("")   -- off
```

### scroll_gesture.set_space_step

**Expects:** modifiers, as for
[`set_pan`](#scroll_gestureset_pan) (default
`"control+option+command"`); `""` turns the gesture off.

**Does:** sets the keys held with a scroll to step between the
Spaces of the screen under the pointer. It fails on the same
chords `set_pan` does, with the pan's chord in place of its own;
`set_pan` cannot take this one.

**Example:**

```lua
scroll_gesture.set_space_step("control+option+shift")
scroll_gesture.set_space_step("")   -- off
```

### scroll_gesture.set_natural_scrolling

**Expects:** a boolean, then optionally `"trackpad"` or
`"mouse"` (default `true` for both).

**Does:** on, a scroll gesture steps the way Natural scrolling
moves content; off, the other way. Named, the input
takes the value alone; left out, both do. A swipe on a trackpad
or Magic Mouse reads the trackpad's value and a notched mouse
wheel the mouse's, whatever macOS's Natural scrolling is set
to.

**Example:**

```lua
scroll_gesture.set_natural_scrolling(false, "mouse")
```

### scroll_gesture.set_long_swipes

**Expects:** a boolean (default `false`).

**Does:** on, a swipe moves one more window every
[step distance](#scroll_gestureset_step_distance) of travel
after its first, on every layout; off, a swipe moves one window
however long it is. A mouse wheel moves one window per notch
either way, as the section above qualifies. The Space step
always steps one Space per swipe.

**Example:**

```lua
scroll_gesture.set_long_swipes(true)
```

### scroll_gesture.set_step_distance

**Expects:** points, 10–1000 (default `60`); a value outside the
range fails.

**Does:** sets the finger travel per extra window of a
[long swipe](#scroll_gestureset_long_swipes). It is kept, and
does nothing, while long swipes are off.

**Example:**

```lua
scroll_gesture.set_step_distance(120)
```

## When Windows No Longer Fit

No layout ever shrinks a window below `min_window_size`. Where
windows stop fitting, the overflow **cascades vertically**:
offset 40 pt downward per window, so every title bar stays
visible and clickable. There is no horizontal (side-reveal)
stacking.

:::unreleased
A Stack zone — master or stack — and each Track track scroll
instead of cascading. A zone shows as many windows as fit at
their minimum size, which is `min_window_size`, or an app's own
minimum once KiwiDesk has learned it where that is larger. Each
shown window gets its minimum plus a share of what is left, and
the rest wait off screen, parked at the screen's bottom corner
like the windows of a Space you are not on. Scrolling moves the
shown windows one slot along the zone; the window scrolling in
appears in its slot at once, and the one scrolling out returns
to the corner. A window whose
minimum is larger than the zone is shown alone. Focusing a
hidden window scrolls the zone by the smallest step that shows
it: the window joins as the last in line (the first, going
back), and the zone hides windows at its other end only until
it fits, so a step reveals one window. A zone at rest keeps the
windows it shows; closing one lets the others grow into the
room.

Each end of a zone that hides windows shows a "+n" overflow mark
on its edge window, counting that end's hidden windows. Clicking
the mark opens the list of them, nearest first; clicking one
focuses it, which scrolls it in. The arrow keys and Return walk
and pick its rows; Escape or any other key, a click on the list's
header or a click outside closes it. The mark takes no
room, so no window resizes when it appears.

In Stack, `focus` and `swap` along a zone that hides windows
step through them in order, as Track does along a track; a
direction from another zone lands only on a shown window. A
Track [`set_swap_skips_cascade`](#set_swap_skips_cascade) swap
treats hidden windows as ordinary track members.

A zone cascades whole only when not even one window fits in it
at `min_window_size`, and the whole Space cascades when the
master and stack zones, or Track's tracks side by side, cannot
all keep that size.

A Grid scrolls the windows past its cells through its last track
along the fill order: the last row when columns fill first, the
last column when rows fill first. A grid with fixed columns and
rows shows exactly that track's cells, lined up with the tracks
above; an [auto-sized](#gridset_auto_size) grid shows as many
windows there as fit at their minimum size. The track is as deep
as the largest minimum of every window in it, hidden ones
included, so it keeps its size as it scrolls. Focus, `swap`, the
overflow marks and their list work as in a Stack zone. A Grid
cascades whole only when not even one cell fits at
`min_window_size`.

In BSP, where a split cannot hold two windows at their minimum
size, the windows from the last run of splits in one direction
scroll along that direction as one line: a line of side-by-side
windows scrolls left and right, a stacked one up and down.
Windows split off in the other direction stay where they are.
The line is at least as thick as the largest minimum of every
window in it, hidden ones included, as far as the window split
off beside it keeps `min_window_size`. Focus, `swap`, `resize`
along the line, the overflow marks and their list work as in a
Stack zone. Where the line starts beside a fixed window, under
either [strategy](#bspset_strategy), the mark at that end sits
across the gap between them and covers a few points of that
window. BSP cascades whole only when not even one window fits at
`min_window_size`.
:::

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

A standard window that cannot be resized — its green zoom button is
disabled, as on most Settings and About windows — floats
automatically too, and a window of an app with no Dock icon that
carries its own title-bar buttons on a raised layer (a system
"Join Network" sheet, for one) is floated rather than ignored.

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

A **shadow window** — a window with no title-bar buttons and no
content beside a real window of the same app (Orion's "Orion
Preview") — is not managed either: it takes no slot and appears
in no bar, whatever its size or position. A `float_rules` entry
does not bring it back. A window with neither buttons nor content
that is the first its app shows is managed after a short wait;
one opened beside a managed window of its app at once.

**KiwiDesk's Settings window** is tracked and **tiled like any
other window** — it takes a layout slot, appears in the App Bar,
and answers `make_floating` / `toggle_floating` and the other
window verbs. Its float rules work the same way yours do, so a
`float_rules` entry can keep it out of the layout permanently.
KiwiDesk's *other* windows are not managed: the setup tour and
the Config Issues window are tracked but always floating, and its
panels — KiwiHub, drag/drop overlays, App Bar
overlays and focus borders — are ignored outright and appear in
no bar and no window list KiwiDesk publishes.

**Example:**

```lua
float_rules = {
    "com.apple.systempreferences",
    "com.apple.finder:Get Info",
}
```

### tile_rules

**Expects:** a Lua table of app bundle identifiers.

**Does:** an app named here tiles the windows KiwiDesk would
otherwise float on a guess: windows that can't be resized, and
every window of an app with no Dock icon. Dialogs, sheets, panels
and raised-layer windows still float, and a `float_rules` entry
for the same app still floats the windows it matches. Matching is
case-insensitive. Like `float_rules`, this table is the global
base, a profile adds or removes entries with its sparse
`tile_rules` object, and the table counts as a setting that makes
`init.lua` the config owner.

**Example:**

```lua
tile_rules = { "com.valvesoftware.steam" }
```

### set_float_automatically

**Expects:** `enabled` (boolean). Default `true`.

**Does:** turns off the guesses `tile_rules` escapes for every
app at once: with `false`, a window floats only through
`float_rules`, a dialog, sheet, panel or raised layer, or your own
`make_floating`. It writes the global base, so a profile's own
`float_automatically` value still applies while that profile is
loaded, and lasts until the next config load.

**Example:**

```lua
KiwiDesk.set_float_automatically(false)
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

A raised Ghostty window with title-bar buttons, such as its
configuration-error window, is one of Ghostty's own windows and is
managed as a float, as is its update alert; the buttonless quick
terminal stays ignored.

**Command bars are ignored automatically.** A Spotlight/Raycast-style
launcher is a menu-bar (accessory) app whose bar is a raised-layer
overlay; KiwiDesk never manages such a window, so the bar is not
tiled, stashed, or pulled along on a space switch. The rule is
generic — accessory app **and** raised window layer — so any
launcher or HUD qualifies without a rule; the app's normal windows
(settings, pickers) stay managed as floats. Raycast's command bar is
additionally recognized by bundle id for setups where Raycast shows
a dock icon and loses the accessory policy.

A raised window of an accessory app, or of Ghostty, counts as one
of its app's normal windows only when it lists title-bar buttons
and macOS does not report it as a system dialog, so Spotlight's
panel on macOS 27 stays ignored.

Invisible helper windows are ignored automatically: a raised-layer
window that is fully transparent or sits entirely off-screen (the
lifecycle keepalive some menu-bar apps create) is never tracked.
`ignore_rules` remains the whole-app escape hatch for anything
either heuristic misses.

A window at the screen-saver level or above — a dictation HUD, a
screen-share overlay you draw on — is ignored too, whatever its
app: it covers the screen or hovers over everything, and is never a
window to arrange.

### app_rules

**Expects:** a Lua table mapping app **bundle identifiers** to
space identifiers.

**Does:** new windows of listed apps go to their assigned space.
An app is named by its bundle identifier (case-insensitive), not
its display name. See [Finding a bundle
identifier](#finding-a-bundle-identifier).

Opening a listed app takes you with it: when you launch it,
reopen it with no window showing, or restore its minimized
window yourself — a Dock click, Spotlight, `focus_or_spawn` —
and the window goes to a space other than the one you are on,
KiwiDesk switches to that space and focuses the window. The
windows macOS reopens at login or KiwiDesk finds when it starts,
and the windows a Desktop switch shows you, stay in their space
([#1599](https://github.com/KiwiCanopy/KiwiDesk/issues/1599)).

:::unreleased
A new window of a running app takes you there too — ⌘N, File ▸
New, or one the app opens on its own — with the exceptions in
[accepted limitations](accepted-limitations.md)
([#2478](https://github.com/KiwiCanopy/KiwiDesk/issues/2478)).
:::

A popup menu the app opens — a window above the normal window
layer — is not filed by the rule: it opens in the space you are
in. The app's dialogs and panels follow the rule like its other
windows.

A popup with no title-bar button, such as a browser extension's
popup, is not filed by the rule either
([#2475](https://github.com/KiwiCanopy/KiwiDesk/issues/2475)).

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

### App rule verbs

The `app_rule` table changes the live rules from Lua, the CLI and
an AI app. It is not the [`app_rules`](#app_rules) and
[`float_rules`](#float_rules) globals, which declare the rules in
`init.lua`. A change lasts until a config reload, a profile load, a
Settings Save of the rules or a quit; over the CLI or an AI app,
[`keep_settings`](cli.md#raw-ipc-protocol) keeps it.

#### app_rule.list

**Expects:** nothing.

**Does:** returns the live rules: `spaces` (bundle id → Space),
`floats`, `tiles`, `ignores`, `float_automatically`, the `owner`
of the rules (`gui` or `lua`) and the live `profile`.

#### app_rule.set_space / app_rule.remove_space

**Expects:** a bundle identifier, and for `set_space` a Space that
exists.

**Does:** the app's NEXT windows open in that Space, or stop
doing so; windows already open stay where they are.
`remove_space` refuses an app with no rule.

#### app_rule.set_float / app_rule.remove_float

**Expects:** a bundle identifier, and optionally a title fragment.

**Does:** adds or removes a float rule — the app's every window,
or those whose title contains the fragment. Open windows are
checked again at once. `remove_float` removes exactly the rule
named, so an app's title rules stay unless each is named, and
refuses a rule that is not there.

**Example:**

```lua
app_rule.set_space("com.spotify.client", "music")
app_rule.set_float("com.apple.finder", "Get Info")
```

### Finding a bundle identifier

App rules and the app verbs (`focus_or_spawn`, `spawn_new`,
`gather`) identify an app by its bundle identifier.
The Settings app's pickers list installed apps by name and store
the identifier for you. To find one by hand:

- Ask macOS: `osascript -e 'id of app "Safari"'` →
  `com.apple.Safari`. It answers for any installed app — hidden,
  windowless or not running.
- Or run `kiwidesk get_state` (or the `get_state` command over
  IPC): every window carries a `bundle_id` field alongside its
  display `app` name.
- Or `mdls -name kMDItemCFBundleIdentifier /Applications/Safari.app`.

An app verb passed a running app's name instead is still refused,
and the refusal names that app's identifier:
`app not found: safari — did you mean 'com.apple.Safari'?`.

Identifiers are matched case-insensitively. An app with no bundle
identifier (a rare unbundled helper process) cannot be targeted
by a rule.

## Making Windows Floating or Tiled

`make_floating`, `make_tiled` and `toggle_floating` take an
optional window id from [`get_state`](#get_state), and then act on
that window rather than the focused one:
`KiwiDesk.make_floating(4711)`. An id no managed window carries is
refused, and a window on a Space no screen shows takes its floating
frame when that Space is next shown.

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
then leaves its z-order untouched.) The float survives the
window closing and reopening (matched by app name and title; a
window that closes while untitled has no identity to match and
loses it) and applies only to that window — use `float_rules` to
float every window of an app.

A window that a `float_rules` entry, KiwiDesk's dialog and panel
detection, or its app having no Dock icon already floats is left
as it is, and nothing is remembered for it.

**Example:**

```lua
KiwiDesk.make_floating()
```

### make_tiled

**Expects:** nothing.

**Does:** returns the focused window to its space's tiling
layout.

It undoes a `make_floating`: from then on
`float_rules` and KiwiDesk's own detection decide whether it
floats, including rules you add later. A window floated by a
`float_rules` entry, by that detection (dialogs, sheets, panels)
or because its app has no Dock icon cannot be tiled: the command
does nothing, a pill on the window names the reason, and over the
CLI it fails. Remove the `float_rules` entry to tile such a
window. A window that floats only because its Space is in
floating layout still floats there.

A window floated only because it can't be resized or its app has
no Dock icon tiles once its app is in [`tile_rules`](#tile_rules)
or [`set_float_automatically`](#set_float_automatically) is off.

Dragging a window out of a floating-layout Space onto a tiled
Space on another screen floats it the way `make_floating` does,
so it stays floating there; `make_tiled` undoes it.

`make_auto` is retired, and `make_tiled` does its job: a call
fails with `make_auto was retired — use make_tiled`.

**Example:**

```lua
KiwiDesk.make_tiled()
```

### toggle_floating

**Expects:** nothing.

**Does:** flips the focused window in one verb — a floating
window is tiled as [`make_tiled`](#make_tiled) tiles it, and a
tiled one floated as [`make_floating`](#make_floating) floats it.
On a floating-layout Space every window floats, so the window
does not move there (its Space Bar glyph still shows the float
badge or loses it); the flip decides whether it keeps floating
once a command moves it to a tiled Space or the Space changes
layout. It is bound to `control+option+f` by default
and is the only float verb offered in the Settings shortcut
list; the explicit `make_*` verbs remain for scripts that need a
specific direction.

The window's on-window floating mark follows the setting as its
Space Bar float badge does.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+f", function()
    KiwiDesk.toggle_floating()
end)
```

## Opening and Closing Windows

Both verbs take an optional window id from
[`get_state`](#get_state) and act on the focused window
otherwise. They reach another app through Accessibility and
return before it answers, so a refusal only the app can give
shows as a pill on screen and a line in the log, never as an
error here. KiwiDesk's own windows are refused.

### new_window

**Expects:** optionally a window id.

**Does:** brings that window's app forward and presses its
**File ▸ New Window** — the File-menu item with the shortcut ⌘N
(or ⇧⌘N) whose title names a window. An app with no such item
opens nothing, and a pill says so. A new window its App Rule
files into another Space takes you there, as opening the app
would ([accepted limitations](accepted-limitations.md)).

**Example:**

```lua
KiwiDesk.bind("cmd+alt+n", function()
    KiwiDesk.new_window()
end)
```

### close_window

**Expects:** optionally a window id.

**Does:** presses that window's close button, so the app
answers unsaved work its own way. A window with no close button
stays open, and a pill says so.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+w", function()
    KiwiDesk.close_window()
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
  every space of **every** screen. Wears the `infinity` (∞)
  mark.
- **Screen sticky** (`make_display_sticky` /
  `toggle_display_sticky`) — present on every space of **one**
  screen: the screen its home space lives on. Wears the
  `pin.fill` (📌) mark.

Both share one off-switch (`make_unsticky`), and each verb sets
its own scope outright — `make_sticky` on a screen-sticky window
turns it global, and vice versa. On a single screen the two
scopes coincide.

`move_to_space` is guarded: a **global** sticky refuses any
target; a **screen** sticky refuses a target on the *same*
screen and accepts one on *another* screen, which re-homes it
to that screen. A refused move shows a brief pill on the
window.

A sticky window is marked in its top-right corner
(`sticky.set_mark`; `infinity` for global, `pin.fill` for
screen), and the same per-scope badge rides its Space Bar
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
on every space of every screen. No mode argument: the window
keeps its existing floating or tiled state. Overrides screen
sticky if the window already had it.

**Example:**

```lua
KiwiDesk.make_sticky()
```

### make_display_sticky

**Expects:** nothing.

**Does:** marks the focused window sticky to its **current
screen** — visible on every space of that one screen, not on
other screens. Moving it to a space on another screen re-homes
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
a screen-sticky window switches it to global.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+s", function()
    KiwiDesk.toggle_sticky()
end)
```

### toggle_display_sticky

**Expects:** nothing.

**Does:** flips the focused window between **screen** sticky
(its current screen only) and off. Also offered in the Settings
shortcut list. Toggling screen sticky on a global-sticky window
switches it to screen sticky.

**Example:**

```lua
KiwiDesk.bind("cmd+alt+d", function()
    KiwiDesk.toggle_display_sticky()
end)
```

:::unreleased
### toggle_maximized

**Expects:** nothing.

**Does:** makes the focused tiled window fill its screen —
the whole area between the menu bar and the Dock, with no gaps —
and hides both bars on that screen, without a macOS full-screen
Desktop. The rest of the Space keeps its layout behind it. A
second call puts the window back in its slot; so does moving
focus to another tiled window of the Space, and the window
leaving the layout (closed, minimized, floated or moved). A
swap, resize, layout change or reset of sizes
puts it back first, then acts, and a mouse drag of it puts it
back; a command that refuses leaves it as it is. Focus on a
floating window, a switch to another Space or Desktop and back,
or KiwiDesk's own restart leaves it filling the screen. Fails on
a floating or sticky window. Bound to `⌃⌥M` by default.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+m", function()
    KiwiDesk.toggle_maximized()
end)
```
:::

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
for sticky's refusal pills (home-space, move-blocked), which
go silent with it. Off while the Space Bar is not shown leaves sticky state with no mark at all; neither
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

On [Liquid Glass](#stickyset_liquid_glass) the color tints the
mark's glass instead, and the disc goes.

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

The floating mark draws the same way, tinted by
[`floating.set_color`](#floatingset_color) where no sticky glyph
shares its plate.

**Example:**

```lua
sticky.set_liquid_glass(false)
```

### floating.set_mark

**Expects:** boolean (default `true`).

**Does:** shows or hides the on-window floating mark — the
`macwindow.on.rectangle` glyph at the top-right corner of a
floating window, including one in a floating-mode space: one
floated by `make_floating` or `toggle_floating`, by a
`float_rules` entry, or by KiwiDesk's own detection. A window
that floats only because its space is in floating mode gets no
mark. A window that is also
sticky carries both glyphs on one plate, the sticky one
outermost; on a window too narrow for both, the floating glyph
is left out. The mark draws as Liquid Glass under
[`sticky.set_liquid_glass`](#stickyset_liquid_glass).

**Example:**

```lua
floating.set_mark(false)
```

### floating.set_color

**Expects:** a hex color string `#RRGGBB` or `#RRGGBBAA`, or an
empty string `""` for **Automatic** (default `""`).

**Does:** tints the floating mark — the on-window mark and the
Space Bar floating badge read this one value, as
[`sticky.set_color`](#stickyset_color) describes for sticky. On
a window that is both sticky and floating, Liquid Glass takes
the sticky color and the floating glyph the label color. `""`
is Automatic; any non-empty value must parse as a hex color.

**Example:**

```lua
floating.set_color("#8E5DE0")
```

## Launching Apps

### focus_or_spawn

Renamed from `pull_or_spawn`, which is now refused with a Config
Issue naming this verb. A shortcut made in Settings is updated for
you; a call in your `init.lua` needs the new name.

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

A first press focuses the app window you used **most recently**
among the ones KiwiDesk is tracking — its windows on the
Desktops on screen — switching to its Space. Right after
KiwiDesk starts, before you have used any of them, it takes the
app's own focused window, else the first in the cycle order
above. A window on another Desktop is reached only when the app
has none on the Desktops on screen, as described above.

If the app is running with **no window at all** — you closed
its last one and it stayed open, as Safari does — the shortcut
asks it for a new window, the same as clicking it in the Dock.

**Example:**

```lua
KiwiDesk.bind("ctrl+return", function()
    KiwiDesk.focus_or_spawn("com.apple.safari")
end)
```

### spawn_new

**Expects:** an app bundle identifier (e.g. `com.apple.Terminal`).
See [Finding a bundle identifier](#finding-a-bundle-identifier).

**Does:** always launches a new instance of the app, even if one
is already running. Matching is keyed on the bundle id, like
`focus_or_spawn`.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+return", function()
    KiwiDesk.spawn_new("com.apple.Terminal")
end)
```

Both launch verbs are also reachable from the Settings app, from
the per-row menu of an Open applications shortcut: *Open or Focus*
(`focus_or_spawn`, the default) or *Open New* (`spawn_new`).

### gather

**Expects:** an app bundle identifier (e.g. `com.apple.Notes`).
See [Finding a bundle identifier](#finding-a-bundle-identifier).

**Does:** moves every window of the app into the Space you are
on, in the order the Space Bar lists them, after the windows
already there. Floating windows stay floating and sticky windows
stay sticky; a window in native full screen keeps its own Space.
Windows up on another macOS Desktop are moved onto the Desktop
you are looking at, without switching to theirs — that needs the
Desktop bridge; without it they stay where they are. It never
launches the app: with no window to move, it does nothing and
reports an error.

**Example:**

```lua
KiwiDesk.bind("ctrl+shift+return", function()
    KiwiDesk.gather("com.apple.Notes")
end)
```

It is the third choice, *Gather Windows*, in the **Action** menu
of an Open applications shortcut in Settings.

### move_here

**Expects:** an app bundle identifier (e.g. `com.apple.Notes`),
then optionally a piece of window title. See [Finding a bundle
identifier](#finding-a-bundle-identifier).

**Does:** moves one window of the app into the Space you are on
and focuses it: the open window you focused most recently that is
not here yet — in another Space, or up on another macOS Desktop —
and only once none is left, a minimized one. Press it again for
the next. The app's other windows stay where they are; to move
them all, use [gather](#gather).

With a title, only windows whose title contains it count,
ignoring case and accents, so `"Inbox"` keeps finding Mail's
window as its message count changes.

- A window in native full screen is skipped, and so is a window
  on another Desktop when the Desktop bridge is absent. When
  nothing else is left, a refusal says the window can't be moved
  here.
- Every matching window already here, or a title no window has,
  shows a refusal on the focused window and moves nothing. A
  sticky window shown here counts as here.
- A hidden app is unhidden, and the window it brings back
  focused moves here — with a title, only if it matches.
- An app with no window at all is opened, the same as
  [focus_or_spawn](#focus_or_spawn).

**Example:**

```lua
KiwiDesk.bind("ctrl+shift+n", function()
    KiwiDesk.move_here("com.apple.Notes")
end)
KiwiDesk.bind("ctrl+shift+i", function()
    KiwiDesk.move_here("com.apple.mail", "Inbox")
end)
```

## User Interface

### kiwihub.show

**Expects:** a side: `"windows"`, `"shortcuts"` or `"view"`.

**Does:** opens **KiwiHub** on that side, switches to it from
another side, or closes KiwiHub when it already shows that side.
Over the CLI it is `kiwidesk kiwihub.show windows`; any other side
is refused, naming the three.

The `"shortcuts"` side is the read-only **shortcuts panel** — a
live glance at the active layer's bindings.

- Typing narrows the list by name, the matched letters in bold.
- **↑** **↓** and **Page Up** / **Page Down** scroll the list;
  **Return** runs nothing.
- **⌘,** or **Edit in Settings…** opens Shortcuts & Gestures.

The `"windows"` side is the **window switcher**, its field at
Spotlight's height on the screen under the pointer. It lists every
window KiwiDesk knows except the one you are in — open windows
first, most recently used first, including those up on another
macOS Desktop, then minimized windows, then one row per hidden
app. Typing narrows the list by app name, then by title. While a
[KiwiVision lens](#kiwivisiondefine_lens) is on, the rows of the
lens's apps come first and every other app's follow under **Other
apps**, while you type too. Moving the mouse over a row selects it.

- **Return** goes to the selected window, switching Space or
  Desktop as needed; on a minimized window it brings it back, on a
  hidden app it unhides it.
- **⇧Return** moves the window into the Space you are on instead,
  as [move_here](#move_here) does.
- **⌘1** … **⌘9** pick one of the first nine results.

A window in native full screen is listed, and Return activates its
app rather than switching to its full-screen Space.

The `"view"` side is the **view picker**, three lines in one
panel, the current item on each marked ✓. The menu bar's **Open
KiwiHub…** row opens it too, its bound combo shown beside that
row.

- **Layout** — a tile per layout for the Space shown on the screen
  under the pointer, greyed where there is none; Return applies it
  like `set_mode` for that Space.
- **Profile** — one per saved profile; one that cannot load is
  greyed. Return loads it like `load_profile`. The line ends in
  **Save as New Profile…**: Return turns the search field into a
  name field, and Return again saves the current arrangement under
  that name like `save_profile`, which hands it the connected
  screen setup; a taken name saves beside it rather than over it. Esc
  goes back to picking, and ⌘1–9 and ↓ skip the chip.
- **KiwiVision** — Default, which turns
  [KiwiVision](#kiwivisiontoggle) on with no lens, then one item
  per lens, which turns that lens on. Picking the item already on
  turns KiwiVision off. A lens with no apps is left out until it
  has some, and one the live profile leaves out is greyed "Not in
  Studio". The line ends in **New Lens…**, which opens Settings ▸
  KiwiVision ready to name a lens; ⌘1–9 and ↓ skip it, and a
  Lua-owned setup greys it.

Keys on this side:

- **←** and **→**, or moving the mouse over an item, move along a
  line; **↑** and **↓** move between lines and keep the position,
  clamped to a shorter line. A line longer than the panel scrolls
  sideways.
- Typing narrows all three lines, dimming the rest, and selects
  the first match.
- **Return** applies the selected item and closes KiwiHub.
  **⌘1** … **⌘9** apply the line's items by position, counted
  among the matches while you type; holding **⌘** shows the
  numbers.
- **⌘,** opens the Settings page of the line the selection is on;
  **⌘S** keeps the layouts in the profile, as Keep in a Space's
  Layout menu does.

On every side:

- **Tab** steps to the next side and **⇧Tab** to the one before —
  Windows, Shortcuts and View, wrapping — clearing the typing. The
  switch at the end of the field shows each side's own key, read
  from your shortcuts.
- **Escape** clears the typing, then closes KiwiHub; **⌘W**, a
  click elsewhere or another app taking the keyboard close it too.

Seeded on **⌃⌥J** (windows), **⌃⌥K** (shortcuts, in every layer
you create too) and **⌃⌥L** (view), and offered under
**Shortcuts & Gestures ▸ KiwiHub**, where you can rebind or clear
each per layer.

**Example:**

```lua
KiwiDesk.bind("alt+space", function()
    kiwihub.show("windows")
end)
```

:::unreleased
### kiwihub.set_key

**Expects:** a built-in KiwiHub key — `"up"`, `"down"`,
`"page_up"`, `"page_down"`, `"left"` or `"right"` — and a combo
string; no combo, or `""`, clears it.

**Does:** makes the combo a second key for that built-in key
while KiwiHub is open: `"down"` moves the selection down as **↓**
does, `"page_down"` a page as **Page Down** does. `"left"` and
`"right"` move only on the View side, as **←** and **→** do;
elsewhere their combo types into the search field. The built-in
keys keep working, holding **⇧** with a combo moves as with the
arrows, and the combo does nothing outside KiwiHub. While the
field names a profile, every combo types. A KiwiDesk shortcut on
the same combo runs instead.

Refused, naming the reason: a combo it cannot read; one without
**ctrl** or **cmd**; one with **hyper**; **Return**, **Enter**,
**Escape**, **Tab**, an arrow or a page key under any modifier;
**cmd** with a digit or with **S**, **,**, **W**, **A**, **C**,
**V**, **X** or **Z**; and a combo already set for another key.

The keys are the Mac's, not a profile's. Lua-only: no Settings
row shows them.

**Example:**

```lua
kiwihub.set_key("down", "ctrl+n")
kiwihub.set_key("up", "ctrl+p")
kiwihub.set_key("page_down", "ctrl+d")
kiwihub.set_key("page_up", "ctrl+u")
```
:::

### Retired panel verbs

`show_shortcuts`, `show_jump_to_window` and `show_layout_picker`
are retired for [kiwihub.show](#kiwihubshow). A call in
`init.lua` is reported in Config Issues, naming `kiwihub.show`;
over the CLI it fails with `<verb> was retired — use
kiwihub.show`. A shortcut made in Settings is updated for you.

### open_settings

**Expects:** nothing.

**Does:** opens the **Settings** window and brings it to the
front. It never closes the window: pressing the key with
Settings already open returns it to **Home**, the same as
opening Settings from the menu bar. Unsaved edits survive that;
only the place you were reading resets.

Seeded on **`⌃⌥,`** in the base layer and in every layer you
create in Settings.

Offered under **Shortcuts & Gestures ▸ Open applications ▸
KiwiDesk** ("Open Settings"), where you can rebind it per layer.

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

`hyper` is KiwiDesk's own Hyper modifier, live once
[`set_hyper_key`](#set_hyper_key) names a key; it combines with
any of the others (`"hyper+cmd+ctrl+x"`). Held, a Hyper combo is
its chord without `hyper`, so an enabled macOS shortcut on that
chord (`hyper+cmd+space` is Spotlight's) still wins.

:::unreleased
A side is `l` or `r` before a short name: `lcmd` / `rcmd`,
`lopt` / `ropt`, `lalt` / `ralt`, `lshift` / `rshift`, `lctrl` /
`rctrl` (`"rcmd+h"`). It counts only while
[`set_modifier_sides`](#set_modifier_sides) is on. Two spellings
of one modifier (`"lcmd+rcmd+h"`, `"cmd+rcmd+h"`) and a side with
`hyper` are unrecognized.
:::

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
& Gestures page flags the row with ⚠ *"isn't a recognized shortcut"*.

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

#### switch_layer

**Expects:** a layer name: one `define_layer` declared, or
`"default"`.

**Does:** makes that layer the active one, so only its bindings
fire until the next switch. An unknown name changes nothing and
is logged.

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

A floating window's `min_window_size` is Floating's
([`set_min_window_size`](#set_min_window_size)), whatever layout
its space uses: its width for `"x"`, its height for `"y"`.

The delta is split between **both** edges (#1091), so a float
grows and shrinks around its own centre. An edge already against
the boundary is *pinned* and the whole delta goes to the other
side; the boundary is the screen's visible bounds less any bar
strips on that space, so a float cannot be grown underneath a
bar, and when both edges are against it a grow refuses and
flashes a pill. Shrinking pins the same way.

Tiled windows resize in bsp, stack, scrolling, track and grid
layouts; monocle reports "not supported" and flashes a pill on
the focused window saying the layout has no resizing (#1255). In
a grid, `"x"` moves the edge the focused cell shares with the
column after it — or, for the last column, the one before — and
`"y"` does the same for rows, so the neighbour gives exactly what
the focused column takes and no other column moves (#763). A
mouse drag on a cell's inner edge moves that edge the same way.
The sizes are kept as [column and row weights](#gridset_column_weight)
in a session layer that
[`reset_layout_sizing`](#reset_layout_sizing) clears.

`set_refusal_sound(true)` adds the system alert sound
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
own key-repeat delay, a continuous **glide** on the screen's
frame clock. Each frame moves a fraction of *that binding's own
delta*, at a speed in steps per second that starts gently and
ramps up over a second or two. The amount moved is the frame's
elapsed time × that speed, so the same hold travels the same
distance on a 60 Hz screen, a 120 Hz one, and a ProMotion panel
changing rate mid-hold.

The glide re-issues the **`resize` command your press ran**,
with a scaled delta — never the binding's Lua body, which runs
exactly once, on the press. Whether a binding glides is decided
by what its press **did**: a body that runs two commands, or a
different verb, fires once per press, and `focus`/`swap` never
glide. A body that rebuilds its own bindings (`bind` inside the
body) arms nothing.

:::unreleased
While [`set_modifier_sides`](#set_modifier_sides) is on, a
shortcut whose keys a sided shortcut also uses — sided or not —
fires once per press.
:::

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
  (#383) — the screen minus any Space Bar strip.
- **stack** — focus-aware (#67). `"x"` moves the master/stack
  split *in the direction that grows the focused window*: with
  a master focused, a positive delta raises the master ratio;
  with a stack window focused, it lowers the ratio. The write
  stops at the bound that keeps both zones at their effective
  minimums (per zone, #933) within the area the layout fills
  (#44). `"y"` grows or shrinks the focused window's vertical
  share of its column via per-window weights — session-scoped,
  never saved to a profile, and reset when a window leaves the
  space or KiwiDesk quits. If the focused window is alone in
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

The area a layout fills, which every bound above is taken
within, is the screen minus the [KiwiShelf](#kiwishelf) strip
wherever a bar draws in that layout (#1517).

**Where the ratio write lands (#458):** in a **session layer
scoped to that space** — never the shared global, so resizing
one space does not visibly resize every other space, and never
a per-space override, authored or not, so what
`bsp.set_ratio_h_override` or the Settings override editor set
stays the number you wrote and
[`reset_layout_sizing`](#reset_layout_sizing) can return to it.
Session values behave like the stack's per-window weights:
never saved to a profile, gone when KiwiDesk quits, reseeded from config
on a real mode change, `reload_config`, `load_profile` (or any
other explicit profile/preset/GUI apply), a Desktop switch or
screen change that loads a *different* profile, and dropped
for a
field the moment you set it explicitly — its global
(`bsp.set_ratio_h`, `stack.set_master_ratio`,
`scroll.set_slot_size`) drops it on every space, its `_override`
twin on that space — so an explicit write always shows. This
covers the BSP split ratios, the stack master ratio, and the
scrolling slot size — the three interactive-resize knobs —
consistently.

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

Where a screen's Space Bar draws nothing at rest
([`space_bar.set_visibility`](#space_barset_visibility)), the
status item shows the Space that screen is showing instead
([User Guide ▸ Space Bar](user-guide.md#space-bar)), led by the layer's icon — or
the two-character cut of its name — the way the bar is.

**Example:**

```lua
KiwiDesk.define_layer("resize", { --[[ bindings ]] },
    { icon = "arrow.left.and.right" })
KiwiDesk.define_layer("service", { --[[ bindings ]] },
    { icon = "⚙️" })
```

:::unreleased
#### Describing a Shortcut

**Expects:** an optional third table on `KiwiDesk.bind`, or a
`{ fn = …, … }` table in place of a function in a `define_layer`
table, with any of:

- `desc` — what the shortcut does, in your words.
- `group` — the shortcut group it is listed in: a built-in
  group's token (`focus`, `move_windows`, `layout`, `size_float`,
  `kiwivision`, `kiwishelf`, `apps`) puts it there, whatever its
  case and the spaces around it; any other name makes a shortcut
  group of its own.
- `symbol` — an SF Symbol name for its row.

**Does:** KiwiHub's Shortcuts side lists the shortcut under its
description instead of its Lua, in its group, wearing its symbol.
A group of your own is listed after the built-in ones and before
Custom, under the name as written. Without a symbol a row wears
`</>`; a name that is not an SF Symbol shows `</>` too and is
listed in Config Issues, and the shortcut still works.

A shortcut whose action KiwiHub knows — `KiwiDesk.focus("left")` —
keeps its built-in name, group and symbol for each field it leaves
empty, and shows the ones it sets. An inactive or unavailable
shortcut stays in its own section whatever its group.
[`shortcut.list_groups`](#shortcutlist_groups) lists the names in
use.

A row in Settings ▸ Shortcuts & Gestures ▸ Lua bindings sets the
same three fields for a shortcut Settings made. A shortcut
`init.lua` binds is not listed there.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+shift+f", move_and_follow, {
  desc = "Move to the next Space and follow",
  group = "Move and follow",
  symbol = "arrow.right.square",
})
KiwiDesk.define_layer("resize", {
  ["h"] = { fn = shrink, desc = "Narrower", group = "size_float" },
})
```
:::

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

A profile can also leave a base binding out: its layer entry
lists the combo under `"removed"`, and that base row is not
registered while the profile is loaded. That includes your
profile-switch shortcut — leave it in, or switch from the menu
bar.

Profiles re-resolve their bindings whenever they apply: on
`load_profile`, on a screen change, and on a Desktop binding
switch. Switching profiles also returns you to the default
layer.

### Shortcut verbs

The `shortcut` table reads and writes the saved shortcuts of the
live profile from Lua, the CLI and an AI app, in the default layer. Shortcuts
load only from the saved files, so a write saves at once and the
key works straight away — the shortcut rows alone, never the rest
of the profile. A new shortcut goes into the shared base on the
loaded profile, as Settings ▸ Shortcuts starts one. With
`init.lua` owning the config, or no saved profile live, the verbs
refuse, save `shortcut.list_groups`, which reads the shortcuts in
effect.

#### shortcut.list

**Expects:** nothing.

**Does:** returns the live `profile` and its `layers`, each with
its `name`, whether it is the `default`, and its `shortcuts` —
each `chord` and the `lua` it runs.

:::unreleased
A shortcut that describes itself carries its `desc`, `group` and
`symbol` too ([Describing a Shortcut](#describing-a-shortcut)). It
reads the saved files, where
[`shortcut.list_groups`](#shortcutlist_groups) reads the shortcuts
in effect.
:::

#### shortcut.set

**Expects:** a chord (`"ctrl+alt+h"`), a command's name, and that
command's arguments.

**Does:** binds the chord to one call of the command, built from
the arguments — strings, numbers and booleans. Only a command the
CLI could run is bound: never a destructive one, never `exec` or
another Lua-only verb, so the binding cannot run other Lua. A
chord another action holds, or a command already bound to another
chord, is refused; remove the old binding first.

#### shortcut.remove

**Expects:** a chord.

**Does:** unbinds it, from every profile holding it when it is a
shared shortcut. A chord with no shortcut is refused.

**Example:**

```lua
shortcut.set("ctrl+alt+h", "focus", "left")
shortcut.remove("ctrl+alt+h")
```

:::unreleased
#### shortcut.list_groups

**Expects:** nothing.

**Does:** returns `built_in`, the tokens of KiwiHub's built-in
groups, and `custom`, every shortcut group the installed shortcuts
make of their own, each once. It reads the
shortcuts in effect, so it answers with `init.lua` owning the
config too.
:::

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
`focus_or_spawn` match on; the display `app` name is
locale-dependent. It is the trailing Lua argument (skip it if
you don't need it), `""` for unbundled processes; in the CLI
event stream the key is `bundle_id`, JSON `null` when unknown.

When the number of screens changes, `monitor_change` fires once
the screens have stopped changing for a second (at most five
seconds after the first change), with the count they settled on. macOS briefly reports an in-between layout on
some changes, such as disconnecting an Apple Vision Pro, and the
profile is chosen only for the settled one.

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

Commands at `init.lua` top level run on load and on
[reload](#reload_config); see
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

### reload_config

**Expects:** nothing.

**Does:** reads the configuration from disk again once the
calling function returns, running `init.lua`'s top level as at
launch.

**Example:**

```lua
KiwiDesk.bind("ctrl+alt+shift+r", function()
    KiwiDesk.reload_config()
end)
```

## Profiles & Screens

### save_profile, load_profile, delete_profile, set_default_profile

**Expects:**

- `save_profile(name)` — a name string; updates if it exists.
- `load_profile(name)` — a name string.
- `delete_profile(name)` — a name string.
- `set_default_profile(name)` — a name string (sets the profile to
  load for this screen count when no exact match exists).

**Does:**

- `save_profile` persists the current layout (gaps, modes,
  parameters, animations, window positions, and optionally a sparse
  keybinding override).
- `load_profile` switches to the named profile and makes its space
  list the authority (see *Space Reconciliation*).
- `delete_profile` removes the profile; deleting the last profile of
  a count reverts that count to its built-in Standard.
- `set_default_profile` marks a profile as the fallback for its
  screen count.

`save_profile` and `load_profile` also hand the connected screen
setup to that profile, and `set_default_profile` refuses a profile
that holds no setup (see [Profile Screen
Setups](#profile-screen-setups)).

**Example:**

```lua
KiwiDesk.save_profile("Developer Rig")
KiwiDesk.load_profile("Developer Rig")
KiwiDesk.delete_profile("Developer Rig")
KiwiDesk.set_default_profile("Developer Rig")
```

**Profiles are the single source of truth for tiling.** A profile
owns the gaps, per-space layout modes, layout parameters,
animations, mouse-resize behavior, and the space→screen
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

**Does:** sets where windows land when their space goes —
`delete_space`, or a profile switch away from a hand-written
config with no profile or Standard live, which has nothing to
hold the space for. Without an explicit choice (or when the
chosen space doesn't exist in the profile), windows land in the
**first space** of the profile's ordered list.

**Example:**

```lua
KiwiDesk.set_fallback_space("mail")
```

### set_space_icon

**Expects:**

- A space identifier.
- An SF Symbol name, emoji, single character, or `""` to clear.

**Does:** sets a recognition icon next to the space name in the
Spaces list, Screens cards, and per-space shortcut rows. Icons ride
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
screen** (the one with the menu bar), KiwiDesk loads the
bound profile — its spaces, layouts, and settings — provided
the profile is saved for the connected screen count; otherwise
the binding stands aside, the current profile stays, and a
screen change picks by the connected screens instead. Desktops
without a binding keep whatever profile is active. A binding
takes effect when that Desktop next activates. With "Displays
have separate Spaces" off, or with a single screen, the main
screen's Desktop is *the* Desktop. In a hand-written config
the call lives in `init.lua`; when the config is GUI-managed,
bindings are edited in the Profiles section instead.

A GUI-managed config keeps its bindings on this Mac, in
`~/Library/Application Support/KiwiDesk/bindings.json`, and a
backup carries them. Such a binding follows its profile through a
rename ([Spaces and Desktops](spaces-and-desktops.md#a-binding-follows-its-desktop-not-its-number));
a call in `init.lua` names the profile again on every load, so
there the binding follows the name. Restored on another Mac, a
binding stays dormant until that Mac shows the Desktop it was
made on; one kept by Mission Control number attaches to that
number there.

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

**Screen arguments bind a profile for one screen setup.** After
the profile, pass the fingerprint of every screen in that setup,
as `list_monitors` prints them; the binding then loads only while
exactly those screens are connected. A call replaces the entry of
the same screen count **and** the same scope, so per count a
Desktop holds one profile for all screen setups and one for each
setup named, each of the profile's own screen count. Which entry
loads, and that either loads over the profile that holds the
connected setup, is the binding rung of [Profile Screen
Setups](#profile-screen-setups).

```lua
-- Desktop 3 on two screens: "Dual" anywhere, "Studio" at the desk.
KiwiDesk.bind_profile_to_desktop(3, "Dual")
KiwiDesk.bind_profile_to_desktop(3, "Studio",
  "Built-in Retina Display:1512x982", "LG UltraFine:2560x1440")
```

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

**A space is its name; every profile owns what it holds.** Two
profiles can each define a space called `1` — or `Work` — and it
is one space: across a switch between them it stays live and
takes the incoming profile's settings, and each profile's record
below decides which of the windows it knows go there. The name
is how you address a space (`focus_space 1` means "space 1 of the
profile I'm in"); give two spaces different names to keep them
apart.

**Switching profiles remembers where your windows were.** When
you switch away, KiwiDesk files which space each window was in
under the profile you are leaving; when you switch back, it puts
them back.

A window the incoming profile has never seen — opened while
another profile was up — stays where it is: in a space the
profile declares, or in its own space, now held, when the profile
does not declare it (below).

This happens on any profile CHANGE — an explicit `load_profile`,
a Desktop binding swapping profiles under you, or a screen
change that resolves a different profile. Re-applying the
profile that is *already* live changes nothing, so a reconnect
that lands on the same profile leaves your layout alone.

The record is per session and is not written to disk.

**A screen change holds a gone screen's spaces.** When a screen
change resolves a different profile, a space that lived on a
screen no longer connected — pinned there, or placed there by
the Main role or by KiwiDesk — and still holds windows on any
Desktop is *held* instead of pruned: it stays live on a remaining
screen, and where the incoming profile declares its name it takes
the next number past the highest live one. A
profile or Standard that later applies and declares a held
space's current number moves it past the highest live number
again. A held space keeps its icon and mode — `reload_config`
does not reset its mode
([#1507](https://github.com/KiwiCanopy/KiwiDesk/issues/1507)).

**Every switch holds what it does not name.** The same hold runs
on every profile CHANGE — `load_profile` of another profile, a
Desktop binding, a screen change, or a built-in Standard taking
over — for every live space the incoming profile or Standard does
not declare by name and that still holds windows, whether its
screen left or stayed. An empty one is dropped. A space held
while its screen stayed goes home when the arrangement it left
applies again and declares its original name, as below. Switching
away from a hand-written `init.lua` with no profile or Standard
live holds only a gone screen's spaces, and forwards the rest to
the fallback space
([#1790](https://github.com/KiwiCanopy/KiwiDesk/issues/1790)).

A held space wears a two-screen marker in the Space Bar. A temporary
space held this way comes back temporary.

Held spaces keep their order: when a switch holds them, a
numbered held space after a renumbered one is renumbered past it
too, even where its own name is free, and a later renumber keeps
the Space Bar in that order
([#1664](https://github.com/KiwiCanopy/KiwiDesk/issues/1664)).

Once its screen is back, a held space goes home when the
arrangement then live is the one it left — the same profile, or
the same Standard — and declares its original name: everything in
it moves into that space, which takes the returning arrangement's
mode, and the hold ends. This includes a reconnect that keeps the
live profile. With a different arrangement, or the name
undeclared, it stays held, pinned back to its screen. With a
hand-written `init.lua` and no profile for the connected
screens, a reconnect only places spaces, and a held space stays
held.

A window the incoming profile remembers in one of its own spaces
goes there, even out of a held space; a held space keeps only
the windows that profile has never seen, and is dropped once
empty.

A held space is dropped once no window is left in it on any
Desktop, and by `delete_space`, which forwards its windows to the
fallback space; resetting every setting ends every hold. A
`load_profile` does not end one: its prune drops only the empty
spaces the profile does not declare. `save_profile`, the
`gui.json` space list and pins and the per-profile record above
never include one.

Held spaces survive a KiwiDesk restart, an update and a crash:
every session snapshot records them, and a held space whose
screen is connected at launch goes home at once by the rule
above. A held space whose windows were all closed meanwhile
ends by the rule above once macOS confirms they are gone, and a
restart of the Mac ends every hold
([#1646](https://github.com/KiwiCanopy/KiwiDesk/issues/1646)).

### Profile Screen Setups

A profile covers concrete **screen setups** of one screen count — each a list
of screen fingerprints plus the space→screen pins valid for that
arrangement. Updating a profile while a new combination is connected
teaches it that combination. When screens change, KiwiDesk resolves
in this order:

1. **Desktop binding** — a profile bound to the Desktop your main
   screen is on and saved for the connected screen count
   ([bind_profile_to_desktop](#bind_profile_to_desktop)); a binding
   that cannot fire stands aside.
2. **Exact match** — a profile stores exactly the connected screens
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

Within the binding rung, a profile bound for exactly the connected
screen setup comes before one bound for all screen setups.

Every space always resolves to a screen: an explicit fingerprint pin
wins, then the **Main** role (the space follows whatever screen is
currently main — dock and undock without stale fingerprints), then
the built-in positional default.

And every screen keeps at least one space: whatever leaves a
screen empty — a pin, a moved or deleted space, a profile loaded
onto screens it was not saved for — KiwiDesk seeds one numbered
space there, in the layout the starter setup would open that
screen in. No file learns the seed until you save; `init.lua`
never does.

Explicitly loading a profile whose stored sets don't cover the
connected screens works, but the state loads *dirty* until you
update the profile on this hardware or return to a covered set.

A screen setup belongs to one profile. `save_profile` (unless
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
screen change and a Desktop binding never move a set, so two
hand-edited profiles that hold the same set still resolve as
before. A profile left with no set is *dormant*:
its file keeps `"monitor_sets": []` beside `"monitor_count"`, it is
never picked by its screens (a Desktop binding still loads it), it
still loads by name, and it takes a set back on its next load. A
dormant profile loses its default flag; the profile that took its
set becomes the default unless the count already has another.

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
  "main_spaces": ["1"],       // follow the main screen
  "fallback_space": "1",      // rehome target
  "saved_at": "2026-07-04T12:00:00Z",
  "settings": {
    "drag": {
      "ghost": {
        "enabled": true, "border": true,
        "border_color": "#347957", "border_alignment": "inside",
        "fill": true, "fill_color": "#34795740"
      },
      "drop_zone": {
        "enabled": true, "border": true,
        "border_color": "#C2790A", "border_alignment": "inside",
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
                   "app_bar": { "visibility": "always",
                                "active_indicator": "edge_mark" } },
      "scroll": { "anchor": "follow", "slot_size": 0,
                  "new_window_placement": "after_focused" },
      "stack": { "master_count": 1, "master_ratio": 0.6,
                 "new_window_placement": "first" }
    },
    "min_window_size": {          // per layout, in pt
      "bsp": { "height": 300, "width": 300 },
      "floating": { "height": 300, "width": 300 },
      "grid": { "height": 160, "width": 220 },
      "scrolling": { "height": 300, "width": 300 },
      "stack": { "height": 300, "width": 300 },
      "track": { "height": 300, "width": 300 }
    },
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

`lens_reach` leaves [KiwiVision lenses](#kiwivisiontoggle) out of
the profile. It maps a lens name, in lower case, to `false`:
`"lens_reach": { "writing": false }`. A lens the key does not name
reaches the profile, and without the key every lens does.

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
and layout reflowing ([Animation Cascade](#animation-cascade)).

**Example:**

```lua
animations.set_duration(150)
```

### animations.set_scroll_duration

**Expects:** a number (milliseconds, clamped 50–1000).

**Does:** sets the scrolling-layout focus-shift duration, a knob
independent of `set_duration` ([Animation Cascade](#animation-cascade)).

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
  continuously. By default the size updates **per screen
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
follows the screen refresh (per-tick); set a lower rate only if
a heavy app falls behind. It caps both directions. No effect
under `"mid_slide"`. Engine-only, not persisted (#47, #593).

**Example:**

```lua
animations.set_size_rate(30)   -- throttle a heavy app
animations.set_size_rate(0)    -- back to per-tick default
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

### Retired Monocle flip verbs

`animations.set_on_monocle_focus` and
`animations.set_monocle_flip_duration` are retired → nothing: a
Monocle focus change brings the window to the front and plays no
flip. A call in `init.lua` is reported in Config Issues; over the
CLI each fails with `…: a Monocle focus change is a raise and
plays no flip`. A saved profile's stored values are dropped on its
next write.

### animations.set_on_expand, animations.set_expand_duration

**Expects:**

- `set_on_expand(bool)` — `true` or `false` (default `true`).
- `set_expand_duration(ms)` — a number (milliseconds: `0`, or
  500–2000; default `750`). `0` snaps the bars into place; a value
  from 1 to 499 becomes 500.

**Does:** the KiwiShelf expand when you switch Spaces: a bar
sharing a shelf grows out of the other bar and shrinks back into
it, a bar on an edge of its own fades in and out, the App Bar's row
dissolves to the new Space's, and the bars glide to their new
places. Off, they move at once. It is not under the
window-animation switches, and it plays with Reduce Motion on too.
Lua-only: no Settings row turns it off; while it is off, KiwiShelf ▸
KiwiShelf ▸ Show ▸ Durations ▸ Expand duration greys and names
`animations.on_expand`.
`animations.set_on_shelf` and `animations.set_shelf_duration` are
retired → these two; a saved profile, look or backup carrying the
old names is renamed on its next read.

**Example:**

```lua
animations.set_expand_duration(1000)
```

### animations.set_reveal_duration

**Expects:** milliseconds: `0`, or 150–800 (default `300`). `0`
shows and hides the bar at once; a value from 1 to 149 becomes
150.

**Does:** how long a hidden bar takes to come in, whichever
[`kiwishelf.set_reveal_style`](#kiwishelfset_reveal_style) it plays;
it goes back out in a little less. It plays with Reduce Motion on
too.

**Example:**

```lua
animations.set_reveal_duration(400)
```

:::unreleased
### animations.set_on_peek

**Expects:** `true` or `false` (default `true`).

**Does:** the bars' peeks: the short fade of what a bar item shows
on hover — a label, or a collapsed Space's list — and a list a
click opens growing out of its item — a bar's "+n", a glyph or App
Bar item standing for several windows, the overflow mark's "+n" —
and back, fading as it retracts. Off, both show and hide at once.
With Reduce Motion on, a list cross-fades in place instead of
growing, unless this is off. Lua-only: no Settings row
turns it off.

**Example:**

```lua
animations.set_on_peek(false)
```
:::

### enable_wake_restore, set_wake_restore_delay

**Expects:**

- `enable_wake_restore(bool)` — `true` or `false`.
- `set_wake_restore_delay(ms)` — a number (milliseconds).

**Does:** when `true`, restores window positions and focus after
the machine wakes from sleep or the screen unlocks, after the
specified delay (default 1500 ms). The restore is skipped when
the screen setup changed while the machine was away (undock,
screen power-off); the screen-change profile resolution wins
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

With a GUI-managed configuration the animations are part of the
look: a profile using the shared look runs the shared look's
`animations.*`, and a profile with its own look keeps its own.
A saved look carries them; a bundled look carries none, so
applying one leaves the animations unchanged.

### Quit & Restart

Quitting KiwiDesk saves the current arrangement — window order
per space, focus, and the active space — and restores it on the
next launch. After the restore, KiwiDesk lands on the space of
the window that has focus *right now*, falling back to the space
that was active at quit. This works within one login session
(macOS window ids reset on logout/reboot; after that, windows
are re-tiled fresh). Crashes restore from the last autosave
(30 s interval) instead.

A restart of the Mac, or a logout, that begins while KiwiDesk is
running is the exception: KiwiDesk keeps the arrangement it had
when the restart began, and the first launch after it matches the
windows macOS reopens to it by app and title instead of by window
id. An app with one window goes back to its space at launch; the
others move into their spaces about 30 seconds later, once their
titles have settled — never the window you are working in, nor
one you moved since launch — and a window that reopens up to two minutes
after launch is still placed. An app's windows that share one
title go back to that app's spaces in no particular order. The
arrangement is used once, by that first launch. A plain Quit
counts the same way when the restart or login that follows it
begins within 10 minutes; later than that, the next launch starts
fresh: quitting lets the arrangement go.

A quit, restart or logout closes a dialog left open in KiwiDesk
as if you had pressed Cancel. If Settings is open with unsaved
edits, the quit stops and asks whether to save them, with
Settings in front: Save (Return) or Discard (⌘D) then quits, and
Cancel (Escape) keeps KiwiDesk running.
Closing the Settings window asks the same, and
Settings never keeps unsaved edits once its window is closed. A
logout, restart or shut down, and a SIGTERM — `kill`, launchd,
`kiwidesk service restart` — cannot wait for an answer and
discard them.

On quit, KiwiDesk moves each managed tiled window
back onto the screen its space is assigned to and arranges them
per `quit.layout` (see `quit.set_layout` below). KiwiDesk keeps
all managed windows on the single visible macOS Desktop (inactive
spaces are parked off-screen at the peek corner, not on a
different Desktop), so every reachable window lands there
together. Windows on a screen's background Desktops cannot be
repositioned without disabling SIP, which KiwiDesk never does —
the visible Desktop per screen is the arranged scope.

Floating windows are arranged too, on every space, shown or not;
a popup or other transient window is left alone. The next launch
puts each one back — in its space, still floating, at the frame
it had before the quit — a window you floated by hand included,
and one whose app reopens it late. A restart of the Mac or a
logout keeps them too, under the rules above. After a crash, a
window you floated by hand comes back without its float, so it
tiles again unless its space is in floating mode; only one that
had not reopened yet since the last quit keeps it.

Two restarts arrange nothing: an update's **Install and
Relaunch**, and `kiwidesk service restart` of a running service
whose new program is signed like the running one. Windows stay
where they are, hidden spaces' windows included, and the new
process picks them up in place — along with the session's
resized splits, weights and scroll positions and the windows you
floated or made sticky by hand; a quit and relaunch start the
sizing and the sticky windows fresh. Every other stop,
`service stop` and an automatic update included, arranges per
`quit.layout`. If the new process never
comes up, the windows stay as a crash leaves them, and the next
launch restores the arrangement.

### quit.set_layout

**Expects:** the string `"grid"`.

**Does:** picks how remaining managed windows are spread on quit.
`grid` builds a per-screen grid and round-robin fills it —
window 1 into cell 1, window 2 into cell 2, wrapping back to
cell 1 and stacking. Windows sharing a cell cascade vertically
like `overflow_all`, in **every** cell, so each title bar stays
reachable. After placing, KiwiDesk raises every window in a
fixed circle — cell 1 through the last cell, each pile top slot
first and deepest slot last — so within a pile every title bar
stays visible and later cells sit above earlier ones (one window
is exempt; see below). It waits for each raise to land before
issuing the next.

The whole restack is capped at one second across every screen.
The cap is a hard stop: once reached, the restack stops after at
most one more raise — it does not carry on through the rest of
the screen it was on, and it does not start a screen it had
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
cell's bottom edge (floored at Floating's `min_window_size`),
keeping piles from spilling into the row below. Each screen sizes its own
grid from its window count `N` and the density target `T` (see
`quit.set_grid_target_depth` below), never past 4×4. One-shot
teardown placement: windows stay on their own screen, and
nothing is managed afterwards. Default: `grid`.

The setting is app-wide: it is stored in `gui.json` as
`quit.layout`, no profile carries it, and loading a profile never
changes it. It has no Settings row while `grid` is its one value.
The upgrade and a Lua-owned setup are as for
[`set_refusal_sound`](#set_refusal_sound), and the verb changes
the running value only, never `gui.json`.

The grid fills before it stacks. Up to six windows each take a
tile, split so the tiles come nearest square on that screen: on
16:9 one window fills it, two sit side by side, three share a
row, four take 2×2, five and six 3×2. When the last row is short,
its last window stretches across the rest — the window you were
last working in, since it is placed last. A portrait screen
mirrors this and fills column by column. Past six windows the
grid is the smallest step of the ladder 3×2 → 4×2 → 4×3 → 4×4
(mirrored on a portrait screen) whose cells hold every window
in piles `T` deep — at the standard 5: up to 30 windows 3×2, up
to 40 4×2, up to 60 4×3, beyond that 4×4. Windows pile only once
they outnumber its cells; until then each still takes a tile.

**Example:**

```lua
quit.set_layout("grid")
```

### quit.set_grid_target_depth

**Expects:** an integer between 1 and 20 (whole windows per cell).

**Does:** sets the quit grid's density target — the stack depth a
cell aims for before the grid grows. Grid dimensions stay
automatic, calculated per screen from that screen's window
count, and never pass 4×4; the target only moves the growth
thresholds. It is not a hard maximum: past 4×4, additional
windows keep cascading in its cells. Default: `5`.

The GUI twin is **General ▸ Windows per pile on quit**. The
setting is app-wide: it is stored in `gui.json` as
`quit.grid_target_depth`, no profile carries it, and loading a
profile never changes it. The upgrade, the verb's reach and a
Lua-owned setup are as for
[`set_refusal_sound`](#set_refusal_sound).

The thresholds sit on the ladder 3×2 → 4×2 → 4×3 → 4×4: 3×2
through `6×T` windows, 4×2 through `8×T`, 4×3 through `12×T`,
4×4 above. Up to six windows tile whatever the target.

**Example:**

```lua
quit.set_grid_target_depth(10)  -- denser piles, later growth
```

When AX permission is revoked mid-session, KiwiDesk pauses
window management but cannot spread windows into the grid —
`setFrame` calls return `kAXErrorAPIDisabled` and are silent no-ops. Windows stay wherever
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

Each window object has: `id`, `app`, `bundle_id`, `title`,
`floating` (boolean).

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

### explain_window

**Expects:** optionally a window id from `get_state`'s `windows`;
the focused window otherwise.

**Does:** returns why the window floats or tiles: `id`, `app`,
`bundle_id`, `space_id`, `mode`, `floating` (its own float flag,
as `get_state` has it), `float`, `app_rule`, `sticky` (`none`,
`global` or `display`), `fullscreen`, `presenting` and `focused`.
`float` holds `floats` (whether it floats, a floating-layout Space
included — for a sticky window, the Space it is drawn on), `cause` (`detection`, `user`, `space_mode` or `nil`) and
`detection` (`reason` — `rule`, `panel`, `accessory_app` or
`fixed_size` — `is_guess`, and `escapes`, what would let it tile:
`set_float_automatically`, `app_rule.remove_float`, or `tile_rule`,
a Tile rule only Settings, Lua or a profile writes). `app_rule`
holds the app's Space rule (`space`), its float rules (`floats`),
whether it has a Tile rule (`tile_rule`) and
`float_automatically`. `space_id`, `mode` and `app_rule` are `nil`
where the window has none. No window title is returned. Any other
id is refused, an away window's included; ask `explain_app`
instead.

:::unreleased
`detection.reason` can also read `raised_layer`: a standard
window that floats because it opened above the normal window
level, such as a picture-in-picture video. Like `panel`, it has
no escapes.
:::

### explain_app

**Expects:** an app's bundle identifier.

**Does:** returns what KiwiDesk knows of the app, for a window
`get_state` does not list: `bundle_id` (lowercased), `ignored`
(`by_rule`, an ignore rule; `built_in`, KiwiDesk's own ignore list; `built_in_raised`, whether
that list ignores the app's raised windows, as it does Ghostty's
quick terminal),
`running` (each process's `pid`, whether KiwiDesk `observed` it,
its `policy` and whether it is `hidden`), `windows` (tracked
ids), `minimized` (ids), `away` (each `id` with its `space_id`)
and `app_rule`, as `explain_window` has it. An app nothing knows
answers empty lists.

### get_config_status

**Expects:** nothing.

**Does:** returns `{issues, sync}`: the Config Issues and the
sync folder's status. Each issue carries its `source` file, a
`kind` with its fields, and the `profile` where one applies:

- `profile_broken`, with a `cause`: `malformed_json`,
  `unexpected_shape`, `unreadable` or `newer_format`.
- `lua_vm_unavailable`.
- `lua_error`, with its `message`.
- `gui_config_unreadable`.
- `newer_format`: `source` is the file a newer KiwiDesk wrote.
- `unknown_call`, with its `name` and a `suggestion`, the verb
  it may have meant, or `nil`.
- `retired_call`, with its `name` and a `replacement`, the verb
  that replaces it, or `nil` where nothing does.
- `missing_font_family`, with its `name`.

:::unreleased
A shortcut whose `symbol` is no SF Symbol is
`unknown_shortcut_symbol`, with its `layer`, `chord` and `symbol`.
A saved shortcut KiwiDesk could not install, so its key does
nothing, is `dead_shortcut`, with its `layer`, `chord` and a
`reason`: `lua_error` with the interpreter's `message`, or
`invalid_chord`.
:::

`sync` carries the followed `folder` (`nil` when none) and a
`status`: `off`, `up_to_date`, `folder_unavailable`,
`changed_on_both`, `conflict_copy` with its `path`, or
`newer_on_another_mac` / `newer_here` with the `file` a newer
KiwiDesk wrote.

### list_windows

**Expects:** optionally a Space id; every tracked window otherwise.
An unknown Space is refused.

**Does:** returns where each window sits, one entry per window, in
Space order: `id` (as `get_state` has it, which keeps the app and
title), `space_id`, `display` (the `list_monitors` id of the screen
it draws on), `shown`, `frame` (`x`, `y`, `width`, `height`),
`visibility`, `floats`, `focused` and `fullscreen`. `visibility` is
`visible`, `hidden`, `partly` (another window covers part of it), or
`partly_left`, `_right`, `_top` or `_bottom` (the screen's edge cuts
it, and that side is still in view). A tile's frame is where its
layout places it; a float's is where KiwiDesk is moving it, else
its last reported frame. No app is asked. Frames are in screen
points from the top-left of the main screen, y growing down. A
window on a Space no screen shows, or parked out of sight, has
`frame` `null`, and `visibility` too where no screen shows it; a
full-screen window has no `visibility`.

`list_monitors` reports each screen's `x` and `y` in the same
coordinates, and `layout_frame`, the area its shown Space lays
windows out in.

:::unreleased
Each entry also carries `app`, `pid`, `index` (the window's
place in its Space's row, from 1; `null` for a window no Space
holds) and `z`: its stacking rank among the windows KiwiDesk
tracks on the screen `display` names, `0` frontmost, as macOS
reports it. A window no screen shows — on a Space no screen shows,
parked out of sight or minimized — has `z` `null`. The list's own
order is the Spaces' rows, not the stacking order: sort by `z` for
that. A window KiwiDesk does not track, such as a menu, counts
toward no rank, though it may cover a window.

`z` and `visibility` can disagree. `visibility` follows the order
KiwiDesk arranged, as the App Bar does, while `z` is the order
macOS shows now: a tile an app raised over its pile by itself
reads `hidden` with `z` `0`. To work out how much of a window is
in view as macOS draws it, compare its `frame` with those of the
windows of lower `z` on its screen.
:::

**Example:**

```lua
for _, w in ipairs(KiwiDesk.list_windows()) do
    if w.focused then
        print(w.frame.x, w.frame.y, w.frame.width, w.frame.height)
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

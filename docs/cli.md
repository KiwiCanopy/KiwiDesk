---
title: CLI & IPC Reference
description: Every command, the event stream, and the raw socket protocol.
---

# CLI & IPC Reference

One binary is both the app and the CLI:

```sh
kiwidesk                      # run the window manager
kiwidesk <command> [args...]  # send a command to the app
kiwidesk help                 # local usage
kiwidesk --version            # local version (no app needed)
kiwidesk list_commands        # every command (app running)
```

> The Homebrew cask puts it on your `PATH` as lower-case
> `kiwidesk`, which is what every example here uses. A source
> build produces `.build/release/KiwiDesk` instead — same
> commands, so substitute that path for `kiwidesk` throughout.
> The capitalized `KiwiDesk` elsewhere on this page is the Lua
> global, the config directory, or the product name — none of
> those change.

Commands are sent over a UNIX domain socket at
`~/.config/KiwiDesk/KiwiDesk.sock`. Exit code is 0 on
success, 1 on error (message on stderr, data on stdout).

## Version

```sh
kiwidesk --version   # or -v; works without the app running
```

Prints `<semantic version> (<short commit>)`, e.g. `0.1.0
(abc1234)`, or just the semantic version when the commit is
unknown (a build made without running
`scripts/bump-version.sh`). The same information is available
over IPC/Lua as the `version` command — see the table below.

## Service Control

```sh
kiwidesk service start     # LaunchAgent: run at login,
                           # restart after crashes
kiwidesk service stop
kiwidesk service restart
kiwidesk service status    # loaded? running? pid?
```

`start` bootstraps the agent when it isn't loaded, and
**relaunches it when the job is loaded but idle** — the state a
quick-menu Quit leaves behind (the app exits cleanly, so
`KeepAlive` doesn't restart it, but the launchd job stays
registered). It no-ops with `KiwiDesk service is already
running` only when a process is actually running. `stop` prints
`KiwiDesk service is not running` cleanly when nothing is
loaded. `restart` boots the job out and back in; when nothing
was loaded it reports `KiwiDesk service was not running —
started it` rather than claiming to have restarted something
that wasn't there. `status` reports the loaded/running state and
the pid.
A real `launchctl` failure exits non-zero; the ordinary
already-running / not-running cases exit 0.

This service is also the top level of the **Start KiwiDesk**
control in Settings ▸ General: *At Login + Restart on Crash* loads
exactly this LaunchAgent, so running `service start` and choosing
that level are equivalent, and `service status` reports the same
state — one live source of truth, no second store. The middle
level, *At Login*, is instead the `SMAppService` login item
(visible in System Settings ▸ Login Items), a separate path that
launches KiwiDesk at login without crash supervision. Both launch
at login; the single-instance lock keeps that to one process, so
they never conflict (see
[Accepted limitations](accepted-limitations.md)). To keep the two
visible to each other, `service status` adds a `login item:` line
reporting the login-item state, and `service start` prints a note
when the login item is *also* on. These strings are the login
item's only appearance in CLI output.

## Commands

| Category | Command | Arguments |
|---|---|---|
| Navigation | `focus` | `left\|right\|up\|down` |
| | `swap` | `left\|right\|up\|down` |
| | `focus_space` | space id |
| | `move_to_space` | space id |
| | `move_to_space_and_follow` | space id |
| | `move_space_to_display` | space id, display index or name |
| | `pin_space_to_display` | space id, display index or name |
| | `create_space` | space id, [mode] |
| | `delete_space` | space id |
| Window | `make_floating` | — |
| | `make_tiled` | — |
| | `make_auto` | — |
| | `toggle_floating` | — |
| | `make_sticky` | — (sticky on every monitor) |
| | `make_display_sticky` | — (sticky on this monitor only) |
| | `make_unsticky` | — |
| | `toggle_sticky` | — |
| | `toggle_display_sticky` | — |
| | `resize` | `x\|y`, delta (px) |
| | `move_to_track` | `prev\|next` — move window to the adjacent track (track spaces) |
| Launch | `pull_or_spawn` | app bundle id (e.g. `com.apple.safari`) |
| | `spawn_new` | app bundle id |
| System | `set_mode` | [space,] mode |
| | `set_mouse_resize` | `layout\|snap_back` |
| | `mouse.set_follows_focus` | true\|false (default `false`) — warp the pointer to the newly-focused window |
| | `set_gap_global` | size |
| | `set_gap_override` | space, size |
| | `set_min_window_size` | pt (default 300) |
| | `set_resize_step` | pt (default 50) — Grow/Shrink magnitude |
| | `set_resize_feedback` | true\|false (default `true`) — alert sound when a resize hotkey can't act |
| | `set_swap_skips_cascade` | true\|false (default `true`) — swap from a pile targets the outside neighbor |
| | `set_float_nudge` | true\|false (default `true`) — shove a window toward center when it toggles to floating |
| | `set_fallback_space` | space id ("" clears) — rehome target on profile switch |
| | `set_space_icon` | space id, icon (SF Symbol\|emoji\|char; "" clears) |
| | `quit.set_layout` | `grid` (default) — how windows are spread on quit |
| | `quit.set_grid_target_depth` | 1–20 (default 5) — quit-grid density target (windows per cell before the grid grows) |
| | `get_state` | — (returns `{active_space, spaces, windows, monitor_count, native_space, exec_running}`) |
| | `reload_config` | — |
| | `version` | — (returns `{version, commit}`) |
| Profiles | `save_profile` | name (updates in place when it exists) |
| | `load_profile` | name |
| | `delete_profile` | name |
| | `set_default_profile` | name (its screen count's fallback) |
| | `list_profiles` | — |
| | `get_profile_status` | — (returns `{name, standard, isDirty}`) |
| | `bind_profile_to_native_space` | desktop number, profile |
| Diagnostics | `get_layout_info` | — |
| | `list_monitors` | — |
| | `debug_log` | message |
| Animation | `animations.set_duration` | ms (50–1000); persisted per-profile |
| | `animations.set_scroll_speed` | ms (50–1000); scroll-layout focus speed, persisted per-profile |
| | `animations.set_on_space_change` | true\|false (default false) |
| | `animations.set_on_scrolling` | true\|false (default true) |
| | `animations.set_on_window_resize` | true\|false (default true) |
| | `animations.set_on_window_swap` | true\|false (default true) |
| | `animations.set_on_relayout` | true\|false (default true) |
| | `set_space_animation` | deprecated alias for `animations.set_on_space_change` |
| | `set_animation_duration` | deprecated alias for `animations.set_duration` |
| | `scroll.set_speed` | deprecated alias for `animations.set_scroll_speed` |
| Sleep/Wake | `enable_wake_restore` | true\|false |
| | `set_wake_restore_delay` | ms |
| Drag | `drag.set_ghost_enabled` | true\|false |
| | `drag.set_ghost_border` / `drag.set_ghost_fill` | true\|false |
| | `drag.set_ghost_border_width` | pt (default 5) |
| | `drag.set_ghost_border_alignment` | `inside\|outside` (default inside) |
| | `drag.set_ghost_border_color` / `drag.set_ghost_fill_color` | #RRGGBB[AA] |
| | `drag.set_drop_zone_enabled` | true\|false |
| | `drag.set_drop_zone_border` / `drag.set_drop_zone_fill` | true\|false |
| | `drag.set_drop_zone_border_width` | pt (default 5) |
| | `drag.set_drop_zone_border_alignment` | `inside\|outside` (default inside) |
| | `drag.set_drop_zone_border_color` / `drag.set_drop_zone_fill_color` | #RRGGBB[AA] |
| | `drag.set_corner_radius` | pt (default 16) |
| Stack | `stack.promote` / `stack.demote` | — |
| | `stack.set_master_count` | n |
| | `stack.set_master_ratio` | 0.1–0.9 |
| | `stack.set_overflow_style` | `cascade_overflow\|cascade_all` |
| | `stack.set_stack_position` | `top\|right\|bottom\|left` (default `right`; derives the stack's lineup) |
| | `stack.set_master_orientation` | `vertical\|horizontal` (default `horizontal`) |
| | `stack.set_new_window_placement` | placement¹ (default `first`) |
| BSP | `bsp.set_strategy` | `longest_side\|alternating` |
| | `bsp.set_ratio_h` | 0.1–0.9 (side-by-side splits) |
| | `bsp.set_ratio_v` | 0.1–0.9 (stacked splits) |
| | `bsp.set_new_window_placement` | placement¹ (default `after_focused`) |
| Scrolling | `scroll.set_slot_size` | px, `"NN%"`, or `0` (auto) |
| | `scroll.set_anchor` | `center\|start\|end\|follow` (default `follow`) |
| | `scroll.set_orientation` | `horizontal\|vertical` |
| | `scroll.set_new_window_placement` | placement¹ (default `after_focused`) |
| | `scroll.set_wrap_focus` | true\|false (default false) |
| Grid | `grid.set_type` | `dynamic\|rigid` |
| | `grid.set_fill_empty_space` | true\|false |
| | `grid.set_split_direction` | `horizontal\|vertical` |
| | `grid.set_dimensions` | columns, rows (upper bound in dynamic) |
| | `grid.set_auto_size` | true\|false (default `false`; dims from screen) |
| | `grid.set_new_window_placement` | placement¹ (default `last`) |
| Monocle | `monocle.set_orientation` | `horizontal\|vertical` |
| | `monocle.set_wrap_focus` | true\|false (default `true` — monocle is a carousel) |
| | `monocle.set_new_window_placement` | placement¹ (default `first`) |
| Track | `track.swap` | `prev\|next` — swap the focused window's whole track with the adjacent one |
| | `track.set_axis` | `vertical\|horizontal` (default vertical = columns) |
| | `track.set_limit` | n (0 = automatic; n>0 pins a cap and turns automatic off) |
| | `track.set_auto_tracks` | true\|false (default `true`) |
| | `track.set_new_window` | `own_track\|focused_track` (default `focused_track`) |
| | `track.set_new_window_position` | placement¹ (default `first`) — where within the new_window choice |
| | `track.set_overflow_style` | `cascade_all\|cascade_overflow` (default `cascade_all` for track) |
| | `track.set_wrap_focus` | true\|false (default false) |
| Spawn | `set_new_window_placement_override` | space id, placement¹ (not track spaces — they follow `track.set_new_window`) |

¹ placement: `first\|last\|before_focused\|after_focused`

The table lists each layout global once. Every layout global
has a per-space `_override` twin (e.g. `bsp.set_ratio_h_override`,
`scroll.set_slot_size_override`) that takes a leading `space id,
value` and shadows the global for that space only.

`resize` adapts to the active layout and is per-axis (#56). A
floating focused window resizes itself directly in any mode
(width for `x`, height for `y`, floored at `min_window_size`).
For tiled windows: in BSP, `x` moves the side-by-side split
ratio and `y` the stacked one, independently, each in the
direction that grows the *focused* window's region (#122).
Stack is focus-aware too (#67) and arrangement-aware (#222):
the split axis (`x` for a left/right stack zone, `y` for
top/bottom) moves the master/stack split in the direction that
grows the *focused* window; the focused zone's own axis grows
that window's share of its zone (session-scoped weights, reset
on relaunch). An axis matching neither fails with the cue — so
a master zone lined up *along* the split axis has no reachable
per-window shares (accepted, see design-decisions). Scrolling resizes
the slot along its own scroll axis for either `x` or `y`. In a
track space the axis across the tracks resizes the focused
window's track, the axis along them its share within the track
(#128; session-scoped weights too). monocle, grid, and floating
reply "not supported" — from a hotkey that failure also plays
the system alert sound (`set_resize_feedback`, default on;
CLI/IPC callers stay silent).

### Applying Ignore Rules

`ignore_rules` is declarative config, not a session command. Edit
`ignore_rules = { "bundle.id" }` in `init.lua`, then
apply it with:

```sh
kiwidesk reload_config
```

For GUI-managed setups, put the array at the root `ignore_rules` key
in `gui.json`, then run `kiwidesk reload_config`. Matching apps
disappear from KiwiDesk state and emit no window events. Removing an
id and reloading makes its windows manageable again.

Those declarations are the global base. A profile JSON may carry a
sparse `ignore_rules` object: `true` adds an id and `null` removes an
inherited one while that profile is active. `load_profile` applies the
resolved rules immediately over either a Lua- or GUI-owned base.

## Event Stream

External tools subscribe over the same socket:

```sh
kiwidesk subscribe                          # all events
kiwidesk subscribe space_change layout_change
```

Each event is one JSON line:

```json
{"event": "space_change",
 "data": {"space_id": "3", "layout_mode": "bsp",
          "window_count": 4}}
```

Events: `space_change`, `layout_change`, `focus_change`,
`monitor_change`, `native_space_change`, `window_created`,
`window_destroyed`, `window_moved_to_space`.

Every window event carries `bundle_id` — the stable identity
key (the one app rules and `pull_or_spawn` match on) — next to
the locale-dependent display `app` name. It is JSON `null` for
unbundled processes; the Lua callback receives it as the
trailing positional argument, `""` when unknown.

`focus_change` data carries `window_id`, `app`, `bundle_id`,
**and** `title` — but the Lua callback receives only
`window_id, app, bundle_id` positionally, so the window title
is available on the socket stream but not to a Lua handler:

```json
{"event": "focus_change",
 "data": {"window_id": 4711, "app": "Ghostty",
          "bundle_id": "com.mitchellh.ghostty",
          "title": "~/src — zsh"}}
```

The window lifecycle events fire even when focus does not
change, so bars can drop stale icons immediately:

```json
{"event": "window_created",
 "data": {"window_id": 4711, "app": "Ghostty",
          "space_id": "2", "reason": "new",
          "bundle_id": "com.mitchellh.ghostty"}}
{"event": "window_destroyed",
 "data": {"window_id": 4711, "app": "Ghostty",
          "space_id": "2", "reason": "closed",
          "bundle_id": "com.mitchellh.ghostty"}}
```

`window_created` carries the space the window was placed in
(`app_rules` included); `window_destroyed` carries the space
the window disappeared from — its own space, even when that
space is not active.

These events track the *visible window set*, not app
lifecycle; the `reason` field says why the set changed:

- `window_created` — `new` (a genuinely new window),
  `returned` (back from another native macOS desktop or a
  session restore), `restored` (deminiaturized).
- `window_destroyed` — `closed` (a real close), `minimized`
  (only minimized; it will come back as `restored`),
  `vanished` (its native desktop was switched away; it
  returns as `returned`).

A native macOS Space switch thus fires a burst of `vanished`
destroys and a burst of `returned` creates — filter on
`reason` to ignore them. Caveat: a window closed *while its
desktop is off-screen* already emitted `vanished` and never
gets a corrective `closed`; consumers that filter `vanished`
must also refresh their state on `native_space_change`.

`window_moved_to_space` fires when a window is explicitly
moved to another virtual space (`move_to_space`,
with or without follow, or a drag onto another display — the
live crossing emits as the membership moves, so a drag pulled
back before release emits once per crossing); bulk
reassignments (profile load, session restore) stay silent:

```json
{"event": "window_moved_to_space",
 "data": {"window_id": 4711, "app": "Spotify",
          "from_space_id": "1", "to_space_id": "3",
          "bundle_id": "com.spotify.client"}}
```

`native_space_change` fires when the user switches native
macOS Spaces (Mission Control desktops); its data carries the
1-based desktop number and the active profile:

```json
{"event": "native_space_change",
 "data": {"native_space": 2, "profile": "Creator Studio"}}
```

## Raw IPC Protocol

Anything that can write to a UNIX socket can drive KiwiDesk —
newline-delimited JSON, one request per line:

```sh
printf '{"command":"set_mode","args":["1","grid"]}\n' \
    | nc -U ~/.config/KiwiDesk/KiwiDesk.sock
```

Response:

```json
{"status": "success"}
{"status": "error", "error": "unknown command: ..."}
```

Unknown commands come back with a did-you-mean suggestion when
a close match exists.

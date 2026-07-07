# CLI & IPC Reference

The `KiwiDesk` binary is both the app and the CLI:

```sh
KiwiDesk                      # run the window manager
KiwiDesk <command> [args...]  # send a command to the app
KiwiDesk help                 # local usage
KiwiDesk --version            # local version (no app needed)
KiwiDesk list_commands        # every command (app running)
```

Commands are sent over a UNIX domain socket at
`~/.config/KiwiDesk/KiwiDesk.sock`. Exit code is 0 on
success, 1 on error (message on stderr, data on stdout).

## Version

```sh
KiwiDesk --version   # or -v; works without the app running
```

Prints `<semantic version> (<short commit>)`, e.g. `0.1.0
(abc1234)`, or just the semantic version when the commit is
unknown (a build made without running
`scripts/bump-version.sh`). The same information is available
over IPC/Lua as the `version` command — see the table below.

## Service Control

```sh
KiwiDesk service start     # LaunchAgent: run at login,
                           # restart after crashes
KiwiDesk service stop
KiwiDesk service restart
```

## Commands

| Category | Command | Arguments |
|---|---|---|
| Navigation | `focus` | `left\|right\|up\|down` |
| | `swap` | `left\|right\|up\|down` |
| | `focus_virtual_space` | space id |
| | `move_to_virtual_space` | space id |
| | `move_to_virtual_space_and_follow` | space id |
| Window | `make_floating` | — |
| | `make_tiled` | — |
| | `resize` | `x\|y`, delta (px) |
| Launch | `pull_or_spawn` | app name |
| | `spawn_new` | app name |
| System | `set_mode` | [space,] mode |
| | `set_mouse_resize` | `layout\|snap_back` |
| | `set_gap_global` | size |
| | `set_gap_override` | space, size |
| | `get_state` | — |
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
| | `drag.set_ghost_border_thickness` | pt (default 5) |
| | `drag.set_ghost_border_alignment` | `inside\|outside` (default inside) |
| | `drag.set_ghost_border_color` / `drag.set_ghost_fill_color` | #RRGGBB[AA] |
| | `drag.set_drop_zone_enabled` | true\|false |
| | `drag.set_drop_zone_border` / `drag.set_drop_zone_fill` | true\|false |
| | `drag.set_drop_zone_border_thickness` | pt (default 5) |
| | `drag.set_drop_zone_border_alignment` | `inside\|outside` (default inside) |
| | `drag.set_drop_zone_border_color` / `drag.set_drop_zone_fill_color` | #RRGGBB[AA] |
| | `drag.set_corner_radius` | pt (default 16) |
| Stack | `stack.promote` / `stack.demote` | — |
| | `stack.set_master_count` | n |
| | `stack.set_master_ratio` | 0.1–0.9 |
| | `stack.set_overflow_style` | `cascade_overflow\|cascade_all` |
| | `stack.set_new_window_placement` | placement¹ (default `first`) |
| BSP | `bsp.set_strategy` | `shortest_side\|alternating` |
| | `bsp.set_ratio` | 0.1–0.9 |
| | `bsp.set_new_window_placement` | placement¹ (default `after_focused`) |
| Scrolling | `scroll.set_slot_size` | px, `"NN%"`, or `0` (auto) |
| | `scroll.set_anchor` | `center`, or edge `left\|right` (`top\|bottom` vertical) |
| | `scroll.set_speed` | ms |
| | `scroll.set_new_window_placement` | placement¹ (default `after_focused`) |
| Grid | `grid.set_type` | `dynamic\|rigid` |
| | `grid.set_fill_empty_space` | true\|false |
| | `grid.set_split_direction` | `horizontal\|vertical` |
| | `grid.set_dimensions` | columns, rows |
| | `grid.set_new_window_placement` | placement¹ (default `last`) |
| Spawn | `set_new_window_placement_override` | space id, placement¹ |

¹ placement: `first\|last\|before_focused\|after_focused`

`resize` adapts to the active layout: BSP adjusts the split
ratio, Stack the master ratio, Scrolling the column width.

## Event Stream

External tools subscribe over the same socket:

```sh
KiwiDesk subscribe                          # all events
KiwiDesk subscribe space_change layout_change
```

Each event is one JSON line:

```json
{"event": "space_change",
 "data": {"space_id": "3", "layout_mode": "bsp",
          "window_count": 4}}
```

Events: `space_change`, `layout_change`, `focus_change`,
`monitor_change`, `native_space_change`, `window_created`,
`window_destroyed`, `window_minimized`,
`window_moved_to_space`.

The window lifecycle events fire even when focus does not
change, so bars can drop stale icons immediately:

```json
{"event": "window_created",
 "data": {"window_id": 4711, "app": "Ghostty",
          "space_id": "2"}}
{"event": "window_destroyed",
 "data": {"window_id": 4711, "app": "Ghostty",
          "space_id": "2"}}
```

`window_created` carries the space the window was placed in
(`app_rules` included); `window_destroyed` and
`window_minimized` carry the space the window disappeared
from — its own space, even when that space is not active. A
minimize fires only `window_minimized`, never
`window_destroyed`.

Caveat: these events track the *visible window set*, not app
lifecycle. Deminiaturize surfaces as `window_created`, and a
native macOS Space switch fires a burst of `window_destroyed`
for the old desktop's windows and `window_created` when they
return.

`window_moved_to_space` fires when a window is explicitly
moved to another virtual space (`move_to_virtual_space`,
with or without follow); bulk reassignments (profile load,
session restore) stay silent:

```json
{"event": "window_moved_to_space",
 "data": {"window_id": 4711, "app": "Spotify",
          "from_space_id": "1", "to_space_id": "3"}}
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

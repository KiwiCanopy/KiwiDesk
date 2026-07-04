# CLI & IPC Reference

The `KiwiDesk` binary is both the app and the CLI:

```sh
KiwiDesk                      # run the window manager
KiwiDesk <command> [args...]  # send a command to the app
KiwiDesk help                 # local usage
KiwiDesk list_commands        # every command (app running)
```

Commands are sent over a UNIX domain socket at
`~/.config/KiwiDesk/KiwiDesk.sock`. Exit code is 0 on
success, 1 on error (message on stderr, data on stdout).

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
| Profiles | `save_profile` | name |
| | `load_profile` | name |
| | `list_profiles` | — |
| | `get_profile_status` | — |
| | `bind_profile_to_native_space` | desktop number, profile |
| Diagnostics | `get_layout_info` | — |
| | `list_monitors` | — |
| | `debug_log` | message |
| Animation | `enable_animations` | true\|false |
| | `set_animation_duration` | ms (50–1000) |
| | `set_space_animation` | true\|false (default false) |
| Sleep/Wake | `enable_wake_restore` | true\|false |
| | `set_wake_restore_delay` | ms |
| Stack | `stack.promote` / `stack.demote` | — |
| | `stack.set_master_count` | n |
| | `stack.set_master_ratio` | 0.1–0.9 |
| | `stack.set_overflow_style` | `cascade_overflow\|cascade_all` |
| | `stack.set_new_window_placement` | placement¹ (default `first`) |
| BSP | `bsp.set_strategy` | `shortest_side\|alternating` |
| | `bsp.set_ratio` | 0.1–0.9 |
| | `bsp.set_new_window_placement` | placement¹ (default `after_focused`) |
| Scrolling | `scroll.set_width` | px |
| | `scroll.set_anchor` | `center\|left\|right` |
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
`monitor_change`, `native_space_change`.

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

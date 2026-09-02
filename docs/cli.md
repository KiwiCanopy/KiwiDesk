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
kiwidesk list_commands        # every command, grouped
kiwidesk help <name>          # one command's arguments
```

> The Homebrew cask puts it on your `PATH` as lower-case
> `kiwidesk`, which is what every example here uses. A source
> build produces `.build/release/KiwiDesk` instead — same
> commands, so substitute that path for `kiwidesk` throughout.
> The capitalized `KiwiDesk` elsewhere on this page is the Lua
> global, the config directory, or the product name — none of
> those change.

**Installed from the `.dmg`?** The app bundle carries the same
executable — the CLI is not a separate program — so all the cask
does is link it onto your `PATH`. Do that once yourself:

```sh
sudo mkdir -p /usr/local/bin
sudo ln -sf /Applications/KiwiDesk.app/Contents/MacOS/KiwiDesk \
  /usr/local/bin/kiwidesk
```

The `mkdir` is not redundant: `/usr/local/bin` does not exist on a
clean macOS that has never had Homebrew — which is exactly this
paragraph's reader — and `ln` fails with *No such file or
directory* without it.

A symlink rather than a copy, deliberately. It resolves through to
whatever is inside the bundle, so the CLI stays the version of the
app you are running after KiwiDesk updates itself. A copy would
not work at all: the executable's signature is sealed to its
bundle and macOS kills it the moment it runs from anywhere else,
and it would no longer find the Sparkle framework it loads from
alongside the app.

Another directory works if you would rather not use `sudo`, as
long as it is one your shell already searches — note that
`~/.local/bin` is **not** on the macOS default `PATH`, so it needs
adding first.

Commands are sent over a UNIX domain socket at
`~/.config/KiwiDesk/KiwiDesk.sock`. Exit code is 0 on
success, 1 on error (message on stderr, data on stdout).

Data on stdout is JSON with its object keys **sorted**, so two
captures of the same response can be diffed. It is indented when
stdout is a terminal and compact — one line — when it is piped or
redirected, which keeps it exactly what a script or `jq` already
expects. `subscribe` is unaffected either way: its stream is
newline-delimited JSON, one event per line, whatever stdout is.

## Version

```sh
kiwidesk --version   # or -v; works without the app running
```

Prints `<semantic version> (<short commit>)`, e.g. `0.1.0
(abc1234)`, or just the semantic version when the commit is
unknown. Only a build produced by the release workflow knows its
own commit — a commit cannot contain its own SHA, so a checked-in
tree cannot name the one it becomes, and any build you make
yourself prints the bare version. The same information is
available over IPC/Lua as the `version` command — see the table
below.

## Discovering Commands

```sh
kiwidesk list_commands              # every command, grouped
kiwidesk help scroll.set_anchor     # one command in full
kiwidesk list_commands --json       # the same, machine-readable
```

Both work **without the app running**. The listing describes the
API the binary was built with — no app state goes into it — and
that binary is the CLI, so nothing is asked over the socket. If
an older KiwiDesk is running while a newer `kiwidesk` is first on
your `PATH`, the listing describes the newer one; they ship as a
single binary, so that is a half-finished install rather than
something to reason about.

`list_commands` prints one block per group: the `KiwiDesk` table
first (the commands a keybinding usually names), then each layout
and bar namespace. Every line carries the command's arguments and
a one-line summary:

```
scroll
  set_anchor <anchor>                Sets where the focused …
  set_orientation <orientation>      Sets whether columns scroll …
  set_slot_size_override <space> <size>   Overrides the slot …
```

Required arguments are in `<angle brackets>`, optional ones in
`[square brackets]`. A command the CLI cannot reach is marked:
`(lua only)` for the entry points that live on the Lua table
alone (`bind`, `on`, `exec`, …), `(cli only)` for `subscribe`.

Naming one command prints its full signature, including the legal
values of an enum argument and the Swift type they come from:

```
$ kiwidesk help scroll.set_anchor
scroll.set_anchor <anchor>

  Sets where the focused window comes to rest in the viewport.

arguments:
  anchor        choice
                  center | start | end | follow
                  (ScrollingParams.Anchor)

  lua: scroll.set_anchor(anchor)
  cli: kiwidesk scroll.set_anchor <anchor>
```

Those values are **read from the decoder that accepts them**, so
the listing cannot fall behind the code — that is the whole point
of keeping this data in `APIReference` rather than in prose.

A misspelled name fails with a suggestion and exit code 1:

```
$ kiwidesk help focsu
error: unknown command: focsu (did you mean focus?)
```

Unlike the did-you-mean hint on an unknown *command*, this one
will point at a Lua-only name: you are looking a name up, not
invoking it.

**Text or JSON.** A terminal gets the text above; a pipe or a
redirect gets JSON. `--json` forces JSON either way. An
unrecognised option is an error, not a silent no-op.

**The JSON shape changed, and nothing preserves the old one.**
`list_commands` used to return a flat array of 262 name strings;
it now returns `{"commands": <count>, "groups": [...]}`, each
group carrying one object per command — `name`,
`qualified_name`, `group`, `command`, `channel`, `summary`,
`aliases`, and an `arguments` array whose enum entries add
`values`. A script that read the old array needs updating; a
command's output is not a stored value, so no compatibility
shape is owed for one.

The Swift type an enum's values were read from is deliberately
**not** a JSON field. It is printed in the terminal rendering,
where it helps a person find the decoder, but publishing it
would make an internal symbol part of this command's output —
and those get renamed freely. `values` is what answers "what may
I send".

Bare `kiwidesk help` (and `--help` / `-h`) still prints the short
usage block. Add a name, or `--json`, to get the API instead.

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
`start` while KiwiDesk is already running loads the agent, whose
`RunAtLoad` spawns one supervised launch; it finds the instance
lock held, brings the running copy forward once — taking focus
from your terminal — and exits cleanly.

**This service is the only way to get crash supervision** (#1071).
Settings offers no switch for it: it is a second launcher, and
running it beside the login item means two mechanisms starting
KiwiDesk at login, which is a thing to understand rather than a
checkbox to tick. Settings ▸ General's **Start at login** is the
`SMAppService` login item (visible in System Settings ▸ Login
Items) and nothing else — it never touches this agent, and this
agent never touches it.

Both launch at login. The single-instance lock keeps that to one
process, so they never fight over your windows — but only the
launch that *wins* is supervised, so running both means
supervision is a coin flip (see
[Accepted limitations](accepted-limitations.md)). Run one: this
service if you want crash restart, the login item if you do not.
While the service is loaded, the Settings switch shows as on and
inert, saying so. To keep the two
visible to each other, `service status` adds a `login item:` line
reporting the login-item state, and `service start` prints a note
when the login item is *also* on — telling you two mechanisms
will start KiwiDesk, and to run one. These strings are the login
item's only appearance in CLI output.

## Exporting the Log

KiwiDesk writes every diagnostic line to the macOS unified log
under its own subsystem, at default level and with the text
public — so the shipped app's log is readable on any Mac with no
debug build and no extra permission. To hand it over with a bug
report, export the last stretch to a file:

```sh
/usr/bin/log show --last 15m \
  --predicate 'subsystem == "com.kiwicanopy.kiwidesk"' \
  --style compact > ~/Desktop/kiwidesk-log.txt
```

Reach back to just before the problem happened — `--last 15m`,
`--last 2h`, or `--start "2026-09-02 09:40:00"` for an exact
window — and attach the file to the issue rather than pasting
fragments. `/usr/bin/log`, spelled out, because a shell alias
named `log` is common. To watch live while reproducing:

```sh
/usr/bin/log stream --predicate 'subsystem == "com.kiwicanopy.kiwidesk"' --style compact
```

The subsystem filter is the right one: filtering on the word
"KiwiDesk" misses the system daemons' lines a report sometimes
needs and catches unrelated apps mentioning the name. (`kiwidesk
debug_log <message>` WRITES a marker line into this same log,
which is useful to bracket a repro; it exports nothing.)

## Commands

| Category | Command | Arguments |
|---|---|---|
| Navigation | `focus` | `left\|right\|up\|down` |
| | `swap` | `left\|right\|up\|down` |
| | `focus_space` | space id |
| | `move_to_space` | space id |
| | `move_to_space_and_follow` | space id |
| | `focus_desktop` | Desktop number (Mission Control's) |
| | `move_to_desktop` | Desktop number — moves the focused window, you stay |
| | `move_to_desktop_and_follow` | Desktop number — moves the focused window, switches there, and leaves keyboard focus on the window |
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
| | `override_sticky_reach` | `on\|off\|auto` — pins the focused sticky window's Desktop reach against `sticky.set_desktop_reach` (`auto` clears the pin) |
| | `resize` | `x\|y`, delta (px) |
| | `move_to_track` | `prev\|next` — move window to the adjacent track (track spaces) |
| Launch | `pull_or_spawn` | app bundle id (e.g. `com.apple.safari`) — a repeat press while its window is focused cycles the app's windows |
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
| | `sticky.set_desktop_reach` | true\|false (default `true`) — sticky windows follow you across macOS Desktops (needs the window-management bridge) |
| | `set_fallback_space` | space id ("" clears) — rehome target on profile switch |
| | `set_space_icon` | space id, icon (SF Symbol\|emoji\|char; "" clears) |
| | `quit.set_layout` | `grid` (default) — how windows are spread on quit |
| | `quit.set_grid_target_depth` | 1–20 (default 5) — quit-grid density target (windows per cell before the grid grows) |
| | `get_state` | — (returns `{active_space, spaces, windows, monitor_count, desktop, exec_running}`; `desktop` is the main screen's current Desktop) |
| | `reload_config` | — |
| | `version` | — (returns `{version, commit}`) |
| Profiles | `save_profile` | name (updates in place when it exists) |
| | `load_profile` | name |
| | `delete_profile` | name |
| | `set_default_profile` | name (its screen count's fallback) |
| | `list_profiles` | — |
| | `get_profile_status` | — (returns `{name, standard, isDirty}`) |
| | `bind_profile_to_desktop` | Desktop number, profile (fires when that Desktop becomes current on the main screen) |
| Diagnostics | `get_layout_info` | — |
| | `list_monitors` | — |
| | `debug_log` | message |
| Animation | `animations.set_duration` | ms (50–1000); persisted per-profile |
| | `animations.set_scroll_duration` | ms (50–1000); scroll-layout focus-shift duration, persisted per-profile |
| | `animations.set_on_space_change` | true\|false (default false) |
| | `animations.set_on_scrolling` | true\|false (default true) |
| | `animations.set_on_window_resize` | true\|false (default true) |
| | `animations.set_on_window_swap` | true\|false (default true) |
| | `animations.set_on_relayout` | true\|false (default true) |
| | `animations.set_size_policy` | smooth (default)\|mid_slide; size policy (#47, #593), Lua-only, not persisted |
| | `animations.set_size_rate` | Hz (1–120; 0 = per-tick default); throttles `smooth` size-sets both directions, Lua-only, not persisted |
| Sleep/Wake | `enable_wake_restore` | true\|false |
| | `set_wake_restore_delay` | ms |
| Drag | `drag.set_ghost_enabled` | true\|false |
| | `drag.set_ghost_border` / `drag.set_ghost_fill` | true\|false |
| | `drag.set_ghost_border_width` | pt (default 5, Lua-only per stroke) |
| | `drag.set_ghost_border_alignment` | `inside\|outside` (default inside, Lua-only) |
| | `drag.set_ghost_border_color` / `drag.set_ghost_fill_color` | #RRGGBB[AA] |
| | `drag.set_drop_zone_enabled` | true\|false |
| | `drag.set_drop_zone_border` / `drag.set_drop_zone_fill` | true\|false |
| | `drag.set_drop_zone_border_width` | pt (default 5, Lua-only per stroke) |
| | `drag.set_drop_zone_border_alignment` | `inside\|outside` (default inside, Lua-only) |
| | `drag.set_drop_zone_border_color` / `drag.set_drop_zone_fill_color` | #RRGGBB[AA] |
| | `drag.set_corner_radius` | pt (default 16, numeric range Lua-only) |
| Stack | `stack.promote` / `stack.demote` | — |
| | `stack.set_master_count` | n |
| | `stack.set_master_ratio` | 0.1–0.9 |
| | `stack.set_overflow_style` | `cascade_overflow\|cascade_all` |
| | `stack.set_stack_position` | `top\|right\|bottom\|left` (default `right`; derives the stack's lineup) |
| | `stack.set_master_orientation` | `vertical\|horizontal` (default `horizontal`) |
| | `stack.set_new_window_placement` | placement¹ (default `first`) |
| BSP | `bsp.set_strategy` | `longest_side\|alternating` (default `alternating`) |
| | `bsp.set_ratio_h` | 0.1–0.9 (side-by-side splits) |
| | `bsp.set_ratio_v` | 0.1–0.9 (stacked splits) |
| | `bsp.set_new_window_placement` | placement¹ (default `after_focused`) |
| Scrolling | `scroll.set_slot_size` | px, `"NN%"`, or `0` (auto) |
| | `scroll.set_anchor` | `center\|start\|end\|follow` (default `follow`) |
| | `scroll.set_orientation` | `horizontal\|vertical` |
| | `scroll.set_new_window_placement` | placement¹ (default `after_focused`) |
| | `scroll.set_wrap_focus` | true\|false (default false) |
| Grid | `grid.set_type` | `dynamic\|rigid` |
| | `grid.set_fill_empty_cells` | true\|false |
| | `grid.set_split_direction` | `horizontal\|vertical` |
| | `grid.set_dimensions` | columns, rows (upper bound in dynamic) |
| | `grid.set_auto_size` | true\|false (default `false`; dims from screen) |
| | `grid.set_new_window_placement` | placement¹ (default `last`) |
| Monocle | `monocle.set_orientation` | `horizontal\|vertical` |
| | `monocle.set_hide_style` | `stack\|park` (default `stack`; park hides unfocused windows at the stash corner) |
| | `monocle.set_wrap_focus` | true\|false (default `false`, matching scrolling/track) |
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
(width for `x`, height for `y`, floored at `min_window_size`),
splitting the delta between both edges and pinning one that is
already against the screen edge or a bar (#1091).
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
`monitor_change`, `desktop_change`, `window_created`,
`window_destroyed`, `window_moved_to_space`.

Give no arguments and you get every event; give arguments and
the filter is honoured exactly. An argument that names no event
is dropped, and the subscription still succeeds — so the
confirmation line lists what was dropped:

```json
{"status": "success", "data": {"unknown": ["space_chnage"]}}
```

A non-string argument appears there as `<non-string>`: it has no
name to report back, but it was dropped just the same. The same
names, truncated after the first few, go to the application log
(viewable in Console.app).

Subscribe to nothing *but* unrecognised names and the stream
stays silent — an empty filter is not the same request as no
filter, and `unknown` says why nothing is arriving.

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
  `returned` (back from another macOS Desktop, from an app
  that was unhidden, or from a session restore), `restored`
  (deminiaturized).
- `window_destroyed` — `closed` (a real close), `minimized`
  (only minimized; it will come back as `restored`),
  `hidden` (its app was hidden, with ⌘H or by hiding itself
  as its last window closed; the window is untouched and
  comes back as `returned`), `vanished` (its macOS Desktop
  was switched away; it returns as `returned`).

A macOS Desktop switch thus fires a burst of `vanished`
destroys and a burst of `returned` creates — filter on
`reason` to ignore them. Caveat: a window closed *while its
Desktop is off-screen* already emitted `vanished` and never
gets a corrective `closed`; consumers that filter `vanished`
must also refresh their state on `desktop_change`.

`window_moved_to_space` fires when a window is explicitly
moved to another space (`move_to_space`,
with or without follow, or a drag onto another display — the
live crossing emits as the membership moves, so a drag pulled
back before release emits once per crossing). A
`move_to_desktop` onto a Desktop that lives on **another
screen** emits it too: the window joins the space that screen
shows, or the layout would carry it back to the screen it left
([#1010](https://github.com/KiwiCanopy/KiwiDesk/issues/1010)).
Bulk reassignments (profile load, session restore) stay silent:

```json
{"event": "window_moved_to_space",
 "data": {"window_id": 4711, "app": "Spotify",
          "from_space_id": "1", "to_space_id": "3",
          "bundle_id": "com.spotify.client"}}
```

`desktop_change` fires when the visible Desktop changes on any
screen — a swipe, Mission Control, or a `focus_desktop` /
`move_to_desktop_and_follow` command; its data carries the 1-based
Desktop number now current on the screen that switched, that
screen's positional number (`monitor`: 1 is the main screen,
secondaries follow left to right — the same 1-based positional
numbering a display argument takes), and the active profile:

```json
{"event": "desktop_change",
 "data": {"desktop": 2, "monitor": 1,
          "profile": "Creator Studio"}}
```

With "Displays have separate Spaces" on, each screen switches
Desktops on its own, so watch `monitor` to tell them apart:
only a switch on the main screen (`monitor: 1`) selects
profiles or moves the active Space — a secondary screen's
swipe reports its Desktop and changes nothing else. With the
option off, or with a single screen, `monitor` is always 1.

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

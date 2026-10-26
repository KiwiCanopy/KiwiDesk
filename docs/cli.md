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
> `kiwidesk`, which every example here uses. A source build
> produces `.build/release/KiwiDesk` instead — same commands, so
> substitute that path for `kiwidesk` throughout. The capitalized
> `KiwiDesk` elsewhere on this page is the Lua global, the config
> directory, or the product name.

**Installed from the `.dmg`?** The app bundle carries the same
executable; the cask only links it onto your `PATH`. Do that once
yourself:

```sh
sudo mkdir -p /usr/local/bin
sudo ln -sf /Applications/KiwiDesk.app/Contents/MacOS/KiwiDesk \
  /usr/local/bin/kiwidesk
```

The `mkdir` is there because `/usr/local/bin` may not exist on a
Mac that has never had Homebrew. Link, never copy: a copy fails
its signature check.

A directory you own works without `sudo` as long as your shell
already searches it; `~/.local/bin` is **not** on the macOS
default `PATH`, so it needs adding first.

Commands are sent over a UNIX domain socket at
`~/Library/Application Support/KiwiDesk/KiwiDesk.sock`.

Exit code is 0 on success, 1 on error; data goes to stdout, the
error message — and, on some successes, a note — to stderr.

Data on stdout is JSON with its object keys **sorted**, indented
when stdout is a terminal and compact — one line — when it is
piped or redirected. `subscribe` is unaffected either way: its
stream is newline-delimited JSON, one event per line, whatever
stdout is.

## Version

```sh
kiwidesk --version   # or -v; works without the app running
```

Prints `<semantic version> (<short commit>)`, e.g. `0.1.0
(abc1234)`, or just the semantic version when the commit is
unknown: only a release build knows its commit, so a build you
make yourself prints the bare version. The same information is
available over IPC/Lua as the `version` command — see the table
below.

## Discovering Commands

```sh
kiwidesk list_commands              # every command, grouped
kiwidesk help scroll.set_anchor     # one command in full
kiwidesk list_commands --json       # the same, machine-readable
```

Both work **without the app running**: the listing describes the
API the binary was built with, carries no app state, and asks
nothing over the socket.

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
alone (`bind`, `on`, `exec`, …), `(cli only)` for the commands
a config never calls, such as `subscribe`.

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
the listing cannot fall behind the code.

A misspelled name fails with a suggestion and exit code 1:

```
$ kiwidesk help focsu
error: unknown command: focsu (did you mean focus?)
```

Unlike the did-you-mean hint on an unknown *command*, this one
will point at a Lua-only name.

**Text or JSON.** A terminal gets the text above; a pipe or a
redirect gets JSON. `--json` forces JSON either way. An
unrecognised option is an error, not a silent no-op.

`list_commands` returns `{"commands": <count>, "groups": [...]}`,
each group carrying one object per command — `name`,
`qualified_name`, `group`, `command`, `channel`, `summary`,
`aliases`, and an `arguments` array whose enum entries add
`values`.

Each command object also carries `destructive`: `true` for a
command that cannot be undone
([Using KiwiDesk from AI Apps](#using-kiwidesk-from-ai-apps)).

:::unreleased
Each command object carries `kind`: `action` for a command that
does something, `setting` for one that changes a value, `query`
for one that only answers. `--kind action`, `--kind setting` or
`--kind query` keeps only that kind, in text or JSON:

```sh
kiwidesk list_commands --kind action
```

`--kind` lists; with a command name it is an error. The
[Actions](commands.md) page lists every action a key can run.
:::

The Swift type an enum's values were read from is **not** a JSON
field; it appears in the terminal rendering only. `values` is
what answers "what may I send".

Bare `kiwidesk help` (and `--help` / `-h`) still prints the short
usage block. Add a name, or `--json`, to get the API instead.

## Shell Completion

`kiwidesk completion zsh`, `bash` or `fish` prints a completion
script. It completes command names, an argument's legal values,
event names, and — while the app runs — Space ids, window ids,
profile names and look names. The script asks the binary for every
answer, so it never needs regenerating after an upgrade.

```sh
# zsh: add to ~/.zshrc, after compinit
source <(kiwidesk completion zsh)
# bash: add to ~/.bash_profile
eval "$(kiwidesk completion bash)"
# fish
kiwidesk completion fish > ~/.config/fish/completions/kiwidesk.fish
```

## Using KiwiDesk from AI Apps

`kiwidesk mcp` runs a [Model Context Protocol](https://modelcontextprotocol.io)
server on stdin and stdout, so an AI app that launches local MCP
servers — Claude Desktop, Claude Code, Cursor, Codex — can drive
KiwiDesk. Point the app at the binary inside the bundle; most apps
take this entry, and one with its own config format takes the same
`command` and `args`:

```json
{
  "mcpServers": {
    "kiwidesk": {
      "command": "/Applications/KiwiDesk.app/Contents/MacOS/KiwiDesk",
      "args": ["mcp"]
    }
  }
}
```

Settings ▸ AI ▸ Other AI apps ▸ **Copy Setup Prompt** puts a short
prompt carrying this entry, with the path of the copy you are
running, on the clipboard: paste it into the AI app, which adds
the server itself or walks you through it. The same page has
ready-made prompts that have the AI app ask you what you want, one
question at a time.

**Add…** in the Claude Desktop row of the same page builds a Claude
Desktop extension for the copy you are running and opens it in Claude
Desktop, which asks you to install it. The extension starts that
copy, so after moving KiwiDesk add it again.

In Claude Code, the KiwiDesk plugin adds the server and a skill
(`/kiwidesk:drive`) on how to change things live and keep them:

```sh
/plugin marketplace add KiwiCanopy/kiwidesk-claude
/plugin install kiwidesk@kiwidesk
```

It finds KiwiDesk in `/Applications`, in `~/Applications` or as
`kiwidesk` on your `PATH`.

The server speaks MCP `2026-07-28` and, after an `initialize`,
`2025-11-25` and `2025-06-18`. It offers eleven tools:

| Tool | Does |
|---|---|
| `list_commands` | Every command the tools can send, filtered by name, group or summary, the destructive ones marked |
| `help` | One command's arguments, as `kiwidesk help <name> --json` returns them |
| `get_state` | `get_state`'s answer |
| `run` | One command that can be undone |
| `run_batch` | Up to 100 commands in order, stopping at the first failure |
| `run_destructive` | One command that cannot be undone |
| `keep` | Makes this session's setting changes permanent |
| `looks` | The `look.*` verbs as one tool: list, inspect, wear and save looks |
| `app_rules` | The `app_rule.*` verbs as one tool: list app rules, and set or remove which Space an app opens in and which windows float |
| `diagnose_window` | Why a window floats, tiles or opens where it does: `explain_window` for a window, `explain_app` for an app whose window KiwiDesk does not manage |
| `kiwivision` | The `kiwivision.*` verbs as one tool: read what KiwiVision shows, turn it or a lens on and off, change its settings, and define or delete a lens |

`list_commands` and `help` answer without the app; the others
need it running. A command `list_commands --json` marks
`destructive` goes only through `run_destructive`, and `run` and
`run_batch` refuse it. `run_destructive` carries MCP's destructive
hint, which an AI app that honours it turns into a question to you
before the command runs. A shortcut verb saves at once, so `run`
tells the AI app to show you the mapping and ask first. `subscribe` and the Lua-only verbs are
not offered.

:::unreleased
The `list_commands` tool also takes `kind` (`action`, `setting` or
`query`), and each row it returns carries its `kind`.
:::

An AI app reads Config Issues and the sync folder's status by
sending `get_config_status` through `run`. When `keep` cannot write
a change because a newer KiwiDesk wrote the file it goes to, it
says so (`newer_format`) instead of reporting a plain failed write.

`looks` takes an `action` — each `look.*` verb that can be undone —
and that verb's arguments by name; `look.delete` goes through
`run_destructive`. The AI page's **Make a new look** prompt offers to
match your wallpaper from a screenshot you give the AI app: KiwiDesk
never reads the wallpaper itself.

`app_rules` takes the same shape over the `app_rule.*` verbs. An app
is named by the `bundle_id` `get_state` lists for its windows.

`diagnose_window` takes exactly one of `window` (an id from
`get_state`'s `windows`) or `app` (a bundle id), and sends
`explain_window` or `explain_app`
([`explain_window`](lua-reference.md#explain_window)); `window` has
no focused-window default here.

`kiwivision` takes an `action`, as `looks` does, over every
`kiwivision.*` verb, `kiwivision.current` among them;
`define_lens` takes `table`, the lens as a JSON object string.
`keep` cannot write a KiwiVision change: Settings ▸ KiwiVision
keeps it, so change the setting, or define or delete the lens,
there.

A setting changed through MCP is live but not kept, and every
command result after the change tells the AI app so, with where
`keep` would write it: the live profile, or the shared look for a
look setting of a profile that wears it — a kept look setting
changes every profile wearing that look, and `keep` names them. An
app rule the live profile does not hold for itself is kept in the
shared rules, which every profile without its own rule for that app
follows, and removing one of those takes it from every profile
holding it; `keep` names every profile whose rule changed.
Say "keep" and `keep` writes those changes as they are now; a
change `init.lua` owns, one made while no saved profile is live, an
app-wide one, or one belonging to a Space that is not in the
profile is named but cannot be kept. A change a Settings Save
stored, or one set back to its saved value, needs no keep. A config
reload, a profile load, a built-in layout's apply or Settings that
puts another value there before the keep replaces it, and the AI
app is told. A command the binary does
not know is refused rather than sent. `get_state` and
`diagnose_window` hand the AI app your window titles.

ChatGPT reaches only remote MCP servers, so it needs
[OpenAI's Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
in front of `kiwidesk mcp`; KiwiDesk itself opens no network port.
With a tunnel created in your OpenAI Platform organization and a
runtime key in `CONTROL_PLANE_API_KEY`, OpenAI's `tunnel-client`
runs the server for it:

```sh
tunnel-client init --sample sample_mcp_stdio_local \
  --profile kiwidesk --tunnel-id <tunnel id> \
  --mcp-command "/Applications/KiwiDesk.app/Contents/MacOS/KiwiDesk mcp"
tunnel-client run --profile kiwidesk
```

Then add a connector in ChatGPT whose connection is that tunnel.

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
quick-menu Quit leaves behind. It no-ops with `KiwiDesk service
is already running` only when a process is actually running. `stop` prints
`KiwiDesk service is not running` cleanly when nothing is
loaded. `restart` boots the job out and back in; when nothing
was loaded it reports `KiwiDesk service was not running —
started it`. `status` reports the loaded/running state and the
pid. A real `launchctl` failure exits non-zero; the ordinary
already-running / not-running cases exit 0. `start` while
KiwiDesk is already running loads the agent, whose `RunAtLoad`
spawns one supervised launch; it finds the instance lock held,
brings the running copy forward once — taking focus from your
terminal — and exits cleanly.

`start` and `restart` refuse a copy opened straight from
Downloads, which macOS runs from a temporary location that
changes each time it starts: move `KiwiDesk.app` to
`/Applications` and run them from there.

`restart` of a running service leaves your windows where they
are: the app is told first, spreads nothing out on its way down,
and the new process picks the windows up in place, sizes
included. It does so only when the program the service will start
is signed like the one running; otherwise, and on `stop`, the
windows are spread out per `quit.layout` as on any quit.

**This service is the only way to get crash supervision** (#1071),
and Settings offers no switch for it. Settings ▸ General's
**Start at login** is the `SMAppService` login item (visible in
System Settings ▸ Login Items) and nothing else — it never
touches this agent, and this agent never touches it.

Both launch at login. The single-instance lock keeps that to one
process, but only the launch that *wins* is supervised, so
running both makes supervision a coin flip (see
[Accepted limitations](accepted-limitations.md)). Run one: this
service if you want crash restart, the login item if you do not.
While the service is loaded, the Settings switch shows as on and
inert, saying so. `service status` adds a `login item:` line
reporting the login-item state, and `service start` prints a note
when the login item is *also* on, saying that two mechanisms will
start KiwiDesk and to run one. These strings are the login item's
only appearance in CLI output.

## Exporting the Log

KiwiDesk writes its diagnostic lines to the macOS unified log
under its own subsystem, at default level and with the text
public, so the shipped app's log is readable on any Mac with no
debug build and no extra permission. To attach it to a bug
report, export the last stretch to a file:

```sh
/usr/bin/log show --last 15m \
  --predicate 'subsystem == "com.kiwicanopy.kiwidesk"' \
  --style compact > ~/Desktop/kiwidesk-log.txt
```

Reach back to just before the problem happened — `--last 15m`,
`--last 2h`, or `--start "2026-09-02 09:40:00"` for an exact
window — and attach the whole file to the issue. Spell out
`/usr/bin/log`: a shell alias named `log` is common. To watch
live while reproducing:

```sh
/usr/bin/log stream --predicate 'subsystem == "com.kiwicanopy.kiwidesk"' --style compact
```

`kiwidesk debug_log [message]` writes a marker line into this
same log — one before and one after a repro brackets it; it
exports nothing.

## Checking the Private Fast Paths

KiwiDesk reaches some of macOS through private WindowServer
calls, each with a public fallback or, where macOS offers none, a
refusal. A new macOS can drop any of them without a crash, so
`self_test` asks the running app which ones still answer:

```sh
kiwidesk self_test          # a table on a terminal
kiwidesk self_test --json   # JSON, as a pipe also gets
```

Each path gets one verdict:

- `works` — it answered, and a second reading agreed.
- `answered` — it answered, and nothing else can read the same
  thing to check it: it is alive, no more.
- `resolved` — it is there, but the check never calls it: it
  writes, or calling it would take something KiwiDesk needs.
- `absent` — macOS no longer has it; the fallback runs.
- `failed` — it is there but answered nothing, or disagreed.
- `inconclusive` — it is there, with nothing to check it against
  (KiwiDesk showing no window, say).

The check only reads: it moves no window, switches no Desktop and
changes no setting. The JSON carries `macos`, a `counts` object by
verdict, and a `probes` array of `name`, `kind` (`symbol` or
`bridge_class`), `home`, `verdict` and `detail`. CLI only — Lua
cannot call it.

:::unreleased
`kind` may also be `objc_method`: a private AppKit method
KiwiDesk answers on its own panels — `_hasActiveAppearance`,
which gives KiwiDesk's glass the bright edge of a focused window
(#2569). Its row reads `answered` while macOS still asks it and
`absent` once it stops, when that glass draws its plain look.
:::

The exit code is 2 when any path `failed`, and 0 otherwise —
`absent`, `resolved` and `inconclusive` are findings, not
failures. 1 still means the command itself did not get through.

## Commands

A `set_*` command other than `set_default_profile` writes no file:
it changes the running value only.
[`save_profile`](lua-reference.md#save_profile-load_profile-delete_profile-set_default_profile)
keeps what it captures, and so does a Settings Save for a setting
the live profile stores; any other value lasts until a profile
load or a config reload sets it again, or until KiwiDesk quits.

`focus_space_previous`, `focus_space_next`, `focus_space_back`,
`focus_space_forward` and `set_space_history` step through the
Spaces by their order and by the ones you visited
([`focus_space_back`](lua-reference.md#focus_space_back--focus_space_forward)).
`set_desktop_cue` turns off the plate a Desktop switch shows
([`set_desktop_cue`](lua-reference.md#set_desktop_cue)).

:::unreleased
`focus_display_last` goes to the screen you were on before, and
`focus_display` takes `left|right|up|down` to the nearest screen
that way, stopping at the edge; neither takes other arguments
([`focus_display_last`](lua-reference.md#focus_display_last--focus_display)).
:::

:::unreleased
`set_space_transition` picks how a Space switch shows itself, and
`set_space_slide_duration` paces the slide
([`set_space_transition`](lua-reference.md#set_space_transition)).
:::

`set_mode_cue` turns off the plate `cycle_mode` shows
([`set_mode_cue`](lua-reference.md#set_mode_cue)).

:::unreleased
`set_modifier_sides` takes `true|false` (default `false`) and
makes a shortcut written with a side, such as `rcmd+h`, keep it
([`set_modifier_sides`](lua-reference.md#set_modifier_sides)).
:::

`take_over_hyper_remap` takes over a Hyper remap another tool
left in place when it is exactly the one KiwiDesk would write for
the chosen key ([`set_hyper_key`](lua-reference.md#set_hyper_key)).
KiwiDesk then removes it when it quits, and an app still listening
for F18 keeps hearing the key. CLI only — Lua cannot call it.

:::unreleased
`export_setup <path>` writes the same backup file as **Export…** in
Settings, replacing a file already at that path, and `restore_setup
<path>` does what **Restore…** does: the same refusals, the replaced
files in the Trash, the reload, and unsaved edits in an open
Settings window dropped
([Backups](user-guide.md#moving-to-another-mac-backups)).
`init.lua` is opt-in on both ends: `--include-init-lua` carries it,
and `--init-lua` replaces this Mac's with the backup's where the
backup carries one; the reply's `init_lua` says what happened. The
`kiwidesk` CLI resolves a relative path against your current
directory; any other caller passes an absolute one. CLI only — Lua
cannot call them.
:::

`get_config_status` returns the Config Issues and the sync
folder's status
([`get_config_status`](lua-reference.md#get_config_status)).

`look.list`, `look.current`, `look.apply <name>`, `look.save
<name>` and `look.delete <name>` reach the look library
([Looks](lua-reference.md#looks)). `look.apply` wears a look
without writing it.

`shortcut.list`, `shortcut.set <chord> <command> [argument…]` and
`shortcut.remove <chord>` read and write the saved shortcuts; a
write saves at once ([Shortcut verbs](lua-reference.md#shortcut-verbs)).

:::unreleased
`shortcut.list_groups` lists the shortcut groups a binding's `group`
can name: the built-in tokens and the groups your shortcuts make
([`shortcut.list_groups`](lua-reference.md#shortcutlist_groups)).
:::

`app_rule.list`, `app_rule.set_space <app> <space>`,
`app_rule.remove_space <app>`, `app_rule.set_float <app> [title]`
and `app_rule.remove_float <app> [title]` change the app rules live
([App rule verbs](lua-reference.md#app-rule-verbs)).

`explain_window [window]` says why a window floats or tiles and
what would change it; `explain_app <bundle_id>` says what KiwiDesk
knows of an app whose window it does not list
([`explain_window`](lua-reference.md#explain_window)).

`list_windows [space]` returns every window's frame, screen and
visibility ([`list_windows`](lua-reference.md#list_windows)), and
`focus_window <window>` focuses one by its id
([`focus_window`](lua-reference.md#focus_window)). Pick one window
with `jq`:

```bash
kiwidesk list_windows | jq '.[] | select(.focused)'
```

`swap <window> [window]` swaps the focused window with the one an
id names, or two named windows, across Spaces and screens too, and
`swap <direction> <window>` swaps a named window with its neighbour
([`swap`](lua-reference.md#swap)); `swap_here <window>` brings
one into your slot instead ([`swap_here`](lua-reference.md#swap_here)).

`kiwivision.toggle [lens]`, `kiwivision.current`, the
`kiwivision.set_*` verbs, `kiwivision.define_lens <table>` and
`kiwivision.delete_lens <name>` reach KiwiVision and its lenses
([KiwiVision](lua-reference.md#kiwivision)). `kiwivision.current`
says whether KiwiVision is on, which lens is on, its settings and
every lens with why it cannot turn on.

| Category | Command | Arguments |
|---|---|---|
| Navigation | `focus` | `left\|right\|up\|down` |
| | `focus_window` | window id |
| | `swap` | `left\|right\|up\|down` |
| | `focus_space` | space id |
| | `focus_space_previous` / `focus_space_next` | — (the focused screen's order; past an end, see `set_focus_wrap`) |
| | `focus_space_back` / `focus_space_forward` | — (the Spaces you visited; see `set_space_history`) |
| | `move_to_space` | space id |
| | `move_to_space_and_follow` | space id |
| | `focus_desktop` | Desktop number (Mission Control's) |
| | `move_to_desktop` | Desktop number, [space id] — moves the focused window there; you stay. `space id` names the Space it lands in |
| | `move_to_desktop_and_follow` | Desktop number, [space id] — moves the focused window there, switches with it and keeps keyboard focus on it. `space id` names the Space it lands in |
| | `move_space_to_display` | space id, display index or name |
| | `pin_space_to_display` | space id, display index or name |
| | `create_space` | space id, [mode] — see [`create_space`](lua-reference.md#create_space) |
| | `delete_space` | space id — see [Deleting a Space](#deleting-a-space) |
| Window | `make_floating` | — |
| | `make_tiled` | — |
| | `toggle_floating` | — |
| | `make_sticky` | — (sticky on every screen) |
| | `make_display_sticky` | — (sticky on this screen only) |
| | `make_unsticky` | — |
| | `toggle_sticky` | — |
| | `toggle_display_sticky` | — |
| | `toggle_maximized` | — the focused tiled window fills its screen, bars hidden, until called again |
| | `pocket` | — pockets the focused window, takes the pocket window out onto this screen, or puts it back ([`pocket`](lua-reference.md#pocket)) |
| | `override_sticky_reach` | `on\|off\|auto` — pins the focused sticky window's Desktop reach against `sticky.set_desktop_reach` (`auto` clears the pin) |
| | `resize` | `x\|y`, delta (px) |
| | `move_to_track` | `prev\|next` — move window to the adjacent track (track spaces) |
| Launch | `focus_or_spawn` | app bundle id (e.g. `com.apple.safari`) — a repeat press while its window is focused cycles the app's windows |
| | `spawn_new` | app bundle id |
| System | `set_mode` | [space,] mode |
| | `set_mouse_resize` | `layout\|snap_back` |
| | `mouse.set_follows_focus` | true\|false (default `false`) — warp the pointer to the newly-focused window |
| | `set_gap_global` | size |
| | `set_gap_override` | space, size |
| | `set_min_window_size` | width[, height][, layout] in pt (default 300 × 300 every layout) |
| | `set_min_window_size_override` | space, width[, height] in pt — that Space's own minimum, whatever its layout |
| | `set_resize_step` | pt (default 50) — Grow/Shrink magnitude |
| | `reset_layout_sizing` | `[space\|all]` returns the active space's ratios, slot size and weights to what the profile set — or one space's, or every space's; structure stays |
| | `set_refusal_sound` | true\|false (default `false`) — add the system alert sound to a blocked action's pill |
| | `set_desktop_cue` | true\|false (default `true`) — the plate naming the Desktop a `focus_desktop` lands on |
| | `set_space_transition` | `slide` (default) \| `show` \| `none` — how an explicit Space switch shows itself: the plate slide, a plate naming the Space, or nothing |
| | `set_space_slide_duration` | ms (150–1000, default 300) — the plate slide's pace |
| | `set_mode_cue` | true\|false (default `true`) — the plate showing the layout a `cycle_mode` lands on |
| | `set_space_history` | `per_screen` (default) \| `all_screens` — whose visits Space back and forward walk |
| | `set_swap_skips_cascade` | true\|false (default `true`) — swap from a pile targets the outside neighbor |
| | `set_float_placement` | `center` (default) \| `keep` — where a window lands when it toggles to floating or moves into a floating Space |
| | `sticky.set_desktop_reach` | true\|false (default `true`) — sticky windows follow you across macOS Desktops (needs the window-management bridge) |
| | `set_fallback_space` | space id ("" clears) — rehome target for the windows of a space that goes |
| | `set_space_icon` | space id, icon (SF Symbol\|emoji\|char; "" clears) |
| | `quit.set_layout` | `grid` (default) — how windows are spread on quit |
| | `quit.set_grid_target_depth` | 1–20 (default 5) — quit-grid density target (windows per cell before the grid grows) |
| | `get_state` | — (returns `{active_space, spaces, windows, away_windows, monitor_count, desktop, exec_running}`; `desktop` is the main screen's current Desktop; `away_windows` lists the windows on Desktops no screen shows, each with `id`, `app`, `bundle_id`, `space_id` and `desktop`, and each space object carries its own `away_windows` ids) |
| | `reload_config` | — |
| | `version` | — (returns `{version, commit}`) |
| Profiles | `save_profile` | name (updates in place when it exists; see [Profile Screen Setups](lua-reference.md#profile-screen-setups)) |
| | `load_profile` | name (see [Profile Screen Setups](lua-reference.md#profile-screen-setups)) |
| | `delete_profile` | name |
| | `set_default_profile` | name (its screen count's fallback) |
| | `list_profiles` | — |
| | `get_profile_status` | — (returns `{name, standard, isDirty}`) |
| | `bind_profile_to_desktop` | Desktop number, profile, screen fingerprints… (optional; scopes the binding to that setup) (fires when that Desktop becomes current on the main screen and the profile is saved for the connected screen count) |
| Diagnostics | `get_layout_info` | — |
| | `list_monitors` | — |
| | `list_windows` | [space] |
| | `debug_log` | [message] |
| Animation | `animations.set_duration` | ms (50–1000) |
| | `animations.set_scroll_duration` | ms (50–1000); scroll-layout focus-shift duration |
| | `animations.set_on_scrolling` | true\|false (default true) |
| | `animations.set_on_window_resize` | true\|false (default true) |
| | `animations.set_on_window_swap` | true\|false (default true) |
| | `animations.set_on_relayout` | true\|false (default true) |
| | `animations.set_on_expand` | true\|false (default true); the KiwiShelf expand on a Space switch |
| | `animations.set_expand_duration` | ms (0 or 500–2000, default 750; 0 snaps); the KiwiShelf expand's length |
| | `animations.set_reveal_duration` | ms (0 or 150–800, default 300; 0 is instant); a hidden bar's reveal |
| | `animations.set_size_policy` | smooth (default)\|mid_slide; size policy (#47, #593), Lua-only, not persisted |
| | `animations.set_size_rate` | Hz (1–120; 0 = per-tick default); throttles `smooth` size-sets both directions, Lua-only, not persisted |
| Scroll gestures | `scroll_gesture.set_pan` | modifiers joined by `+` (default `control+option`; `""` off) — held with a scroll to move focus window by window |
| | `scroll_gesture.set_space_step` | modifiers (default `control+option+command`; `""` off) — held with a scroll to step between the Spaces of the screen under the pointer |
| | `scroll_gesture.set_natural_scrolling` | true\|false, [`trackpad\|mouse`] (default `true` for both) |
| | `scroll_gesture.set_long_swipes` | true\|false (default `false`) |
| | `scroll_gesture.set_step_distance` | pt (10–1000, default 60) — travel per extra window of a long swipe |
| Sleep/Wake | `enable_wake_restore` | true\|false |
| | `set_wake_restore_delay` | ms |
| Drag | `drag.set_ghost_enabled` | true\|false |
| | `drag.set_ghost_border` / `drag.set_ghost_fill` | true\|false |
| | `drag.set_ghost_border_alignment` | `inside\|outside` (default inside, Lua-only) |
| | `drag.set_ghost_border_color` / `drag.set_ghost_fill_color` | #RRGGBB[AA] |
| | `drag.set_drop_zone_enabled` | true\|false |
| | `drag.set_drop_zone_border` / `drag.set_drop_zone_fill` | true\|false |
| | `drag.set_drop_zone_border_alignment` | `inside\|outside` (default inside, Lua-only) |
| | `drag.set_drop_zone_border_color` / `drag.set_drop_zone_fill_color` | #RRGGBB[AA] |
| Stack | `stack.promote` / `stack.demote` | — |
| | `stack.set_master_count` | n |
| | `stack.set_master_ratio` | 0.1–0.9 |
| | `stack.set_stack_position` | `top\|right\|bottom\|left` (default `right`; derives the stack's lineup) |
| | `stack.set_master_orientation` | `vertical\|horizontal` (default `horizontal`) |
| | `stack.set_new_window_placement` | placement¹ (default `first`) |
| | `stack.set_fill_when_alone` | true\|false (default true; off keeps the master zone even alone) |
| BSP | `bsp.set_strategy` | `longest_side\|alternating` (default `alternating`) |
| | `bsp.set_ratio_h` | 0.1–0.9 (side-by-side splits) |
| | `bsp.set_ratio_v` | 0.1–0.9 (stacked splits) |
| | `bsp.set_new_window_placement` | placement¹ (default `after_focused`) |
| Scrolling | `scroll.set_slot_size` | px, `"NN%"`, or `0` (auto) |
| | `scroll.set_anchor` | `center\|start\|end\|follow` (default `follow`) |
| | `scroll.set_orientation` | `horizontal\|vertical` |
| | `scroll.set_new_window_placement` | placement¹ (default `after_focused`) |
| | `scroll.set_fill_when_alone` | true\|false (default true; off keeps the slot size even alone) |
| Grid | `grid.set_type` | `dynamic\|rigid` |
| | `grid.set_fill_empty_cells` | true\|false |
| | `grid.set_split_direction` | `horizontal\|vertical` |
| | `grid.set_dimensions` | columns, rows (an upper bound, capped where a cell falls under `min_window_size`) |
| | `grid.set_auto_size` | true\|false (default `false`; dims from screen) |
| | `grid.set_new_window_placement` | placement¹ (default `last`) |
| Monocle | `monocle.set_orientation` | `horizontal\|vertical` |
| | `monocle.set_hide_style` | `stack\|park` (default `stack`; park hides unfocused windows at the stash corner) |
| | `monocle.set_new_window_placement` | placement¹ (default `first`) |
| Track | `track.swap` | `prev\|next` — swap the focused window's whole track with the adjacent one |
| | `track.set_axis` | `vertical\|horizontal` (default vertical = columns) |
| | `track.set_limit` | n (0 = automatic; n>0 pins a cap and turns automatic off) |
| | `track.set_auto_tracks` | true\|false (default `true`) |
| | `track.set_new_window` | `own_track\|focused_track` (default `focused_track`) |
| | `track.set_new_window_position` | placement¹ (default `first`) — where within the new_window choice |
| Spawn | `set_new_window_placement_override` | space id, placement¹ (not track spaces — they follow `track.set_new_window`) |

:::unreleased
`get_state`'s window objects carry `pocket`: `"pocketed"` or
`"out"` for the [pocket](lua-reference.md#pocket)'s window, `null`
for every other.
:::

:::unreleased
`set_focus_wrap` takes `off`, `this_screen` or `all_screens`
(default `all_screens`): what `focus <direction>` does at the
last window that way in every layout — stop, wrap within the
screen, or continue onto the next screen
([Lua reference](lua-reference.md#set_focus_wrap)). It replaces
`scroll.set_wrap_focus`, `monocle.set_wrap_focus` and
`track.set_wrap_focus`, which now fail naming it. It also decides
whether `focus_space_previous` / `focus_space_next` wrap
([Lua reference](lua-reference.md#focus_space_previous--focus_space_next)).
:::

`set_min_window_size`'s layout is `stack`, `grid`, `track`,
`bsp`, `scrolling` or `floating`, and without one it sets every
layout ([Lua reference](lua-reference.md#set_min_window_size)).
The starter setup seeds every layout from the main screen's
width instead of the 300 × 300 default.
`set_min_window_size_override` gives one Space a value that
replaces its layout's
([Lua reference](lua-reference.md#set_min_window_size_override)).

Grid: `grid.set_column_weight` and `grid.set_row_weight` take a
track number (from 1) and a positive weight, `1` being an equal
share; each has a `_override` sibling taking a space id first
([Lua reference](lua-reference.md#gridset_column_weight)).

:::unreleased
`set_space_cue`, `animations.set_on_space_change` and
`animations.set_space_change` are refused, naming
`set_space_transition`; `animations.set_space_change_duration` is
refused, naming `set_space_slide_duration`; and
`set_space_switch_liquid_glass` is refused, since the Space
slide's plates follow KiwiHub's glass.
:::

:::unreleased
`stack.set_overflow_style`, `track.set_overflow_style` and their
`_override` siblings are refused, since a Stack zone or Track
track scrolls the windows that do not fit
([When windows no longer fit](lua-reference.md#when-windows-no-longer-fit)).
:::

`animations.set_on_monocle_focus` and
`animations.set_monocle_flip_duration` are refused, since a
Monocle focus change is a raise and plays no flip.

`mouse.set_hover_focus` takes `true|false` (default `false`):
focus and raise the window the pointer comes to rest on.
`mouse.set_hover_focus_delay` takes milliseconds, `0` or more
(default `200`): how long the pointer rests first.

`focus_or_spawn` was `pull_or_spawn`; the old name is refused,
naming the new one.

`cycle_mode` (System) takes `prev` or `next` (default) and
moves the focused Space to the next layout in its cycle list;
`set_mode_cycle` sets that list. See
[cycle_mode](lua-reference.md#cycle_mode).

`kiwihub.show` takes `windows`, `shortcuts` or `view` and opens
KiwiHub on that side, so a launcher reaches it without a shortcut;
any other side is refused, naming the three. See
[kiwihub.show](lua-reference.md#kiwihubshow).

:::unreleased
`kiwihub.set_key` takes a built-in KiwiHub key (`up`, `down`,
`page_up`, `page_down`, `left`, `right`) and a combo, and makes the
combo a second key for it while KiwiHub is open; no combo clears it.
See [kiwihub.set_key](lua-reference.md#kiwihubset_key).
:::

`gather` (Launch) takes an app bundle id and moves every window of
that app into the Space you are on, from other macOS Desktops too
where the Desktop bridge is present; it never launches the app, and
an app with nothing to move answers with an error. See
[gather](lua-reference.md#gather).

`move_here` (Launch) takes an app bundle id and optionally a piece
of window title, and moves that app's most recently focused window
not yet here into the Space you are on and focuses it — a
minimized one only once no open one is left; an app with no window
is opened. See [move_here](lua-reference.md#move_here).

`move_to_space`, `move_to_space_and_follow`, `make_floating`,
`make_tiled` and `toggle_floating` take an optional last
argument, a window `id` from `get_state`: they then act on that
window rather than the focused one, and refuse an id no managed
window carries (`kiwidesk make_floating 4711`).

`new_window` and `close_window` take the same optional window
`id`. `new_window` presses that window's app's **File ▸ New
Window**; `close_window` presses the window's close button. Both
reach another app through Accessibility, so `success` means the
press was asked for: an app with no such item, or a window with no
close button, is refused by a pill on screen, not in the reply —
see [Opening and Closing Windows](lua-reference.md#opening-and-closing-windows).

The `scroll_gesture.*` commands set the scroll gestures; see
[Scroll Gestures](lua-reference.md#scroll-gestures).

`animations.set_on_expand` and `animations.set_expand_duration` set
the KiwiShelf expand on a Space switch, and
`animations.set_reveal_duration` a hidden bar's reveal; see
[animations.set_on_expand](lua-reference.md#animationsset_on_expand).
`animations.set_on_shelf` and `animations.set_shelf_duration` are
retired and fail naming their replacements.

:::unreleased
`animations.set_on_peek` (true|false, default true) turns the bars'
peeks instant; see
[animations.set_on_peek](lua-reference.md#animationsset_on_peek).
:::

`make_auto` is retired: it fails with `make_auto was retired —
use make_tiled`, and `make_tiled` does its job. `make_tiled`, and
`toggle_floating` towards tiled, fail on a window that a float
rule, dialog and panel detection or a missing Dock icon floats
([`make_tiled`](lua-reference.md#make_tiled)).

`set_float_placement` replaces `set_float_nudge`: a saved setting
that had the nudge off becomes `keep`, and a call to
`set_float_nudge` fails naming its replacement.

`drag.set_ghost_border_width` and
`drag.set_drop_zone_border_width` fail naming `border.set_width`,
and `drag.set_corner_radius` fails naming
`border.set_corner_style`.

`bind_profile_to_desktop` files one profile per screen count on a
Desktop, for all screen setups: a second profile of another count
adds beside the first, the same count replaces it.

Screen fingerprints after the profile, as `list_monitors` prints
them, scope the binding to that one screen setup ([Lua
reference](lua-reference.md#bind_profile_to_desktop)).

¹ placement: `first\|last\|before_focused\|after_focused`

`reset_layout_sizing` clears what `resize` accumulated on the
active space — or the space named, or every space for `all` —
the session layer and the stack and track weights — so it
lands on what its profile authored (an override's size field
stays; the global only where nothing was authored), and leaves
structure alone
([Lua reference](lua-reference.md#reset_layout_sizing)).

Every layout global has a per-space `_override` twin (e.g.
`bsp.set_ratio_h_override`, `scroll.set_slot_size_override`) that
takes a leading `space id, value` and shadows the global for that
space only.

`resize` adapts to the active layout and is per-axis (#56). A
floating focused window resizes itself directly in any mode
(width for `x`, height for `y`, floored at `min_window_size`),
splitting the delta between both edges and pinning one that is
already against the screen edge or a bar (#1091). "Floating" is
the effective float (#1184): the window's own flag, or any window
in a floating-layout space, which places nothing.

That floor is Floating's `min_window_size` on the axis
resized, whatever layout the window's space uses.

A focused window in native full screen is refused ahead of every layout,
whatever its float state, with `the focused window is
fullscreen` (#1298): nothing is written and no neighbour moves;
the pill and sound rule below apply to it as to the monocle
reply.
For tiled windows: in BSP, `x` moves the side-by-side split
ratio and `y` the stacked one, independently, each in the
direction that grows the *focused* window's region (#122). In
stack (#67, #222), the split axis (`x` for a left/right stack
zone, `y` for top/bottom) moves the master/stack split in the
direction that grows the *focused* window; the focused zone's
own axis grows that window's share of its zone (session-scoped
weights, reset on relaunch). An axis matching neither fails with
the cue, so a master zone lined up *along* the split axis has no
reachable per-window shares (accepted — see
[design decisions](design-decisions.md)). Scrolling resizes the
slot along its own scroll axis for either `x` or `y`. In a track
space the axis across the tracks resizes the focused window's
track, the axis along them its share within the track (#128;
session-scoped weights too). Monocle replies "not supported" —
that failure flashes a pill on the focused window
whatever issued it, and adds the system alert sound when
`set_refusal_sound` is on (default off) and a hotkey was what
fired: a CLI or IPC caller reads the error reply and never hears
one.

In grid (#763), `x` moves the edge the focused cell shares with
the next column (the previous one for the last column) and `y`
the same for rows, writing session-scoped column and row
weights.

### Deleting a Space

`delete_space` succeeds whether or not the removal lasts.

`kiwidesk delete_space 5 profile` also removes the Space from
the live profile's file, and `kiwidesk create_space 7 profile`
adds one there; the scope is the command line's confirmation.
Both refuse a Space `init.lua` or a built-in layout declares,
naming it. A Space made any other way is temporary — see
[`create_space`](lua-reference.md#create_space).

When the space is still declared somewhere, the response says
where:

```json
{"status": "success",
 "data": {"declared_in": ["profile:Work", "init.lua"]}}
```

`declared_in` names every source that re-creates the space on the
next config load — what each means is under
[`delete_space`](lua-reference.md#delete_space) — and is absent
when none does. The JSON goes to stdout as always; the CLI adds
one line per source on stderr, so stdout carries nothing new:

```
removed from the live layout but still in saved profile "Work" — delete it with scope profile to remove it there too
still composed by the built-in "Developer" standard — save a profile to make this durable
still created by init.lua — remove the call that creates it
```

### Applying Ignore Rules

`ignore_rules` is declarative config, not a session command. Edit
`ignore_rules = { "bundle.id" }` in `init.lua`, then
apply it with:

```sh
kiwidesk reload_config
```

For GUI-managed setups, put the array at the root `ignore_rules`
key in `gui.json` and reload the same way. Matching apps
disappear from KiwiDesk state and emit no window events. Removing
an id and reloading makes its windows manageable again.

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
`window_destroyed`, `window_moved_to_space`, `layer_change`.

Give no arguments and you get every event; give arguments and
the filter is honoured exactly. An argument that names no event
is dropped, and the subscription still succeeds — so the
confirmation line lists what was dropped:

```json
{"status": "success", "data": {"unknown": ["space_chnage"]}}
```

A non-string argument is dropped the same way and appears there
as `<non-string>`. The same names, truncated after the first few,
go to the application log (viewable in Console.app).

Subscribe to nothing *but* unrecognised names and the stream
stays silent: an empty filter is not the same request as no
filter.

The stream ends when the app quits. Add `--reconnect` to keep it
across a quit and relaunch: it waits for the app, subscribes again
with the same names, and notes on stderr that events in between
were missed. Each reconnection prints the confirmation line again.

```sh
kiwidesk subscribe --reconnect space_change
```

Every window event carries `bundle_id` — the stable identity
key (the one app rules and `focus_or_spawn` match on) — next to
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
change:

```json
{"event": "window_created",
 "data": {"window_id": 4711, "app": "Ghostty",
          "space_id": "2", "reason": "new",
          "bundle_id": "com.mitchellh.ghostty"}}
{"event": "window_destroyed",
 "data": {"window_id": 4711, "app": "Ghostty",
          "space_id": "2", "reason": "closed",
          "bundle_id": "com.mitchellh.ghostty",
          "desktop": null}}
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
  as its last window closed, and the window comes back as
  `returned` — or KiwiDesk stopped managing a window, an app's
  shadow window it had tracked),
  `vanished` (the window is on a
  macOS Desktop no screen is showing; it returns as
  `returned`). A `vanished` payload also carries `desktop`,
  the Mission Control number of the Desktop holding the
  window, where the Desktop can be read; every other reason —
  and a Mac without SkyLight — sends `null`.

A window re-shown after a `closed` destroy — an app whose close
hides the window and shows the same one again — comes back as
`new` and is placed like one; `returned` is a Desktop return, an
unhide or a session restore.

A macOS Desktop switch thus fires a burst of `vanished`
destroys and a burst of `returned` creates — filter on
`reason` to ignore them. The reason is read off the
WindowServer: a window it still hosts on an unshown Desktop is
`vanished`, one it hosts nowhere is `closed`, whenever the
destroy lands. A window closed *while its Desktop is off-screen*
is reported `closed` when KiwiDesk next reads the Desktops — at
the next Desktop switch, or within about five seconds while any
window is away — so a consumer sees two destroys for that
window, `vanished` then `closed`, and refreshing on
`desktop_change` remains the safe pattern.

`window_moved_to_space` fires when a window is explicitly
moved to another space (`move_to_space`,
with or without follow, or a drag onto another screen — the
live crossing emits as the membership moves, so a drag pulled
back before release emits once per crossing). A
`move_to_desktop` onto a Desktop that lives on **another
screen** emits it too: the window joins the space that screen
shows
([#1010](https://github.com/KiwiCanopy/KiwiDesk/issues/1010)).
`move_to_desktop` with a **named Space** emits it as well when
that Desktop is the one its screen is already showing —
`to_space_id` is the Space you named. When the Desktop is hidden
there is no `window_moved_to_space` at all: the window is
reported `vanished` and comes back with `window_created`,
`reason: returned`, already in the named Space
([#1150](https://github.com/KiwiCanopy/KiwiDesk/issues/1150)).
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
numbering a screen argument takes), and the active profile:

```json
{"event": "desktop_change",
 "data": {"desktop": 2, "monitor": 1,
          "profile": "Creator Studio"}}
```

`desktop_change` fires once KiwiDesk has read the arriving
Desktop's windows, after that switch's `vanished` and `returned`
bursts, so a state query sent on it sees them — save an app slow
to answer, whose windows follow within a few seconds
([#2347](https://github.com/KiwiCanopy/KiwiDesk/issues/2347)).
Switches in quick succession deliver their events in order, after
the last one's windows are read.

With "Displays have separate Spaces" on, each screen switches
Desktops on its own, so watch `monitor` to tell them apart:
only a switch on the main screen (`monitor: 1`) selects a
profile. A secondary screen's swipe reports its Desktop and
moves that screen onto the Space its arriving Desktop should
show — which emits `space_change` too when that screen is the
one holding the active Space. With the
option off, or with a single screen, `monitor` is always 1.

`layer_change` fires when the active keyboard layer changes —
a `switch_layer` call, a config reload returning you to
`default`, a profile switch — and never when a switch names the
layer already active. It carries the previous and the new layer
names, `default` included:

```json
{"event": "layer_change",
 "data": {"from_layer": "default", "to_layer": "resize"}}
```

### Running a Command per Event

`watch` runs a command once per event:

```sh
kiwidesk watch space_change -- sketchybar --trigger kiwi_space
kiwidesk watch -- sh -c 'echo "$KIWIDESK_EVENT" >> ~/events.log'
```

Event names go before `--`, as with `subscribe` (none means every
event), and a name the app does not know is reported on stderr; the
command and its arguments go after it and run without
a shell, so wrap shell syntax in `sh -c`. Each run gets the event's
JSON line on stdin, and these variables:

- `KIWIDESK_EVENT` — the event name.
- `KIWIDESK_DATA` — the event's `data` object as JSON.
- `KIWIDESK_<KEY>` for each top-level string, number or boolean
  in `data`, upper-cased: `KIWIDESK_SPACE_ID`, `KIWIDESK_WINDOW_ID`.

Runs happen one at a time, in event order; events that arrive
during a run wait for it. A command that exits non-zero is reported
on stderr and the watch continues. The watch reconnects across a
relaunch, as `subscribe --reconnect` does, and runs until stopped.

## Raw IPC Protocol

Anything that can write to a UNIX socket can drive KiwiDesk —
newline-delimited JSON, one request per line:

```sh
printf '{"command":"set_mode","args":["1","grid"]}\n' \
    | nc -U ~/Library/Application\ Support/KiwiDesk/KiwiDesk.sock
```

Response:

```json
{"status": "success"}
{"status": "error", "error": "unknown command: ..."}
```

Unknown commands come back with a did-you-mean suggestion when
a close match exists.

A request may add `"report_changes": true` — `kiwidesk mcp` does —
and the response then carries a `changes` object: the live
`profile`, and the setting leaves the command changed under
`touched`, each an `id` (a JSON Pointer such as
`/settings/border/width`, `/space_modes/2` or
`/app_wide/refusal/sound`, `/app_rules/com.spotify.client`), an
`owner` (`profile`, `shared_look`, `shared_rules`, `init_lua` or
`none`), its live `value`, whether that is the
`stored` one, and a `not_keepable` reason where no keep can write
it. Ids sent as `"keep_watch": [...]` come back judged the same way
under `watched`. `keep_settings` writes those ids as they are live
and answers which ones it `kept`, which it could not
(`not_keepable`), the live `profile`, the profiles wearing a kept
shared look (`followers`) and the profiles whose rule a kept rule
changed (`rule_profiles`):

```sh
kiwidesk keep_settings /settings/border/width
```

`revert_settings` is its twin: it puts those ids back to the value
the live profile or its shared look stores, applied live, and
answers which ones it `reverted` and which it could not
(`not_revertable`, each an `id` with its `reason`: `not_a_setting`,
`not_keepable` or `not_applied`). It takes settings leaves only; a Space's
layout and the rules are left as they are live.

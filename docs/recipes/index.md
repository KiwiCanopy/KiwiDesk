---
title: Recipes
description: Integration patterns for KiwiDesk with tools like
  sketchybar, borders, and shell scripts.
---

# Recipes

Real-world integration patterns for KiwiDesk. All recipes use
either Lua event callbacks or the CLI event stream — no plugins
required.

## Integration approaches

**Lua hooks** (in `init.lua`): Subscribe to events within the
KiwiDesk Lua VM and trigger side effects directly. This is the
fastest path: no subprocess overhead, stateless, fire-and-forget.
Use this for tools that accept external command invocation
(sketchybar `--trigger`, borders `active_color=...`).

**CLI event stream** (shell scripts, other processes): Use
`KiwiDesk subscribe <events...>` to receive newline-delimited
JSON from a separate terminal session or script. Query state
on-demand with `KiwiDesk get_state` and `KiwiDesk list_monitors`.
Use this when you need durable polling, cross-process
communication, or your tool runs in a different sandbox (like
Hammerspoon).

## External commands (KiwiDesk.exec)

Commands run asynchronously in the background and never block
window management. They append `/opt/homebrew/bin` and
`/usr/local/bin` to the child's PATH so Homebrew tools resolve.
See the [Lua reference](../lua-reference.md) for the full
`KiwiDesk.exec` and `os.execute` API, including callback,
timeout, and output capture.

> **Binary path note:** KiwiDesk is not yet on PATH. Until
> Homebrew symlinks it at version 1.0, either use the absolute
> path to your built binary (e.g.,
> `~/.build/release/KiwiDesk`) or symlink it yourself. The
> recipes below assume you've stored the path in a variable
> like `KIWIDESK=~/.build/release/KiwiDesk`.

## Recipe pages

- [**SketchyBar**](sketchybar.md) — spaces widget with click
  to focus, window icons, layout-aware styling. The flagship
  integration.
- [**JankyBorders**](jankyborders.md) — layout-aware border
  colors via the `layout_change` event.
- [**Miscellaneous**](misc.md) — shell scripts, event stream
  queries, Hammerspoon, per-desktop keybinds.

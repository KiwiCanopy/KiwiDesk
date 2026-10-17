---
name: drive
description: Change how KiwiDesk tiles and looks through its MCP tools — layouts, Spaces, gaps and borders, the bars, looks, app rules, shortcuts and KiwiVision — or explain why a window floats, tiles or opens where it does. Use when the user asks Claude to set up, change or troubleshoot KiwiDesk.
---

# Driving KiwiDesk

KiwiDesk is a tiling window manager for macOS. Its tools come from
the `kiwidesk` MCP server, which talks to the running app; each
tool's description and each result say the details this skill
leaves out.

## Find before you act

- `get_state` shows the Spaces, their layouts and the windows.
- `list_commands` and `help` name every command the tools can send
  and its arguments. Read `help` before calling a command you have
  not used.
- For "why does this window float / not tile / open there", call
  `diagnose_window` with the window's id (from `get_state`), or with
  the app's bundle id when KiwiDesk does not manage the window. Do
  this before changing a rule.

## Change live, then keep

- `run` and `run_batch` apply changes live; they stay temporary
  until kept, and the results say what is still pending.
- Show the user each change as you make it. Ask **once per task**
  whether to keep the result, not after every command. When the
  user's words already ask for permanence ("from now on",
  "always"), keep straight away.
- `keep` writes the pending changes — all of them, or the ids you
  name — and its result says where each went. Tell the user that,
  and why any change could not be kept.
- `looks` and `app_rules` bundle the common jobs: trying, saving and
  wearing a look; adding and removing app rules.
- `kiwivision` turns KiwiVision and its lenses on and off and
  changes them; its `current` action reads what is on. Its changes
  are app-wide and `keep` cannot write them: point the user at
  Settings ▸ KiwiVision to keep one.

## Ask before anything that cannot be undone

- A command `list_commands` marks `destructive` goes only through
  `run_destructive`. Ask the user first and name what will be lost.
  Never use it to work around a refusal.
- Shortcut commands save at once: show the whole mapping in the
  chat and write only after the user agrees.

## Privacy

`get_state` and `diagnose_window` can show window titles. Use them to
answer the user; do not quote them back beyond what the task needs.

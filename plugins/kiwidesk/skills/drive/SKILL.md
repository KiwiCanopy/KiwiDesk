---
name: drive
description: Change how KiwiDesk tiles and looks through its MCP tools — layouts, Spaces, gaps and borders, the bars, looks, app rules and shortcuts — or explain why a window floats, tiles or opens where it does. Use when the user asks Claude to set up, change or troubleshoot KiwiDesk.
---

# Driving KiwiDesk

KiwiDesk is a tiling window manager for macOS. Its tools come from
the `kiwidesk` MCP server, which talks to the running app.

## Find before you act

- `get_state` shows the Spaces, their layouts and the windows.
- `list_commands` and `help` name every command and its arguments.
  Read `help` before calling a command you have not used.
- For "why does this window float / not tile / open there", call
  `diagnose_window` with the window's id (from `get_state`), or with
  the app's bundle id when the window is not managed. Do this before
  changing a rule.

## Change live, then keep

- `run` and `run_batch` apply changes **live**. They are temporary
  until kept, and each result says how many changes are pending.
- Show the user each change as you make it. Ask **once per task**
  whether to keep the result, not after every command. When the
  user's words already ask for permanence ("from now on", "always"),
  keep straight away.
- `keep` writes exactly the changes this session made into the live
  profile. A change it reports as `not_keepable` stays live only;
  tell the user why.
- `looks` and `app_rules` bundle the common jobs: trying, saving and
  wearing a look; adding and removing app rules.

## Ask before anything that cannot be undone

- `run_destructive` carries commands that delete or overwrite —
  a Space, a profile, a look, a shortcut. Ask the user first and
  name what will be lost. Never use it to work around a refusal.
- Shortcut commands save at once rather than live: show the whole
  mapping in the chat and write only after the user agrees.

## Privacy

`get_state` and `diagnose_window` can show window titles. Use them to
answer the user; do not quote them back beyond what the task needs.

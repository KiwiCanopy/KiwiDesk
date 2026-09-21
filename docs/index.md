---
title: KiwiDesk Documentation
description: A tiling window manager for macOS — docs home.
---

# KiwiDesk Documentation

KiwiDesk is a tiling window manager for macOS. Windows live in
a flat list per space, layouts are pure functions over that
list, and everything is configurable twice over: visually in
the Settings app, or in Lua (`~/.config/KiwiDesk/init.lua`).

## Where to go

- **[User Guide](user-guide.md)** — what the Settings app
  cannot tell you: how settings interact, where things live,
  which profile loads.
- **[Spaces & Desktops](spaces-and-desktops.md)** — how your
  screens, macOS's Desktops, profiles and KiwiDesk's Spaces
  fit together.
- **[Lua Reference](lua-reference.md)** — the complete
  `init.lua` API, every setting in *expects → does → example*
  form.
- **[CLI & IPC](cli.md)** — every command, the event stream,
  and the raw socket protocol.
- **[Recipes](recipes/index.md)** — ready-to-copy integrations:
  [SketchyBar](recipes/sketchybar.md),
  [JankyBorders](recipes/jankyborders.md), and
  [more](recipes/misc.md).

## For contributors

- **[Design Decisions](design-decisions.md)** — the why behind
  settled product and UX behavior.
- **[Settings UI Patterns](ui-patterns.md)** — the shared
  control conventions every Settings surface follows.
- **[Translating](translating.md)** — the localization
  workflow and how to add a language.

## Install

Requirements: macOS 14 or later on Apple silicon.

```sh
brew install --cask kiwicanopy/tap/kiwidesk
```

Or download the signed, notarized `.dmg` from
[kiwidesk.kiwicanopy.com](https://kiwidesk.kiwicanopy.com/) and
drag KiwiDesk into your Applications folder. It is the same app;
the cask additionally puts the `kiwidesk` CLI on your `PATH`,
which [the CLI page](cli.md) shows how to link after a `.dmg`
install. Either way KiwiDesk keeps itself up to date.

The [User Guide](user-guide.md) covers the Starter setup,
**Start at login**, and the Accessibility permission under
[Troubleshooting](user-guide.md#troubleshooting). If windows stop
being managed after an upgrade, re-approve KiwiDesk in **System
Settings › Privacy & Security › Accessibility**.

To build it yourself, `swift build -c release` produces
`.build/release/KiwiDesk`, which takes the same commands.

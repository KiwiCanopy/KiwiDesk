---
title: KiwiDesk Documentation
description: A tiling window manager for macOS — docs home.
---

# KiwiDesk Documentation

KiwiDesk is a tiling window manager for macOS. Windows live in
a flat list per virtual space, layouts are pure functions over
that list, and everything is configurable twice over: visually
in the Settings app, or in Lua (`~/.config/KiwiDesk/init.lua`).

Six layouts ship out of the box — **bsp**, **stack**,
**scrolling** (PaperWM-style), **monocle**, **grid**, and
**floating** — with per-space overrides, profiles that follow
your monitor setup, and native macOS Spaces integration.

## Where to go

- **[User Guide](user-guide.md)** — the Settings app: layouts,
  profiles, shortcuts, monitors, and the visual editor. Start
  here if you configure KiwiDesk through the app.
- **[Lua Reference](lua-reference.md)** — the complete
  `init.lua` API, every setting in *expects → does → example*
  form. Start here if you hand-write your config.
- **[CLI & IPC](cli.md)** — every command, the event stream,
  and the raw socket protocol, for scripts and external tools.
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

## Install (public beta)

KiwiDesk is in public beta and installs through Homebrew:

```sh
brew install --cask kiwicanopy/tap/kiwidesk
```

That installs the app and puts the `kiwidesk` CLI on your
`PATH`; start the background service with `kiwidesk service
start`. The [User Guide](user-guide.md) covers the Accessibility
permission and first-run setup.

Prefer to build it yourself? `swift build -c release` produces
`.build/release/KiwiDesk`, which takes the same commands.

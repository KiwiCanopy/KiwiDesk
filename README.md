<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)"
    srcset="assets/dark_logo_wordmark.png">
  <img src="assets/logo_wordmark.png" alt="KiwiDesk" width="220">
</picture>

### A tiling window manager for macOS

Flat arrays instead of i3 trees · configured in Lua · seven
layouts · never disables SIP.

**Start simple. Grow without limits.** KiwiDesk tiles your windows
the moment you install it — no config required. When you want more,
go deeper: custom Lua, profiles, advanced layouts, per-space rules.
Powerful when you reach for it, never in your way.

<br>

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
[![CI](https://github.com/KiwiCanopy/KiwiDesk/actions/workflows/ci.yml/badge.svg)](https://github.com/KiwiCanopy/KiwiDesk/actions/workflows/ci.yml)
[![License MIT](https://img.shields.io/badge/License-MIT-8DB354)](LICENSE)
[![Homebrew](https://img.shields.io/badge/Homebrew-cask-8DB354)](https://github.com/KiwiCanopy/homebrew-tap)
[![Release](https://img.shields.io/github/v/release/KiwiCanopy/KiwiDesk?color=8DB354&label=Release)](https://github.com/KiwiCanopy/KiwiDesk/releases/latest)
[![Direct download](https://img.shields.io/badge/Direct_download-.dmg-8DB354)](https://kiwidesk.kiwicanopy.com/)

<br>

[![Documentation](https://img.shields.io/badge/📖_Documentation-8DB354?style=for-the-badge)](https://kiwidesk.kiwicanopy.com/docs/)
[![Quick Start](https://img.shields.io/badge/🚀_Quick_Start-627D3A?style=for-the-badge)](https://kiwidesk.kiwicanopy.com/docs/user-guide/)
[![Recipes](https://img.shields.io/badge/🧩_Recipes-AACB5D?style=for-the-badge)](https://kiwidesk.kiwicanopy.com/docs/recipes/)
[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/KiwiCanopy)
[![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-FF5E5B?style=for-the-badge&logo=kofi&logoColor=white)](https://ko-fi.com/kiwicanopy)

</div>

<!-- Add a screenshot or demo GIF here once one is captured. -->
<!-- Add a short demo video here once one is recorded. -->

> **Status: 1.0, released.** The core (layouts, Lua
> config, CLI, profiles, per-Desktop profiles, per-space window
> hiding) and the SwiftUI Settings app are complete and in daily
> use.
> Install it with the Homebrew cask below, or download the
> signed, notarized `.dmg` from
> [kiwidesk.kiwicanopy.com](https://kiwidesk.kiwicanopy.com/) —
> it is the same build either way, and KiwiDesk keeps itself up
> to date from there. That the download waited for a build which
> could update itself is
> [No distribution channel without an update path](https://kiwidesk.kiwicanopy.com/docs/design-decisions/#no-distribution-channel-without-an-update-path).
> KiwiDesk is
> distributed directly and **not** through the Mac App Store —
> see [Distribution](https://kiwidesk.kiwicanopy.com/docs/design-decisions/#distribution-direct-download-not-the-mac-app-store)
> for why.

KiwiDesk is a modular, high-performance tiling window manager for
macOS, written in Swift and configured in Lua. It combines robust
window tracking with smooth, spring-based animations, runs as an
ordinary app with no kernel extension, and **never requires
disabling System Integrity Protection**.

## Why KiwiDesk?

**Flat arrays instead of i3 trees.** Classic tiling window managers
organize windows in split-container trees — powerful, but hard to
predict and hard to script. KiwiDesk keeps every space as a flat,
one-dimensional list of windows. Layouts are pure functions over
that list:

| Layout | Behavior |
|---|---|
| `bsp` | Binary space partitioning (square-ish splits) |
| `stack` | Master zone + stack column (`master_count`) |
| `scrolling` | Niri/PaperWM-style scrolling columns or rows |
| `monocle` | Focused window maximized, rest behind it |
| `grid` | Dynamic (auto-balanced) or rigid rows × columns |
| `track` | Resizable columns (or rows) with per-track control |
| `floating` | macOS default behavior, untouched |

Switching layouts instantly rearranges the same window list with a
different formula — no tree surgery, no lost state.

## Key Features

- **Spaces**: Instant per-space window hiding on top of macOS's own
  Desktops.
- **GUI, CLI & Lua**: SwiftUI Settings app for simple tweaks; CLI &
  sandboxed Lua 5.5 VM for advanced workflows.
- **Modal Layers & Hotkeys**: Vim-style hotkey layers (`define_layer`) and
  smart app switching (`pull_or_spawn`) via Carbon — zero Input Monitoring needed.
- **Cascading Profiles**: Display- or Desktop-bound profiles with inherited
  defaults and sparse overrides.
- **Sticky Windows**: Pin a window so it stays with you across spaces, or
  just across one screen. It carries an on-window mark and a Space Bar
  badge, and where a layout tiles some windows and piles the rest, a
  sticky one keeps a real tile.
- **Visual Overlays & IPC**: Customizable focus rings, App/Space Bar
  overlays, and UNIX socket JSON event streams (`kiwidesk subscribe`).
- **Smooth & Lightweight**: 60/120 Hz DisplayLink spring animations, zero
  SIP modifications, and localized out of the box.
- **Accessible**: The Settings app is built to be driven entirely by
  keyboard and narrates itself fully under VoiceOver — every control
  announces its name *and* its value, areas expose rotor headings, and
  even the keyboard-shortcut preview describes itself in words. Full
  keyboard reach needs macOS's own **Keyboard navigation** setting; the
  [user guide](docs/user-guide.md#using-settings-from-the-keyboard)
  has the details.

## Solving macOS Papercuts

- **No Green-Button Desktop Isolation**: The `monocle` layout maximizes
  windows on the *current space* without kicking you to a far-right Desktop.
- **No `⌘Tab` Black Holes**: `pull_or_spawn` opens the app, pulls its windows front-and-center, or cycles through all open windows of that app on repeated presses.
- **Zero Layout Amnesia**: Moving windows between spaces automatically tiles
  them into the target layout grid instead of forcing manual micro-resizing.
- **Predictable Spatial Memory**: KiwiDesk's spaces stay in fixed,
  predictable slots rather than macOS automatically shuffling your
  Desktops around.

## Installation

Requirements: macOS 14 or later, on Apple silicon.

```sh
brew install --cask kiwicanopy/tap/kiwidesk
```

Or **[download the `.dmg`](https://kiwidesk.kiwicanopy.com/)** and
drag KiwiDesk into your Applications folder. It is the same
signed, notarized app; what the cask adds is a link putting the
`kiwidesk` CLI on your `PATH` — see [the CLI guide](docs/cli.md)
for making that link yourself after a `.dmg` install.

The cask installs the app and puts the `kiwidesk` CLI on your
`PATH`. It ships from this project's own tap
([`KiwiCanopy/homebrew-tap`](https://github.com/KiwiCanopy/homebrew-tap));
the fully-qualified token above taps it for you, so there is no
separate `brew tap` step. The shorter `brew install --cask
kiwidesk` would need acceptance into homebrew-cask itself, which
has not been applied for.

Later builds install themselves. KiwiDesk checks for new releases
in the background and offers you the update, so there is nothing
to run. Upgrade an older copy through Homebrew once to reach a
version that can do this, and it takes over from there — the
[user guide](docs/user-guide.md#the-status-bar-quick-menu) has the
detail.

> Releases are signed with a stable Developer ID and notarized. If
> windows stop being managed after an upgrade, re-approve KiwiDesk
> in **System Settings › Privacy & Security › Accessibility**.

On first launch, an onboarding wizard walks you through granting
the Accessibility permission KiwiDesk needs to manage windows.

KiwiDesk starts at login by default — first-run setup ticks it,
and **Settings ▸ General ▸ Start at login** is the switch. To
have it relaunched after a crash as well, install the LaunchAgent
that does both:

```sh
kiwidesk service start
```

Run one or the other, not both — [the CLI guide](docs/cli.md)
explains why.

### Building from source

For contributors, or to run an unreleased commit. Requirements:
macOS 14+, Xcode 16+ / Swift 6.

```sh
git clone https://github.com/KiwiCanopy/KiwiDesk.git
cd KiwiDesk
swift build -c release
.build/release/KiwiDesk           # run the app
```

## Quick Start

The CLI is the same binary — `kiwidesk` from the cask, or
`.build/release/KiwiDesk` from a source build:

```sh
kiwidesk set_mode monocle        # current space → monocle
kiwidesk focus left              # move focus
kiwidesk set_gap_global 12       # breathing room
kiwidesk help                    # list every command
```

Everyday settings live in the **Settings** app. Prefer Lua?
The config file `~/.config/KiwiDesk/init.lua` is created
all-commented on first launch — see the
[Lua reference](https://kiwidesk.kiwicanopy.com/docs/lua-reference/)
for the full API.

## Documentation

Full docs live at
**[kiwidesk.kiwicanopy.com](https://kiwidesk.kiwicanopy.com/docs/)**
(searchable, light/dark):

- [User guide](https://kiwidesk.kiwicanopy.com/docs/user-guide/) —
  the Settings app, profiles, and the visual editor
- [Lua reference](https://kiwidesk.kiwicanopy.com/docs/lua-reference/) —
  the full init.lua API
- [CLI & IPC reference](https://kiwidesk.kiwicanopy.com/docs/cli/) —
  every command, event stream, socket protocol
- [Recipes](https://kiwidesk.kiwicanopy.com/docs/recipes/) —
  SketchyBar, JankyBorders, and more
- [Design decisions](https://kiwidesk.kiwicanopy.com/docs/design-decisions/) —
  the why behind settled behavior

## Contributing

KiwiDesk is built to be contributor-friendly (including for AI
coding agents — small files, strict lint, exhaustive tests).
See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

```sh
./scripts/install-hooks.sh   # once after cloning
swift test                   # the full suite
```

## Security

KiwiDesk needs only the Accessibility permission. It never asks
you to disable SIP and never requests Input Monitoring. To report
a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE). Bundles Lua 5.5 ([MIT](Vendor/CLua/LICENSE)).

---

KiwiDesk is free and always will be. If it saves you time, a
⭐ on this repo is the one thing that helps other people find it.

<div align="center">
<br>
<sub>A <a href="https://kiwicanopy.com"><strong>KiwiCanopy</strong></a> project — Because our time
is precious 🥝</sub>
</div>

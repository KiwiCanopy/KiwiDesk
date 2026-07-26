<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)"
    srcset="assets/dark_logo_wordmark.png">
  <img src="assets/logo_wordmark.png" alt="KiwiDesk" width="220">
</picture>

### A tiling window manager for macOS

Flat arrays instead of i3 trees · configured in Lua · six
layouts · never disables SIP.

**Start simple. Grow without limits.** KiwiDesk tiles your windows
the moment you install it — no config required. When you want more,
go deeper: custom Lua, profiles, advanced layouts, per-space rules.
Powerful when you reach for it, never in your way.

<br>

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
[![CI](https://github.com/KiwiCanopy/KiwiDesk/actions/workflows/ci.yml/badge.svg)](https://github.com/KiwiCanopy/KiwiDesk/actions/workflows/ci.yml)
![License MIT](https://img.shields.io/badge/License-MIT-8DB354)
![Public beta](https://img.shields.io/badge/Public_beta-Homebrew-8DB354)
![App Store — later](https://img.shields.io/badge/App_Store-after_the_beta-8B5E3C)

<br>

[![Documentation](https://img.shields.io/badge/📖_Documentation-8DB354?style=for-the-badge)](https://kiwidesk.pages.dev/docs/)
[![Quick Start](https://img.shields.io/badge/🚀_Quick_Start-627D3A?style=for-the-badge)](https://kiwidesk.pages.dev/docs/user-guide/)
[![Recipes](https://img.shields.io/badge/🧩_Recipes-AACB5D?style=for-the-badge)](https://kiwidesk.pages.dev/docs/recipes/)
[![Support on Ko-fi](https://img.shields.io/badge/Support-FF5E5B?style=for-the-badge&logo=kofi&logoColor=white)](https://ko-fi.com/kiwicanopy)

</div>

<!-- Add a screenshot or demo GIF here once one is captured. -->

> **Status: public beta, on Homebrew.** The core (layouts, Lua
> config, CLI, profiles, per-native-space profiles, virtual
> workspace hiding) and the SwiftUI Settings app are functional.
> Install it with the Homebrew cask below; a packaged `.dmg` and
> the macOS App Store build follow once the beta has settled.

KiwiDesk is a modular, high-performance tiling window manager for
macOS, written in Swift and configured in Lua. It combines robust
window tracking with smooth, spring-based animations, runs
entirely in user-space, and **never requires disabling System
Integrity Protection**.

## Why KiwiDesk?

**Flat arrays instead of i3 trees.** Classic tiling window
managers organize windows in split-container trees — powerful,
but hard to predict and hard to script. KiwiDesk keeps every
space as a flat, one-dimensional list of windows. Layouts are
pure functions over that list:

| Layout | Behavior |
|---|---|
| `bsp` | Binary space partitioning (square-ish splits) |
| `stack` | Master zone + stack column (`master_count`) |
| `scrolling` | Niri/PaperWM-style horizontal columns |
| `monocle` | Focused window maximized, rest behind it |
| `grid` | Dynamic (auto-balanced) or rigid rows × columns |
| `floating` | macOS default behavior, untouched |

Switching layouts instantly rearranges the same window list with
a different formula — no tree surgery, no lost state.

**More highlights:**

- **Smooth spring animations**, one display link per monitor, so
  mixed 60 Hz / 120 Hz setups each animate at native cadence.
- **Lua configuration** (`~/.config/KiwiDesk/init.lua`) with a
  sandboxed Lua 5.5 VM — a broken config can never freeze your
  windows (500 ms timeout, faulty callbacks auto-disabled).
- **CLI + UNIX socket IPC**: script everything, stream events to
  SketchyBar, JankyBorders, or your own tools.
- **Modal keybindings** via the Carbon API — no Input Monitoring
  (keylogger) permission needed.
- **Profiles that follow your displays**: save a layout per
  monitor arrangement and it loads automatically when you connect
  those screens — with per-native-Space bindings on top.
- **Crash recovery** and **sleep/wake restore** keep your window
  arrangement across restarts and lid cycles.

## Installation

Requirements: macOS 14 or later.

```sh
brew install --cask kiwicanopy/tap/kiwidesk
```

The cask installs the app and puts the `kiwidesk` CLI on your
`PATH`. It ships from this project's own tap
([`KiwiCanopy/homebrew-tap`](https://github.com/KiwiCanopy/homebrew-tap));
the fully-qualified token above taps it for you, so there is no
separate `brew tap` step. The shorter `brew install --cask
kiwidesk` would need acceptance into homebrew-cask itself, which
is a post-beta step.

Later builds arrive the same way:

```sh
brew upgrade --cask kiwidesk
```

> Until KiwiDesk ships a signed `.app` (#89), each upgrade changes
> the binary and macOS drops its Accessibility grant — re-approve
> it in **System Settings › Privacy & Security › Accessibility**
> if windows stop being managed after an upgrade.

On first launch, an onboarding wizard walks you through granting
the Accessibility permission KiwiDesk needs to manage windows.

To start KiwiDesk automatically at login:

```sh
kiwidesk service start
```

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
kiwidesk set_mode monocle        # current space -> monocle
kiwidesk set_mode 2 stack        # space "2" -> master/stack
kiwidesk focus left              # move focus
kiwidesk set_gap_global 12       # breathing room
kiwidesk get_state               # inspect everything as JSON
kiwidesk help                    # list every command
```

Everyday settings live in the **Settings** app — see the
[user guide](docs/user-guide.md). Prefer Lua? The config file
`~/.config/KiwiDesk/init.lua` is created **all-commented** on
first launch (the built-in defaults apply until you uncomment a
line); it's for optional custom config and event hooks:

```lua
KiwiDesk.set_gap_global(10)

-- Layouts are per SPACE (virtual workspace, number or name);
-- every space defaults to "bsp".
KiwiDesk.set_mode("music", "floating")

float_rules = { "Calculator", "Finder:Get Info" }
app_rules   = { ["Spotify"] = "music" }

KiwiDesk.bind("cmd+alt+left", function()
    KiwiDesk.focus("left")
end)
```

## Documentation

Full docs live at **[kiwidesk.pages.dev](https://kiwidesk.pages.dev)**
(searchable, light/dark). The same pages are readable here on
GitHub:

- [User guide](docs/user-guide.md) — the Settings app, profiles,
  and the visual editor
- [Lua reference](docs/lua-reference.md) — the full init.lua API,
  every setting in expects → does → example form
- [CLI reference](docs/cli.md) — every command, IPC protocol,
  event stream
- [Recipes](docs/recipes/index.md) — SketchyBar, JankyBorders,
  and other ready-to-copy integrations
- [Design decisions](docs/design-decisions.md) — the why behind
  settled product and UX behavior

## Contributing

KiwiDesk is built to be contributor-friendly (including for AI
coding agents — small files, strict lint, exhaustive tests).
See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

```sh
./scripts/install-hooks.sh   # once after cloning
swift test                   # 700+ tests and counting
```

## Security

KiwiDesk needs only the Accessibility permission. It never asks
you to disable SIP and never requests Input Monitoring. To report
a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE). Bundles Lua 5.5 ([MIT](Vendor/CLua/LICENSE)).

<div align="center">
<br>
<sub>A <strong>KiwiCanopy</strong> project — Planting Kiwis for a
richer world 🥝🥝🥝</sub>
</div>

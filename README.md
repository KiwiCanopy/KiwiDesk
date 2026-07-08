# KiwiDesk 🥝

A modular, high-performance tiling window manager for macOS,
written in Swift and configured in Lua.

KiwiDesk combines robust window tracking with smooth,
spring-based animations. It runs entirely in user-space and
**never requires disabling System Integrity Protection**.

> **Status: CLI beta.** The core (layouts, Lua config, CLI,
> profiles, per-native-space profiles, virtual workspace
> hiding) is functional; the SwiftUI settings GUI and packaged
> releases are still in progress.

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
- **Profiles with monitor fingerprints**: plug in your office
  display and the matching profile loads automatically.
- **Crash recovery** and **sleep/wake restore** keep your window
  arrangement across restarts and lid cycles.

## Installation

Beta: build from source (packaged `.dmg` and a Homebrew cask
come with the 1.0 release).

Requirements: macOS 14+, Xcode 16+ / Swift 6.

```sh
git clone https://github.com/hajiboy95/KiwiDesk.git
cd KiwiDesk
swift build -c release
.build/release/KiwiDesk           # run the app
```

On first launch, an onboarding wizard walks you through granting
the Accessibility permission KiwiDesk needs to manage windows.

To start KiwiDesk automatically at login:

```sh
.build/release/KiwiDesk service start
```

## Quick Start

The CLI is the same binary:

```sh
KiwiDesk set_mode monocle        # current space -> monocle
KiwiDesk set_mode 2 stack        # space "2" -> master/stack
KiwiDesk focus left              # move focus
KiwiDesk set_gap_global 12       # breathing room
KiwiDesk get_state               # inspect everything as JSON
KiwiDesk help                    # list every command
```

Configuration lives in `~/.config/KiwiDesk/init.lua` (created on
first launch):

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

- [Configuration guide](docs/configuration.md) — the full
  init.lua reference
- [CLI reference](docs/cli.md) — every command, IPC protocol,
  event stream
- [Integrations](docs/integrations.md) — SketchyBar and
  JankyBorders recipes
- [Design decisions](docs/design-decisions.md) — why the
  Settings app behaves the way it does

## Contributing

KiwiDesk is built to be contributor-friendly (including for AI
coding agents — small files, strict lint, exhaustive tests).
See [CONTRIBUTING.md](CONTRIBUTING.md) and
[AGENTS.md](AGENTS.md).

```sh
./scripts/install-hooks.sh   # once after cloning
swift test                   # 114 tests and counting
```

## Security

KiwiDesk needs only the Accessibility permission. It never asks
you to disable SIP and never requests Input Monitoring. To
report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE). Bundles Lua 5.5
([MIT](Vendor/CLua/LICENSE)).

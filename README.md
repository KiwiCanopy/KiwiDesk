<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)"
    srcset="assets/dark_logo_wordmark.png">
  <img src="assets/logo_wordmark.png" alt="KiwiDesk" width="220">
</picture>

### Tiling that feels like it shipped with macOS.

**Start simple. Grow without limits.** KiwiDesk tiles your windows
the moment you install it — no config required. When you want more,
go deeper: custom Lua, profiles, advanced layouts, per-space rules.
Powerful when you reach for it, never in your way.

<br>

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
[![CI](https://github.com/KiwiCanopy/KiwiDesk/actions/workflows/ci.yml/badge.svg)](https://github.com/KiwiCanopy/KiwiDesk/actions/workflows/ci.yml)
[![License BSL 1.1](https://img.shields.io/badge/License-BSL_1.1-8DB354)](LICENSE)
[![Homebrew](https://img.shields.io/badge/Homebrew-cask-8DB354)](https://github.com/KiwiCanopy/homebrew-tap)
[![Release](https://img.shields.io/github/v/release/KiwiCanopy/KiwiDesk?color=8DB354&label=Release)](https://github.com/KiwiCanopy/KiwiDesk/releases/latest)

[Website](https://kiwidesk.kiwicanopy.com/) ·
[Docs](https://kiwidesk.kiwicanopy.com/docs/) ·
[Quick Start](https://kiwidesk.kiwicanopy.com/docs/user-guide/) ·
[Recipes](https://kiwidesk.kiwicanopy.com/docs/recipes/) ·
[Changelog](https://kiwidesk.kiwicanopy.com/changelog/) ·
[Sponsor](https://github.com/sponsors/KiwiCanopy)

<br>

<img src="assets/demo-scrolling.gif" width="800"
  alt="Windows gliding sideways through the scrolling layout as focus moves between them">

</div>

## Why KiwiDesk?

I love tiling window managers, but I could never recommend one to a
friend who doesn't live in a terminal. On the Mac they all want a
config file first; they feel like a nerd's toy. KiwiDesk is the one I
can hand over: it tiles your windows the moment it starts, everything
is a slider or a switch in a real Settings window, and going deeper
feels like learning a feature rather than hacking a file. When you do
want the file, it is there: Lua config, a CLI and a socket, the whole
nerd's toy underneath.

It is also built to survive macOS updates. Every private Apple API
has a public fallback, and the two things only Apple's own bridge can
do switch themselves off after an update instead of breaking.

[How it compares with yabai, AeroSpace and the rest →](https://kiwidesk.kiwicanopy.com/compare/)

## Installation

Requirements: macOS 14 or later, on Apple silicon.

```sh
brew install --cask kiwicanopy/tap/kiwidesk
```

Or **[download the `.dmg`](https://kiwidesk.kiwicanopy.com/)** — the
same signed, notarized app; the cask additionally puts the `kiwidesk`
CLI on your `PATH`. Either way KiwiDesk keeps itself up to date.

On first launch a wizard walks you through the Accessibility
permission, then tiles your windows straight away. Everything past
that — Settings, the CLI, Lua — is in the
**[Quick Start](https://kiwidesk.kiwicanopy.com/docs/user-guide/)**.

### Building from source

For contributors, or to run an unreleased commit. Requirements:
macOS 14+, Xcode 16+ / Swift 6.

```sh
git clone https://github.com/KiwiCanopy/KiwiDesk.git
cd KiwiDesk
swift build -c release
.build/release/KiwiDesk           # run the app
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) —
small files, strict lint, exhaustive tests, AI coding agents welcome.
To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[Business Source License 1.1](LICENSE): the source is public, and
using KiwiDesk is free — at home and at work. Offering, selling,
bundling or hosting it as a product or service needs a commercial
license. Each version converts to the
[MIT License](https://opensource.org/license/mit) four years after it
is first published.

---

KiwiDesk's source is public. If you like it, leave a ⭐ — it is the
one thing that helps other people find it.

<div align="center">
<br>
<sub>A <a href="https://kiwicanopy.com"><strong>KiwiCanopy</strong></a> project — Because our time
is precious 🥝</sub>
</div>

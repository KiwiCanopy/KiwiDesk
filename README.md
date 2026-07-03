# KiwiDesk

A modular, high-performance tiling window manager for macOS,
written in Swift.

KiwiDesk combines robust multi-monitor window tracking with smooth,
spring-based animations — configured through a dynamic Lua scripting
system and an intuitive SwiftUI GUI. It runs entirely in user-space
and **does not require disabling SIP**.

> **Status:** Early development (pre-alpha). Not yet usable.

## Core Ideas

- **Flat arrays instead of i3 trees.** Each space manages its windows
  as a simple one-dimensional list. Layouts (BSP, Stack, Scrolling,
  Monocle, Grid, Floating) are pure functions over that list — easy
  to reason about, easy to test, and easy to extend with your own
  Lua layouts.
- **Smooth animations without SIP hacks.** Private SkyLight APIs are
  used where available, with a transparent fallback to the public
  Accessibility API.
- **Simple for beginners, full control for power users.** Shipped
  presets and a SwiftUI settings GUI on top of a single `init.lua`
  source of truth, with a built-in code editor for custom logic.

## Building from Source

Requirements: macOS 14+, Xcode 16+ / Swift 6.

```sh
swift build
swift test
```

KiwiDesk needs Accessibility permission to manage windows. On first
launch, an onboarding wizard guides you through granting it.

## Development

- Read [`AGENTS.md`](AGENTS.md) for code style, file size limits,
  and workflow rules (they apply to humans and AI agents alike).
- Install the git hooks once after cloning:

```sh
./scripts/install-hooks.sh
```

## License

[MIT](LICENSE)

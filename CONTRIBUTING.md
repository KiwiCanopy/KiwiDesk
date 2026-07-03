# Contributing to KiwiDesk

Thanks for helping! KiwiDesk is designed so that both humans
and AI coding agents can contribute safely: small focused
files, strict linting, and a heavily unit-tested core.

## Getting Started

```sh
git clone https://github.com/hajiboy95/KiwiDesk.git
cd KiwiDesk
./scripts/install-hooks.sh   # pre-commit lint hook
swift build
swift test
```

Requirements: macOS 14+, Xcode 16+ (Swift 6).

## Ground Rules

The binding style and workflow rules live in
[AGENTS.md](AGENTS.md). The short version:

- **File size:** aim for 100–250 lines per Swift file; the
  pre-commit hook errors above 350.
- **Line length:** 79 characters, enforced by `swift format`
  and `scripts/lint.sh`.
- **One responsibility per type.** Layout math stays pure and
  testable; AppKit/AX code stays at the edges.
- **Every layout/state change needs tests.** Pure logic
  (layouts, state, parsing) must be covered; AX/GUI glue is
  exempt where CI cannot exercise it.
- Run `swift build && swift test && ./scripts/lint.sh` before
  pushing — CI enforces all three and blocks merging on red.

## Pull Requests

1. Fork and branch from `main`.
2. Keep PRs focused; separate refactors from features.
3. Include tests for new behavior and update the docs
   (`docs/`, README) when you change user-facing behavior.
4. Make sure CI is green.

## Bug Reports

Please include:

- macOS version and Mac model (Apple Silicon / Intel).
- KiwiDesk version or commit hash.
- Steps to reproduce, expected vs. actual behavior.
- Relevant output: `KiwiDesk get_state`,
  `KiwiDesk get_layout_info`, and log lines (KiwiDesk logs to
  the system log; filter for "KiwiDesk").
- Whether other window managers / AX tools were running —
  they often interact.

## Feature Requests

Open an issue describing the use case (not just the feature).
Check the roadmap in the README status note first — the GUI,
per-native-space profiles, and drag-and-drop are already
planned.

## Vulnerability Reports

Not in the issue tracker, please — see
[SECURITY.md](SECURITY.md).

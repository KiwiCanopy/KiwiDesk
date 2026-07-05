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

## Branching & Pull Requests

**Branch naming:** follow Conventional Commit types with kebab-case
descriptions. Examples:
- `feat/scrolling-snap-mode` — new feature
- `fix/z-order-on-monitor-change` — bug fix
- `refactor/layout-math` — code restructure (no behavior change)
- `docs/update-cli-guide` — documentation
- `test/animation-timing` — new tests
- `chore/upgrade-lua` — build/maintenance

Branch from `main` and keep one focused change per branch. Separate
refactors from features (review them independently).

**Pull request process:**
1. Fill in the PR template (checklist of tests, docs,
   linting).
2. Commit messages follow Conventional Commits format
   (see [AGENTS.md](AGENTS.md) §3).
3. CI (build, lint, test) must pass before merging.
4. Address feedback from code-reviewer and
   architect-reviewer agents (see [AGENTS.md](AGENTS.md) §4)
   before opening a PR.

## Reporting Issues

Use the [issue templates](.github/ISSUE_TEMPLATE/) when opening
an issue. GitHub will prompt you to choose a template.

**Bug reports** capture macOS version, KiwiDesk version/commit,
repro steps, expected vs. actual behavior, and relevant logs
(`KiwiDesk get_state`, `get_layout_info`, and system log lines).
The template walks you through the details.

**Feature requests** should describe the **use case** and
**problem it solves** (not just the feature itself). Check the
**Status** note at the top of the
[README](https://github.com/hajiboy95/KiwiDesk) first to see
what already ships and what's still in progress.

## Vulnerability Reports

Not in the issue tracker, please — see
[SECURITY.md](SECURITY.md).

# KiwiDesk — Agent & Contributor Guidelines

Binding rules for human developers and AI agents working on this
repository. Read this file before modifying any code.

---

## 1. Project Overview

KiwiDesk is a tiling window manager for macOS (Swift, SwiftUI, Lua).
It manages windows in a **flat, one-dimensional array per space** —
never in hierarchical trees. Layout algorithms are pure functions
over that array.

```mermaid
graph TD
    A[UI / SwiftUI App] <-->|Settings & Profiles| B[App Core / Swift]
    B <-->|Bridge| C[Lua Engine / VM]
    B -->|Calls| D[OS Layer / Private APIs & AX]
```

Module layout (SwiftPM targets):

| Target | Path | Responsibility |
|---|---|---|
| `KiwiDeskCore` | `Sources/KiwiDeskCore` | State, events, OS bridge |
| `KiwiDesk` | `Sources/KiwiDesk` | Executable, menu bar, GUI |
| `KiwiDeskCoreTests` | `Tests/KiwiDeskCoreTests` | Unit tests |

The Swift core must stay strictly separated from the SwiftUI GUI
and (later) the Lua VM.

## 2. Code Rules

1. **File size:** target **100–250 lines** per Swift file. Hard
   ceiling: **350 lines** (only for cohesive, performance-critical
   logic). Split files before they grow past the ceiling.
2. **Line length:** max **79 characters** per line. Enforced by the
   pre-commit hook and CI (`scripts/lint.sh`).
3. **Single Responsibility:** one class/struct = one job (event
   listening, layout math, IPC — never mixed).
4. **DRY vs. readability:** extract shared helpers (`AXHelper`,
   `GeometryUtils`) instead of duplicating, but prefer a small,
   readable duplication over a deep protocol hierarchy or heavy
   generics. Keep code flat.
5. **Formatting:** `swift format` with the repo's `.swift-format`
   config owns all style (whitespace, commas, braces). SwiftLint
   (SPM build plugin, `.swiftlint.yml`) owns semantic rules
   (force casts, complexity, file length) and warns directly in
   Xcode during builds. Never enable a SwiftLint style rule that
   fights swift-format. Run `scripts/lint.sh` before committing.
6. **Concurrency:** AppKit/AX interaction is `@MainActor`. Pure
   state and layout code must stay actor-free and unit-testable.

## 3. Workflow: Refine → Plan → Act → Verify

1. **Refine:** read the relevant code and specs before proposing
   changes; clarify ambiguities first.
2. **Plan:** for features and major fixes, write a short written
   plan (files to change, API surface, tests) before implementing.
3. **Act:** implement step by step; keep commits focused.
4. **Verify:** `swift build && swift test && scripts/lint.sh` for
   the fast inner loop. A **release build** (`swift build -c
   release`) must also pass before any commit or PR — it enables
   the optimizer and stricter concurrency diagnostics (e.g.
   non-Sendable captures in `@Sendable` closures) that the debug
   build silently misses.
5. **Document:** any user-visible behavior change updates the
   matching docs in the same change set — `docs/configuration.md`
   (Lua config & behavior), `docs/cli.md` (commands, events, IPC),
   `docs/integrations.md` (recipes) — and `plan/` when the design
   itself shifts. Code and docs must never describe different
   behavior.
6. **Review:** once a substantial change is finished, verified,
   and committed, spin up **both** `code-reviewer` and
   `architect-reviewer` on the diff since the last review point —
   the branch's merge base with `main`, or the last reviewed
   commit / PR if there is one. Address or consciously dismiss
   their findings before opening a PR. (See §4 subagent
   delegation.)

### Commit messages (Angular / Conventional Commits)

Format: `type(scope): subject` — imperative, lower-case subject,
no trailing period. Body (optional) explains the why, wrapped at
72 columns.

- Types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`,
  `build`, `ci`, `chore`.
- Scope is the touched area, e.g. `animation`, `tiling`, `layout`,
  `commands`, `lua`, `ax`, `profiles`, `docs`. Omit when the
  change is repo-wide.
- Examples:
  - `feat(layout): add stack.set_overflow_style`
  - `fix(tiling): defer z-order restore until animations settle`
  - `perf(animation): apply position-only frames per app`

## 4. Tooling

- Shared automation lives in the visible `/scripts/` directory
  (never hidden in dot-folders): lint, git hooks, localization
  scripts.
- Install hooks once per clone: `./scripts/install-hooks.sh`.
- Fetch and install workspace subagents and skills:
  `./scripts/install-subagents.sh`.

### Subagent delegation (AI agents)

When subagents are available, spin them off proactively — no
need to wait for the user to ask — but only where the payoff is
clear. A subagent starts with zero conversation context, so
delegate work that does not depend on it:

- **Broad fan-out searches** across many files or naming
  conventions where only the conclusion matters (`Explore`).
- **Independent review passes** on a finished, substantial
  change (`code-reviewer`, `architect-reviewer`).
- **Parallel, isolated implementation work** (e.g. in a separate
  worktree) that would otherwise serialize.

Stay inline for anything small, sequential, or dependent on
conversation context: a cold agent re-deriving what the session
already knows costs more than it saves.
- CI (`.github/workflows/ci.yml`) builds, lints, and tests on every
  push and on PRs targeting `main`. A red build blocks merging.

## 5. Guardrails (Known Pitfalls)

Keep this list updated whenever a recurring mistake is found.

- **One vocabulary across Lua and profile JSON.** A profile
  JSON key is the Lua command name with the `set_` verb
  stripped, snake_case, grouped by namespace:
  `set_gap_override` → `gap.override`, `bsp.set_ratio` →
  `layout.bsp.ratio`, `stack.set_master_ratio` →
  `layout.stack.master_ratio`. Multi-part element names nest
  further when the element is a configurable unit:
  `drag.set_ghost_fill_color` → `drag.ghost.fill_color`.
  Groups are singular (`gap`,
  `layout`, `drag`); never invent synonyms or plurals. When
  adding a setting, pick the Lua name first and derive the
  JSON key from it via `CodingKeys` (Swift property names may
  differ internally). `SettingsCodingTests` pins this shape.
- **Never disable SIP or ask users to.** Private SkyLight/CGS
  symbols are resolved at runtime via `dlsym` (`SkyLight.swift`),
  never linked with `@_silgen_name` — a linked symbol that
  disappears in a macOS update would crash the app at launch,
  while a failed lookup returns nil and the caller falls back to
  the public Accessibility API (`AXUIElement`). Every private
  fast path must have such a fallback.
- **AX calls are slow and can block.** Never call AX APIs inside
  tight loops or layout math; snapshot state first.
- **Electron/WebKit apps answer AX queries lazily** (100–300 ms).
  `AXEnhancedUserInterface` is set to `true` on managed apps to keep
  their AX tree warm; do not remove this without a replacement.
- **Windows live in a flat `[WindowID]` per space.** Do not
  introduce tree/container structures into state or layout code.
- **Space identifiers are strings** and case-sensitive; numeric
  strings and integers are equivalent (`"1"` == `1`).
- **Hotkeys use the Carbon API** (`RegisterEventHotKey`), not
  CGEventTap — this avoids Input Monitoring permission. Event taps
  are only for mouse drag tracking.
- **One `DisplayLink` per monitor** (mixed refresh rates). Never
  drive animations from a single global timer.
- **`AXObserver` callbacks arrive on the thread's run loop** that
  registered them; keep observer registration on the main thread.

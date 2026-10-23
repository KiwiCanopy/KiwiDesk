# KiwiDesk — Agent & Contributor Guidelines

Binding rules for human developers and AI agents working on this
repository. Read this file before modifying any code. Every agent
(Claude Code, Cursor, Codex) and human reads it directly.

## How this file is organized

This file is the **hub**: the project shape, the rules that apply
everywhere, and an index of the subsystem guardrails (§5). The
guardrails live in [`.claude/rules/*.md`](.claude/rules/), one file
per subsystem. Each rule file is canonical for its subsystem; where
it and this file disagree, the rule file wins and this file is the
thing to fix. Claude Code loads a rule file when you touch a path
its `paths:` glob matches; every other reader follows the §5 links.

The five guardrails at the top of §5 are repeated in short form
from their rule files, because they destroy something before a
rule file would ever load.

Two shelves, don't confuse them:

- **`docs/`** — the product: Lua reference, user guide, CLI,
  design decisions, accepted limitations. Ships to users through
  the site.
- **`.claude/rules/`** — the workshop: engineering guardrails for
  whoever changes the code.

---

## 1. Project Overview

KiwiDesk is a tiling window manager for macOS (Swift, SwiftUI,
Lua). It manages windows in a **flat, one-dimensional array per
space** — never in hierarchical trees. Layout algorithms are pure
functions over that array. The Swift core stays strictly separated
from the SwiftUI GUI and the Lua VM; Core calls the OS layer
(private APIs and AX).

Module layout (SwiftPM targets):

| Target | Path | Responsibility |
|---|---|---|
| `KiwiDeskCore` | `Sources/KiwiDeskCore` | State, events, OS bridge |
| `KiwiDesk` | `Sources/KiwiDesk` | Executable, menu bar, GUI |
| `KiwiDeskCoreTests` | `Tests/KiwiDeskCoreTests` | Unit tests |
| `KiwiDeskGuiTests` | `Tests/KiwiDeskGuiTests` | GUI tests, plus the source-scanning parity guards (`SourceScan`) — which scan **both** trees, so a `KiwiDeskCore` invariant may be guarded from here |

Subsystem map (`Sources/KiwiDeskCore/*`) — directory-level, not a
file list; grep within a subsystem for specifics:

| Dir | Responsibility |
|---|---|
| `State` | Flat `[WindowID]`-per-space window state |
| `Tiling` | Placing windows from state into layouts |
| `Layouts` | Pure layout algorithms over the flat array |
| `Commands` | Command dispatch (the `set_*` verbs), plus the z-order raise machinery every command path shares (`ZOrderDrain` and its policy) |
| `Config` | Decoding the Lua/profile config into settings |
| `Profiles` | Profile JSON load/save & defaults |
| `Appearance` | Color palettes (bundled + user, one-shot apply) |
| `Lua` | Lua VM bridge, watchdog, registry refs |
| `AX` | Accessibility bridge & `AXObserver` callbacks |
| `OS` | Private SkyLight/CGS symbols via `dlsym`, AX fallback |
| `Keys` | Carbon hotkey registration |
| `Events` | Event listening / mouse drag taps |
| `Tabs` | Native-tab reconciliation (`windowRekeyed` coalescing) |
| `Animation` | Per-monitor `DisplayLink` animation |
| `IPC` | CLI / external command IPC |
| `Bar` | KiwiShelf: one panel per display carrying the App Bar & Space Bar sections |
| `Borders` | Focus & sticky overlays (rings, sticky marks) |
| `Vision` | KiwiVision: a dim plate per screen below the focus (#2103) |
| `Power` | Power / display-state handling |
| `Permissions` | AX / permission prompts |
| `Localization` | `L()` string routing & locale catalogs |
| `App` | Core bootstrap & wiring |
| `Models` | Shared value types |
| `Service` | Long-running service glue |
| `Resources` | Bundled assets (locales, vendored app font, palettes) (assets, not code) |

The GUI lives in `Sources/KiwiDesk` — layout conventions in
[`.claude/rules/gui.md`](.claude/rules/gui.md).

This table is the *where*. For the *how* — end-to-end pipelines
(event→placement, command dispatch, config resolve, animation)
traced at directory altitude — see **`docs/architecture.md`**.

## 2. Code Rules

1. **File size:** target **100–250 lines** per Swift file. Hard
   ceiling **350** (only for cohesive, performance-critical
   logic). Split before you cross it.
2. **Line length:** max **79 characters**. Enforced by the
   pre-commit hook and CI (`scripts/lint.sh`).
3. **Single Responsibility:** one class/struct = one job (event
   listening, layout math, IPC — never mixed).
4. **DRY vs. readability:** extract shared helpers (`AXHelper`,
   `GeometryUtils`) instead of duplicating, but prefer a small,
   readable duplication over a deep protocol hierarchy or heavy
   generics. Keep code flat.
5. **Formatting:** `swift format` with the repo's `.swift-format`
   owns style; `scripts/lint.sh` adds the §2.1 and §2.2 limits.
   Linting is its own step, not a build plugin (`Package.swift`
   says why). Run `scripts/lint.sh` before committing — its
   **exit code** decides, not its warnings.
6. **Concurrency:** AppKit/AX interaction is `@MainActor`. Pure
   state and layout code stays actor-free and unit-testable.
7. **GUI north-star — simplicity, intuitiveness, Apple-native
   feeling, in that order**, approachable by default and powerful
   on demand through Lua. The principle, its corollaries and the
   settled conventions are in
   [`.claude/rules/gui.md`](.claude/rules/gui.md).
8. **Comments: state the constraint, cite the ruling, stop.**
   A comment carries only what the code cannot show — a
   non-obvious invariant, a platform trap, the why behind a
   choice that looks wrong. Budget: 1–3 lines plus the issue
   ref (`#NNN`); the argument lives in the issue, the owning rule
   file or `docs/design-decisions.md`. A docstring states the
   contract — what it does, units, threading, ownership. Never
   write how the code got here, rejected alternatives, what the
   next line visibly does, or justification aimed at a reviewer.
   Exception: a docstring a rule file or guard names as a
   canonical home (a census like `OwnWindowTiling`'s doc, a
   number-pin's retuning argument) keeps the length its job needs.

## 3. Workflow

1. **Refine and plan:** read the relevant code and the owning rule
   file first; clarify ambiguities. For features and major fixes,
   write a short plan (files, API surface, tests) before
   implementing.
2. **Act:** implement step by step; keep commits focused.
3. **Verify:** run the **`verify-gate` skill**
   ([`.claude/skills/verify-gate`](.claude/skills/verify-gate/SKILL.md)).
   It owns which gate a change earns and what to run.
4. **Document:** a user-visible behavior change updates the
   matching doc in the same change set, and a new setting gains a
   guide section only when the owner asks (#1395). Which doc owns
   what: [`.claude/rules/docs.md`](.claude/rules/docs.md) and
   [`.claude/rules/site.md`](.claude/rules/site.md).
5. **Review:** once a substantial change is verified and
   committed, run the **`review-change` skill**
   ([`.claude/skills/review-change`](.claude/skills/review-change/SKILL.md))
   and address or consciously dismiss every finding before opening
   a PR.

### Branching & Pull Requests

Branch from `main` as `<type>/<kebab-description>`, the type a
Conventional Commit type (`feat/scrolling-snap-mode`). One focused
change per branch; separate refactors from features. Use the
[PR template](.github/pull_request_template.md) and reference
issues with `fixes #123`. A first PR from an account signs the
[CLA](CLA.md).

**Merge only from an up-to-date branch:** bring the branch onto
current `main`, let CI go green on that head, then squash-merge
(`gh pr merge <n> --squash`, or `--auto`). Never merge directly.

**File issues through the `file-issue` skill**
([.claude/skills/file-issue](.claude/skills/file-issue/SKILL.md)).
`gh issue create` skips the templates, whose fields are the
questions a maintainer triages on, so the skill reproduces them and
sets the Type, Priority, Effort and milestone at filing. Never
apply the retired `bug` / `enhancement` / `documentation` / `feat`
labels.

### Commit messages (Angular / Conventional Commits)

`type(scope): subject` — imperative, lower-case, no trailing
period. Optional body explains the why, wrapped at 72 columns.

- Types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`,
  `build`, `ci`, `chore`.
- Scope is the touched area (`animation`, `tiling`, `layout`,
  `commands`, `lua`, `ax`, `profiles`, `docs`); omit when the
  change is repo-wide.

## 4. Tooling

Shared automation lives in `/scripts/`, never in dot-folders.

- `./scripts/install-hooks.sh` once per clone. The `pre-commit`
  hook lints staged Swift, runs the locale checks, and refuses a
  commit while HEAD is `main` (override with
  `KIWIDESK_ALLOW_MAIN_COMMIT=1`, never `--no-verify`).
- `scripts/gate-lock <cmd…>` runs a heavy gate step in the one
  machine-wide gate slot; `scripts/gate-hook` applies it to every
  agent's `swift build` / `swift test`. A human types the prefix.
- `./scripts/build-app.sh` packages and signs the `.app`;
  `./scripts/release.sh <version>` cuts a release in two runs.
  Both, and CI's `changes` gating, are
  [packaging-and-release.md](.claude/rules/packaging-and-release.md)'s.
- `scripts/mutate <spec.json>` proves guards red: commit first,
  it refuses a tree that differs from HEAD and restores every
  mutated file from its own bytes ([tests.md](.claude/rules/tests.md)).
- `./scripts/sync-agents.sh` regenerates the Codex mirror of
  `.claude/agents/` ([subagents.md](.claude/rules/subagents.md)).
- Optional per developer: Node `>= 18`, which only
  `scripts/sparkle-public-key.js` needs, and skill installs, which
  land in the ignored `.agents/skills/`.

### Subagent delegation (AI agents)

Delegate only work that needs no conversation context: broad
searches where only the conclusion matters, independent review of
a finished change, proving a new guard reds (`guard-prover`).
Stay inline for small, sequential or context-dependent work,
including implementation: a cold agent re-deriving what the
session already knows costs more than it saves. The roster is in
[subagents.md](.claude/rules/subagents.md).

## 5. Guardrails

These apply everywhere, whatever you touch:

- **Rename code freely; a stored VALUE needs a crossing.**
  Command names, Lua/CLI verbs and event names take no aliases or
  deprecation layers — save `kiwidesk mcp`'s verb and server name
  (`MCPInvocationContractTests`). A rename that changes a stored
  value or key owes a one-shot `ConfigMigration` step reaching
  every reader of that file shape (`ConfigMigrationRoutingTests`),
  never a lenient decoder: decoders stay strict, and one unreadable
  value costs the whole file (`ConfigMigrationTests`,
  [profiles.md](.claude/rules/profiles.md)).
- **Windows live in a flat `[WindowID]` array per space.** Never
  introduce tree or container structures into state or layout.
- **Never disable SIP, or ask a user to.** Every private fast
  path has a public-API fallback.
- **Never `Bundle.module` in code that runs from the `.app`** —
  go through `ResourceBundle.locate`. It resolves on the machine
  that built it and `fatalError`s everywhere else.
- **Space identifiers are strings** and case-sensitive; numeric
  strings and integers are equivalent (`"1"` == `1`).

**Read the owning rule file before editing its subsystem.**

| Rule file | Scope (its `paths:` frontmatter decides) | Covers |
|---|---|---|
| [core-boundaries](.claude/rules/core-boundaries.md) | `Sources/KiwiDeskCore` | Core/GUI seam, logging, command records |
| [state-and-layout](.claude/rules/state-and-layout.md) | `State`, `Tiling`, `Layouts`, `Commands`, `App`, `Tabs`, `Models`, crash recovery | Flat state, retiles, floats, focus, z-order, snapshots |
| [profiles](.claude/rules/profiles.md) | `Config`, `Profiles`, `Commands` | Profiles, Desktop bindings, keymap seeds, migrations, sync |
| [config-vocabulary](.claude/rules/config-vocabulary.md) | setting names, `CodingKeys` | Lua name first, one noun per concept |
| [accessibility](.claude/rules/accessibility.md) | `AX`, the boot scan and reconcile `Events` files | Slow AX, adoption, removal distrust |
| [os-private-apis](.claude/rules/os-private-apis.md) | `OS`, `SkyLight*.swift`, `AXHelper.swift` | `dlsym`, fallbacks, WindowServer reads |
| [lua](.claude/rules/lua.md) | `Lua` | Watchdog, registry refs |
| [input-and-animation](.claude/rules/input-and-animation.md) | `Keys`, `Events`, `Animation`, frame applier, Space slide | Hotkeys, gestures, focus reports, springs |
| [bars](.claude/rules/bars.md) | `Bar`, bar drivers, shelf layouts, glass hosts | KiwiShelf, App Bar, Space Bar, glass |
| [borders](.claude/rules/borders.md) | `Borders`, `Vision` | Rings, marks, KiwiVision |
| [gui](.claude/rules/gui.md) | `Sources/KiwiDesk` | Settings conventions, theming, VoiceOver, windows |
| [localization](.claude/rules/localization.md) | `Localization`, `Resources/Locales`, `scripts/*key*` | Catalogs, `L()`, specifiers, wording |
| [tests](.claude/rules/tests.md) | `Tests/**` | Fixtures, seams, guard proving |
| [parity-tests](.claude/rules/parity-tests.md) | hand-mirrored field lists | Reflection parity past two mirrors |
| [packaging-and-release](.claude/rules/packaging-and-release.md) | `scripts/build-app.sh`, `scripts/release.sh`, `Package.swift`, workflows, `plugins/` | Signing, notarization, releases, CI |
| [rule-authoring](.claude/rules/rule-authoring.md) | `.claude/rules/**`, `.claude/agents/**`, `AGENTS.md` | Obligations, not state claims (#614) |
| [subagents](.claude/rules/subagents.md) | `.claude/agents/**`, `scripts/sync-agents.sh` | Agent roster and authoring |
| [docs](.claude/rules/docs.md) | `docs/**` | Which doc owns what, design-decisions charter |
| [site](.claude/rules/site.md) | `site/**` | Astro site, Cloudflare Pages, generated data |

When a recurring mistake is found, add it to the rule file that
owns the subsystem as an obligation, not a state claim
([rule-authoring.md](.claude/rules/rule-authoring.md)), and refresh
its row here only if its scope changed.

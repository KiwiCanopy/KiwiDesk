<!-- GENERATED from AGENTS.md by scripts/build-agent-brief.sh
     DO NOT EDIT. Regenerate after editing AGENTS.md.
     source-sha256: d61b300259b22eeaa191d90925290796cda140afb3cf03b9d43cb2f6e51ed189 -->

# KiwiDesk — Agent & Contributor Guidelines

Binding rules for humans and AI agents on this repo. Read before touching code.

Canonical source. Claude Code loads caveman-compressed brief from it (`.claude/AGENTS.brief.md`, built by `scripts/build-agent-brief.sh`) to save per-session context; regenerate brief whenever edit this file. Other agents (Cursor, Codex) and humans read this file direct.

---

## 1. Project Overview

KiwiDesk = tiling window manager for macOS (Swift, SwiftUI, Lua). Manages windows in **flat, one-dimensional array per space** — never trees. Layout algorithms = pure functions over that array.

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

Swift core stay strictly separate from SwiftUI GUI and (later) Lua VM.

Subsystem map (`Sources/KiwiDeskCore/*`) — directory-level, not file list; grep within subsystem for specifics:

| Dir | Responsibility |
|---|---|
| `State` | Flat `[WindowID]`-per-space window state |
| `Tiling` | Placing windows from state into layouts |
| `Layouts` | Pure layout algorithms over the flat array |
| `Commands` | Command dispatch (the `set_*` verbs) |
| `Config` | Decoding the Lua/profile config into settings |
| `Profiles` | Profile JSON load/save & defaults |
| `Lua` | Lua VM bridge, watchdog, registry refs |
| `AX` | Accessibility bridge & `AXObserver` callbacks |
| `OS` | Private SkyLight/CGS symbols via `dlsym`, AX fallback |
| `Keys` | Carbon hotkey registration |
| `Events` | Event listening / mouse drag taps |
| `Animation` | Per-monitor `DisplayLink` animation |
| `IPC` | CLI / external command IPC |
| `Bar` | sketchybar integration |
| `Borders` | Focus-window border overlays (per-window rings) |
| `Power` | Power / display-state handling |
| `Permissions` | AX / permission prompts |
| `App` | Core bootstrap & wiring |
| `Models` | Shared value types |
| `Service` | Long-running service glue |

GUI lives in `Sources/KiwiDesk` (`Settings/`, `Settings/Tabs/`).

Table = the *where*. For the *how* — end-to-end pipelines (event→placement, command dispatch, config resolve, animation) traced at directory altitude — see **`docs/architecture.md`**.

## 2. Code Rules

1. **File size:** target **100–250 lines** per Swift file. Hard ceiling **350 lines** (only for cohesive, performance-critical logic). Split before past ceiling.
2. **Line length:** max **79 characters** per line. Enforced by pre-commit hook and CI (`scripts/lint.sh`).
3. **Single Responsibility:** one class/struct = one job (event listening, layout math, IPC — never mixed).
4. **DRY vs. readability:** extract shared helpers (`AXHelper`, `GeometryUtils`) instead of duplicating, but prefer small readable duplication over deep protocol hierarchy or heavy generics. Keep code flat.
5. **Formatting:** `swift format` with repo's `.swift-format` config owns all style (whitespace, commas, braces). SwiftLint (SPM build plugin, `.swiftlint.yml`) owns semantic rules (force casts, complexity, file length), warns direct in Xcode during builds. Never enable SwiftLint style rule that fights swift-format. Run `scripts/lint.sh` before commit.
6. **Concurrency:** AppKit/AX interaction is `@MainActor`. Pure state and layout code stay actor-free and unit-testable.
7. **GUI north-star — simplicity, intuitiveness, Apple-native feeling, in that order.** Settings app should feel like it belongs in macOS System Settings, not bespoke control panel. Native pattern exists → use it; unsure → ask `ui-designer` consult framed by these three priorities before inventing layout.
   Companion principle — **approachable by default, powerful on demand.** New user gets good tiling setup with almost no config; that simplicity must never *cap* what achievable — beneath every easy surface is deeper layer (Lua config, profiles, advanced layouts, per-space overrides) there when wanted, never required to begin. Depth = capability user grows into, not cost paid upfront; simplicity-first is entry point, not ceiling (#326 panel is the shape: glance surface with one "Edit in Settings…" bridge down to full editor). See `docs/design-decisions.md`.
   Settled conventions falling out of this (extend, don't relitigate): **group by topic, never by widget type** — toggle and control it gates are one decision, so toggle sits direct *above* control it gates, never in separate "toggles" block (colors, which gate nothing, may group by type for grid scannability); **grey, don't hide** control with no effect in current mode (#171), keeping disabled control visible and dimmed; **live preview leads** its editor; **defer per-control "why" to contextual help** (planned `?` affordance, #94) rather than bloating labels/captions with glosses that later duplicate it. Caption job = label what shown, not teach.

## 3. Workflow: Refine → Plan → Act → Verify

1. **Refine:** read relevant code and specs before proposing changes; clarify ambiguities first.
2. **Plan:** for features and major fixes, write short written plan (files to change, API surface, tests) before implementing.
3. **Act:** implement step by step; keep commits focused.
4. **Verify:** `swift build && swift test && scripts/lint.sh` for fast inner loop. A **release build** (`swift build -c release`) must also pass before any commit or PR — enables optimizer and stricter concurrency diagnostics (e.g. non-Sendable captures in `@Sendable` closures) that debug build silently misses.
5. **Document:** any user-visible behavior change updates matching docs in same change set — `docs/lua-reference.md` (Lua config & behavior, in *expects → does → example* form), `docs/user-guide.md` (Settings app & GUI flows), `docs/cli.md` (commands, events, IPC), `docs/recipes/` (integration recipes), `docs/design-decisions.md` (when settled product/UX decision made or changed) — and `plan/` when design itself shifts. Code and docs must never describe different behavior.
   Marketing/docs **site (`site/`)** renders `docs/` through symlink, so doc *content* edits flow automatically — never hand-copy doc into `site/`. But site not fully covered by symlink: a **new doc page** needs sidebar entry in `site/astro.config.mjs`, and **site-only surfaces** (landing page, cross-page callouts) updated in same change set when feature warrants surfacing there — e.g. new layout mode (#128) adds its user-guide/reference prose *and* whatever nav or callout makes it findable. Run `npm run build` in `site/` when touch either.
   When review or manual pass classifies behavior as **accepted-by-architecture**, adds row to *Accepted limitations* table in `docs/design-decisions.md` in same change set — user-facing twin of §5 guardrail rule (OS-blocked-by-SIP items are separate class there, no in-app escape hatch).
6. **Review:** once substantial change finished, verified, committed, spin up **both** `code-reviewer` and `architect-reviewer` on diff since last review point — branch's merge base with `main`, or last reviewed commit / PR if one. Address or consciously dismiss findings before opening PR. (See §4 subagent delegation.)

   Sequencing: first round runs both agents **in parallel** — diff finished, perspectives independent, serializing only costs time. When resulting fix batch itself substantial (new abstractions, behavioral gates — not just comment/guard tweaks), run focused re-review of **only fix range**, this time **sequentially**: `code-reviewer` first (fixes correct?), then `architect-reviewer` (do seams the fixes introduced hold up?). Alternate rounds until one returns no major findings. Brief each re-review with what fixes claim to do, so it verifies claims instead of re-reviewing feature.

   Agent reuse (decision 2026-07-13): round 1 always uses **fresh** agents — independence is the point, reviewer carrying opinions from earlier feature anchors on them. Re-reviews of fix batch in **same session** go back to **round-1 agent** (message it) instead of spawning new: already holds diff and own findings, so verifies "were my findings fixed" direct instead of re-deriving whole context. Across sessions moot — subagent context dies with session, so new session always means fresh agents.

### Branching & Pull Requests

Branch from `main` with name matching Conventional Commit type: `feat/`, `fix/`, `refactor/`, `docs/`, `test/`, `chore/`, `ci/`, `perf/`, etc., followed by short kebab-case description (e.g., `feat/scrolling-snap-mode`). One focused change per branch; separate refactors from features.

When opening issue or PR, use GitHub [issue templates](.github/ISSUE_TEMPLATE/) and [PR template](.github/pull_request_template.md). Reference related issues in commit messages or PR descriptions with `fixes #123` syntax.

### Commit messages (Angular / Conventional Commits)

Format: `type(scope): subject` — imperative, lower-case subject, no trailing period. Body (optional) explains the why, wrapped at 72 columns.

- Types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`.
- Scope = touched area, e.g. `animation`, `tiling`, `layout`, `commands`, `lua`, `ax`, `profiles`, `docs`. Omit when change repo-wide.
- Examples:
  - `feat(layout): add stack.set_overflow_style`
  - `fix(tiling): defer z-order restore until animations settle`
  - `perf(animation): apply position-only frames per app`

## 4. Tooling

- Shared automation lives in visible `/scripts/` directory (never hidden in dot-folders): lint, git hooks, localization scripts.
- Install hooks once per clone: `./scripts/install-hooks.sh`.
- Fetch third-party subagents per clone with one explicit target: `./scripts/install-subagents.sh --claude` installs Claude Code agents and workspace skills; `./scripts/install-subagents.sh
  --codex` installs project-scoped Codex agents.
- (Optional, per-developer) install `caveman` skill to compress agent output — not a build dependency; needs Node `>= 18` (installer checks): `npx -y github:JuliusBrussee/caveman --non-interactive`. `--non-interactive` avoids hang when piped; append flags to scope it, e.g. `--only claude`, `--minimal`, `--uninstall`.
- Regenerate compressed agent brief after editing this file: `./scripts/build-agent-brief.sh` (needs caveman + `claude` CLI or `ANTHROPIC_API_KEY`). `scripts/lint.sh` runs `scripts/check-agent-brief.sh`, which only warns (never blocks) if brief stale — so editing this file needs no caveman install; brief just drifts until someone rebuilds it.

### Subagent delegation (AI agents)

When subagents available, spin off proactively — no need to wait for user ask — but only where payoff clear. Subagent starts with zero conversation context, so delegate work not depending on it:

- **Broad fan-out searches** across many files or naming conventions where only conclusion matters (`Explore`).
- **Independent review passes** on finished, substantial change (`code-reviewer`, `architect-reviewer`).
- **Parallel, isolated implementation work** (e.g. in separate worktree) that would otherwise serialize.

Stay inline for anything small, sequential, or dependent on conversation context: cold agent re-deriving what session already knows costs more than saves.
- CI (`.github/workflows/ci.yml`) builds, lints, tests on every push and on PRs targeting `main`. Red build blocks merging.

## 5. Guardrails (Known Pitfalls)

Keep list updated whenever recurring mistake found.

- **Pre-release, single user: no backward-compat shims.** Nothing publicly released, so nothing external depends on current command names, Lua/CLI verbs, event names, or file formats. Rename and restructure freely; do **not** add compatibility aliases, deprecation layers, or migration scripts — re-saving or re-editing config is the migration (#42 renamed space commands outright instead of keeping `*_virtual_space` aliases; profile JSON likewise needs none). Revisit at first public release — until then, back-compat is wasted complexity.
- **One vocabulary across Lua and profile JSON.** Profile JSON key = Lua command name with `set_` verb stripped, snake_case, grouped by namespace: `set_gap_override` → `gap.override`, `bsp.set_ratio` → `layout.bsp.ratio`, `stack.set_master_ratio` → `layout.stack.master_ratio`. Multi-part element names nest further when element is configurable unit: `drag.set_ghost_fill_color` → `drag.ghost.fill_color`. Groups singular (`gap`, `layout`, `drag`); never invent synonyms or plurals. When adding setting, pick Lua name first and derive JSON key from it via `CodingKeys` (Swift property names may differ internally). `SettingsCodingTests` pins this shape.
- **Never disable SIP or ask users to.** Private SkyLight/CGS symbols resolved at runtime via `dlsym` (`SkyLight.swift`), never linked with `@_silgen_name` — a linked symbol that disappears in macOS update would crash app at launch, while failed lookup returns nil and caller falls back to public Accessibility API (`AXUIElement`). Every private fast path must have such fallback.
- **Lua watchdog cannot interrupt blocking C calls.** Runaway-script guard = instruction-count hook; code that blocks inside C (`system()`, pipe reads) executes zero VM instructions and freezes main thread forever. Never add API that blocks in C on main thread — external commands always go through `ExecLauncher`. Lua registry refs (`luaL_ref`) are VM-specific and slots reused: never deliver ref into different interpreter than the one that minted it (capture owning `LuaInterpreter` weakly, as `KiwiCore+ExecAPI` does).
- **AX calls slow and can block.** Never call AX APIs inside tight loops or layout math; snapshot state first.
- **Electron/WebKit apps answer AX queries lazily** (100–300 ms). `AXEnhancedUserInterface` set to `true` on managed apps to keep AX tree warm; do not remove without replacement.
- **Windows live in flat `[WindowID]` per space.** Do not introduce tree/container structures into state or layout code.
- **macOS native tabs = one `NSWindow` per tab, coalesced temporally.** Finder/Terminal/Ghostty native tabs = separate `NSWindow`s sharing one on-screen frame, each with own `CGWindowID`, and **only active tab ever visible to AX** — background tabs never appear in `kAXWindowsAttribute`, and fresh id minted per switch (#308 probe). So tab switch surfaces to reconcile as one window vanishing while another appears at same frame; `TabReconciler` coalesces that pair into `.windowRekeyed` (id swapped in place — no tree, one slot per group) instead of destroy + create. Gate needs `AXTabGroup` on **either** side (Ghostty exposes one only at 2+ tabs, so 1↔2 boundary window has none). Coalescing suppressed on native-Space-switch `reconcileAll` (`coalesceTabs: false`) — same-app windows across spaces tile to identical frames and would false-merge. When editing tracking/reconcile, keep these facts in view; never assume window's `CGWindowID` stable or that every tab is AX window.
- **Cross-layout logic must account for each layout's navigation model.** Anything spanning all layouts — focus/swap navigation, overflow handling, geometric neighbor search — must consider whether layout is *geometric* (neighbor search over calculated slots) or *array-order* (steps flat array), and whether it can produce *overflow pile* (`OverlapStack` cascade). Two models need different handling (e.g. #172: exclude pile-mates from geometric candidate set vs skip their array indices; shared detector is `Navigation.pileMates`). Authoritative map = "Layout navigation & overflow models" table in `docs/design-decisions.md` — a **new layout must add its row** there.
- **Space identifiers are strings** and case-sensitive; numeric strings and integers equivalent (`"1"` == `1`).
- **Hotkeys use Carbon API** (`RegisterEventHotKey`), not CGEventTap — avoids Input Monitoring permission. Event taps only for mouse drag tracking.
- **One `DisplayLink` per monitor** (mixed refresh rates). Never drive animations from single global timer.
- **`AXObserver` callbacks arrive on run loop of thread** that registered them; keep observer registration on main thread.
- **SwiftUI cursor changes use `NSCursor.set()`, never push/pop.** View removed under pointer (link that deletes itself, row rebuilt by rename) never delivers balancing `onHover(false)`, and hover interleaved with drag gesture pops wrong entry — cursor stack cannot balance. Bit the spaces drag handle and link-hover modifier.
- **Keep SwiftUI `body` a shallow container.** Long modifier chain with conditional `background`/`overlay` closures or `+`-concatenated string literals inside one `body` expression can exceed type-checker's budget — and failure machine-dependent: compiles locally but dies on slower CI runner ("unable to type-check this expression in reasonable time"), so local verify gate does not catch it. Extract chained subviews into private computed properties / funcs and hoist concatenated strings into constants. Bit `KeyRecorderField`.
- **Split test suites early.** 79-char limit and 350-line ceiling repeatedly bit large test files. Break suites into focused files before they grow; per-file private helpers are convention and small duplication across suites fine.
- **Discardable test results must express side-effect intent.** When command or setup helper primarily mutates state but also returns optional convenience data, mark declaration `@discardableResult` if valid callers commonly ignore that data. Keep pure queries non-discardable — ignored result there is probably a bug. Test whose subject is command success/failure still asserts returned response; never remove tests or assertions merely to silence unused-result warning.
- **Profiles own tiling, plus sparse behavior overrides.** Profile serializes tiling state — belongs *inside* `TilingSettings` so it rides config split for free (see `gap.override`). Beyond tiling, profile may carry **sparse override of a global _behavior_ setting** — one that shapes how workspace behaves *while profile active*: keybindings (`Profile.modes`), app→space rules (`Profile.appRules`), float rules (`Profile.floatRules`), ignore rules (`Profile.ignoreRules`). Global bases come from active config owner (`gui.json` or `init.lua`); profile layer resolves over either owner. Window-rule families resolve independently, effective ignore remaining hard management gate. May **never** override setting that *routes or selects* the profile itself (`profile_bindings`, native-Space→profile map) or that lives outside config ownership (GUI language pref, which persists in `UserDefaults`) — profile that could rewrite what selects it is self-reference hazard. Every override = base overlaid with sparse diff (absent = inherit; explicit tombstone expresses removal), never second home for setting. Add each deliberately, guarded by round-trip + resolve parity test. App→space uses value-map override; float and ignore share generic list-rule primitive because two real clients now remove drift (see `.claude/rules/parity-tests.md`). `ProfileManager` mutators are `internal` by design — mutate through `KiwiCore` facade, never re-publicize them. `read(name:)` = public load-for-edit primitive (path-traversal guarded, touches no state); `save()` **adopts** (sets `currentName`, clears dirty), so edit-without-activating path must be separate, non-adopting write — never overload `save()`. GUI-vs-Lua ownership predicate centralized in `KiwiCore.isGuiManaged` (`KiwiCore+GuiConfig.swift`); refine that one predicate, never add second. Pre-release (single user): profile JSON needs no migration scripts — re-saving is the migration.
- **Explicit settings applies must `retile(force: true)`.** Engine's "already there" tolerance (±2 pt per edge) exists to absorb AX-echo lag and app-side clamping; un-forced retile after config edit lets it swallow small changes entirely (1 pt gap edit visibly did nothing). Config-apply entry points (`applyProfileScopedState`, `set_gap_*`, `set_min_window_size`, `set_mode`, and whole `layoutCommand` dispatch — every retile triggered by explicit `set_*` from Lua/CLI) force; event-driven retiles stay un-forced so echo lag can't wobble windows. Profile applies classify themselves: `apply(profile:)` / `apply(composed:)` take **required** `forceRetile`, so every new caller must choose — explicit paths (`load_profile`, in-effect edit re-apply, post-reload re-apply, preset apply) force; monitor-change and native-space-binding applies stay un-forced.
- **Resolve before layout, and merge per-field first.** Settings that layer (global → layout → space) merge field-by-field, cross-field clamps applied *last* on already-merged values (`AppBarStyle.resolved…` pattern). Resolution runs before layout math so layout functions stay pure over flat array.
- **Guard hand-mirrored field lists with forget-proof parity test.** Some patterns repeat a struct's field list across sites — global ↔ optional-override mirror (`AppBarStyle` ↔ `LayoutAppBar`), dual apply switch (`AppBarCommandSetting`), manual sparse `Codable`. Small readable duplication fine (§2.4), but past **two** mirrors of same field list the drift risk (add field, forget one site → silent data loss) outweighs clarity. Before adding third, weigh whether duplication still pays off; if ships, it **must** carry parity test — and prefer one that discovers fields by reflection / shared `CodingKeys` over hand-enumerated list, so guard itself cannot silently rot (hand-listed parity test = one more place to forget). Reflection net catches missing *property*, not forgotten `resolved()` / `encode` line — back it with round-trip + resolve-every-field test for those. Reach for generic/keypath merge only when removes drift, not just the `resolved()` lines — sparse `Codable` stays per-field either way, so generics rarely buy down real risk and fight §2.4.
- **`Resources/Locales/*.json` is generated/translation-owned (issue #9).** Every GUI string routes through `L("key", "English")` (`LocalizationManager.swift` in `KiwiDeskCore/Localization/`); English = source of truth, inlined at call site, with per-key fallback when locale omits key. A value interpolated into a sentence (name, count) MUST go through `L(key, english, args...)` overload with POSITIONAL `%1$@`/`%1$d` specifiers, never `+`-concatenated fragments — translation can't reorder pieces stitched in Swift, and many languages need to. `en.json` regenerated wholesale by `scripts/extract-keys` (scans both `Sources/KiwiDesk` and `Sources/KiwiDeskCore`, ignores `//`/`///` comments so doc-comment example call site can't leak phantom key) from real call sites — never hand-edit it, and AI agents must not hand-edit any `Resources/Locales/*.json` file: use `scripts/extract-keys <locale>` / `scripts/merge-keys <locale>` to translate, `scripts/rename-key <old> <new>` to rename key without losing translations, `scripts/drop-key <key>` to delete key's shipped translations when its English **meaning** changed — run in same change set, so every locale falls back to new English and key reappears on its to-translate list; cosmetic English edits (typo, punctuation) keep translations — and `scripts/extract-keys --prune` to drop orphaned ones (see `docs/translating.md`). Because same English text can in principle be authored at two different call sites for one key, `extract-keys` fails loudly on any such drift (mismatched English for same key) rather than silently picking one; `extract-keys --check` (run unconditionally by `scripts/lint.sh` — part of verify gate, CI, and `scripts/pre-commit` whenever Swift or locale file staged) additionally hard-fails if `en.json` stale or if any shipped `<locale>.json` doesn't decode as flat `{string: string}` map (broken file would otherwise make `LocaleCatalog` soft-fail to `[:]` and silently revert that locale to English); orphan key (in locale file, absent from code) only warns — clean up with `extract-keys --prune`. All backed by Swift tests — each localization script has sibling suite (`LocalizationDriftGuardTests`, `LocalizationOrphanTests`, `RenameKeyTests`, `DropKeyTests`, future scripts follow suit) — so regression in tooling itself covered by `swift test`, not just by running script. GUI language pick persists in `UserDefaults` (`LocalizationPreference`), never `gui.json` — documented as side-effect-free and must never create sidecar or flip `KiwiCore.isGuiManaged`.
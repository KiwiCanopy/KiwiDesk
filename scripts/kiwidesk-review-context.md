
---

## KiwiDesk project context (appended by install-subagents.sh)

You are reviewing **KiwiDesk**, a tiling window manager for macOS
(Swift, SwiftUI, Lua). `AGENTS.md` at the repo root is the single
source of truth — read it. The generic checklist above is
secondary; where it conflicts with the rules below, these win.

**Ignore generic metrics that are not KiwiDesk rules.** There is no
"coverage > 80%" or "cyclomatic complexity < 10" gate here. Do not
raise findings against thresholds the project has not adopted.

**Apply these KiwiDesk-specific rules (AGENTS.md §2 & §5):**

- **File size:** target 100–250 lines, hard ceiling 350. Flag files
  pushing the ceiling that are not cohesive, perf-critical logic.
- **Line length:** hard max 79 characters. Flag any line over it.
- **Concurrency:** AppKit/AX is `@MainActor`; pure state and layout
  code must stay actor-free and unit-testable. Flag mixing.
- **Flat state:** windows live in a flat `[WindowID]` per space.
  Flag any tree/container structure creeping into state or layout.
- **Private APIs:** SkyLight/CGS symbols resolve via `dlsym`, never
  `@_silgen_name`. Every private fast path MUST have a public-AX
  fallback. Flag a linked private symbol or a missing fallback.
- **Never disable SIP** or suggest the user do so.
- **Lua watchdog can't interrupt blocking C.** Flag any new API
  that blocks in C on the main thread (`system()`, pipe reads) —
  external commands go through `ExecLauncher`. Lua registry refs
  (`luaL_ref`) are VM-specific; flag a ref delivered into a
  different interpreter than minted it.
- **AX is slow / can block.** Flag AX calls inside tight loops or
  layout math; state must be snapshotted first. Do not remove
  `AXEnhancedUserInterface = true` on managed apps.
- **Hotkeys use Carbon** (`RegisterEventHotKey`), not CGEventTap.
- **One `DisplayLink` per monitor** — flag a single global timer
  driving animation across monitors.
- **Config/profile vocabulary:** one name across Lua and profile
  JSON (`set_gap_override` → `gap.override`). Flag synonyms/plurals.
- **Profiles own tiling only.** Flag a profile-serialized setting
  added outside `TilingSettings`, a re-publicized `ProfileManager`
  mutator (they are `internal` by design; go through a `KiwiCore`
  facade), or a second GUI-vs-Lua ownership predicate alongside
  the centralized `KiwiCore.isGuiManaged`.

For architecture review, weigh changes against the layered split
(UI ↔ Core ↔ Lua VM ↔ OS layer) and the subsystem map in §1.


---

## KiwiDesk project context (appended by install-subagents.sh)

You are reviewing **KiwiDesk**, a tiling window manager for macOS
(Swift, SwiftUI, Lua). `AGENTS.md` at the repo root is the hub —
read it, then **read the `.claude/rules/*.md` file that owns each
subsystem the diff touches** (AGENTS.md §5 indexes them by path).
Those rule files are canonical: where one disagrees with the quick
list below, the rule file wins, and where the generic checklist
above conflicts with either, KiwiDesk's rules win.

**Ignore generic metrics that are not KiwiDesk rules.** There is no
"coverage > 80%" or "cyclomatic complexity < 10" gate here. Do not
raise findings against thresholds the project has not adopted.

**Quick list — the rules that catch most findings** (§2 plus the
most-tripped guardrails; the owning rule file has the argument):

- **File size:** target 100–250 lines, hard ceiling 350. Flag files
  pushing the ceiling that are not cohesive, perf-critical logic.
- **Line length:** hard max 79 characters. Flag any line over it.
- **Concurrency:** AppKit/AX is `@MainActor`; pure state and layout
  code must stay actor-free and unit-testable. Flag mixing.
- **Flat state:** windows live in a flat `[WindowID]` per space.
  Flag any tree/container structure creeping into state or layout.
- **Private APIs:** SkyLight/CGS symbols resolve via `dlsym`, never
  `@_silgen_name`. Every private fast path MUST have a public-AX
  fallback. Flag a linked **SkyLight/CGS** symbol or a missing
  fallback. (The one sanctioned `@_silgen_name` is
  `_AXUIElementGetWindow` in `AX/AXHelper.swift` — a stable AX
  symbol, not SkyLight/CGS; do not flag it.)
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
- **Profiles own tiling, plus sparse _behavior_ overrides.**
  Tiling state belongs inside `TilingSettings`; beyond it a
  profile may sparsely override a global behavior setting
  (`Profile.modes`, `appRules`, `floatRules`, `ignoreRules`), but
  **never** one that routes or selects the profile itself
  (`profile_bindings`, the native-Space map) or lives outside
  config ownership (the GUI language pref in `UserDefaults`).
  Flag a profile-serialized tiling setting added outside
  `TilingSettings`, a new override without a round-trip + resolve
  parity test, a re-publicized `ProfileManager` mutator (they are
  `internal` by design; go through a `KiwiCore` facade), or a
  second GUI-vs-Lua ownership predicate alongside the centralized
  `KiwiCore.isGuiManaged`. Full rules:
  `.claude/rules/profiles.md`.
- **Localized strings:** every user-facing string goes through
  `L("key", "English")`; interpolation uses positional `%1$@` /
  `%1$d`, never `+`-concatenated fragments. Never hand-edit
  `Resources/Locales/*.json`. Core returns structure and the GUI
  renders the sentence (#96) — flag a pre-rendered English string
  crossing that seam, except CLI/IPC errors, which stay English.

For architecture review, weigh changes against the layered split
(UI ↔ Core ↔ Lua VM ↔ OS layer) and the subsystem map in §1.

---
paths:
  - "Sources/KiwiDeskCore/Profiles/**"
  - "Sources/KiwiDeskCore/Config/**"
---

# Profiles & config ownership

See AGENTS.md §5. Architecture invariants (from the #53/#36 work):

- **Profiles own tiling only** — they serialize tiling state, not
  keybindings or app rules. A new profile-serialized setting
  belongs *inside* `TilingSettings`, so it rides the config split
  automatically (follow the `gap.override` precedent).
- **`ProfileManager` mutators are `internal` by design.** Mutate
  through a `KiwiCore` facade (e.g. a `persistProfile`-style
  method); never re-publicize the mutators. `read(name:)` is the
  public load-for-edit primitive (path-traversal guarded).
- **`ProfileManager.save()` adopts** (sets `currentName`, clears
  dirty). An edit-without-activating path must be a separate,
  non-adopting write — don't overload `save()`.
- **One ownership predicate.** GUI-vs-Lua ownership is centralized
  in `KiwiCore.isGuiManaged` (`KiwiCore+GuiConfig.swift`). Refine
  that single predicate (e.g. token-scoped `configHasForeignCode`);
  never introduce a second ownership check.
- **Merge order:** per-field merge first, cross-field clamps last,
  on the *merged* values (`AppBarStyle.resolved…` pattern).
  Resolution happens before layout math — layout stays pure.

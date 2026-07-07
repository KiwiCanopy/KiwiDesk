---
paths:
  - "Sources/KiwiDeskCore/Profiles/**"
  - "Sources/KiwiDeskCore/Config/**"
---

# Profiles & config ownership

The binding rules live in **AGENTS.md §5** (canonical) — read them
before editing this subsystem. The ones this code trips over most,
as a checklist (rationale is in §5, not restated here):

- Profiles own **tiling only** — a new profile-serialized setting
  goes *inside* `TilingSettings` (the `gap.override` precedent).
- `ProfileManager` mutators are `internal`; go through a `KiwiCore`
  facade. `read(name:)` loads for edit; `save()` **adopts** — an
  edit-without-activating path is a separate, non-adopting write.
- One ownership predicate: `KiwiCore.isGuiManaged`. Never add a
  second.
- Resolve before layout; merge per-field first, cross-field clamps
  last (`AppBarStyle.resolved…`).
- One vocabulary across Lua and profile JSON — see
  [config-vocabulary.md](config-vocabulary.md).

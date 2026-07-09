---
paths:
  - "Sources/KiwiDeskCore/Profiles/**"
  - "Sources/KiwiDeskCore/Config/**"
---

# Profiles & config ownership

The binding rules live in **AGENTS.md §5** (canonical) — read them
before editing this subsystem. The ones this code trips over most,
as a checklist (rationale is in §5, not restated here):

- Profiles own **tiling, plus sparse _behavior_ overrides** — tiling
  state goes *inside* `TilingSettings` (the `gap.override`
  precedent); beyond it, a profile may sparsely override a global
  *behavior* setting (keybindings via `Profile.modes` today; app
  rules planned, #109), but **never** one that routes/selects the
  profile (`profile_bindings`) or lives outside config ownership
  (GUI language in `UserDefaults`). Each override is base + sparse
  diff with a tombstone for removal, templated on `KeyModeOverride`
  and parity-tested — not a generic primitive until a real second
  flat-map client exists (see §5 / [parity-tests.md](parity-tests.md)).
- `ProfileManager` mutators are `internal`; go through a `KiwiCore`
  facade. `read(name:)` loads for edit; `save()` **adopts** — an
  edit-without-activating path is a separate, non-adopting write.
- One ownership predicate: `KiwiCore.isGuiManaged`. Never add a
  second.
- Resolve before layout; merge per-field first, cross-field clamps
  last (`AppBarStyle.resolved…`).
- One vocabulary across Lua and profile JSON — see
  [config-vocabulary.md](config-vocabulary.md).

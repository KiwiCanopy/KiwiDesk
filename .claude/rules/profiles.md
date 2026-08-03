---
paths:
  - "Sources/KiwiDeskCore/Profiles/**"
  - "Sources/KiwiDeskCore/Config/**"
  - "Sources/KiwiDeskCore/Commands/**"
---

# Profiles & config ownership

Canonical for this subsystem (AGENTS.md §5 indexes it).

## Profiles own tiling, plus sparse behavior overrides

A profile serializes **tiling state** — that belongs *inside*
`TilingSettings` so it rides the config split for free (see
`gap.override`).

Beyond tiling, a profile may carry a **sparse override of a global
_behavior_ setting** — one that shapes how the workspace behaves
*while the profile is active*: keybindings (`Profile.layers`),
app→space rules (`Profile.appRules`), float rules
(`Profile.floatRules`) and ignore rules (`Profile.ignoreRules`).
`Profile`'s `…Override?`-typed properties are the register of
which families exist — the test for a new one is the *rule*
below, not membership of this list.
Global bases come from the active config owner (`gui.json` or
`init.lua`); the profile layer resolves over either owner.
Window-rule families resolve independently, with effective ignore
remaining the hard management gate.

It may **never** override a setting that *routes or selects* the
profile itself (`profile_bindings`, the native-Space→profile map)
or that lives outside config ownership (the GUI language pref,
which persists in `UserDefaults`) — a profile that could rewrite
what selects it is a self-reference hazard.

Every override is the base overlaid with a sparse diff (absent =
inherit; an explicit tombstone expresses removal), never a second
home for the setting. Add each one deliberately, guarded by a
round-trip + resolve parity test. App→space uses a value-map
override; float and ignore share the generic list-rule primitive
because two real clients now remove drift — see
[parity-tests.md](parity-tests.md).

## API shape

- `ProfileManager` mutators are `internal` **by design** — mutate
  through a `KiwiCore` facade, never re-publicize them.
- `read(name:)` is the public load-for-edit primitive
  (path-traversal guarded, touches no state).
- `save()` **adopts** (sets `currentName`, clears dirty), so an
  edit-without-activating path must be a separate, non-adopting
  write — never overload `save()`.
- The GUI-vs-Lua ownership predicate is centralized in
  `KiwiCore.isGuiManaged` (`KiwiCore+GuiConfig.swift`); refine
  that one predicate, never add a second.
- Pre-release, single user: profile JSON needs no migration
  scripts — re-saving is the migration.

## Resolve before layout, and merge per-field first

Settings that layer (global → layout → space) merge field by
field, with cross-field clamps applied *last* on the
already-merged values (the `AppBarStyle.resolved…` pattern).
Resolution runs before layout math so the layout functions stay
pure over the flat array.

## Applies force or don't, explicitly

`apply(profile:)` / `apply(composed:)` take a **required**
`forceRetile`, so every new caller must choose. Explicit paths
force — `load_profile`, an in-effect edit re-apply, the
post-reload re-apply, preset apply. Monitor-change and
native-space-binding applies stay un-forced. The wider rule (and
why the ±2 pt tolerance makes this matter) is in
[state-and-layout.md](state-and-layout.md).

## Vocabulary

One vocabulary across Lua and profile JSON — see
[config-vocabulary.md](config-vocabulary.md).

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

## The starter setup is derived, and its tuning is profile-wide

A fresh install's `Starter` profile is **chosen from the screens
that are connected** — `ScreenClass` (shape, in points) →
`StarterAllocation` (how many spaces, and which layouts) →
`StarterTuning` (the settings) → `StarterSetup` (assembles). The
argument, and why it superseded #466's five-per-display ladder,
is in `docs/design-decisions.md`. The obligations that fall on a
change here:

- **The tuning is profile-wide and named by the MAIN screen.**
  `TilingSettings` has one gap value and one stack ratio to give,
  so a laptop beside a 27" gets one answer and the only question
  is which screen names it. Per-space overrides express the rest.
  `StarterTuning.settings(mainShape:)` takes ONE `ScreenClass`,
  so a per-display answer cannot be expressed without changing
  the signature — do not change it into a per-display seam, which
  would put a second config behind every value the Settings
  window shows. `StarterSetupSeedTests` holds the tuning against
  each class.
- **Which entry point a call site takes is a rule, not a
  preference.** `StandardProfiles.workflows` is the
  hardware-agnostic list; `all(sizes:)` / `layouts(for:sizes:)`
  are the live catalog, and the ONE `Starter` they carry is
  derived from those screens; `standard(for:)` is the silent
  monitor-change fallback and reads `workflows` alone, so it
  needs no screens and stays answerable anywhere. A string
  lookup takes `workflows` — asking the live catalog builds a
  whole setup to read a name.
  (`StarterSetupSeedTests` pins which face carries the Starter.)
- **An unlisted mode in a sparse preset follows the screen.**
  `StandardLayout.mode(of:on:)` answers a space the map does not
  declare with that screen's own best layout, never a fixed
  `bsp` — the layout `ScreenClass` rules out on a laptop, which
  owns that threshold. Pass `nil` only where the hardware
  genuinely is not knowable, and the historic `bsp` stands there;
  a caller that CAN know and passes nil makes the preview and the
  apply disagree. `SparseModeFallbackTests` holds both arms.
- **`StarterSetup.slots` is the one walk.** Space numbering, the
  mode map and the screen pins all derive from it; a second walk
  is how a space takes its mode from one screen and its pin from
  another (`StarterSetupSeedTests`).
- **The share arithmetic is proportional, not merely summing.**
  `StarterAllocation.shares` must keep equal screens equal and
  never let a narrower screen out-rank a wider one — both are
  invisible to a sum-and-clamp assertion, and both shipped
  (`StarterAllocationTests`).

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

## A new file in the config directory answers the backup question

`SetupBundle` (#606) is what a backup carries, and its contents
are an **allow-list, never a directory sweep** — that type's doc
comment is the one register of what travels and what is left
behind, with the reason per entry. So **adding a file to
`~/.config/KiwiDesk` owes an explicit answer to "does this
travel?" in the same change set**, recorded there.

`SetupBundleTests.theAllowListIsPinned` guards the bundle's own
shape in both directions, by reflection over its stored
properties: a property ADDED has to argue for itself, and one the
hand-written composer OMITS reds too. Weaker forms of that guard
were tried and proven blind — asserting the written file's keys
alone misses the omission, and re-encoding the struct misses it as
well, `JSONEncoder` omitting a nil Optional.

What no guard can see is the step before: a **new store** whose
file never became a `ConfigArtifact` at all. `SetupBundleArtifactTests`
narrows it — the register is checked against what an export
carries, and against a live config directory — but nothing can
enumerate the files a future store will write, and the symptom is
a user moving Macs and silently losing whatever it held. `palettes.json` is the worked case, and it
nearly was that symptom: applying a palette writes its colours
into `gui.json`, so the current *look* travelled while the saved
*library* would have been left behind.

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

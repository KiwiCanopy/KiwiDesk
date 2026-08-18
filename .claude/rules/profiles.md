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

## The active Desktop is the MAIN display's (#888)

A binding, profile-selection or Desktop-memory path reads the
active Desktop from **`NativeSpaces.activeDesktopNumber()`** —
or, when it is handling a switch and will ask more than one
question, from `NativeSpaces.desktopSnapshot()`, whose
`authority` is the same answer — never from the global
`activeSpaceNumber()`. `DesktopAuthorityRoutingTests`'
`allowed` map is the one copy of who may name the global read,
and it holds exactly the snapshot's public fallback: a main
display the topology cannot name (shared mode's synthetic
managed-display identifier, no SkyLight, no display-UUID
symbol), where the global number IS the main screen's.

The two functions are the same shape, the same type and the
same answer on every single-display machine — they diverge only
under "Displays have separate Spaces" with two screens, which is
the state the rule exists for and the state a dev machine
usually is not in. That is why this is a guard rather than a
convention.

Two obligations fall out for a **switch handler**. Take ONE
snapshot and answer every question from it — which Desktop is
authoritative, which displays changed, whether a display's
current Space is a user desktop, which key the Space memory
writes under — because two readings taken moments apart can
disagree about which display switched. That means **threading
the value, not re-reading the seam**: a helper the handler calls
takes the answer as a parameter (`applyNativeSpaceBinding(desktop:)`,
`virtualSpaceTarget(for:key:)`, the emit's `mainUUID`), and the
no-argument conveniences beside them exist for callers that hold
no snapshot — a Lua/CLI verb, a config load. Nothing scans for
a helper that reads its own answer back, so each new one owes
this deliberately; three shipped without it inside the handler
this rule was written for (review round 2, 2026-08-18).

And never decide anything from a nil Desktop number: nil means a
fullscreen/system space AND "no SkyLight", the conflation
[state-and-layout.md](state-and-layout.md)'s #670 row bans —
the fullscreen verdict is `isUser`, per display
(`DesktopSnapshot.currentSpaceIsUser(on:)`). `SecondarySwitchTests`
holds the secondary-switch decision including its nil case.

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

A backup carries an **allow-list, never a directory sweep**, and
the register is `ConfigArtifact` — one case per file, answering
where it lives, whether it travels, and why not when it does not.
`SetupBundle`'s doc comment argues the reasoning; the enum is what
the code reads. So **adding a file to `~/.config/KiwiDesk` owes a
case there and an answer to "does this travel?" in the same change
set** — a prose line alone leaves the code unchanged, and a case
alone leaves the reason unrecorded.

`travelsInABackup` is load-bearing rather than documentation:
`exportSetup` and the restore's discard both read it, so flipping
a case to `false` changes behaviour rather than only a test.

**A change that breaks the decoded shape of anything the bundle
carries bumps `SetupBundle.currentFormat` in the same change set.**
Nothing can guard this, and it is the obligation the format
integer rests on: `<=` is decoder tolerance rather than a
compatibility shim, so an older backup is accepted — which is
right, and which silently becomes a lie the first time a
`GuiConfig`, `Profile` or `ColorPalette` field is renamed. §5
actively encourages that rename, so the bump is the reader's
responsibility here.

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

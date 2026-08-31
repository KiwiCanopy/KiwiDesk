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

## The seeded keymap has two bases, plus one key

- **Seed a HELD verb on `⌥⌘` and a PRESSED verb on the `⌃⌥`
  ladder — never the reverse (#1075/#1094).** Size is the one verb
  a user holds, so it is the only thing on `⌥⌘`; `⌘` on the
  ladder means exactly one thing, "and follow", and giving it a
  second sense is what the split removed. The toggles (`⌃⌥F`,
  `⌃⌥S`, `⌃⌥P`) and app chrome (`⌃⌥K`) are pressed, so they
  stay on the base tier as mnemonic letters
  (`SizeLayerSeedTests`, `DefaultKeybindingsTests`).
- **Never spend `⇧` on anything but "act on the window".** It
  qualifies a positional row — an arrow or a digit — so a
  lettered toggle never carries it: `⌃⌥⇧S` did, and it was the
  one chord in the seed a user who had learned the ladder read
  wrong (#1094, `DefaultKeybindingsTests` ▸
  `shiftNeverQualifiesALetter`). Which letter each sticky scope
  takes, why the screen-scoped one is named for a mark rather
  than a label, and why `D` was refused, are argued in
  `docs/design-decisions.md` ▸ "Size is not a positional verb" —
  do not restate them here or in the seed's docstring.
- **Check a new `⌥⌘` default against `SystemShortcuts.map`, never
  against prose — and do not stop there.** That base is free only
  where the register says so: the first draft of this layer took
  `⌥⌘8`, which is macOS's Zoom toggle. But the register models
  macOS's OWN chords, so it is blind to app menus, which is where
  most real collisions live — `⌥⌘`+digit came back bound in
  Finder, Preview, Safari and PowerPoint against a register that
  stayed green (#1098). The check is necessary and not
  sufficient; enumerate the apps too. What the register must carry, and how to enumerate
  a base, is [input-and-animation.md](input-and-animation.md)'s;
  the product argument is `docs/design-decisions.md` ▸ "Size is
  not a positional verb" (`SizeLayerSeedTests`).

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
- **A screen's FIRST space is the lead, and the lead may
  repeat.** `StarterAllocation.lead(_:of:)` decides it before the
  screen's own list is read — Scrolling everywhere but the
  narrowest screen, which leads Monocle — so it is appended
  WITHOUT consulting `used` and joins it afterwards. A change
  that folds the lead back into the ordinary fill silently
  restores best-first opening, and a change that makes the
  no-repeat rule absolute breaks the lead; `StarterLeadTests`
  holds both, including the tie-break that keeps a main screen
  beside an identical twin on Scrolling. Read "smallest" off
  `fillOrder`'s far end rather than sorting again — a second
  ordering is a second tie-break to disagree with.
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

**A Desktop VERB is the counterpart, and takes the wider
list.** `focus_desktop` / `move_to_desktop(_and_follow)`
resolve a Mission Control number globally and act on the
screen that Desktop lives on, so a surface OFFERING those
verbs offers every user Desktop — `DesktopSnapshot.userDesktops`,
never `mainDisplayDesktops`, which would put a second screen's
Desktops out of reach of every surface but hand-written Lua.
The rule above is about which Desktop is AUTHORITATIVE; this is
about which Desktops are REACHABLE, and reading the first as
settling the second is the mistake this clause exists to stop —
a single-screen machine cannot tell the two lists apart.
`DesktopAuthorityTests` ▸ `userDesktopsSpanEveryScreen` holds
them against one two-screen arrangement where they differ, and
`KiwiCore.bindableDesktops(in:)` is where the list meets the
capability.

Two obligations fall out for a **switch handler**. Take ONE
snapshot and answer every question from it — which Desktop is
authoritative, which displays changed, whether a display's
current Space is a user desktop, which key the Space memory
writes under — because two readings taken moments apart can
disagree about which display switched. That means **threading
the value, not re-reading the seam**: a helper the handler calls
takes the answer as a parameter (`applyDesktopBinding(desktop:)`,
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
  (path-traversal guarded, touches no in-memory state — it does
  rewrite the FILE when a migration applies, see below).
- `save()` **adopts** (sets `currentName`, clears dirty), so an
  edit-without-activating path must be a separate, non-adopting
  write — never overload `save()`.
- The GUI-vs-Lua ownership predicate is centralized in
  `KiwiCore.isGuiManaged` (`KiwiCore+GuiConfig.swift`); refine
  that one predicate, never add a second.
- **A stored value that is renamed owes a one-shot migration**
  in `ConfigMigration`, applied at EVERY reader of that file
  shape. Add the step to `ConfigMigration.steps`, never to a
  reader: readers name the migration-agnostic seam, so a second
  migration touches one file. `ConfigMigrationRoutingTests` is
  the census of who reads and who is exempt — do not re-list
  them in prose here, which is what missed `KiwiCore.readBackup`
  the first time. That one matters most: a `SetupBundle` carries
  `[Profile]` inline, and unlike a profile file a backup is never
  rewritten, so a refusal there ("that file isn't a KiwiDesk
  backup", about a file this app wrote) is permanent.
  The older rule here — "pre-release, single user, re-saving is
  the migration" — was retired with AGENTS.md §5's premise: it
  was true while the author was the only user, and v0.9.7 shipped
  to others. A lenient decoder is still banned; it never ends,
  where a rewrite does.

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
carries bumps `SetupBundle.currentFormat` in the same change set,
and a breaking schema change to `Profile` or `GuiConfig` bumps
`Profile.currentFormat` or `GuiConfig.currentFormat`.** A
breaking `ColorPalette` (or `PaletteDocument`) schema change
owes TWO bumps — `PaletteDocument.currentFormat` for the
standing `palettes.json` AND `SetupBundle.currentFormat`,
because the bundle carries `[ColorPalette]` inline — and it
must also rule the exported-palette SIDECAR deliberately: a
bare `ColorPalette` file has no shape marker, sits outside the
migration census by ruling (#945), and like a backup is never
rewritten.
Nothing can guard this, and it is the obligation the format
integers rest on: `<=` is decoder tolerance rather than a
compatibility shim, so an older config or backup is accepted — which is
right, and which silently becomes a lie the first time a
`GuiConfig`, `Profile` or `ColorPalette` field is renamed. §5
actively encourages that rename, so the bump is the reader's
responsibility here.

When removing an old migration from `ConfigMigration`, the removal
advances the supported format floor: files below the floor are
refused explicitly rather than silently failing (#902).

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

## The two profile writes mean different things (#1179)

A layout can be changed in two places, and the writes they lead
to are not the same verb. Keep them apart, in both directions:

- **The quick menu's Keep = a whole-live snapshot.** "Write down
  what is on screen", every screen at once.
  `persistProfile(named:)` with no `modesFrom` is that meaning,
  and it is the only thing that turns a temporary layout
  permanent.
- **A Settings Save = a draft commit.** "Save what I edited." It
  applies and persists the modes of the spaces the draft
  actually edited and nothing else —
  `applyProfileScopedState(from:applyingModesFor:)` scoped, and
  `persistProfile(named:modesFrom:)` writing the draft's modes.

**Neither half may be dropped, because each is the other's
mirror.** A Save that re-asserts the draft's modes wholesale
destroys a standing temporary layout the save pill never counted
— that is Revert's meaning wearing a Save label, and it is the
defect #1179 closes. A Save that captures LIVE instead adopts
that same temporary layout into the file. Both shipped at once.

**The GUI draft seeds its per-space modes from the SAVED
profile, never from live.** `overlayLiveProfileState` still
mirrors live for everything else — which spaces exist, their
order, pins, the Main role — because those are live's to state
(#75/#55); the modes are the one field that is not, and that
split IS the fix. `savedModes` answers `[:]` where no profile is
readable, and live is then the only truth there is, so an
unmanaged setup is not silently reset to `.bsp`.

**"Edited" is one predicate, with three readers.**
`SettingsDraftDiff.editedSpaceModes` answers it for the diff's
own attribution, for the Save's partial apply, and for the
unsaved-changes popover's rows. The save pill is the draft's one
narrator, so what a Save writes must never exceed what the pill
counted — and a comparison re-derived beside any reader agrees
today and disagrees on the release that changes the sparse
encoding. `SettingsSaveTemporaryLayoutTests` holds the
behaviour, the mixed case and the source scan; the sparse
encoding's omitted `.bsp` resolves in one place,
`GuiConfig.modes(for:)`.

`docs/design-decisions.md` ▸ *Quick-menu layout switch is
session-only* owns the product half, including the two residues
this deliberately leaves visible.

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

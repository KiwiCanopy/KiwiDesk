# Design decisions

The major product/design decisions behind KiwiDesk's Settings
app and menu bar, with the reasoning — so users understand why
things behave the way they do, and contributors don't relitigate
(or accidentally undo) a settled choice. Decisions from the
Settings redesign (#68, PR #88) unless noted; deeper rationale
lives in the linked issues. Architecture and code guardrails
live in `AGENTS.md`, not here.

## Navigation & saving

**Two-group sidebar: "This Profile" vs "Whole App".** Every
control either travels with the profile being edited or is
app-wide, and the old flat tabs hid which was which — the
single biggest source of confusion. The sidebar makes the
scope split part of the navigation itself; profile-scoped
sections follow the banner's edit target, Whole-App sections
are always live. (#68 §3.1)

**One stable save footer: Revert / Save a Copy As… / Save.**
The old footer showed up to seven differently-labeled verbs
depending on invisible mode state, but they expressed only
two intents: "persist to what I'm editing" and "duplicate
under a new name". Three stable slots, clustered at the
trailing edge. The banner above names the edit target
authoritatively — a destination caption beside Save
duplicated it, read as confusing, and its fixed width split
the button cluster apart, so it was dropped. Adopt is not a
save verb — it lives with the raw-Lua content it migrates.
(#68 §3.12)

**"Unsaved changes" is a live comparison, not a latched
flag.** `isDirty` compares the edited config and Lua source
against the as-loaded baselines on every change, so manually
undoing an edit clears the footer again — a latched flag
kept claiming unsaved changes after the user had already
put everything back.

## Spaces & profiles

**The fallback space is an explicit choice, not "whichever
row is first".** When a profile switch drops a space, its
windows need a home. Tying that to the first list row (the
#75 interim rule) forces users to order spaces by system
constraint instead of preference — and the redesign made the
order user-owned (drag to reorder). So the rehome target is a
dedicated per-profile reference (`fallback_space`,
`KiwiDesk.set_fallback_space`), shown as a badge on the row;
without one, the first-of-list rule still applies, so old
profiles behave unchanged. Pull-to-first was considered and
rejected: it would have made reordering silently change the
fallback. (#68 §3.3, #75)

**Space rows are bordered cards; reorder is an axis-locked
handle drag, not a drag session.** A system drag session's
ghost follows the pointer on both axes and cannot be
constrained, and its drop choreography (snap-back flights,
ghost-over-row double vision) kept reading as broken. The
reorder is therefore a plain vertical `DragGesture` on the
grab handle: the row itself lifts (shadow + slight scale)
and steps slot to slot — it never leaves the column, only
the pointer's vertical position matters, and there is no
ghost at all. (`List.onMove` was rejected too: it brings
list chrome that fights the card sections and shows no
better affordance.) Each row is a bordered card, the handle
flips the cursor to an open hand on hover, and the name is
a visible rounded-border field of fixed width — renaming is
discoverable without clicking first, and the fields align
in a column.

**Space icons are recognition sugar; the name stays primary.**
Optional per-space icon (`space.icon`) shown where scanning
many small items pays off — space rows, monitor chips,
per-space shortcut labels — never as the only signifier.
(#68 §6.5)

**Deleting a space removes every reference it holds** (pin,
Main role, fallback, per-space overrides) — a leftover
reference would silently resurrect the space on the next
profile load. App rules survive by design: they're global,
and another profile may declare a space of the same name.

**Saved profiles lead; Presets demote once one exists.** On
the Profiles tab, the built-in Presets top the list only
while no profile is saved yet — they're a bootstrap tool,
and leading with an empty saved-profiles list would leave
first launch barren. From the first saved profile on, the
order flips: the user's own content takes the top — saved
profiles with the Desktop bindings that reference them
directly beneath — and the full preset list closes the tab.
No disclosure folding on any section — collapsed content
was tried and rejected as visual clutter; a plain order
swap carries the same priority signal.

**Native macOS Spaces read as "Desktop n", never "Space n".**
"Space n" is how KiwiDesk's own virtual spaces read, so
reusing it for Mission Control desktops made the two systems
blur; "Desktop n" is the name Mission Control itself shows.
Binding a profile to a Desktop is dropdown-only: the earlier
draggable profile chips duplicated the dropdown while adding
a chip palette row and drop-target styling — a second
interaction model with zero extra capability. (#7)

## Icons

**A curated, keyword-tagged icon catalog — because macOS has
no API to list SF Symbols.** The system ships the glyphs but
can't enumerate them at runtime, so every symbol picker ships
its own list. Ours is curated *with search tags* ("mail" finds
`envelope`), which searches better than a raw dump of ~6,000
names ever could. The full catalog stays reachable: any valid
SF Symbol name typed into the search appears as a result, and
any single character (incl. emoji) works via "Use as text".
One `IconPicker` serves mode icons and space icons. (#68 §6.4)

**Browsing is tabbed (Emoji first); search is global.** The
picker's popover splits Emoji and Symbols into segmented
tabs — emoji lead because space icons are the picker's most
frequent use — but a typed query searches both vocabularies
at once (the tabs stand back, like Character Viewer). The
button shows a glyph-sized smiley when no icon is set,
never a "Choose…" label: the text made unset pickers wider
than set ones, so rows wouldn't line up. Clearing is a
control, not a choice: the remove button sits beside the
tabs (disabled when nothing is set) instead of posing as a
grid cell under Recents.

## Shortcuts

**A shortcut is modifiers plus exactly one key.** Carbon's
`RegisterEventHotKey` (one key code + modifier mask) is the
mechanism, chosen because it needs no Input Monitoring
permission. Multi-key chords (⌘J+K) are therefore not
recordable — pressing a second key while the first is held
keeps the first and shows a one-key hint — and a
hand-written `cmd+j+k` is inert and flagged ⚠ unrecognized.
**Modal modes are the layering mechanism**: a mode switch
gives a whole second set of single-key bindings, ergonomically
better than finger-twister chords.

**The recorder locks on full release.** The chord is
snapshotted as keys go down (live preview), modifiers only
accumulate while a base key is held, and the combo commits
when everything is released — so staggered release order or
timing can never corrupt it. Correction is
release-then-press (⌘J, J up, K down → ⌘K); an overlapped
second key keeps the first with a hint. Bare Escape,
click-away, and app deactivation cancel. (#68 recorder UX)

**Duplicates hard-block; system shortcuts soft-warn.**
Recording a combo another KiwiDesk row already holds is
rejected inline with *Steal* (rebind here) and *Go to* (jump
to the holder) — silent duplicates were the #34 bug class. A
macOS system-shortcut collision commits with a persistent ⚠
instead: shadowing a system shortcut can be intentional.
(#33/#34/#35, #68 §3.6.2)

**One recorder at a time.** Starting a recording snaps any
other recording field back instantly. (#33)

## Overrides & appearance

**Overrides are visible-but-inherited, never hidden.** A
per-layout or per-space override row always shows — dimmed
with the inherited global value until its checkbox unlocks
it, and carrying a left accent once overridden so active
overrides form a scannable boundary. Discoverable without an
"Add override…" hunt, quiet without a wall of enabled inputs.
(#68 §3.4)

**Gaps are uniform-first.** One Outer and one Inner slider
for the everyday "more breathing room" action, per-edge
sliders behind a disclosure. When stored edges differ, the
disclosure pre-expands and the master slider disables itself
— asymmetric setups can't be blindly flattened. (#68 §3.14)

**The gap preview is a live 2×2 grid, not a layout
preview.** It teaches the outer/inner vocabulary: a uniform
2×2 shows both gap kinds on both axes, where a skewed
BSP-style split would only add noise at miniature size. It
tracks the sliders live — each of the six stored values maps
through a square-root curve (`GapPreviewScale`, 0–100 pt →
1–14 pt) so everyday 8–20 pt changes move visibly while the
top of the range compresses, and per-edge asymmetry renders
honestly as uneven margins. Deliberately not a "what will my
layout look like" preview — that would be its own component.

**Hex stays a first-class color affordance.** The native
color well is primary, but the `#RRGGBBAA` field remains
beside it — theme sharing via hex strings is a real workflow.
(#68 §3.14)

## Monitors

**One representation: monitor cards.** The old tab rendered
the same space→monitor mapping three ways (proportional
canvas, drag palette, resolution list). Equal-sized cards in
physical x-order hold the space chips that resolve to them;
a dashed "Follows main display" card holds the Main-role
spaces. Chips carry semantic micro-icons (pin/link) rather
than border styles alone (accessibility), ⓧ clears to
automatic, and the context menu is the keyboard/VoiceOver
fallback. macOS's Displays pane owns true spatial layout —
identity + order is enough here. (#68 §3.13)

## App rules

**One row per app, two facets.** "Finder lives on space 2
but its Get Info windows float" used to be two entries in two
differently-shaped lists. Now each app has a Space facet and
a Float facet; the `App:Title` colon syntax is assembled by
the GUI and never shown (it's serialization, not UI). Storage
is untouched, so hand-written configs round-trip. (#68 §3.11)

## Errors & the menu bar

**A half-loaded config is visible state, not a log line.**
`KiwiCore` publishes the issues of the last config load
(broken init.lua, unreadable gui.json, undecodable profile
JSONs); the menu-bar icon shows a distinct config-error badge
(permission warnings still win — without Accessibility
nothing works), and a standalone Config Issues window is
reachable without opening Settings. Profile issues also
refresh on save/delete, so repairing one clears its badge
immediately. (#68 §3.7, #39/#31 own the validation cores)

**The quick menu is for daily driving.** Header row naming
the live profile, a Switch Profile submenu (`load_profile`
finally has a quick path), Config Issues… only while
something is wrong, Support near Quit. Menu entries stay
monochrome template symbols; the colored tiles are a
Settings-window device. (#68 §3.10, §6.2)

## Out of scope, on purpose

- **Onboarding** is a separate follow-up pass (shares only
  the branding glyph). (#68 §5.9)
- **Configurable resize step** (#58) and **2-axis resize**
  (#56) have a reserved slot in Shortcuts ▸ Size & Float;
  the design there is additive so their arrival won't
  re-layout the section.

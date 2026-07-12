---
title: Design Decisions
description: The reasoning behind settled product and UX choices.
---

# Design decisions

The major product/design decisions behind KiwiDesk's Settings
app and menu bar, with the reasoning — so users understand why
things behave the way they do, and contributors don't relitigate
(or accidentally undo) a settled choice. Decisions from the
Settings redesign (#68, PR #88) unless noted; deeper rationale
lives in the linked issues. Architecture and code guardrails
live in `AGENTS.md`, not here.

## Accepted limitations

Some behaviors are *bugs by design* — accepted consequences of a
settled architectural trade, not defects to fix. This table is the
one place that says, for each: it's known, here's why it's
accepted, here's the architectural root, and here's the real fix
where one is planned. Every row links to its full reasoning
elsewhere on this page (or to the issue that owns it).

Convention: when a review or manual pass classifies a behavior as
accepted-by-architecture, it adds a row here **in the same change
set** — the user-facing twin of the `AGENTS.md` §5 guardrail rule.
A row needs an architectural root and, where one exists, the
planned escape hatch; it is not a wontfix dumping ground.

| Behavior | Why it's accepted | Architectural root | Escape hatch / planned fix |
|---|---|---|---|
| In BSP, the inner window of a nested pair can't grow — a "grow" press (or edge-drag) widens its outer neighbor instead. | Its width `r·(1−r)·W` is already maximized at the default ratio, so no resize direction can widen it. | All same-orientation splits share the one per-space ratio; per-node ratios would need a container tree the flat-array model forbids (#56 trade). | **Shipped**: the [`track` layout (#128)](https://github.com/hajiboy95/KiwiDesk/issues/128) — `set_mode(space, "track")` gives every window one true resize target. See [BSP resize is focus-aware in *direction* only](#shortcuts). |
| An extreme *stored* BSP ratio still collapses the space into the overlap cascade — even though the stack layout no longer does. | The stack's layout-time clamp hasn't been migrated to BSP yet; doing it as a follow-up rather than riding the #44 fix keeps that change scoped. | BSP has no effective-ratio clamp authority; the #44 fix (`StackLayout.effectiveRatioRange`) landed in the stack only. | Migrate the clamp principle to BSP (follow-up to [#44](https://github.com/hajiboy95/KiwiDesk/issues/44)). See [The stack cascade is a last resort](#shortcuts). |
| Dragging a stack window's height with the mouse snaps back; only keyboard/CLI `resize("y")` actually moves the vertical share. | Vertical weights are a windowless keyboard/CLI concept; the mouse-drag seam has no window to anchor a weight against. | Per-window vertical weights are session-scoped and keyboard-only by design ([#67](https://github.com/hajiboy95/KiwiDesk/issues/67)). | Use keyboard/CLI `resize("y")`; the mouse asymmetry is deliberate. See [Stack resize is focus-aware](#shortcuts). |
| Mouse-resizing a window in the track layout snaps back on both axes; keyboard/CLI `resize` covers both knobs. | Both track adjustments (the track's weight, the in-track share) key off the dragged window's identity — the same windowless mouse-resize seam as the stack height drag above. | The mouse-resize translation (`MouseResize.translate`) is deliberately windowless; track weights are session-scoped resize state ([#128](https://github.com/hajiboy95/KiwiDesk/issues/128)). | Keyboard/CLI `resize` (both axes) and `move_to_track`; revisit together with the stack height drag if mouse parity is asked for. |
| Holding a key to resize a floating window under-accumulates while a slide/resize animation is still in flight. | Each step re-bases on the last AX-reported frame; mid-animation the AX echo lags, so rapid repeats read stale geometry. | Resize re-bases on live AX state, and AX echoes trail an in-flight animation. | Let the frame settle, or press again once the animation completes ([#129](https://github.com/hajiboy95/KiwiDesk/issues/129)). |
| Animation and screen-selection heuristics assume a single screen; some multi-monitor edge cases aren't fully modeled yet. | These paths were scoped single-screen first; multi-monitor is a tracked frontier, not a regression. | Screen-pick and per-monitor animation heuristics are single-screen by construction. | Multi-monitor hardening (roadmap `plan/06_Roadmap.md`). |
| A window closed *while its native desktop is off-screen* is reported as `reason: vanished`, never as a corrective `closed`; and a real close landing within the ~1 s settle window after a desktop switch can also read `vanished`. | The reason payload (#40) classifies visibility changes at emit time; once a desktop is off-screen, a close there is observationally identical to the vanish that already fired, and inside the settle window a close is indistinguishable from the switch burst. Both self-heal under the documented consumer pattern (events as dirty flags + re-query). | macOS AX only reports the current desktop's windows (the same observation limit behind the SIP-blocked items): KiwiDesk cannot see lifecycle on an off-screen desktop, and the burst is only separable from user closes by time. | Consumers filtering `vanished` refresh on `native_space_change` — the [sketchybar recipe](https://github.com/hajiboy95/KiwiDesk/blob/main/docs/recipes/sketchybar.md) pattern does this already. |
| Dragging a floating window shows no drag ghost and no snap zone, and dropping it over a tiled slot does nothing — in every layout mode. | A floating window has no tile slot: there is no home slot for a ghost to preview and no swap a drop could perform, so a highlight would promise an action that cannot happen. A once-planned opt-in toggle (`drag.ghost.show_for_floating`) was rejected as a no-op for the same reason ([#161](https://github.com/hajiboy95/KiwiDesk/issues/161)); earlier reports of drag visuals on floating windows were [#160](https://github.com/hajiboy95/KiwiDesk/issues/160) — float state silently reverting to tiled on reopen. | Layout algorithms run over the flat array of *tiled* windows only; floating windows are filtered out before slot computation, so no slot geometry exists for them. | `make_tiled` returns the window to the grid; drag visuals resume immediately. |
| At deep BSP splits under extreme ratios, the screen-midpoint side rule can misread which side a "grow" acts on. | Mouse parity is the spec: keyboard matches the mouse's midpoint reading exactly, warts included, so the two never diverge. | The sign is inferred from the focused window's screen-midpoint side (`MouseResize.bspSide`), shared with the mouse for parity. | **Shipped**: the [`track` layout (#128)](https://github.com/hajiboy95/KiwiDesk/issues/128) gives each resize one true target; within BSP the parity is intentional ([#122](https://github.com/hajiboy95/KiwiDesk/issues/122)). |
| When scrolling focus steps *backward* (up/left) toward a window pinned behind the leading edge, keystrokes still reach the previously focused app until the pan settles (one animation length, 50–1000 ms). Forward (down/right) focus and the handoff after closing a window raise immediately, so only the backward slide has the delay. A genuine click on a window KiwiDesk just raised, before that raise's focus echo lands and while focus has already moved to another window in the same scrolling space, is read as KiwiDesk's own echo, so focus re-asserts to that other window. | Raising a pinned-behind row first pops it over the whole screen before the slide starts ([#143](https://github.com/hajiboy95/KiwiDesk/issues/143)); deferring *only* that direction keeps the pinned row reading as a real scroll, while forward moves and closes lay the target on top at once. Echo provenance ([#152](https://github.com/hajiboy95/KiwiDesk/issues/152)) tells KiwiDesk's own raise echoes apart from user focus — tracking every raise whose echo is still in flight — but AppKit gives a click and a raise echo the same shape, so the window focus has already moved to wins the tie over a still-unechoed self-raise. Normal for scroll-style window managers. | AppKit keyboard status only moves with the real AX raise, and the backward raise waits on the animation-settle signal (shared with the z-order restore). | Global Carbon hotkeys are unaffected (they reach KiwiDesk regardless of the key app); `animations.set_on_scrolling(false)` disables the slide and restores instant transfer. |

### Blocked by macOS (SIP)

A separate class: capabilities macOS forbids without disabling
**System Integrity Protection**. KiwiDesk drives native Spaces
through private SkyLight/CGS symbols resolved at runtime, and the
few operations that *write* the native-Space arrangement are
gated by SIP. KiwiDesk **never disables SIP or asks a user to** —
a disabled-SIP requirement is a non-starter for a window manager
(`AGENTS.md` §5), so these stay unimplemented rather than shipping
a fragile fast path with no safe fallback. Unlike the table above,
the root is the OS, not our architecture, and there is no in-app
escape hatch — only Apple exposing a supported API. They are
tracked, not abandoned:

- **Move the focused window to another native Space**
  ([#25](https://github.com/hajiboy95/KiwiDesk/issues/25)).
- **Switch the visible native Space programmatically**
  ([#26](https://github.com/hajiboy95/KiwiDesk/issues/26)).
- **Restore windows across all native Spaces on quit**
  ([#70](https://github.com/hajiboy95/KiwiDesk/issues/70)).
- **Place a window above the top screen border** — the
  WindowServer silently rejects any frame above the visible
  area's top edge. (Partial left/right/bottom overflow is
  allowed; fully offscreen frames clamp back to a title-bar
  sliver on every edge.) So a
  vertical scrolling row scrolled past the top cannot tuck above
  the screen with its lower strip peeking, the way a true
  scroll would; `ScrollingLayout` pins those rows at the border
  instead — their *upper* strip peeks — so retile targets stay
  achievable and the already-there tolerance keeps working.
  Horizontal scrolling is unaffected
  ([#139](https://github.com/hajiboy95/KiwiDesk/issues/139);
  the pin shipped with
  [#66](https://github.com/hajiboy95/KiwiDesk/issues/66)).
  On the other edges KiwiDesk pins far-offscreen slots at its
  own fixed sliver, safely above the OS minimum, for the same
  achievable-target reason
  ([#142](https://github.com/hajiboy95/KiwiDesk/issues/142));
  stashed inactive-space windows park at the same
  floor-derived sliver
  ([#148](https://github.com/hajiboy95/KiwiDesk/issues/148)).

All of these are collected in
[#140](https://github.com/hajiboy95/KiwiDesk/issues/140).

## Navigation & saving

**Two-group sidebar, topic-named: "Design" vs "System".**
Every control either travels with the profile being edited or
is app-wide, and the old flat tabs hid which was which — the
single biggest source of confusion. The sidebar makes the
split part of the navigation, but names the groups by *topic*,
not scope (System Settings groups by subject, never by
per-machine/per-user scope): **Design** holds the
profile-scoped content (Spaces, Layout, Monitors, Appearance,
Behavior); **System** holds the app-level surfaces (Profiles,
Shortcuts, App Rules, General). Scope stays the underlying
model — the header's profile picker shows which profile
"Design" edits — it's just no longer the group label, since a
new user can't predict placement from "is this a Profile
thing?". The membership is unchanged from the earlier "This
Profile" / "Whole App" split; only the labels are topical.
(#68 §3.1)

**One stable save footer: Revert / Save a Copy As… / Save.**
The old footer showed up to seven differently-labeled verbs
depending on invisible mode state, but they expressed only
two intents: "persist to what I'm editing" and "duplicate
under a new name". Three stable slots, clustered at the
trailing edge. The header's profile picker names the edit
target authoritatively — a destination caption beside Save
duplicated it, read as confusing, and its fixed width split
the button cluster apart, so it was dropped. Adopt is not a
save verb — it lives with the raw-Lua content it migrates.
(#68 §3.12)

**One header bar: section title leading, profile picker
trailing; status only when non-nominal.** The section name and
the profile edit-target picker are related facts (what am I
looking at / in which profile), so they share one titlebar row
instead of a title stacked over a separate profile banner. The
picker moves into a trailing toolbar item, shown everywhere
except General (`showsProfileContext`) — App Rules keeps it
because its rules target profile-scoped spaces, so it is *not*
the same exclusion as `visibleWhileEditingStoredProfile`.
The status sentence is demoted to a conditional strip that
mounts only when there's something non-nominal to say
(divergence, unsaved, built-in, no-match, or a warning) — a
synced profile says nothing, so the common case is a single
bar and content scrolls straight under the blurred titlebar.
(#68 §3.1)

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

**Live state is the single source of truth for which spaces
exist; `gui.json` mirrors it, never the reverse.** A deletion
prunes the space from live immediately (windows rehome to the
fallback), not only when a later profile load happens to drop
it — otherwise the next save re-captured it from live and it
reappeared. The sidecar's `spaces` list is kept a faithful
copy of live *as of the last authoritative reconcile*: every
explicit prune — a `load_profile` (including a scripted
Lua/CLI one) or an in-place edit — writes the live set back.
Hardware-driven applies (monitor change, native-Space
binding) deliberately don't prune or mirror (the
no-shuffle-on-reconnect rule), so between such an event and
the next reconcile the list may lag; the cold-boot seed and
the next prune re-converge it. The one place `gui.json` seeds
*into* live is cold boot — a space that lives only in the
sidecar (no profile, pin, window, or `set_mode` backs it) is
seeded so it survives the reload. That seed is safe against
resurrecting a profile-pruned space precisely because the
mirror keeps the list current. Deletion is per-profile:
each profile is its own file, so removing a space from the
active profile never touches another profile that still
declares a space of the same name. (#77)

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

**Profiles may override *behavior* settings, never *routing*
ones.** A profile owns tiling, and may also carry a sparse
override of a global setting that shapes how the workspace
*behaves while the profile is active* — keybindings today
(`Profile.modes`), app rules next (#109). It may never
override a setting that *selects or routes* the profile
itself: the native-Space→profile bindings decide *which*
profile loads, so a profile owning part of that map would be
a self-reference (load A → A rebinds Desktop 2 → B → …). The
GUI language is a second hard exclusion for a different
reason — it lives in `UserDefaults`, outside config ownership
entirely, and must never touch a sidecar. Every override is
the base overlaid with a sparse diff (absent inherits; a
tombstone removes), never a second home for the setting. Each
new one is added deliberately and parity-tested, templated on
the keybinding override's seam — not folded into a generic
primitive, which stays unjustified until a real second
flat-map client exists (one client removes no duplication).

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
**Switch-mode shortcuts sit right under the mode strip.**
The rows that switch modes render directly beneath the strip
that defines the modes, ahead of the action groups — the
definition and its bindings read as one unit. The strip's
caption also states that "default" is the standard mode and
always the active one after an app start. Renaming a mode
shares Delete's gate (base modes are protected in
profile-override editing, #55) and rewrites the switch-mode
rows of the config being edited through the catalog's
single authority, so writer and import classifier keep
matching byte-for-byte (#4). Scope: a stored profile whose
sparse override targets the old name keeps it and
resurfaces it as a standalone mode — the same accepted
pre-release gap Delete has (the edit is a draft until Save,
so stored files can't be chased at click time). Saved
profiles get the same affordance: a pencil beside the
profile name renames immediately — file, adopted name, and
native-Space bindings follow, like Delete and make default.

**Modal modes are the layering mechanism**: a mode switch
gives a whole second set of single-key bindings, ergonomically
better than finger-twister chords.

**The recorder locks on full release; the preview downgrades
lazily.** Releases work through a burst window (~a third of
a second): the first release that downgrades a chord stashes
it, and a full release within the window locks the stash —
so staggered release order can't corrupt the combo (⌘ let go
a split second before J still locks ⌘J). The DISPLAY keeps
showing the stashed chord for that same window: an instant
downgrade made the combo visibly vanish right before every
normal lock-in. Only a genuinely lingering hold settles the
preview to what is actually held — then nothing stale can
lock, the field stays recording, and re-entry just works
(a preview that kept showing released keys read as stuck).
Correction is release-then-press (⌘J, J up, K down → ⌘K); an
overlapped second key keeps the first with a hint. Bare
Escape, click-away, and app deactivation cancel. (#68
recorder UX)

**Duplicates hard-block; system shortcuts soft-warn.**
Recording a combo another KiwiDesk row already holds is
rejected inline with *Steal* (rebind here) and *Go to* (jump
to the holder) — silent duplicates were the #34 bug class.
The taken-by notice already shows *while the chord is being
formed* (live in-app check against the edited bindings); a
macOS system-shortcut collision instead commits with a
persistent ⚠ — shadowing one can be intentional, and a
live system check could go stale. Conflict surfaces
(the banner and the "Assigned to…" row) re-derive from live
bindings on every render, so fixing the conflict anywhere —
clearing either row, deleting the holder — retires them
without a dismiss. (#33/#34/#35, #68 §3.6.2)

**One recorder at a time.** Starting a recording snaps any
other recording field back instantly. (#33)

**A catalog label's identity and its display text are two
different fields.** `KeybindingCatalog`'s `NavCommand.label`
(and `StandardLayout.name`/`.summary`) stay the stable,
English canonical text — persisted into `KeyBinding.label`,
matched on by `KeybindingImportClassifier` (keyed off `lua`,
never display text), and used to seed a new saved profile's
name (`freeName(base: layout.name)`). Only a separate
`resolvedLabel` / `displayName` / `displaySummary` — resolved
through `L(...)` at render time, keyed by the stable field —
translates. This keeps a language switch from ever rewriting
persisted data or breaking import classification (issue #9
follow-up: the original literal-routing sweep covered SwiftUI
view literals but missed catalog-defined strings).

**First run seeds a starter shortcut set — base tier, only
into emptiness.** A fresh install used to boot with zero
shortcuts (the default mode existed but was empty): a GUI-first
user had no way to focus or move a window until they authored
every combo. Now `Core.DefaultKeybindings` seeds a starter set
(⌥HJKL focus, ⌥⇧HJKL swap, ⌥digit / ⌥⇧digit per-space, ⌥-/⌥=
width resize, ⌥⇧-/⌥⇧= height resize, ⌥T float) with one
guard everywhere: **only when no
mode carries a single binding** — a user- or Lua-authored
binding anywhere blocks the seed, making it idempotent and
never destructive. The set lives in the **base `gui.json`
modes**, never a profile override (profiles stay
tiling-plus-sparse-behavior, #55): on a true first launch (no
`init.lua`) the seeded model is persisted so the very first
boot is GUI-managed and the shortcuts actually fire; with a
bindings-free `init.lua` the seed appears in the editable
model and persists on the first Save. Per-space rows are
**position-based** (⌥3 = third space in display order,
whatever its name), generated only for spaces that exist at
seed time and capped at nine — no dead rows targeting
nonexistent spaces. The seeded Lua and labels mirror
`KeybindingCatalog` byte-for-byte (guarded by
`DefaultSeedCatalogParityTests`) so the rows stay presets, not
Custom (#4). (#91)

**Resize is truly 2-axis via two per-space BSP ratios; per-node
ratios are rejected.** `resize("x")` and `resize("y")` used to
write the *same* scalar (one `splitRatio` for every BSP split, one
`masterRatio` for stack) — the axis only scaled the step, so a
"resize vertically" key visibly changed column widths. #56 gives
BSP two ratios per space — `ratio_h` for side-by-side splits,
`ratio_v` for stacked splits — so each axis moves its own knob,
in commands and in mouse resize (a width-dominant drag edits H, a
height-dominant one V). **Per-node ratios were deliberately
rejected**: they require stable per-split identity, i.e. a
container tree, which the flat-`[WindowID]`-array model forbids
(AGENTS.md §5) — two global ratios per space is the design that
fits the architecture. The Size & Float catalog grows from 3 rows
to 5 (Grow/Shrink × width/height + Make floating), all authored
from the one shared `resize.step`; scrolling still resizes its
slot along its own scroll axis whichever axis is passed, and
monocle/grid/floating stay explicit no-ops. No back-compat alias
for the old `bsp.set_ratio` / `layout.bsp.ratio` name
(pre-release, single user). (#56)

**Stack resize is focus-aware, and its vertical weights are
ephemeral by design.** The stack layout's resize used to always
move the master/stack split toward the master, whichever window
was focused. #67 makes both axes act on the *focused* window:
`resize("x")` moves the split in the direction that grows the
focused window's zone (flipping the old always-grow-master
behavior when a stack window is focused — intended), and
`resize("y")` grows the focused window's vertical share of its
column via **per-window weights** — a `[WindowID: Double]` map
in `Space`, parallel to the flat window array (a map, not a
tree: it adds no structure the flat-array guardrail forbids).
The weights are **session-scoped and never serialized**: a
`WindowID` is an OS window handle, unstable across app and
window relaunches, so there is nothing durable to persist a
weight against — persisting them would at best restore sizes to
the wrong windows. They are pruned when a window leaves the
space. When a weighted share drops below `min_window_size`, the
column falls back to the existing overflow cascade (weights
apply to the fully-tiled case only), and the resize command
caps weight *growth* at that cliff so presses past it cannot
ratchet the stored weight invisibly; clamping the *master
ratio* against min window size stays a separate issue (#44).
One deliberate asymmetry: a stack height *drag* still snaps
back (the mouse seam is windowless); only the keyboard/CLI
`resize("y")` moves weights. (#67)

**The stack cascade is a last resort; extreme ratios clamp at
layout time, and interactive writes cap at the visible cliff.**
An out-of-range `master_ratio` used to collapse the whole space
into the OverlapStack cascade the moment a second window opened
(#44). Now the layout clamps the *effective* ratio to the widest
value keeping both zones ≥ `min_window_size`
(`StackLayout.effectiveRatioRange`, the single authority), and
cascades only when two min-size zones cannot coexist at any
ratio. The **stored** config value stays untouched — a ratio too
extreme for this display is honored again on a wider one — but
the **interactive** paths (keyboard `resize("x")`, mouse drag)
cap their writes at the current display's effective bound
(`StackLayout.cappedRatioWrite`): past it the layout clamps
anyway, so a wider write would only ratchet invisibly — the same
rule as the #67 vertical weight cap, and the same
config-wide/interaction-capped split. Known divergence, on
purpose: **BSP still cascades on an extreme stored ratio** — the
same clamp principle should migrate there in a follow-up rather
than ride the #44 fix. (#44)

**BSP keyboard resize is focus-aware in *direction* only — and
some nested windows cannot grow. Accepted, by architecture.**
Since #122, `resize` infers its sign from the focused window's
slot (the same screen-midpoint side rule a mouse drag uses,
shared as one authority — `MouseResize.bspSide`), so "grow"
grows the focused window's side instead of always the left/top
region. What it deliberately does **not** do is give every
window a growable boundary: all same-orientation splits still
share the one per-space ratio (#56's settled trade — per-node
ratios need a container tree, which the flat-array model
forbids). Concretely: the inner window of a pair nested inside
the second region has width `r·(1−r)·W`, which is *maximized*
at the default ratio — no resize direction can widen it, and
the visible effect of a grow press is its outer neighbor
widening instead. The same is true when dragging that window's
edge with the mouse; keyboard and mouse stay in lockstep,
warts included. This is an **accepted limitation, not a bug to
fix within BSP**: a smarter sign (derivative-based) was
considered and rejected — it cannot help the pinned case and
would split the just-unified mouse/keyboard rule. The real
answer is the `track` layout (#128, shipped), where every
window sits in exactly one track and every resize has one true
target. A **floating** focused window is exempt from all of
this: it resizes itself directly, in every mode (width for x,
height for y, floored at `min_window_size`). (#122, #124,
#129)

**Orphaned space shortcuts are surfaced, never pruned.** A
binding that targets a space by name outlives the space's
presence in the current profile: it stays Carbon-registered
(pressing it recreates the space via `ensureSpace`) and keeps
its combo (the recorder preflight checks every stored row, not
just visible ones). Before #92 it was also *invisible* — the
per-space catalog rows render only live spaces, and the
Advanced drawer shows only `.custom` — so the user was
hard-blocked by a holder they could not see, and the
rejection's *Go to* scrolled to a row that did not exist. Now
a dimmed **Inactive shortcuts** section renders one ordinary
`NavRow` per orphaned binding (detected via
`SpaceLuaArg.targetSpace`, the strict inverse of the catalog's
authoring, against the live-derived space list, #77), so
rebind / clear / *Go to* all work. Pruning on save was
explicitly rejected: a binding orphaned under a 4-space
profile is valid again under the 8-space one — silently
deleting it would lose config across a routine monitor swap.
The rows stay live at runtime by design; only their
*visibility* was broken. (#92)

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

**Colors are just the native well; hex entry rides the
system panel.** The inline `#RRGGBBAA` field originally kept
beside every well (the "hex stays first-class" round-1 call)
turned ten color rows into a wall of text boxes. The system
color panel the well opens has native hex entry in its
sliders pane, so the inline field was redundant chrome and
was dropped — the stored value stays a hex string, and
copy/paste theme sharing works through the panel. (#68
§3.14, revised)

**Appearance ends with the App Bar block.** Gaps and drag
visuals — the everyday controls — come first; the App Bar
(global style + colors + per-layout overrides) is the
deepest rabbit hole in the tab, so it sits last under one
"App Bar" group title instead of pushing everything else
below the fold.

**Drag & Drop explains itself in plain words.** The group
opens with one sentence on what dragging does (swap a
window's position with another), and Ghost / Drop zone are
smaller subsections — each with a one-sentence caption
("the position your window is dragged from" / "will snap
into when dropped") instead of the parenthetical jargon
titles ("dragged window", "swap target"). Section captions
are a `SettingsSection` affordance, so other groups can
adopt the same pattern.

## Shared controls

**Option tabs are a solid sliding-pill segment control.**
Every pick-one-of-few chooser (layout parameters, mouse
resize, icon picker tabs) uses `SegmentedPicker`
instead of the native segmented picker: a capsule track
where the selection is a solid white pill (light gray in
dark mode) wearing the slider thumb's exact crisp shadow —
the earlier soft glass-era shadow read as the pill "fading
out" — and the selected label is larger and semibold
— a real font-size step, because `scaleEffect` rasterizes
the text and reads as blur. Liquid Glass was tried in three
variants (bare, accent-tinted, clear + specular rim) and
dropped: bare glass over the flat settings background reads
as washed-out, tint reads as "blue, not glass", and the
glass layer blurs content near it. ONE persistent pill
slides between segments via matched geometry; styling
conditionally attached to the selected label proved to
crossfade on selection change (the view is destroyed and
recreated), so the pill is a single view that adopts the
selected segment's anchored frame. Segments are equal-width
across the track (full-bleed, like a native window-toolbar
switcher), a deliberate trade against content-sized
segments. One control, one look — a chooser reads as "pick
a tab" everywhere in the settings.

**Sliders share the pill design.** Every value adjuster
(ratios, gaps, sizes) is a `SettingsSlider`: the same capsule
track as the segmented picker, a native-style solid white
thumb that overhangs the track by 2 pt per edge, and a
full-strength accent fill up to the knob — the earlier
translucent fill read as disabled. A clear Liquid Glass
knob was tried and dropped: it refracted the accent fill
beneath it and turned blue. Accessibility is delegated to a
native `Slider` representation, so assistive tech sees
exactly the control it replaces.

**Rows share one label axis and one readout column.** Every
labeled control row (slider, segmented picker, dropdown)
puts its label in the same fixed-width column
(`SettingsMetrics.labelColumn`), so controls start on one
imaginary line across sections instead of each row picking
its own label width; slider readouts share one trailing
column the same way. The rows read the column from the
environment (`\.settingsLabelColumn`), and `OverrideChrome`
narrows it once (`overrideLabelColumn`, paying for its
checkbox prefix) — so a shared row dropped into override
chrome lands on the plain rows' control axis by
construction, not by remembering a width parameter. Numeric steppers are the
deliberate exception: label leading, then an **editable
monospaced field** plus arrows trailing (the native
System-Settings numeric layout) — a value embedded in the
label string ("Columns: 3") read as static text, and even a
plain readout beside arrows read as passive, so the value is
a real `TextField` (type a number, or use the arrows) that
commits and clamps on Return / focus loss. An optional unit
`suffix` ("ms") sits between the field and the arrows. The color grid is the other exception: its
two-column `HexColorField` layout keeps its own label width
(`colorLabelColumn`), because the shared axis would misalign
the grid's second column. Dropdowns ride the axis via
`DropdownRow` and take `.controlSize(.large)` so a menu
button's height sits with the capsule tracks around it.
Within a section, a `Divider` separates geometry controls
from the behavior dropdowns (overflow, new-window placement)
— eight-point uniform spacing alone let unrelated rows read
as one group.

**Buttons stay native; only size marks their class.** No
gradients, borders, or shadows on buttons — the crisp shadow
is reserved for controls that slide (pill, slider thumb).
Class is expressed through the system styles: one
`.borderedProminent` per surface for the commit action
(footer Save, popover confirms), `.bordered` at
`.controlSize(.large)` for row actions (Load, Apply) so they
sit level with the large dropdowns, `.bordered` for list-add
actions (a `.borderless` "Add …" read as caption text), and
`.plain` + underline + hover lift only for inline prose
links. Icon-only inline row actions (trash, ×-clear, the
rename pencil) stay `.borderless` — the native list-row
convention; only text "Add …" actions warrant a border. The
one smaller control is the Shortcuts import button
(`.controlSize(.small)`): it sits inline beside the mode
chips and must not read as a peer tab.

**A recording shortcut field wears an accent halo.** The
armed recorder among dozens of identical rows gets an accent
fill + ring extending slightly past the button — the same
accent-layer vocabulary as `OverrideChrome`'s active rows —
because a tinted border plus a label swap alone was too
quiet to spot at list speed.

**Status badges stay flat.** The thumb/pill shadow is the
settings' vocabulary for "interactive, movable"; putting it
on a passive `BadgeChip` would promise interaction the chip
doesn't have. Depth comes from the hairline stroke both chip
types now share, matching the flat capsule language of
native tags. A non-interactive value state in a control row
(the slot size's "Auto — orientation standard") renders in
the same capsule language rather than as bare gray prose,
which read as skippable filler.

**"Lives elsewhere" pointers are links.** Prose that names
another tab ("configured in the App Bar tab") is a dead end;
those pointers are `CrossReferenceLink`s in the
make-default link's quiet style, jumping the sidebar
selection through an injected `settingsNavigate` environment
action.

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

**A typo is non-fatal, but never invisible.** An unknown call
on `KiwiDesk` or a layout namespace table is a guarded no-op
(logged with a did-you-mean), so one wrong name can no longer
abort init.lua and silently kill every keybinding below it.
The flip side — non-fatal would mean *unnoticed* — is closed
by recording each load-time hit as a config issue feeding the
badge and window above. Runtime hits (a typo inside a
keybinding closure) only log; a persistent "config error"
badge for a transient slip would mislead. (#39)

**The quick menu is for daily driving.** Header row naming
the live profile, a Switch Profile submenu (`load_profile`
finally has a quick path), Config Issues… only while
something is wrong, Support near Quit. Menu entries stay
monochrome template symbols; the colored tiles are a
Settings-window device. (#68 §3.10, §6.2)

**The real logo ships pre-rasterized, no asset catalog.**
Vector masters live in `/assets`; the app bundles plain
PNG/TIFF copies regenerated with macOS built-ins
(`assets/README.md`) because `swift build` on CI runs no
actool. The menu bar and quick-menu header render the mono
mark as an 18 pt template TIFF (macOS tints it; the old SF
Symbol stays as missing-resource fallback). About shows the
wordmark on a fixed light badge — its navy text is fused into
the artwork's compound path, so it cannot follow dark mode.
The color mark is reserved as the `.icns` master for when an
`.app` bundle exists. (#68 §3.8/§3.9)

## Out of scope, on purpose

- **Onboarding** is a separate follow-up pass (shares only
  the branding glyph). (#68 §5.9)
- **Configurable resize step** (#58): the `resize.step` setting,
  `set_resize_step` command, and import shape-match have landed;
  the **in-GUI step control** (a slider in Shortcuts ▸ Size &
  Float) and the **live-rewrite of already-bound rows** are
  deferred to the redesign, whose reserved slot is additive so
  their arrival won't re-layout the section. Until then the
  setting is authoritative only at *authoring* time — it sizes
  newly-authored Grow/Shrink bindings and is recovered from
  bindings on import, but changing it does not rewrite existing
  bound rows (their literal keeps firing). **2-axis resize**
  (#56) has landed: the slot now sits above four per-axis
  Grow/Shrink rows sharing the one step.

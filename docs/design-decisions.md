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
| In the track layout, when more tracks exist than fit side by side at `min_window_size`, the fitting prefix tiles and every surplus track merges into one far-edge **overflow track** whose windows then pile among themselves. | It is the honest answer to "more tracks than can hold the minimum side by side": the fitting tracks stay tiled (the layout keeps its identity), and the surplus collects into a single overflow track whose windows keep a reachable title bar via the downward cascade offset (the app-wide reveal convention). One collector reads better than scattering each surplus track into its own buried slot. | The overflow track is the cap-merge with the cap set to the geometric fit count (`TrackLayout.fitCap` + `counts(cap:)`), rendered by `trackFrames` per `overflow_style`; a fully-degenerate span still falls back to the whole-region `OverlapStack.frames` ([#192](https://github.com/hajiboy95/KiwiDesk/issues/192)). | Widen the display or raise nothing — it is read-time: the overflow track appears and grows as the fit boundary moves. Adjust its pile with `track.set_overflow_style` (`cascade_all` default). |
| `reload_config` (and re-issuing `set_mode(space, "track")`) reseeds a track space's partition to one window per track, dropping a hand-merged arrangement and its track weights. In-track window shares (`stackWeights`) survive. | Reloading re-runs the declarative config, whose `set_mode` is a statement of the space's *declared* default arrangement; re-applying it resets runtime topology, exactly as it re-centers a scrolling viewport. A same-session **wake/unlock** restore is different — it is involuntary, so it *preserves* the partition (carried in the state snapshot). | The break markers/track weights are session-scoped runtime state ([#128](https://github.com/hajiboy95/KiwiDesk/issues/128)), the `scrollOffset` precedent; an explicit `set_mode` re-apply reseeds by design. | Rebuild the arrangement after a reload (a few `move_to_track` presses); the wake/unlock path already survives it. |
| `track.swap` refuses a swap that would touch the **overflow track** while it folds two or more marker-tracks together — under a fixed limit (`auto_tracks` off, more marker-tracks than `count`) *or* a geometric fold on a display too narrow for the tracks at `min_window_size`. | The folded slot is a read-time merge over the marker partition — its slices have no marker identity, so exchanging them would re-derive a *different* composition after the swap (windows leaking between visible tracks). Rewriting markers to pin the view would destroy the grandfathered partition instead. | The guard gauges the fold against the render's own effective cap — the fixed limit AND the geometric fit (`TrackLayout.overflowCap` / `geometricCap`, shared with the layout math) — and rejects only a swap whose own or target track is the folded slot; two normal tracks still swap ([#182](https://github.com/hajiboy95/KiwiDesk/issues/182) review, widened by [#198](https://github.com/hajiboy95/KiwiDesk/issues/198)). | Raise the track limit, turn automatic tracks on, or widen the display, then swap; `move_to_track` still works under the merge. |
| Holding a key to resize a floating window under-accumulates while a slide/resize animation is still in flight. | Each step re-bases on the last AX-reported frame; mid-animation the AX echo lags, so rapid repeats read stale geometry. | Resize re-bases on live AX state, and AX echoes trail an in-flight animation. | Let the frame settle, or press again once the animation completes ([#129](https://github.com/hajiboy95/KiwiDesk/issues/129)). |
| Animation and screen-selection heuristics assume a single screen; some multi-monitor edge cases aren't fully modeled yet. | These paths were scoped single-screen first; multi-monitor is a tracked frontier, not a regression. | Screen-pick and per-monitor animation heuristics are single-screen by construction. | Multi-monitor hardening (roadmap `plan/06_Roadmap.md`). |
| A window closed *while its native desktop is off-screen* is reported as `reason: vanished`, never as a corrective `closed`; and a real close landing within the ~1 s settle window after a desktop switch can also read `vanished`. | The reason payload (#40) classifies visibility changes at emit time; once a desktop is off-screen, a close there is observationally identical to the vanish that already fired, and inside the settle window a close is indistinguishable from the switch burst. Both self-heal under the documented consumer pattern (events as dirty flags + re-query). | macOS AX only reports the current desktop's windows (the same observation limit behind the SIP-blocked items): KiwiDesk cannot see lifecycle on an off-screen desktop, and the burst is only separable from user closes by time. | Consumers filtering `vanished` refresh on `native_space_change` — the [sketchybar recipe](https://github.com/hajiboy95/KiwiDesk/blob/main/docs/recipes/sketchybar.md) pattern does this already. |
| Dragging a floating window shows no drag ghost and no snap zone, and dropping it over a tiled slot does nothing — in every layout mode. | A floating window has no tile slot: there is no home slot for a ghost to preview and no swap a drop could perform, so a highlight would promise an action that cannot happen. A once-planned opt-in toggle (`drag.ghost.show_for_floating`) was rejected as a no-op for the same reason ([#161](https://github.com/hajiboy95/KiwiDesk/issues/161)); earlier reports of drag visuals on floating windows were [#160](https://github.com/hajiboy95/KiwiDesk/issues/160) — float state silently reverting to tiled on reopen. | Layout algorithms run over the flat array of *tiled* windows only; floating windows are filtered out before slot computation, so no slot geometry exists for them. | `make_tiled` returns the window to the grid; drag visuals resume immediately. |
| The Layout Defaults schematics are fixed illustrative diagrams (a handful of tiles, capped with a "+N" chip), not a render of your actual window count or arrangement. | They answer "what does this value look like" from the *staged config* alone; a faithful desktop simulation would need live window state (an AX read) and re-introduce exactly the live-apply coupling #123 rejects. Monocle's diagram shows its focus-cycle navigation model, not tiling geometry (it has none). | The schematics are pure SwiftUI over the config model (`LayoutSchematicKit`), by the #123 never-live-apply principle. | None needed — the preview is for judging values pre-Save; Save and observe the real windows ([#125](https://github.com/hajiboy95/KiwiDesk/issues/125)). |
| At deep BSP splits under extreme ratios, the screen-midpoint side rule can misread which side a "grow" acts on. | Mouse parity is the spec: keyboard matches the mouse's midpoint reading exactly, warts included, so the two never diverge. | The sign is inferred from the focused window's screen-midpoint side (`MouseResize.bspSide`), shared with the mouse for parity. | **Shipped**: the [`track` layout (#128)](https://github.com/hajiboy95/KiwiDesk/issues/128) gives each resize one true target; within BSP the parity is intentional ([#122](https://github.com/hajiboy95/KiwiDesk/issues/122)). |
| When scrolling focus steps *backward* (up/left) toward a window pinned behind the leading edge, keystrokes still reach the previously focused app until the pan settles (one animation length, 50–1000 ms). Forward (down/right) focus and the handoff after closing a window raise immediately, so only the backward slide has the delay. A genuine click on a window KiwiDesk just raised, before that raise's focus echo lands and while focus has already moved to another window in the same scrolling space, is read as KiwiDesk's own echo, so focus re-asserts to that other window. | Raising a pinned-behind row first pops it over the whole screen before the slide starts ([#143](https://github.com/hajiboy95/KiwiDesk/issues/143)); deferring *only* that direction keeps the pinned row reading as a real scroll, while forward moves and closes lay the target on top at once. Echo provenance ([#152](https://github.com/hajiboy95/KiwiDesk/issues/152)) tells KiwiDesk's own raise echoes apart from user focus — tracking every raise whose echo is still in flight — but AppKit gives a click and a raise echo the same shape, so the window focus has already moved to wins the tie over a still-unechoed self-raise. Normal for scroll-style window managers. | AppKit keyboard status only moves with the real AX raise, and the backward raise waits on the animation-settle signal (shared with the z-order restore). | Global Carbon hotkeys are unaffected (they reach KiwiDesk regardless of the key app); `animations.set_on_scrolling(false)` disables the slide and restores instant transfer. |
| `mouse.follows_focus` is a **per-profile** setting: switching profiles can silently flip mouse-follows-focus, and a profile saved before the toggle existed loads with it off. | It lives on the settings root profiles serialize — the same home as `animations.*` and `mouse_resize` ([#186](https://github.com/hajiboy95/KiwiDesk/issues/186)); standing up the sparse behavior-override seam (`KeyModeOverride`-style) for one bool is exactly the premature generic override AGENTS.md §5 forbids until a second client exists. | Profiles serialize `TilingSettings` wholesale, and missing keys decode to their defaults by the profile contract. | Set the toggle in each profile you use (re-saving captures it); revisit the placement if a real global-behavior tier ever emerges. |
| On macOS 14.0–14.3 the quick menu's checked layout shows no "not saved to profile" subtitle when the session layout drifts from the profile; the menu itself still works. | `NSMenuItem.subtitle` is a macOS 14.4 API and the deployment target is 14.0; a hand-rolled attributed-title fake would fight the system menu rendering for a cosmetic hint ([#123](https://github.com/hajiboy95/KiwiDesk/issues/123)). | The drift hint rides a system menu affordance that arrived mid-major-release; the same drift is still visible in Settings (layout caption + footer lines). | None needed — macOS 14.4+ shows it; older point releases read the drift in Settings. |
| While the Settings window is open, a `set_mode` issued from a hotkey, Lua, or the CLI does not update the layout-drift captions (Spaces caption, footer lines, Revert enablement) until the window is reopened or a quick-menu layout action fires. | The captions render a snapshot refreshed on window `show()` and by the quick menu's own actions; wiring the GUI into the core event bus for one cosmetic caption would add a GUI↔engine subscription seam nothing else needs ([#123](https://github.com/hajiboy95/KiwiDesk/issues/123)). | Drift is a transient computed by direct comparison (never latched into `isDirty`/`profileDirty`), so nothing marks the view model stale on external commands; the quick menu always recomputes on open and is never stale. | Reopen the Settings window (every `show()` reloads), or switch via the quick menu, which refreshes the captions; revisit if the GUI ever subscribes to core events for another feature. |

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

## Layout navigation & overflow models

Two facts about each layout are invisible without reading its
implementation, yet several cross-layout behaviors turn on them:
**how it navigates** (a geometric neighbor search over calculated
slots, or an array-order step along the flat window list) and
**whether it can produce an overflow pile** (an `OverlapStack`
cascade it falls back to when windows stop fitting at
`min_window_size`). This bit the swap-skip-cascade fix (#172),
which needs a geometric path *and* a separate array-index path —
and track was nearly mis-classified as "already fine" because its
array navigation plus new overflow piles (#128) were written down
nowhere.

There are exactly **two** navigation models, and every layout is
one of them: **geometric** (a neighbor search over calculated
slots — BSP, Stack, Grid) or **array-order** (steps the flat
window array — Scrolling, Monocle, Track). The "how" column below
names only *how that one layout walks its slots* — which axes it
steps, cycle vs step, any cross-axis fallback — a detail of the
same model, **not** a further model. Grep the cited symbol for
detail:

| Layout | Model | How it walks | Overflow → pile? |
|---|---|---|---|
| **BSP** | geometric | `Navigation.neighbor` over slots | yes — an extreme stored ratio cascades the whole space (`BspLayout` → `OverlapStack`) |
| **Stack** | geometric | `Navigation.neighbor` over slots | yes — a column overflow cascade / `cascade_all` (`StackLayout`) |
| **Grid** | geometric | `Navigation.neighbor` over slots | yes — a last-cell pile (rigid/dynamic past the cap) or a whole-grid cascade at min-size (`GridLayout`) |
| **Scrolling** | array-order | steps along the scroll axis (`scrollingStep`), geometric fallback cross-axis | no min-size cascade — the edge pile (#142) is a viewport pin, not an `OverlapStack` fallback |
| **Monocle** | array-order | steps along the orientation, wraps iff `wrap_focus` (`monocleCycle`) — same 1-D shape as scrolling | no — every window shares one frame |
| **Track** | array-order | steps both axes (`trackStep`) | yes — surplus tracks merge into one far-edge **overflow track** (`OverlapStack`) shaped by `overflow_style` (#192, default `cascade_all`); normal tracks always `cascade_overflow` |
| **Floating** | none | no slots | n/a |

The two models need different handling for anything pile-aware:
geometric layouts **exclude** the focused window's pile-mates from
the candidate set, array-order layouts **skip** their array
indices (#172). Both share one geometric detector,
`Navigation.pileMates`.

**Two vocabularies, one split (#185 review, 2026-07-12):**
*navigation* (`focus`, window `swap`) is spatial and
layout-agnostic — left/right/up/down everywhere, per the table
above — while the two *track sequence verbs* (`move_to_track`,
`track.swap`) speak **prev/next**. They operate on the 1D track
sequence, not on geometry: prev = lower array index (the column
to the left / the row above), next = higher (right / below).
This kills the per-axis inert direction pair (with compass
arguments, two of four bindable rows were always dead keys) and
a binding survives an axis flip. Do not extend prev/next to
`focus` — that would fork the navigation model for one layout —
and do not add compass aliases to the sequence verbs.

**Track is guided by copy, not gated (#188, 2026-07-12):** an
earlier design put the track layout's multi-window surfaces
(the cap, `new_window`, `move_to_track` / `track.swap` and their
shortcuts) behind a global `set_track_advanced` switch, default
off, with the shortcut rows inert and hidden until it flipped
(#181). That was reversed: every track surface is always
visible and always works. Newcomers are oriented with copy
instead — a caption at the top of Layout Defaults ▸ Track marks
it a more advanced layout, and the "Move to track" shortcut
subheader carries "(only relevant if you're using the track
layout)". A blocking flag bought guidance at the cost of a
whole machinery — inert-but-stored keybindings, a resolution
clamp, silent-steal conflict handling — and made unbound track
rows in another layout read as broken rather than simply
irrelevant. Copy carries the same message with none of that.

**The overflow track is read-time, not stored (#192, 2026-07-12):**
when there are more tracks than the space's normal capacity, the
fitting prefix tiles and the surplus merges into one far-edge
overflow track. Normal capacity is the **Track limit** N when
automatic tracks is off (so a limit of N shows up to N normal
tracks **plus** one overflow track — `trackCap` is `count + 1`,
and a new `own_track` window past N opens the overflow track
rather than joining), or **how many fit at `min_window_size`**
when automatic is on. Geometry always caps the total: if
capacity + 1 columns can't hold the minimum, the fit count
(`TrackLayout.fitCap`) reduces the columns at layout time,
folded through the existing `counts(cap:)` primitive — so the
overflow track moves on its own as windows are added or the
display changes; nothing is written into the window array or the
break markers. Spawn placement stays
geometry-free (the flat-array / pure-layout invariant, AGENTS.md
§1/§5): a window lands by `new_window` / `new_window_position`
and simply falls into the overflow track's slice at render time.
`overflow_style` shapes only that overflow track (default
`cascade_all`); every normal track's own overflow is always
`cascade_overflow`. An earlier "overflow-aware spawn" idea —
shifting windows into a new track at spawn based on available
space — was rejected for putting geometry into state (it would
make spawn outcomes monitor-dependent and non-deterministic).

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

**Live-apply is the rare exception, earned per control — not
per tab.** (Settled 2026-07-10, full-Settings audit; #123.) A
control stays staged behind Save unless it clears one of two
bars: **(a)** it owns no profile state at all (the General ▸
Language picker persists straight to `UserDefaults`, never
`gui.json` — there is nothing to stage), or **(b)** its
feedback loop *is* the live runtime and no in-window
simulation can substitute (the keybinding recorder: the only
way to know a shortcut works is to press it). Everything else
— sliders, colors, pickers, placement grids — stays staged;
where a raw value is hard to judge, build an in-window
preview (the `GapsDiagram` / `DragVisualsEditor`-strip
pattern), never live-apply. Sweep verdicts: Spaces, Behavior,
App Rules, Shortcuts (minus the recorder), and the
native-Space profile bindings are plainly staged. Monitors'
drag-cards and the icon pickers are **self-previewing** (the
control is its own preview — a third category needing neither
live-apply nor a bolted-on preview). Profiles-section
rename/delete/make-default/preset-apply are immediate file
**actions**, not settings — correctly outside this question.
The Spaces tab's per-space layout picker stays staged. **No
control besides the key recorder passes the live-apply bar.**

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

**The edit-target dropdown lists the loaded profile as its own
row — no collapse to Live.** (#209.) The top **Live** entry
edits the running/global config; every saved profile lists
below, the loaded one included. Picking the loaded profile used
to silently remap to Live, which made it the one profile whose
*stored* sparse overrides (key modes #55, app rules #109) could
never be edited — you could only touch the live/global config.
The considered fix — listing the loaded profile **twice**, top
meaning global and list meaning overrides — was rejected as a
menu anti-pattern: the ✓ can't disambiguate two identical rows,
the closed title goes ambiguous, and the discard guard keys on
the profile name. Instead the rows are already textually
distinct (`Live (currently loaded)` vs `Name (currently
loaded)`), so the collapse is simply deleted and each profile
is one real `.storedProfile` target. Editing the loaded
profile is the sole target whose Save hits the screen at once:
`saveEditedProfile` → `reapplyIfInEffect` re-applies it **in
place** (no switch), because it *is* the layout on screen — so
its status caption drops the generic "changes won't switch your
layout" for a truthful "saving re-applies *Name* with your
changes", and the closed menu title reads "*Name* — overrides"
to stay distinct from Live-with-that-profile-loaded.

*The two doors write different layers, by design.* #209 makes
the loaded profile reachable through **both** the Live entry and
its own row, and the two saves touch **disjoint** field sets of
the same file — intentionally, because they edit different
layers of the sparse-override model, not the same data twice:

- **Live Save** (`updateActiveProfile` → `persistProfile` →
  `buildProfile`) adopts the live **tiling** state (`spaces`,
  `spaceModes`, `mainSpaces`, `fallbackSpace`, `settings`) and
  **deliberately preserves** the profile's stored `modes` /
  `appRules` — those are sparse *diffs* against the global base,
  and Live editing changes the base (`gui.json`), never the
  diff.
- **Override-row Save** (`saveEditedProfile` →
  `overwriteProfile` → `applyProfileEdits`) writes the profile's
  sparse `modes` / `appRules` **diffs** (against `baseKeyModes()`
  / `baseAppRules()`) plus its tiling — this is the surface that
  edits the diff.

So "Live leaves `profile.modes` frozen while the row rewrites
it" is the model working, not divergence: one door edits the
base, the other edits the per-profile diff over it. The trap to
avoid is "fixing" `buildProfile`/`persistProfile` to also adopt
`modes`/`appRules` — that would collapse the diff into an
absolute and silently break the sparse override. Pinned by
`ProfileSaveAsymmetryTests` so a future edit that erases the
asymmetry fails red.

**One header bar: section title leading, profile picker
trailing; status only when non-nominal.** The section name and
the profile edit-target picker are related facts (what am I
looking at / in which profile), so they share one titlebar row
instead of a title stacked over a separate profile banner. The
picker moves into a trailing toolbar item, shown everywhere
except General (`showsProfileContext`) — App Rules keeps it
because its rules target profile-scoped spaces (and, since
#109, its Space facet is itself per-profile-overridable).
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

**Quick-menu layout switch is session-only.** Changing the active
space's layout mode from the status-bar quick menu updates the running
state immediately but is session-only by default (temporary). It does
not write to the active profile JSON, letting users experiment with
transient layouts (e.g., trying Monocle momentarily) without
rewriting their configuration. If they want to keep the layout, a
"Save Current Layout to Profile" row is provided. Saving adopts the
whole live state (whole-state snapshot semantics), avoiding partial
saves or complex tracking; a failed save (e.g. a screen-count
mismatch) raises an alert — the menu has no footer to warn in.
Reverting in Settings re-applies the saved profile **only while
layout drift exists** — matching the footer caption that announces
it; a plain staged-edit revert stays model-only, exactly as before.
The drift-revert reuses the in-effect re-apply path, so it also
prunes spaces created since the profile was saved (their windows
move to the fallback space) — Revert means "back to the profile",
not "back minus the layout". Drift captions recompute on window
show and on quick-menu actions, not on external `set_mode`
(hotkey/Lua/CLI) — the next open catches up.

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
*behaves while the profile is active* — keybindings
(`Profile.modes`) and app→space rules (`Profile.appRules`,
#109; the first tier with a tombstone, since un-pinning a base
rule is a meaningful per-profile intent — float rules stay
global for now, their per-profile story is a separate set-diff
design). It may never
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
recordable — the first non-modifier key locks the combo
(#212) — and a hand-written `cmd+j+k` is inert and flagged
⚠ unrecognized.
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

**The recorder snaps in on key-down.** (#212, replacing the
#68 lock-on-full-release machine.) Modifiers can be pressed
and released freely — the preview mirrors what is held — and
the first non-modifier keyDown locks the combo instantly:
that key plus the modifiers held at that moment, the way the
native System Settings recorder reads. Correction is
re-recording (one click). The release model's burst window,
stashed fullest-chord candidate, lazily-downgrading preview,
one-key overlap hint, and mid-chord letter correction all die
with it — in practice they were buggier than the correction
affordance they bought, and their states read as noise. Bare
Escape cancels (Escape with modifiers records — ⌃Escape is a
valid hotkey); click-away and app deactivation cancel
unchanged. A swallowed key-down owns its matching key-up even
if the field disappears or another recorder takes over; a
short timeout bounds that handoff monitor. The live "Already
used by …" notice while forming
a chord went with the release window (its display window is
now zero); the post-commit duplicate hard-block below remains
the conflict surface.

**Duplicates hard-block; system shortcuts soft-warn.**
Recording a combo another KiwiDesk row already holds is
rejected inline with *Steal* (rebind here) and *Go to* (jump
to the holder) — silent duplicates were the #34 bug class. A
collision compares parsed physical shortcuts, so aliases such
as `alt+j` and `option+j` cannot evade the block. A
macOS system-shortcut collision instead commits with a
persistent ⚠ — shadowing one can be intentional, and a
live system check could go stale. Conflict surfaces
(the banner and the "Assigned to…" row) re-derive from live
bindings on every render, so fixing the conflict anywhere —
clearing either row, deleting the holder — retires them
without a dismiss. (#33/#34/#35, #68 §3.6.2)

**One recorder at a time.** Starting a recording snaps any
other recording field back instantly. (#33)

**An armed recorder suspends KiwiDesk's hotkeys.** (#213.) A
combo you are about to bind is often already bound to a window
action, so pressing it to test it would fire that action
mid-capture. While any recorder is open, the manager
unregisters every KiwiDesk Carbon hotkey and re-registers the
current mode when it closes — the suspend/resume round-trip the
exact table, so a mode change made while armed is honored on
resume. The `RecorderCoordinator` drives this on the idle↔armed
edge only, so hopping between fields never bounces the
registration. It never touches macOS/system shortcuts (not ours
to unregister) and needs no Input Monitoring permission — it is
pure Carbon (un)registration. This is the accepted first slice
of the recorder-collision redesign (#213): the "Assigned to…"
row also gains a colour-independent ⚠ glyph so the conflict does
not read by colour alone. The larger pending-candidate model
(candidate-only "Not assigned" state, Replace/Change
transactions) is scoped separately in #213 pending a design
round — the current *Steal*/*Go to* hard-block stays the
shipped conflict UX until then.

**The recorder live-applies on the live target; stored
profiles stay staged.** (#123 Part 1.) A recorder is an input
device — "recorded but inert until Save" broke its mental
model (users pressed the new combo and nothing happened). A
successfully committed recording (or clear) on the live edit
target re-registers the running Carbon hotkeys immediately,
with no file writes. The runtime source starts from the clean
Settings baseline and accumulates **recorder combo mutations
only**: staged Lua bodies, app choices, mode edits, and other
shortcut fields never hitchhike on a recording. A new row's
action is required payload for its first recording; later
non-recorder edits to it stay staged. The base then resolves
through the active profile's override, matching Save + reload
semantics. `isDirty` and the footer keep their meaning ("the
file hasn't caught up"); Save persists base shortcuts globally
in `gui.json`, while stored-profile editing owns sparse profile
overrides.

Re-registration prepares every Lua callback before one atomic
mode-table swap, then activates the preserved runtime mode once
(profile/config applies still reset to default). Feedback is
scoped to the exact row and mode: "Active now" only after that
combo registered in the active mode; inactive-mode, profile-
shadowed, compile-failed, and Carbon-denied states say so instead.
Revert first re-applies persisted state; if the sidecar/profile
became unreadable, an in-memory pre-edit snapshot removes ghost
hotkeys. That snapshot is valid only within its loaded config/VM
generation; a newer authoritative reload wins and retires the
session instead of replaying stale GUI callbacks. Rollback
bookkeeping clears only after one path succeeds.
Editing a stored profile stays fully staged (instant apply would
rewrite the RUNNING hotkeys while the banner says an inactive
profile is being edited); the override banner states that its
shortcuts take effect the next time the profile is active.

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

**The App Bar has its own sidebar destination.** (#229,
superseding the earlier "Appearance ends with the App Bar
block" note.) Appearance kept only Gaps and Drag & Drop —
the everyday controls people revisit — while the App Bar
(global style + ~10 colors + per-layout overrides) was the
deepest rabbit hole in that tab and dominated the scroll. It
became a first-class, deep-linkable destination in the *This
Profile* group, peer of Appearance. It is **not** a tab
strip alongside Gaps/Drag: those are co-active concerns tuned
together in one session, not a mutually-exclusive set, so a
strip would misapply the #205 "tabs fit a fixed exclusive
set" principle. On the new page the ~10 hex colors collapse
behind an **"Advanced colors" disclosure** (shut by default),
keeping only Box / Active box / Highlight — the ones the
preview strip most visibly reflects — inline.

**Drag & Drop explains itself in plain words.** The group
opens with one sentence on what dragging does (swap a
window's position with another), and Ghost / Drop zone are
smaller subsections — each with a one-sentence caption
("the position your window is dragged from" / "will snap
into when dropped") instead of the parenthetical jargon
titles ("dragged window", "swap target"). Section captions
are a `SettingsSection` affordance, so other groups can
adopt the same pattern.

**Ghost and Drop zone are two side-by-side columns.** (#231.)
Each column leads with its own live preview and puts its
controls directly beneath, so tuning a column's border width
never scrolls that preview off-screen — the failure mode of
the earlier one-strip-then-two-stacked-sections layout. They
are a genuine A/B pair (same schema, edited by comparison),
which is exactly where macOS System Settings itself reaches
for twin panels (Displays' Arrangement, Desktop & Dock's
light/dark), so twin columns state the pairing once instead
of duplicating preview-then-controls structure. The shared
corner radius sits full-width above both (it styles neither
alone). In the narrower columns, rows drop the group prefix
already carried by the Border/Fill sub-grouping ("Border
color" → "Color", "Border width" → "Width", "Border
alignment" → "Alignment"), narrowed onto the
`dragColumnLabelColumn` axis via the `settingsLabelColumn`
override; VoiceOver keeps the full name through `a11yLabel`.
The preview honestly renders **Inside vs Outside** border
alignment (inset within the tile vs straddling outward past
its edge, offset scaling with the border width) — the
control was previously dead because SwiftUI `.strokeBorder`
always draws inside; and both the corner-radius and
border-width previews now remap the full slider range instead
of hard-capping halfway (the `AppBarPreviewStrip` fix).

## App Bar

**App Bar position is axis-relative by design.** (#228.) The
position values `start` and `end` resolve to concrete edges from
the layout's orientation — `start` → top (horizontal) or left
(vertical); `end` → bottom or right. The bar always renders on
the edge the position names, so no clamp or mismatch can occur
between the layout's axis and the bar's placement. The old clamped
behavior with four compass values is gone; users can now set one
position value globally and know it behaves consistently
everywhere.

**Tab background and active indicator are orthogonal.** (#228.)
The old coupled `style` enum (`pills` / `segments` / `underline`)
conflated two orthogonal concerns: the per-tab box rendering and
the active-tab marking. The redesign splits them into `tab_background`
(`boxed` / `plain`) and `active_indicator` (`ring` / `edge_mark` /
`gap`), so all combinations are expressible — e.g. boxed + edge
mark (the old "segments" look), plain + edge mark (the old
"underline" look), boxed + ring (the old "pills" look). The two
render rulings (settled 2026-07-14 by UI designer): plain × ring
is a pure inset stroke in the highlight color (no fill, keeps
plain boxless); boxed edge mark insets its ends by the corner
roundness to sit flush inside the curve.

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

**Numeric controls pick one of three idioms by a single
test.** So Settings reads consistently, a numeric setting's
control is chosen by *would a user say a specific number out
loud?* — not by which pane it lives in:

- **`StepperRow`** (typeable field + arrows) for discrete,
  exact values a user names: counts, ms durations, pt
  thresholds — master count, columns/rows, track limit,
  minimum window size, animation duration.
- **Slider + readout** (no typing) for a continuous feel or
  proportion tuned by eye: split ratios, master ratio, gaps.
- **Segmented / toggle** for a non-numeric choice.

Minimum window size migrated slider → `StepperRow` on this
rule (#204): it is a precise pt threshold, not a feel knob.

**Layout Defaults is a per-mode tab strip, not a stacked
scroll (#204).** The layout modes are a fixed, small,
mutually-exclusive set (`LayoutMode` minus Floating), so they
get a segmented tab strip — one mode's editor visible at a
time — instead of every mode stacked in one `ScrollView`. The
strip lands on the profile's most-used mode. The global
minimum window size is pinned *above* the strip because it
feeds every mode (and gates the `OverlapStack` overflow
cascade), so it belongs to none of them. The formerly bundled
`LayoutParamsEditor` (BSP+Stack) and `ScrollGridEditor`
(Scrolling+Grid) were split at the mode boundary so each mode
owns one tab and one schematic.

**Layout schematics are static previews of staged values, not
live (#125).** Every layout mode's tab leads with a small
`GapsDiagram`-family schematic (`LayoutSchematicKit` /
`LayoutSchematicCanvas` hold the shared canvas, tile, and ghost
language) that redraws from the *staged* config as the user
edits — never from live window state, no AX calls. This is the
one non-negotiable: it upholds the #123 never-live-apply
principle (a preview answers "what would this look like" without
mutating the session). No hover, no tap-to-inspect, no
drag-to-preview, and **no animation** — a looping animation
would be architecturally legal (canned, config-driven) but was
rejected on cost: a timer/reduce-motion state machine in every
tile for a pane open seconds at a time. *All six modes get a
schematic, Monocle included* — it draws the **navigation model**
(a fan of full-screen cards + `orientation` cycle chevrons), not
geometry, which both honours its one real knob and removes the
"why is this the one blank tab" inconsistency. Schematics are
deliberate approximations (a handful of tiles, capped with
"+N"), never a simulation of the user's real desktop.

**Intuitiveness over strict Apple-native, where they conflict
(#125, owner call).** The first cut held to Apple's "one static
frame per control" idiom, but that under-delivered on the knobs
whose whole meaning is a transition. So the family uses a
**mixed, deliberately legible grammar**: a **two-frame sequence**
(mini-screen → arrow → mini-screen) for **BSP**, the one mode
where strategy divergence *and* new-window placement only appear
once a third window arrives; **single frames** for the rest,
carrying the conditional fact with one of a small shared
**ghost vocabulary** — a **spawn ghost** (dashed accent tile +
"+", "the next window lands here": BSP's third window, Track's
own-vs-focused track), an **off-monitor ghost** (solid gray,
straddling a drawn screen edge, "a real window scrolled
off-screen": Scrolling), and the pre-existing **empty-cell gap**
(dashed gray, "unused grid space": rigid Grid). Grid draws five
windows so the columns-first/rows-first wrap is visible; Stack's
overflow is a small iconic fanned-pile badge, not a permanently
cascading column. Reserving the two-frame motif to BSP keeps it
*meaningful* — if every mode had two frames, "why two frames"
would stop reading. The app bar shown in Scrolling/Monocle is
**not** drawn into their schematics (one preview, one job); its
presence surfaces as live On/Off state in the `CrossReferenceRow`
that points at the App Bar destination (#229), keeping app-bar
ownership whole.

**A GUI label may diverge from the Lua/JSON wire name when the
label alone is ambiguous (#217).** The Grid picker shows
"Arrange: Columns first / Rows first"; the wire vocabulary
stays `split_direction: horizontal | vertical` (`horizontal` =
Columns first). "Split direction" collided with two opposed
real-world conventions (divider-axis vs stack-axis); the
row/column labels are unambiguous under both. Only the display
label changes — churning the documented verb would widen the
blast radius (override commands, existing configs, testers'
mental model) for no gain. The label locale key was moved with
`scripts/rename-key` (German preserved); the two option labels
are new keys.

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

**Inapplicable controls are greyed, not hidden.** When a
setting makes another control inert — Auto-size grid overrides
the Columns/Rows steppers (#171), Automatic tracks overrides the
Track limit stepper (#178), Fill empty space does nothing in a
rigid grid, the scroll-speed row is dead when Animate focus
shifts is off — the dependent control stays
visible and `.disabled`, never removed. Hiding it would jump
the list layout every time the governing toggle flips, and a
vanished control loses the cue that its stored value is
*preserved* (turn Auto-size back off and the old counts
return). Greying reads as "not right now"; hiding reads as
"gone". Precedent: `scrollSpeedRow` disabled by `onScrolling`.

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

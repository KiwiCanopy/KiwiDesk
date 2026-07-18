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

## Product principle: approachable by default, powerful on demand

KiwiDesk should give a new user a good tiling setup with almost no
configuration — strong defaults and a handful of obvious controls.
That simplicity must never cap what's achievable: beneath every easy
surface is a deeper layer (Lua config, profiles, advanced layouts,
per-space overrides) that's there when wanted and never required to
begin. Depth is a capability you grow into, not a cost you pay
upfront.

This sits alongside the GUI north-star (`AGENTS.md` §2 — simplicity,
intuitiveness, Apple-native feeling), not inside it: the north-star
governs how a surface *feels* and how to break ties; this principle
governs the *shape of capability* — a shallow floor with a high
ceiling. It's why "simplicity-first" doesn't mean "underpowered," and
it's a deeply Apple-native ethos (products that read simple but
reward digging in). The read-only shortcuts panel (#326) is the shape
in miniature: a dead-simple glance surface, with one "Edit in
Settings…" bridge down to the full editor — simple entry, deeper
layer one click away, never forced.

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
| With **"Displays have separate Spaces" on**, native Desktop→profile bindings cannot represent an independent Desktop choice on every connected display; KiwiDesk applies one global active profile. | Basic tiling remains valid, single-display use is unaffected, and users may want to inspect or prepare bindings before changing the macOS option, so hiding or disabling the controls would overstate the limitation. | Native-Space routing resolves one active Desktop number and one active profile for the whole display setup, not a per-display profile tuple ([#8](https://github.com/hajiboy95/KiwiDesk/issues/8)). | Turn the option off in Desktop & Dock Settings, then log out and back in. Onboarding and the binding-section warning share one gate and fire only in the affected multi-display state, never on a single display. See [Shared display Spaces are recommended, not required](#shared-display-spaces-are-recommended-not-required). |
| In BSP, the inner window of a nested pair can't grow — a "grow" press (or edge-drag) widens its outer neighbor instead. | Its width `r·(1−r)·W` is already maximized at the default ratio, so no resize direction can widen it. | All same-orientation splits share the one per-space ratio; per-node ratios would need a container tree the flat-array model forbids (#56 trade). | **Shipped**: the [`track` layout (#128)](https://github.com/hajiboy95/KiwiDesk/issues/128) — `set_mode(space, "track")` gives every window one true resize target. See [BSP resize is focus-aware in *direction* only](#shortcuts). |
| In stack, when the master zone lines up *along* the split axis (e.g. horizontal masters beside a right stack), the masters' individual shares can't be resized: that axis always moves the split, and the other axis beeps. | The split ratio owns its whole axis — giving the same keypress two meanings (split vs weight) by focus zone would make "grow" unpredictable at the boundary. | One knob per axis per arrangement ([#222](https://github.com/hajiboy95/KiwiDesk/issues/222)); weights live on a zone's own lineup axis by construction. | Pick the orthogonal (vertical) master orientation — since the 2026-07-16 default flip the standard side-by-side arrangement sits *inside* this limitation once `master_count` exceeds one — or put the windows that need individual shares in the stack zone. |
| With a leading stack and parallel master lineup, `cascade_overflow` piles the array-earliest masters at the master zone's trailing edge instead of the latest. | Mirroring the master render order keeps the promote/demote boundary beside the stack seam; preserving one trailing-edge, downward-cascade vocabulary matters more than which seniority subset enters that pile. | `StackLayout.mirrorsMasterZone` reverses the master render order before the shared zone-overflow path takes its trailing suffix ([#313](https://github.com/hajiboy95/KiwiDesk/issues/313)). | Use a trailing stack (`right`/`bottom`), an orthogonal master orientation, or `cascade_all` if the subset distinction matters. See [The master zone fills from the stack seam](#shortcuts). |
| An extreme *stored* BSP ratio still collapses the space into the overlap cascade — even though the stack layout no longer does. | The stack's layout-time clamp hasn't been migrated to BSP yet; doing it as a follow-up rather than riding the #44 fix keeps that change scoped. | BSP has no effective-ratio clamp authority; the #44 fix (`StackLayout.effectiveRatioRange`) landed in the stack only. | Migrate the clamp principle to BSP (follow-up to [#44](https://github.com/hajiboy95/KiwiDesk/issues/44)). See [The stack cascade is a last resort](#shortcuts). |
| Dragging a stack window's height with the mouse snaps back; only keyboard/CLI `resize("y")` actually moves the vertical share. | Vertical weights are a windowless keyboard/CLI concept; the mouse-drag seam has no window to anchor a weight against. | Per-window vertical weights are session-scoped and keyboard-only by design ([#67](https://github.com/hajiboy95/KiwiDesk/issues/67)). | Use keyboard/CLI `resize("y")`; the mouse asymmetry is deliberate. See [Stack resize is focus-aware](#shortcuts). |
| Mouse-resizing a window in the track layout snaps back on both axes; keyboard/CLI `resize` covers both knobs. | Both track adjustments (the track's weight, the in-track share) key off the dragged window's identity — the same windowless mouse-resize seam as the stack height drag above. | The mouse-resize translation (`MouseResize.translate`) is deliberately windowless; track weights are session-scoped resize state ([#128](https://github.com/hajiboy95/KiwiDesk/issues/128)). | Keyboard/CLI `resize` (both axes) and `move_to_track`; revisit together with the stack height drag if mouse parity is asked for. |
| The App Bar's icon styles offer System default and Glyphs — never the system's **Dark**, **Clear**, or **Tinted** icon looks as distinct in-app choices. | A synthesized tinted mode was built and stripped (2026-07-17): a luminance ramp over the flattened bitmap can't match Apple's plate-plus-glyph regeneration, and the system-wide Icon & widget style already tints what "System default" shows. Shipping a knock-off would misrepresent the real styles. | macOS exposes no public API that hands an app another app's (or even its own) styled icon rendering or its icon layers — Apple DTS calls it unsupported ([#294](https://github.com/hajiboy95/KiwiDesk/issues/294)). | A private-IconServices probe with public fallback, the SkyLight `dlsym` pattern ([#362](https://github.com/hajiboy95/KiwiDesk/issues/362)); if viable the picker grows the true system styles. |
| While window management is paused (no Accessibility permission), the read-only shortcuts panel shows base `gui.json` bindings *without* the active profile's sparse keybinding override applied. | The panel is a "defined, not live right now" glance while paused; a profile that overrides `modes` (rather than only tiling) is rare, and reading the authored base avoids the empty-live-space-list that would otherwise misfile every space shortcut into Custom. | Without AX the live resolved snapshot (`liveKeybindingSnapshot`) is nil, so the paused path reads `persistedGuiConfig()` (authored `gui.json`) directly instead of resolving base⊕profile ([#326](https://github.com/hajiboy95/KiwiDesk/issues/326)). | Grant Accessibility — the live resolved snapshot then drives the panel. The divergence exists only while paused *and* only for a profile carrying a keybinding override. |
| In the track layout, when more tracks exist than fit side by side at `min_window_size`, the fitting prefix tiles and every surplus track merges into one far-edge **overflow track** whose windows then pile among themselves. | It is the honest answer to "more tracks than can hold the minimum side by side": the fitting tracks stay tiled (the layout keeps its identity), and the surplus collects into a single overflow track whose windows keep a reachable title bar via the downward cascade offset (the app-wide reveal convention). One collector reads better than scattering each surplus track into its own buried slot. | The overflow track is the cap-merge with the cap set to the geometric fit count (`TrackLayout.fitCap` + `counts(cap:)`), rendered by `trackFrames` per `overflow_style`; a fully-degenerate span still falls back to the whole-region `OverlapStack.frames` ([#192](https://github.com/hajiboy95/KiwiDesk/issues/192)). | Widen the display or raise nothing — it is read-time: the overflow track appears and grows as the fit boundary moves. Adjust its pile with `track.set_overflow_style` (`cascade_all` default). |
| `reload_config` (and re-issuing `set_mode(space, "track")`) reseeds a track space's partition to one window per track, dropping a hand-merged arrangement and its track weights. In-track window shares (`stackWeights`) survive. | Reloading re-runs the declarative config, whose `set_mode` is a statement of the space's *declared* default arrangement; re-applying it resets runtime topology, exactly as it re-centers a scrolling viewport. A same-session **wake/unlock** restore is different — it is involuntary, so it *preserves* the partition (carried in the state snapshot). | The break markers/track weights are session-scoped runtime state ([#128](https://github.com/hajiboy95/KiwiDesk/issues/128)), the `scrollOffset` precedent; an explicit `set_mode` re-apply reseeds by design. | Rebuild the arrangement after a reload (a few `move_to_track` presses); the wake/unlock path already survives it. |
| `track.swap` refuses a swap that would touch the **overflow track** while it folds two or more marker-tracks together — under a fixed limit (`auto_tracks` off, more marker-tracks than `count`) *or* a geometric fold on a display too narrow for the tracks at `min_window_size`. | The folded slot is a read-time merge over the marker partition — its slices have no marker identity, so exchanging them would re-derive a *different* composition after the swap (windows leaking between visible tracks). Rewriting markers to pin the view would destroy the grandfathered partition instead. | The guard gauges the fold against the render's own effective cap — the fixed limit AND the geometric fit (`TrackLayout.overflowCap` / `geometricCap`, shared with the layout math) — and rejects only a swap whose own or target track is the folded slot; two normal tracks still swap ([#182](https://github.com/hajiboy95/KiwiDesk/issues/182) review, widened by [#198](https://github.com/hajiboy95/KiwiDesk/issues/198)). | Raise the track limit, turn automatic tracks on, or widen the display, then swap; `move_to_track` still works under the merge. |
| A lone window left behind at quit lands in a quarter-display top-left grid cell instead of keeping its size centered. | The quit grid's dimension formula is deliberately floored at 2×2 ([#197](https://github.com/hajiboy95/KiwiDesk/issues/197) spec): one placement rule for every window count reads predictably, and a quit-time special case would be the only layout math that branches on N == 1. | `QuitGridLayout.dimension(for:targetDepth:)` clamps to 2…4; teardown placement is one-shot, with no live manager to refine it afterwards. | Future `quit.layout` strategies (center, columns, …) slot into the same enum seam; until then, resize the window after quit. |
| Very large window sets exceed the quit grid's density target: past 4×4 the grid stops growing and cells keep cascading deeper, however high `quit.grid_target_depth` is set. | The 4×4 cap is a teardown safety boundary, not a visual preference ([#281](https://github.com/hajiboy95/KiwiDesk/issues/281)): it interacts with minimum window size, cascade reachability, and display geometry, and no live manager remains after quit to correct an unreachable pile. The density target only moves the 2×2→3×3→4×4 growth thresholds. | `QuitGridLayout.maxDimension` is a constant; the target (`quit.set_grid_target_depth`, GUI "Target windows per cell", default 5, range 1–20) feeds only the dimension formula. | Raising the cap would need a separate architecture change deriving a safe per-display limit; until then the cascade keeps every title bar reachable via the pinned offsets. |
| Holding a key to resize a floating window under-accumulates while a slide/resize animation is still in flight. | Each step re-bases on the last AX-reported frame; mid-animation the AX echo lags, so rapid repeats read stale geometry. | Resize re-bases on live AX state, and AX echoes trail an in-flight animation. | Let the frame settle, or press again once the animation completes ([#129](https://github.com/hajiboy95/KiwiDesk/issues/129)). |
| Animation and screen-selection heuristics assume a single screen; some multi-monitor edge cases aren't fully modeled yet. | These paths were scoped single-screen first; multi-monitor is a tracked frontier, not a regression. | Screen-pick and per-monitor animation heuristics are single-screen by construction. | Multi-monitor hardening (roadmap `plan/06_Roadmap.md`). |
| A window closed *while its native desktop is off-screen* is reported as `reason: vanished`, never as a corrective `closed`; and a real close landing within the ~1 s settle window after a desktop switch can also read `vanished`. | The reason payload (#40) classifies visibility changes at emit time; once a desktop is off-screen, a close there is observationally identical to the vanish that already fired, and inside the settle window a close is indistinguishable from the switch burst. Both self-heal under the documented consumer pattern (events as dirty flags + re-query). | macOS AX only reports the current desktop's windows (the same observation limit behind the SIP-blocked items): KiwiDesk cannot see lifecycle on an off-screen desktop, and the burst is only separable from user closes by time. | Consumers filtering `vanished` refresh on `native_space_change` — the [sketchybar recipe](https://github.com/hajiboy95/KiwiDesk/blob/main/docs/recipes/sketchybar.md) pattern does this already. |
| Dragging a floating window shows no drag ghost and no snap zone, and dropping it over a tiled slot does nothing — in every layout mode. | A floating window has no tile slot: there is no home slot for a ghost to preview and no swap a drop could perform, so a highlight would promise an action that cannot happen. A once-planned opt-in toggle (`drag.ghost.show_for_floating`) was rejected as a no-op for the same reason ([#161](https://github.com/hajiboy95/KiwiDesk/issues/161)); earlier reports of drag visuals on floating windows were [#160](https://github.com/hajiboy95/KiwiDesk/issues/160) — float state silently reverting to tiled on reopen. | Layout algorithms run over the flat array of *tiled* windows only; floating windows are filtered out before slot computation, so no slot geometry exists for them. | `make_tiled` returns the window to the grid; drag visuals resume immediately. |
| A window KiwiDesk *ignores* — Ghostty's quick terminal or any user `ignore_rules` app — can sit under a **top** app bar with its title bar (grab handle) hidden, and is never pushed clear the way a tracked floating window is. The bar being invisible over it is the visible symptom. | The top-bar clamp reaches only windows KiwiDesk *tracks*; an ignored window is deliberately outside management entirely — no tracking, no events, no frame assertion — so there is no seam at which to correct it. Clamping it would mean tracking it, defeating the point of ignoring. User-configurable ignore rules ([#176](https://github.com/hajiboy95/KiwiDesk/issues/176)) widen the set of windows this applies to. | Ignored windows are filtered before any state or layout (`FloatDetection.shouldIgnore`); the clamp (`clampFloatsBelowTopBars`) runs over tracked floats only ([#242](https://github.com/hajiboy95/KiwiDesk/issues/242)). KiwiDesk's Settings window is a tracked float, while its panels and borders stay ignored by `EventLoop.shouldIgnoreOwnWindow` ([#177](https://github.com/hajiboy95/KiwiDesk/issues/177)). | Move the ignored app's window by hand, remove its rule, or don't run a top-edge bar over it. |
| Dismissing an ignored panel (Ghostty's quick terminal) suppresses one focus report to the app's main window. Normally that is the spurious post-dismiss report; but if the panel closes *without* re-reporting the main window, the next genuine focus of that same app's main window — before any other app is focused — is suppressed too. | The on-screen [#21](https://github.com/hajiboy95/KiwiDesk/issues/21) distrust, extended across the dismiss transition ([#244](https://github.com/hajiboy95/KiwiDesk/issues/244)). The panel is untracked, so KiwiDesk can only flag "an ignored panel was active" and drop that flag on the next focus — it cannot tell the dismiss re-report from a genuine one. Suppressing a stray follow beats hijacking the user to another space. | The flag (`ignoredPanelActive`) is set when the event loop filters the panel's own focus report and consumed by the next managed-window focus of that app; a dismiss emitting no main-window report leaves it for the following focus. | Focus any other window or app first (clears the flag), then the main window; or simply focus it a second time. |
| The Layout Defaults schematics are fixed illustrative diagrams (a handful of tiles, capped with a "+N" chip), not a render of your actual window count or arrangement. | They answer "what does this value look like" from the *staged config* alone; a faithful desktop simulation would need live window state (an AX read) and re-introduce exactly the live-apply coupling #123 rejects. Monocle's diagram shows its focus-cycle navigation model, not tiling geometry (it has none). | The schematics are pure SwiftUI over the config model (`LayoutSchematicKit`), by the #123 never-live-apply principle. | None needed — the preview is for judging values pre-Save; Save and observe the real windows ([#125](https://github.com/hajiboy95/KiwiDesk/issues/125)). |
| At deep BSP splits under extreme ratios, the screen-midpoint side rule can misread which side a "grow" acts on. | Mouse parity is the spec: keyboard matches the mouse's midpoint reading exactly, warts included, so the two never diverge. | The sign is inferred from the focused window's screen-midpoint side (`MouseResize.bspSide`), shared with the mouse for parity. | **Shipped**: the [`track` layout (#128)](https://github.com/hajiboy95/KiwiDesk/issues/128) gives each resize one true target; within BSP the parity is intentional ([#122](https://github.com/hajiboy95/KiwiDesk/issues/122)). |
| When scrolling focus steps *backward* (up/left) toward a window pinned behind the leading edge, keystrokes still reach the previously focused app until the pan settles (one animation length, 50–1000 ms). Forward (down/right) focus and the handoff after closing a window raise immediately, so only the backward slide has the delay. A genuine click on a window KiwiDesk just raised, before that raise's focus echo lands and while focus has already moved to another window in the same scrolling space, is read as KiwiDesk's own echo, so focus re-asserts to that other window. | Raising a pinned-behind row first pops it over the whole screen before the slide starts ([#143](https://github.com/hajiboy95/KiwiDesk/issues/143)); deferring *only* that direction keeps the pinned row reading as a real scroll, while forward moves and closes lay the target on top at once. Echo provenance ([#152](https://github.com/hajiboy95/KiwiDesk/issues/152)) tells KiwiDesk's own raise echoes apart from user focus — tracking every raise whose echo is still in flight — but AppKit gives a click and a raise echo the same shape, so the window focus has already moved to wins the tie over a still-unechoed self-raise. Normal for scroll-style window managers. | AppKit keyboard status only moves with the real AX raise, and the backward raise waits on the animation-settle signal (shared with the z-order restore). | Global Carbon hotkeys are unaffected (they reach KiwiDesk regardless of the key app); `animations.set_on_scrolling(false)` disables the slide and restores instant transfer. |
| `mouse.follows_focus` is a **per-profile** setting: switching profiles can silently flip mouse-follows-focus, and a profile saved before the toggle existed loads with it off. | It lives on the settings root profiles serialize — the same home as `animations.*` and `mouse_resize` ([#186](https://github.com/hajiboy95/KiwiDesk/issues/186)); standing up the sparse behavior-override seam (`KeyModeOverride`-style) for one bool is exactly the premature generic override AGENTS.md §5 forbids until a second client exists. | Profiles serialize `TilingSettings` wholesale, and missing keys decode to their defaults by the profile contract. | Set the toggle in each profile you use (re-saving captures it); revisit the placement if a real global-behavior tier ever emerges. |
| On macOS 14.0–14.3 the quick menu's checked layout shows no "not saved to profile" subtitle when the session layout drifts from the profile; the menu itself still works. | `NSMenuItem.subtitle` is a macOS 14.4 API and the deployment target is 14.0; a hand-rolled attributed-title fake would fight the system menu rendering for a cosmetic hint ([#123](https://github.com/hajiboy95/KiwiDesk/issues/123)). | The drift hint rides a system menu affordance that arrived mid-major-release; the same drift is still visible in Settings (layout caption + footer lines). | None needed — macOS 14.4+ shows it; older point releases read the drift in Settings. |
| While the Settings window is open, a `set_mode` issued from a hotkey, Lua, or the CLI does not update the layout-drift captions (Spaces caption, footer lines, Revert enablement) until the window is reopened or a quick-menu layout action fires. | The captions render a snapshot refreshed on window `show()` and by the quick menu's own actions; wiring the GUI into the core event bus for one cosmetic caption would add a GUI↔engine subscription seam nothing else needs ([#123](https://github.com/hajiboy95/KiwiDesk/issues/123)). | Drift is a transient computed by direct comparison (never latched into `isDirty`/`profileDirty`), so nothing marks the view model stale on external commands; the quick menu always recomputes on open and is never stale. | Reopen the Settings window (every `show()` reloads), or switch via the quick menu, which refreshes the captions; revisit if the GUI ever subscribes to core events for another feature. |
| If **Spotlight indexing is disabled** for an app's volume (`mdutil -i off`, a locked-down/managed Mac) or the app was **just installed** and isn't indexed yet, the picker shows its **English** disk name instead of the localized one (e.g. "System Settings", not "Systemeinstellungen"). Normally every app is localized correctly. | App names come from Spotlight's `kMDItemDisplayName` — the same index Finder/Dock/Spotlight read, so it localizes from KiwiDesk's English-only process where a bundle-local lookup can't. When Spotlight has no entry there is no public API that localizes the name from such a process (the limit AeroSpace also hits, naming only running apps), so it falls back to `FileManager.displayName`, which resolves in the process's English locale. | `localizedName(url:)` reads `kMDItemDisplayName`, falling back to `FileManager.displayName`; the picker stores the bundle id (`AppRef`) as identity, so the name is presentation only. | Re-enable Spotlight indexing (`mdutil -i on`), or wait for indexing to catch up; the rule keys on the locale-independent bundle id regardless ([#263](https://github.com/hajiboy95/KiwiDesk/issues/263)). |
| The picker's installed-app list is a **one-shot snapshot** taken the first time any picker opens: an app launched mid-session from outside the scanned disk roots (a running-only app like Finder that wasn't running at first open) won't appear until KiwiDesk relaunches. Disk-installed apps are unaffected. | The list is read directly from a process-cached snapshot so the popover renders fully populated the instant it opens — staging it through view `@State` on open raced the popover presentation and rendered blank until a keystroke. Disk apps are already frozen for process life; only the running-app union is time-sensitive, and a settings picker rarely needs an app launched mid-edit. | The picker reads `KeybindingCatalog.installedAppsSnapshot` (a `static let` computed once), not a per-render `installedApps` query, avoiding both the empty-then-fill race and a rebuild per keystroke ([#263](https://github.com/hajiboy95/KiwiDesk/issues/263)). | Relaunch KiwiDesk to re-snapshot; disk-installed apps (the bulk) never need it. |
| An app with **no bundle identifier** (a rare unbundled or legacy helper process) can't be targeted by an app rule (`float_rules`, `ignore_rules`, `app_rules`) or by `pull_or_spawn`; its windows match no rule and tile normally. | App rules key on the bundle identifier because it is the only stable, locale- and rename-proof identity — the display name is presentation, not identity. A name-based fallback for id-less apps would reintroduce exactly the ambiguity (two apps sharing a display name, locale drift) that keying on the id removes, and split the vocabulary into two identity schemes. | Window identity is `NSRunningApplication.bundleIdentifier`, captured once at attach and stored on `ManagedWindow.appBundleID` (`AppRef`); a nil id stays nil and matches no rule ([#262](https://github.com/hajiboy95/KiwiDesk/issues/262)). | None — effectively every user-facing app is bundled and has an identifier; the blind spot is a handful of window-less helper processes not worth managing. |
| A **thick** focus border at **small gaps** makes neighbouring windows' rings touch or visually merge, and at 0 pt gaps they overlap. | The ring is a pure post-layout overlay with no gap coupling (coupling would leak a visual setting into pure layout math). Its configured width is the full outward reach; a renderer-only overlap sits behind the target and does not count toward visible thickness or gap fitting (rounded keeps a small seam allowance, while square reaches deeper under the corner reveal). The failure mode is a soft visual merge, never window-content clipping. An automatic minimum-gap floor was rejected: silently widening a user's `gap = 0` the moment borders turn on is paternalistic and changes a value the user set; `border.fit_gaps` stays the opt-in escape hatch. | The border is rendered independently of layout ([#278](https://github.com/hajiboy95/KiwiDesk/issues/278)); the width is bounded to 20 pt, but gaps and border width are set separately. | Set gaps at least as wide as the border (or run `border.fit_gaps`), or lower the width; the default 2 pt border is imperceptible at any typical gap. |
| The focus ring is drawn **below** each window (its lower reach picks up the window's own drop-shadow, and the corner is a filled seam rather than a floating hairline), not on top. | Below-order is immune to the per-keystroke compositor reorder storms some apps (Firefox/Zen) emit — the ring's `order(.below)` re-stack is flicker-free, unlike the SkyLight above-order transaction — and, reading each window's real corner radius, it hugs the corner cleanly. The above-order alternative (#357) is crisper and shadowless but flickers on those apps; the drop-shadow reads as subtle depth and was preferred to a browser-specific special case. | The ring is a separate overlay stacked relative to the target: below-order (`AppKitBorderOverlay`, also the mandatory fallback) sits beneath it, above-order (`SkyLightBorderOverlay`) on top. Below is the default; the above path stays in the tree, and the square ring's hidden overlap is derived from the real radius so large-radius corners don't gap (`BorderGeometry.squareHiddenOverlap`, [#361](https://github.com/hajiboy95/KiwiDesk/issues/361)). | A planned draw-order toggle will expose above-order for anyone who prefers the crisp, shadowless corner and can accept the flicker on Gecko browsers. |
| A focused-window shortcut (`focus`, `swap`, `resize`, `make_floating`, `move_to_space`, `move_to_track`, `stack.promote`/`demote`, …) is **rejected without acting** while an ignored panel (Ghostty's quick terminal) or an unmanaged/ignored app holds the foreground — and, for the brief moment during an app-activation or self-raise race before the OS frontmost app catches up to KiwiDesk's focused window. | Acting on the implicit focused window while a *different* window is frontmost would silently mutate a window the user cannot see. Failing closed until the OS foreground genuinely matches the managed focused window is the safe answer: a transient rejected shortcut during activation is far less harmful than a hidden mutation. An unmanaged panel that never emits any focus notification cannot set the ignored-panel latch, so a shortcut fired while it is up relies on the frontmost-pid check alone — the deliberately preserved limit from the Ghostty panel work. | One semantic preflight at `KiwiCore.execute` (`FocusedCommandPolicy` classifies the focused commands; `focusedCommandDenial` requires the OS frontmost pid to equal the focused managed window's pid, the event loop to still observe it, and no ignored-panel latch for it) — shared by Lua, CLI, and IPC, else `no managed window is currently focused` ([#292](https://github.com/hajiboy95/KiwiDesk/issues/292)). | Bring the managed window back to the foreground (click it, or dismiss the panel so its app re-reports a managed window) and re-issue. Global config, `focus_space`, spawns, profile ops, and explicit App Bar clicks are never gated. |
| A **native-tab window** (Finder, Terminal, Ghostty) is managed as **one** window that follows whichever tab is active — its tabs can't be split into separate tiles, and there is one App Bar item for the group, not one per tab. | Native tabs are separate `NSWindow`s the app owns, with only the active tab ever visible to AX; splitting a tab into its own tile would need cross-process `NSWindow` reparenting KiwiDesk cannot perform. Managing the group as one slot that re-keys to the active tab is the honest model — one tile, one App Bar item, and no spurious tile or focus jump on switch/close. Expanding tabs as App Bar sub-items was rejected: the app's own tab bar already does that, and it would be un-Mac-like. | Background tabs never appear in `kAXWindowsAttribute` and mint a fresh `CGWindowID` per switch ([#308](https://github.com/hajiboy95/KiwiDesk/issues/308) probe); the event loop coalesces the same-frame vanish/appear into `.windowRekeyed` (`TabReconciler`), preserving the flat one-slot-per-group state. Detection is temporal (a tab group on either side + same frame within tolerance, in one reconcile pass), so two narrow same-frame false-merge edges are accepted: same-app windows deliberately stacked in an `OverlapStack` pile, and a tab carrier spanning two native Spaces at the identical tiled frame (suppressed by a post-space-switch grace window). Both need the vanish and appear in one pass and self-heal on the next reconcile. | None in-app — a cross-process split is impossible. Whole-app opt-out via `ignore_rules` if a specific app's tab behavior misbehaves. |

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
| **Stack** | geometric | `Navigation.neighbor` over slots | yes — a zone overflow cascade / `cascade_all` (`StackLayout`); piles always cascade downward, whatever the arrangement (#222) |
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

The **focus border** (#278) is a cross-layout overlay that
deliberately opts OUT of the pile-dedup model above: with
`border.unfocused_enabled`, every tiled window gets its own ring,
including every member of an overflow cascade. Buried
rings naturally show only along their exposed cascade edges because
each overlay is ordered directly behind its target window. The stroke
geometry overlaps under the target to prevent a detached seam, while
the target masks that overlap so the border never covers content. A
popover, sheet, or emoji picker above the target naturally covers the
ring too. This is a border-only presentation policy:
`Navigation.pileMates` remains the
shared authority for navigation, swaps, and z-order restoration. In
monocle — where only the focused window is visible — borders stay
focused-only. Floating windows are excluded from the unfocused set;
the focused window is still ringed whether tiled or floating.

A **transient overlay** — a launcher or panel (Spotlight, Raycast,
Alfred) that floats for a *structural* reason (accessory activation
policy, a non-standard panel subrole, or a raised CGWindow layer)
rather than a matched `float_rules` entry — never receives a ring,
even while it holds focus (#300). The suppression is a **draw-time
heuristic**, not an entry in the `ignore_rules`/built-in ignore
list (#176/#177): these overlays float and behave correctly, so
they belong in managed state; only the ring is wrong, and the fix
belongs where the ring is drawn. This is deliberately narrower than
excluding *all* focused floats — a user who floats a standard
window still wants its ring; a launcher does not. The classification
is captured at track time (`ManagedWindow.isTransientOverlay`), so
the pure `borderSpecs` decision stays AX-free, and it clears the
moment detection self-heals a window back to tiled — the flag can
never outlive the float state it depends on (overlay ⟹ floating). A
window that is genuinely an overlay is caught by the stable
accessory-policy path at track time, independent of any one-off
subrole read.

The ring's **rendering backend is opportunistic, not architectural**
(#285): when the complete runtime-linked SkyLight drawing and event
surface resolves, an SLS window follows WindowServer move/resize/order
events directly. Drawing and tracking degrade independently: a failed
raw-window operation replays the ring through the public AppKit panel
without discarding a healthy WindowServer event stream. Direct mouse
drags use one movement authority: WindowServer bounds whenever its event
surface is active, otherwise the stable AX/AppKit fallback. No path
projects a border from cursor motion, so macOS edge/corner dwell holds
the ring and target together. No private symbol is linked at launch,
and the optimization never changes SIP requirements or the layout/state
model.

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

**The sidebar is a fixed-width, floating, non-resizable
column.** (#297) A closed ~9-row icon+label taxonomy never
needs more or less room, so a draggable divider is the same
"bespoke panel" tell that got the collapse toggle removed
(#68) — and a collapsed sidebar had no affordance to reopen
it. System Settings, the GUI north star, fixes its sidebar
too. Mechanically the shell composes the two columns with a
plain `HStack`, not `NavigationSplitView`: on macOS 26 the
split view's divider cannot be locked by any supported means
(the column-width modifier is ignored, `NSSplitViewItem`
thickness writes are reverted by the private controller,
delegate interception crashes), so the static column is fixed
by construction rather than by fighting the framework —
revisit if a later macOS/SwiftUI exposes a supported
fixed-width sidebar. The
column renders as the macOS 26 floating pane: a rounded,
shadowed card inset from the window edges with the traffic
lights inside its top-left, in near-window-background gray
(settled by eye against System Settings), with no divider
line, and softly-shadowed icon tiles. When the window resigns
key the card goes flat #F7F7F7 (sampled from System Settings'
inactive sidebar; dark mode falls back to the flat window
background) and the hand-built chrome above the list
(identity, search, icon tiles) fades uniformly — hue kept,
never desaturated (`InactiveDimmed`), keyed to fully-inactive
only so the shared color panel taking key does not dim the
sidebar.

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
  **deliberately preserves** the profile's stored `modes`,
  `appRules`, `floatRules`, and `ignoreRules` — those are sparse
  *diffs* against the global base, and Live editing changes the
  base (`gui.json` or `init.lua`), never the diff.
- **Override-row Save** (`saveEditedProfile` →
  `overwriteProfile` → `applyProfileEdits`) writes the profile's
  sparse behavior **diffs** (against the matching global bases)
  plus its tiling — this is the surface that edits the diff.
  Ignore rules have no GUI control yet, so that hidden diff is
  preserved verbatim rather than reconstructed from resolved state.

So "Live leaves `profile.modes` frozen while the row rewrites
it" is the model working, not divergence: one door edits the
base, the other edits the per-profile diff over it. The trap to
avoid is "fixing" `buildProfile`/`persistProfile` to also adopt
the behavior overrides — that would collapse the diff into an
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

**Shared display Spaces are recommended, not required.**
KiwiDesk resolves one active native Desktop number and one active
profile across the whole display setup. With macOS's "Displays have
separate Spaces" option on, multiple displays can show independent
Desktop combinations that this one-profile model cannot represent
unambiguously. Shared display Spaces therefore make Desktop→profile
bindings predictable, but they are not a prerequisite for basic
tiling.

Both surfaces share one gate — separate Spaces on *and* two or more
displays connected — so a single-display setup, which has no binding
ambiguity, is never prompted. Onboarding recommends turning the option
off only in that state and lets the user continue without changing it.
The Profiles tab keeps the specific Desktop-binding controls visible
and editable; in the same multi-display state an inline warning
explains the limitation and opens Desktop & Dock Settings. The saved
profile list and its Load actions are unrelated and never warned or
disabled. Hiding the binding section would erase context and existing
configuration; disabling it would incorrectly claim that every binding
is inert. (#8)

**Profiles may override *behavior* settings, never *routing*
ones.** A profile owns tiling, and may also carry a sparse
override of a global setting that shapes how the workspace
*behaves while the profile is active* — keybindings
(`Profile.modes`) and the three window-rule families:
app→space (`Profile.appRules`), float (`Profile.floatRules`),
and ignore (`Profile.ignoreRules`). The global base lives in
the active config owner (`gui.json` or hand-written `init.lua`).
Each profile stores only additions and explicit tombstones;
families resolve independently, then effective ignore remains
the hard management gate. Thus an ignore tombstone exposes an
app to its independently resolved app/float rules. It may never
override a setting that *selects or routes* the profile
itself: the native-Space→profile bindings decide *which*
profile loads, so a profile owning part of that map would be
a self-reference (load A → A rebinds Desktop 2 → B → …). The
GUI language is a second hard exclusion for a different
reason — it lives in `UserDefaults`, outside config ownership
entirely, and must never touch a sidecar. Every override is
the base overlaid with a sparse diff (absent inherits; a
tombstone removes), never a second home for the setting. Each
new one is added deliberately and parity-tested. App→space uses
its value-map override; float and ignore share a list-set sparse
primitive now that there are two real clients.

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
tiling-plus-sparse-behavior, #55): on first launch the seeded
model is persisted so the very first boot is GUI-managed and the
shortcuts actually fire.

**The seed fires whenever `init.lua` declares no managed
_settings_ — not only when `init.lua` is absent (#354).** The
original gate ("no `init.lua` yet") silently punished a user
whose `init.lua` carries only harmless custom Lua — the
documented sketchybar event-hook bridge — booting them to a bare
single space with no profile. The seed now gates on
`ManagedConfig.declaresManagedSettings`: a superset of
`hasForeignCode` that also catches the `set_*` verbs, including
the **namespaced** layout setters (`bsp.set_ratio_h`,
`stack.set_master_ratio`, …) that editor-fallback ignores. Those
verbs are derived from `APIReference.namespaces` (the one
registry) so the check can't drift as sub-APIs grow. Result: a
hooks-only or comment-only `init.lua` boots GUI-managed with the
defaults **and** keeps firing its hooks; an `init.lua` that
declares tiling settings of its own stays Lua-owned (no seed —
seeding would let the GUI defaults overwrite its Lua tiling) and
is offered the **Adopt** path instead. With a settings-free
`init.lua` the seed appears in the editable model and persists on
the first Save. Per-space rows are
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

**Stack resize is focus-aware, and its zone weights are
ephemeral by design.** The stack layout's resize used to always
move the master/stack split toward the master, whichever window
was focused. #67 makes both axes act on the *focused* window:
the split axis (`x` for a left/right stack zone, `y` for
top/bottom — #222) moves the split in the direction that grows
the focused window's zone (flipping the old always-grow-master
behavior when a stack window is focused — intended), and the
focused zone's own axis grows the focused window's share of its
zone via **per-window weights** — a `[WindowID: Double]` map
in `Space`, parallel to the flat window array (a map, not a
tree: it adds no structure the flat-array guardrail forbids).
The weights are **session-scoped and never serialized**: a
`WindowID` is an OS window handle, unstable across app and
window relaunches, so there is nothing durable to persist a
weight against — persisting them would at best restore sizes to
the wrong windows. They are pruned when a window leaves the
space. When a weighted share drops below `min_window_size`, the
zone falls back to the existing overflow cascade (weights
apply to the fully-tiled case only), and the resize command
caps weight *growth* at that cliff so presses past it cannot
ratchet the stored weight invisibly; clamping the *master
ratio* against min window size stays a separate issue (#44).
One deliberate asymmetry: a *drag* along the zones' own axis
still snaps back (the mouse seam is windowless); only the
keyboard/CLI `resize` moves weights. (#67)

**The stack zone's lineup derives from its position — no
`stack_orientation` knob; piles always cascade downward.** #222
made the stack arrangement configurable: `stack_position`
(top/right/bottom/left) picks the split axis, and
`master_orientation` lines up multiple masters. The stack zone
deliberately has no orientation setting of its own — a
left/right zone is a tall strip, so it stacks vertically; a
top/bottom zone is wide, so windows sit side by side
(`StackPosition.stackOrientation`, the single authority). Any
other combination degenerates into slivers, and deriving keeps
the resize axes orthogonal: the split ratio always moves on the
split axis, the stack's weights on the other. Overflow piles
keep cascading downward in every arrangement (ui-designer
consult, 2026-07-15): the title bar is the affordance unit
(identify + drag + raise) and one pile vocabulary spans the app
— a sideways pile would expose blank side slivers and read as a
glitch. A wide zone's `cascade_all` pile may spill over the
master zone; that is the same accepted spill tall zones already
do at the screen's bottom edge, kept coherent by the managed
z-order. If pile depth ever hurts, the lever is a depth cap —
not a direction switch. (#222)

The `master_orientation` default flipped `vertical` →
`horizontal` on 2026-07-16 (designer-consulted): side-by-side
masters beside a right stack turn a raised master count into
columns — the arrangement wide screens actually want — whereas
a vertical master column duplicated the stack's own shape next
to it. The trade is conscious: the standard arrangement now
sits inside the along-axis resize limitation above (masters'
individual shares are unreachable until the orientation is
switched back to vertical), and the leading-edge promotion path
became the default-adjacent bug #313. Existing profiles that
omit `layout.stack.master_orientation` change meaning on next
load — pre-release, no migration (§5).

**The master zone fills from the stack seam when the stack
leads.** (#313) `StackLayout.zone` lays array order from a
region's min edge, which put the boundary master (the
promote/demote swap slot) at the point *farthest* from a
leading stack — every boundary crossing teleported across the
master zone. Mirrored slot order (leading stack + parallel
master lineup only) is a pure render mapping: the flat array,
the promote/demote swaps, and seniority stay untouched;
geometric navigation follows the frames; `StackSchematic`
mirrors via the same `StackLayout.mirrorsMasterZone` predicate
so the preview cannot lie. Perpendicular lineups stay in
natural reading order — every master already touches the seam.
Boundary crossings now read identically to the trailing-stack
(default) arrangement: the crossing window moves locally,
survivors shift one slot. Accepted side effect: when a mirrored
master zone uses `cascade_overflow`, its trailing pile contains
the array-earliest masters instead of the latest; the pile keeps
the same screen position and downward cascade either way.

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

**A per-space override is eligible only when it is
layout-local.** A field belongs in the Spaces → `Overrides…`
tier when three things hold: it belongs to the space's
**active layout**, it **resolves before** the pure layout
calculation (so the resolved value can feed layout math over
the flat array), and it has an **unambiguous layout default
to inherit** (the checkbox has a meaningful "off"). That
admits exactly the six per-layout override models — BSP,
Stack, Scrolling, Grid, Monocle, Track — and nothing else.
Explicitly **excluded**: animations, mouse/drag behavior,
borders, quit behavior, keybindings and window rules, profile
routing (`profile_bindings`), and GUI language — none are
layout geometry, and several are owned outside profile config
(#290). This is parity work over the existing per-layout
mirrors, not a promise that every setting is space-wise
configurable; a generic `SpaceSettingsOverride` was rejected
for exactly that reason. Two boundary notes: **Monocle** has a
single eligible override, focus **orientation** (which
directional keys cycle the window order and which axis the App
Bar follows); **Wrap focus** is a layout-wide Monocle/Scrolling
behavior, deliberately *not* per-space. The `Overrides…`
button's count and the *Saved for other layouts (N)* disclosure
read one reflective `fieldCount` over these six models, so a
new override field is counted without a hand-kept tally. (#290)

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
The preview renders **Inside vs Outside** border alignment
(inset within the tile vs a larger footprint outside its
edge, offset scaling with the border width) — schematic, not
pixel-exact, but the control was previously dead because
SwiftUI `.strokeBorder` always draws inside; and both the
corner-radius and
border-width previews now remap the full slider range instead
of hard-capping halfway (the `AppBarPreviewStrip` fix).

**Preview alignment splits on standalone-vs-paired, not by
tab.** (ui-designer consult 2026-07-14.) A settings preview is
aligned one of two ways, and which one is decided by whether
controls sit right next to it — never by which tab it's on:

- **Standalone illustration** (a Layout schematic, the App Bar
  mock strip) — centered in its card with a caption below.
  Nothing is edited *on* it and no control column shares its
  row, so there is no leading edge to line up against; it reads
  as a figure, the way macOS System Settings centers a
  wallpaper thumbnail or screen-saver preview over its label.
- **Preview paired with the exact controls in the same card**
  (the Gaps diagram + its outer/inner legend, the Drag Ghost /
  Drop-zone columns) — left-aligned, flush with the control
  rows it drives, so preview and controls read as one stack
  (the accent-swatch / Displays-arrangement pattern).

So Layout schematics and the App Bar strip are *both* centered
(they are the same kind of thing); Gaps and Drag are left —
that apparent Layout-vs-Appearance inconsistency is really this
one correct rule. A new preview picks its bucket by asking "are
its controls right here beside it," not by copying its tab.

## App Bar

**App Bar edge is absolute.** (#293, supersedes the #228
axis-relative model.) The stored value is one of the four screen
edges (`top` / `bottom` / `left` / `right`, default top) and the
bar renders exactly there in every layout — the earlier
`start`/`end` values that resolved against the layout's
orientation are gone. Axis-relativity existed to prevent an
edge/axis mismatch when the edge was derived per layout; with the
Space Bar requiring free four-edge placement for both bars, the
derivation (and its rationale) fell away. The GUI preview strip
is edge-aware and rotates vertical for left/right.

**The Space Bar reserves space-first.** (#293.) The Space
Bar's strip is carved from the display's original visible frame,
and the remainder becomes the bounds every layout — and the App
Bar's own reservation — operates inside. Layouts never learn the
Space Bar exists (resolution before layout; layout functions
stay pure over the flat array). Two rules fall out for free:
same-edge stacking (Space Bar screen-facing, App Bar
window-facing, insets add) and perpendicular corners that
cannot overlap (the App Bar strip spans the already-inset
frame).

**Same-edge bar stacking is a supported layout, not an error.**
(#293.) Both bars on one edge is a reversible, deliberate
choice: no conflict dialog, no automatic relocation, no blocked
picker. The GUI explains the resulting order inline; profile
load/import accepts it silently.

**The Space Bar always groups; there is no knob.** (#293.)
Adjacent same-app runs collapse into one glyph + count badge
unconditionally — unlike the App Bar's `group_adjacent_windows`
toggle. The asymmetry is structural, not an oversight: App Bar
tabs are click targets, so grouping changes interaction and
earns a toggle; Space Bar glyphs are informational, and the
fixed cap of five glyph slots depends on grouping running
first (an ungrouped mode would burn the cap on duplicates
while conveying less). The overflow badge's `+n` counts hidden
**windows**, not slots — the same unit as the per-glyph count
badges and the item's accessibility label.

**The Space Bar's two-accent model.** (#293.) Three tinted
states, all GUI-exposed inline (never behind a disclosure —
the system is the bar's defining signature): `text_color`
paints inactive Spaces, `active_text_color` the active Space's
identifier and glyphs, and `focused_item_color` the focused
window's glyph inside the active Space. Emoji identifiers and
native app images stay untinted; shape (the active indicator)
carries the active state there, so color is never the only
signal.

**Space Bar content is fixed in v1.** (#293.) Identifier plus
app glyphs — no clone of the App Bar's `Icon | Name |
Icon & name` chooser. The identifier is structural and the
compact glyphs are the point of the overview; an app-name mode
needs its own demonstrated use case first.

**Space identifiers are icon-only, with settled fallbacks.**
(#293.) The configured Space icon (SF Symbol | emoji | single
character) renders alone — no emoji-vs-name chooser. Without
one: a numeric id becomes the `N.square` SF Symbol (probed —
past the symbol range it falls through), any other id becomes
a two-letter uppercase monogram ("mail" → "MA"). Keeps the
square glyph-slot footprint and stays distinguishable where a
shared generic glyph would not.

**The front-app segment is per-display.** (#293.) With
`space_bar.show_front_app` on, each display's bar shows the
focused window of the Space that display currently shows — not
the globally frontmost app (sketchybar's `front_app`). One bar
per display means per-display content, consistent with every
other per-display fact in the bar; a secondary display shows
its own space's remembered focus.

**Space Bar drag-drop is a two-speed spring, not a blind
relocate.** (#372.) Dragging a window onto a Space item either
relocates it (fast drop, `move_to_space`) or, after a 2 s dwell,
springs the view to that Space so the window is dropped into its
live layout. A first design pass rejected spring-loading over a
cross-process race fear; it was reconsidered once grounded in the
code, because KiwiDesk's Spaces are *virtual* (a retile, not a
WindowServer Space change), which narrows the risk to one place.
The load-bearing details, so they are not relitigated:
- The dragged window is exempted from `stashInactive` for the
  gesture's life (`TilingEngine.dragExemptWindow`), the same kind
  of pin as the existing `!isFloating` exemption — otherwise the
  spring's retile would stash it under the cursor mid-drag.
- The spring uses a private activate-plus-retile helper, **not**
  `focusSpace`: that command warps the cursor to hand off AX
  focus, which would rip the pointer out of the OS drag loop. No
  focus hand-off, no warp, and the spring retile is
  `animated: false` regardless of `animations.on_space_change`
  (a crisp switch must not add motion competing with the live
  foreign-app drag).
- Space membership flips **eagerly at spring** (QA revision): the
  window is moved into the target the moment the view springs, so
  the live drag shows the ordinary drop preview (ghost + drop-
  zone) in the target's layout and the release lands it in the
  exact slot. An earlier design flipped membership lazily at drop
  to avoid stale state, but that left no preview during placement.
  Eager membership needs no rollback: an abnormal end (window
  closed / tab rekeyed) means the window is gone, so stranding is
  moot, and a normal drop is *meant* to place into the sprung
  space — `cancelDrag` only tears down the gesture bookkeeping
  (pending spring, `dragExemptWindow`); it does not, and need not,
  move the window back. The dragged window is exempt from **all**
  frame application in `retile` for the gesture's life — both the
  layout loop and `stashInactive`, via `dragExemptWindow` — so the
  spring's retile places the target's OTHER windows but leaves the
  dragged one under the cursor. Without the layout-loop exemption
  the retile yanks it to its computed slot mid-drag (a small
  dwindled BSP corner, say). Because the move commits at spring,
  `window_moved_to_space` fires then rather than once at drop, and
  once per spring — a chained A→B→C dwell emits two moves. That
  cardinality change is deliberate; hooks keyed on the event see
  the intermediate moves.
- The dwell defaults to **1.5 s** and is user-configurable
  (`space_bar.spring_delay`, clamped 1000–4000 ms; a Spring delay
  slider in the Space Bar editor). Longer than Finder's ~0.7 s:
  the ring sweep shows progress and a whole-view switch is a
  bigger disruption than a folder opening, so the accidental-
  trigger floor sits higher. The sweep animation tracks the
  configured value, but only *starts* after a fixed 0.5 s quiet
  pre-delay (`SpaceBarDropCoordinator.springPreDelay`) so a quick
  flick-to-relocate never flashes a loading ring; the spring still
  fires at the full dwell, so the sweep fills over
  `dwell − 0.5 s`, and the range floors at 1 s to keep that fill
  visible. The pre-delay is a `beginTime` offset on the stroke
  animation, so leaving before it elapses shows nothing. Always-on, no enable toggle; focus-after-drop
  is not a new setting (`move_to_space_and_follow` already models
  following). Option-held-drop → follow is a deferred second gear.

**Bar alignment is edge-relative, one shared default.**
(#293 QA.) Both bars place their content run via `alignment` —
`start` / `center` / `end`, values edge-relative (a left bar's
`start` is its top) for the same reason `edge` is absolute:
correct on every edge without a per-edge remap. One default
(`center`) for both bars and every edge — never per-edge
defaults. The Space Bar's pre-QA left/top anchoring was an
omission, not a decision. Once an App Bar group overflows and
scrolls, the three alignments deliberately collapse to the
scroll offset; the control is not greyed for it (a static
preview can't know real overflow). Copy-appearance copies
alignment (arrangement is appearance); `edge` stays excluded
(placement is not).

**The two bar editors share one canonical row order.** (#374.)
App Bar's shape is the reference: enable, Position (with the
same-edge note under it, in both editors), item-look
(background, indicator, symbol style), content toggles, sizes,
then colors — signature colors inline, the rest behind a shut
"Advanced colors" disclosure in both. Differences remain only
where the bars genuinely differ (per-layout tier, front-app
segment, copy button). A new bar-editor row must slot into
this order on both sides, not grow a per-editor one.

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

**App icon rendering is one global choice with two honest
options.** (#294.) `icon_source` — GUI label "App symbol style" —
offers `app_image` (System default) and `app_font` (Glyphs).
Decisions folded in, 2026-07-17/18 (ui-designer consult + user
direction in chat):

- **Global in the GUI, per-layout only in Lua.** A per-layout
  override row for icon rendering has no user story (it exists in
  the schema because the field mechanically mirrors every other
  bar style field, and stays there as power-layer depth); the
  Settings surface shows exactly one dropdown, directly below
  Content, greyed while Content is Name (#171 grey-don't-hide).
  Accepted side effect: the per-layout override chip counts a
  Lua-set `icon_source` override even though the override editor
  shows no row for it — the chip discovers fields by reflection
  on purpose, and hiding Lua-only depth from it would be the
  bigger lie.
- **Glyphs follow the bar's state text colors** (normal / active
  / hover) — one color system with the labels. Glyph-less apps
  keep their native image.
- **A synthesized Tinted mode was built and stripped** (with its
  `tint_appearance` sub-setting): the system-wide Icon & widget
  style already covers the want for System default icons, and a
  luminance-ramp approximation misrepresents Apple's
  plate-regenerated styles. Dark / Clear / Tinted as true in-app
  choices remain API-blocked — see the accepted-limitations row;
  [#362](https://github.com/hajiboy95/KiwiDesk/issues/362)
  tracks the private-IconServices probe that could add them.
- **The glyph map format is JSON** (`icon_map.json` vendored from
  upstream): decoded directly in Swift, validated once, cached —
  keeps bar rendering independent of the user's Lua VM. The Lua
  and shell forms upstream ships were rejected (coupling static
  vendor data to an interpreter buys nothing).
- **Vendored, not user-supplied**: the TTF + map ship in the app
  (CC0-1.0), refreshed by `scripts/update-app-font.sh` which pins
  the upstream release in `UPSTREAM.md`. CC0 waives copyright but
  not third-party trademark rights in the depicted app marks —
  accepted deliberately pre-release; revisit at public 1.0 with
  the other distribution decisions.
- **The shortcuts panel follows the GLOBAL symbol style**: with
  Glyphs active its Apps band leads with the same ligatures. The
  panel spans all layouts, so a Lua-only per-layout
  `icon_source` override deliberately does not steer it.

## Shared controls

**Per-field help is a click popover behind a `?` right after
the label, not a hover tooltip (#94).** Rows that warrant a
sentence of explanation carry a small `questionmark.circle`
button **immediately after the field's label text, inside
the shared `settingsLabelColumn`**. The question is born at
the label ("what is *Width split ratio*?"), so the
affordance sits where the confusion starts — not past a
control the user has already scanned in confusion.
Owner-tested twice: the first cut (far trailing edge) and
the second (snug after the control) were both anchored to
the wrong end of the row. This is also System Settings' own
info-glyph convention (Focus/Siri panes put it beside the
label). `labelColumn` grew 128 → 150 pt to hold the longest
label plus the glyph; a long label + glyph truncates visibly
(`lineLimit(1)`) — the accepted fallback, and long German
labels on help rows are shortening candidates for the de
review pass. An *unlabeled* `SegmentedPicker` (icon tabs)
has no label to sit beside, so its `?` trails the track.
The button wears the shared `hoverHighlight` chip like
every other icon-only borderless control, so the eye has
something to catch.
Clicking opens a fixed-width popover; `.help()` rides along
as a hover fallback carrying the full text, while the
VoiceOver hint stays a short action phrase ("Shows an
explanation of this setting") — the content is read inside
the popover after activation, so a full-text hint would
announce it twice. A popover, not hover-only `.help()`, because that is
what System Settings does for explanations: a visible,
discoverable glyph; a real focusable button (keyboard and
VoiceOver reach it); dismissible and re-readable — while
hover tooltips are single-line-biased, keyboard-inaccessible
and invisible to anyone who never rests the pointer.
`.help()` remains the idiom for one-line hints on ambiguous
*icon-only controls*. A field with 2–3 named options folds
per-option text into the ONE field-level popover (option
name bold, one line each) — never a `?` per segment. Two
scope guards: help is optional reading (a label must stay
understandable without it — must-know info never lives only
in the popover), and a field already taught by its live
preview or schematic (App Bar colors, layout-tab
geometry) gets no `?` at all. Copy is a normal `L()` string
under the `<key>.help` suffix convention; when a *label* key
is shared by fields with divergent semantics (Stack's and
Track's Overflow both use `layout_params.overflow`), the
help key scopes itself (`layout_params.overflow.stack.help`)
so each field can carry its own text. Shared help copy —
one string rendered on two surfaces, like a Layout Defaults
tab and the per-space Customize popover — is authored once
in a per-domain namespace (`LayoutHelp`); single-call-site
copy stays inline at its call site (namespace membership =
2+ call sites, or an override pair like
`newWindowPlacement`/`trackPosition` — not "it felt
shared"). In the Customize popover the `?` is rendered by
`OverrideChrome` itself, not the wrapped row, so it stays
clickable while the row inherits — help must work exactly
while the user decides whether to override. Accepted
consequence: there the `?` sits at the chrome row's
trailing edge (past the inner row's spacer, a small
distance in the narrow popover), consistently for every
override row — the deliberate exception to label-adjacent
placement, since the label lives inside the disable-able
content, the checkbox-narrowed column has no width to
spare, and the user already met the field (with its
label-adjacent `?`) on the global surface. Do not "fix" it
back inside the row: that re-enters the disabled scope.

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

**Segmented vs. menu is decided by a rule, not per row
(#291).** A pick-one control is a `SegmentedPicker` when the
choices are a *fixed set of 2–4 peers*, every label stays
short and untruncated at the minimum Settings width **and**
in the longest shipped localization, and seeing all choices
at once helps the decision. It is a **menu** (`DropdownRow`)
when any of: five or more choices; dynamic or user-generated
choices; long, explanatory, or localization-risk labels; or
a constrained repeated surface where showing every choice
would crowd or truncate. A binary is a **toggle**, never two
segments. Fixed editor-navigation tabs (the Layout Defaults
mode strip) may exceed four — they switch the visible editor
rather than edit a value, so the count cap doesn't apply.
The *same semantic field uses the same control on comparable
full-width surfaces*: the App Bar global editor and its
per-layout override rows both render Position / Tab
background / Active indicator / Content as segments, so the
two never sit adjacent showing one field two ways. The audit
(#291) converted those four App Bar fields (global and
override), Stack's Master orientation / Stack position /
Overflow, Track's Overflow, Drag's Border alignment, and the
Focus border Corners (which had been a native `.segmented`
`Picker` nested in a menu-styled `DropdownRow` — two
segmented implementations at once — flattened to the shared
`SegmentedPicker`). Menus were kept where the rule keeps
them: new-window placement (comparative labels like "Before
focused"), the Space layout mode (seven icon-bearing
options), Language and Native-Desktop→Profile (dynamic
lists).

**The 384 pt per-Space popover is the documented
compact-surface exception (#291).** There the inherit
chrome (a checkbox plus accent bar, `OverrideChrome`) eats
horizontal width, so its override rows stay menus even for
2–4-peer fields. `OverridePickerRow` carries a **required**
`Style` (`.menu` / `.segmented`, no default): the full-width
App Bar per-layout overrides pass `.segmented`, the per-Space
popover rows pass `.menu`, and a new override row can't
silently pick the wrong control for its surface. The
inherited (unchecked) state comes free from the chrome's
existing `.disabled` + `.opacity(0.5)` — the segmented pill
sits on the resolved global value, dimmed. App Bar Content
("Icon &amp; name" → German "Symbol &amp; Name") is the one
segmented label tight enough to warrant a real render at
minimum width; kept segmented by width headroom, it is a
truncation candidate to re-check when each new locale ships
(#95), the same recurring de-review discipline the help-glyph
labels already carry.

**Row order within a section is fixed-tier, not
usage-frequency.** A field's vertical position is decided by
what *kind* of decision it represents, not by how often a
user reaches for it — a canonical tier order is what lets the
eye learn one shape across every editor. Natural adjust-order
("what you'd tune right before/after this") only breaks ties
*within* a tier, once the tier is fixed. A contributor
placing a new field first asks **which tier**, then **where
in it**. The tiers, top to bottom:

1. **Preview / schematic** — leads unconditionally, *unless*
   the section has one master on/off toggle whose own state
   the preview depicts (Focus border's dimmed-when-off
   preview): then the toggle sits directly above the preview,
   the gate-above-gated rule extended to treat the preview as
   a gated control.
2. **Defining / structural fields** the schematic takes as
   params — counts, ratios, axis / arrangement, positions —
   ordered coarse-to-fine (what fixes the shape before what
   refines it). A *numeric-threshold* gate needs no strict
   adjacency to what it greys (Stack's Master count gates
   Master orientation, yet the unconditionally-relevant
   Master ratio sits between them): unconditional-before-
   conditional outranks adjacency, because the greyed state
   already signals the gating. Strict adjacency stays
   mandatory only for a boolean-toggle-controls-one-row pair.
3. **Standing placement / overflow policy** — New-window
   placement and Overflow style, steady-state behaviour
   rather than static geometry, cluster together and sit last
   among the schematic-tied fields.
4. **Secondary, occasional-use toggles** with their own
   captions (auto-derivation, wrap-focus), each still
   gate-above-gated internally.
5. **Escape-hatch buttons / actions** ("Fit layout gaps")
   — always last.

An escape hatch that transforms other staged settings must expose
the transaction locally: label transient inputs as action parameters,
preview the resulting values before activation, warn when structure
will be flattened, and confirm that the draft changed while footer
Save is still required. Focus Border's **Fit layout gaps** group is
the reference pattern; its action remains opt-in and one-shot rather
than introducing automatic border-to-gap coupling.

Dividers mark tier boundaries, not just breathing room, so a
new field's tier decides which divider-bounded cluster it
joins — never wedge a field mid-cluster to dodge adding a
divider. The audit that set this rule (#291) moved Track's
New-window mode + Position out of tier 2 (it had sat right
after Arrange) down to tier 3 after Overflow, so all five
layout editors now place new-window placement last among
their schematic-tied rows.

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
(mini-screen → arrow → mini-screen) for the modes whose meaning is
a *transition* — **BSP** (strategy divergence and new-window
placement only appear once a third window arrives), **Grid** in
its dynamic mode (the grid rebalances as a fifth window opens),
and **Scrolling**'s `follow` anchor (#239 — the viewport pans the
minimum to reveal the focus, leaving the side you came from open);
**single frames** for the rest,
carrying the conditional fact with one of a small shared
**ghost vocabulary** — a **spawn ghost** (dashed accent tile +
"+", "the next window lands here": BSP's third window, Track's
own-vs-focused track), an **off-monitor ghost** (solid gray,
straddling a drawn screen edge, "a real window scrolled
off-screen": Scrolling), and the pre-existing **empty-cell gap**
(dashed gray, "unused grid space": rigid Grid). Grid draws five
windows so the columns-first/rows-first wrap is visible; Stack's
overflow is a small iconic fanned-pile badge, not a permanently
cascading column. The two-frame motif is gated by a *principle*,
not a headcount: a mode earns a second frame only when it must
teach a fact **inexpressible in one frame** — a transition or a
rebalance, not a steady resting state. Modes whose meaning is a
still position (Scrolling's center/start/end anchors, rigid Grid)
stay single-frame; if every mode had two frames, "why two frames"
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

**Geometric wire, presentational label — the rule for every
two-axis layout.** #217 generalizes past Grid: the **Track**
picker had the same collision ("horizontal/vertical" reads two
ways for a subdivided layout — do the tracks run horizontally, or
do windows stack horizontally?), so it takes the same fix — the
GUI relabels to **"Arrange: Columns / Rows"** (reusing Grid's
`scroll_grid.arrange` label; Track's options are bare
`Columns`/`Rows`, no fill-order "first" since Track has no growth
semantic). The Lua/JSON **wire stays geometric** for both
(`grid.split_direction`, `track.axis` = `horizontal | vertical`):
a wire value describes orientation, which is unambiguous in a
scripting context where nothing is visually parsed, and it keeps
Grid, Track, and scrolling on one axis vocabulary. Renaming the
wire to `columns/rows` was **considered and rejected on gain, not
churn cost** (pre-release makes churn cheap, but cheap is not a
reason): Grid's value carries fill-order (`columns_first`) and
Track's carries pure orientation (`columns`), so no single
key/value shape unifies them — a rename would relocate the
inconsistency (GUI↔wire becomes Grid-wire↔Track-wire, plus a
`columns_first`-vs-`columns` shape mismatch) instead of removing
it, and turn a precise geometric term into a category-error
presentational one (an "axis" whose value is `columns`).
Single-axis layouts (Scrolling, Monocle) stay plain
"Horizontal/Vertical" — one axis, no ambiguity, nothing to
disambiguate. Fix the label, never the wire; §5's one-vocabulary
rule (Lua == JSON) holds either way and is orthogonal to this
GUI↔wire question.

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

**Buttons stay native; semantic role chooses their class.** No
gradients, borders, or shadows on buttons — the crisp shadow
is reserved for controls that slide (pill, slider thumb).
Class is expressed through native style + control size:
`.borderedProminent` regular for the one surface commit
(footer Save, popover confirms); `.bordered` large for row
actions (Load, Apply, Overrides, Set Gap Values), level with
large dropdowns; `.bordered` regular for stateful input
triggers (the shortcut recorder); and `.borderless` regular
for icon-only row actions (trash, ×-clear, rename). List-add
actions stay `.bordered`; `.plain` + underline is reserved
for inline prose links. Small controls are subordinate inline
or popover utilities (Shortcuts import, override resets), never
a normal row action. Native macOS shape differences between
these classes are intentional — choose by semantic role, not
by a desired silhouette.

**Hover confirms custom hit areas; it never creates the only
affordance.** Native bordered/prominent buttons, sidebars,
toggles, sliders, and fields keep system hover. Ambiguous
icon-only borderless actions use the shared adaptive chip
(`0.06` rest → `0.12` hover); custom full-row picker entries
use a hover-only `0.06` fill; unselected custom segments and
mode chips lift their existing fill by about `0.05`. No scale,
movement, shadow, or pointing-hand cursor on ordinary buttons
(the hand remains link-only). Disabled controls never react;
under Reduce Motion the color change is immediate. Every such
control also needs an explicit accessibility label (and concise
hint when the action is not obvious), a visible keyboard-focus
state, and a recognizable rest treatment or list context —
`.help()` and hover alone do not make a control discoverable.

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

**An undecodable profile is greyed, never hidden.** A profile
whose JSON won't decode yields no summary, but hiding it
stranded a broken file with no reachable remedy (#246). It now
stays listed everywhere — a Delete (and Reveal in Finder) on
its Config Issues row, a greyed "couldn't load" row with a
Delete in the Settings profile list, and a disabled entry in
the quick menu's Switch Profile submenu (the remedy is the
same panel, one entry up). Grey-don't-hide (#171); re-saving
was never reachable for a file that can't be read, so the
warning no longer suggests it. (#246)

**A typo is non-fatal, but never invisible.** An unknown call
on `KiwiDesk` or a layout namespace table is a guarded no-op
(logged with a did-you-mean), so one wrong name can no longer
abort init.lua and silently kill every keybinding below it.
The flip side — non-fatal would mean *unnoticed* — is closed
by recording each load-time hit as a config issue feeding the
badge and window above. Runtime hits (a typo inside a
keybinding closure) only log; a persistent "config error"
badge for a transient slip would mislead. (#39)

**The quick menu is for daily driving.** A healthy menu opens
straight on **Layout** (the most-used control), then Switch
Profile (`load_profile`'s quick path) — same topic, no
separator between them — then **Settings… low, next to Quit**,
where every native menu-bar extra keeps Preferences. Warning
rows (**Window Management Paused…** when Accessibility is
missing, **Config Issues…** when a config load failed) appear
**only when they apply**, at the top, fenced by a single
separator that is itself present only when a warning fired;
permission outranks config since without it nothing tiles.
Menu entries stay monochrome template symbols; the colored
tiles are a Settings-window device. (#68 §3.10, §6.2)

Deliberately *not* in the menu: a **header row** naming the
live profile (the active profile is already checkmarked in the
Switch Profile submenu — a permanent top line is near-zero-info
chrome above the thing you came for); a permanent
**Accessibility Settings…** deep link (a standing nag for the
99% granted case — the paused warning row covers the untrusted
case, and onboarding's own "Open System Settings" is the fix
path); and a **Support** row (it lives in Settings ▸ About as a
discreet link — a menu opened daily for Layout is no place for a
recurring support ask). Trimmed from thirteen possible rows to
~six, each of which either does something you came for or is app
chrome you expect near Quit.

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

- **Post-setup discovery** (#331) closes the first-run
  discovery gap with the smallest surface that works: one
  appended wizard card ("You're ready to go" → **Open Settings**
  on Layout, or an equal-weight **Not Now**) plus a one-time
  `NSPopover` anchored to the menu bar icon ("KiwiDesk lives
  here…"). The popover fires only on the *decline* routes (Not
  Now or closing the card): choosing Open Settings already leads
  the user into the app, so a menu-bar hint at a far corner would
  just be a competing second surface. Deliberately *not* a guided
  tour of every tab — that fights the contextual-help convention
  (#94) and is the classic skipped-onboarding trap. Both the card
  and the popover fire exactly once, gated on a
  dedicated `UserDefaults` flag (`onboarding.discoveryShown`),
  **never** the Accessibility trust state: the wizard reopens on
  any AX revoke, so a trust-gated beat would re-pitch a user
  whose TCC a macOS update reset. Copy is jargon-free (no
  "profile", "Accessibility", "tiling") for a first-run
  non-power user. (Supersedes the earlier "onboarding is a
  separate follow-up pass" note, #68 §5.9.)
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

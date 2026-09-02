import AppKit
import CoreGraphics

// MARK: - Layout inputs & per-display placement

extension TilingEngine {
    /// The layout region on `screen`: its visible bounds with the
    /// Space Bar's strip already reserved (#293). Every consumer
    /// of a layout *span* reads it here — the layouts themselves,
    /// track capacity, and the resize paths in `Commands/` and
    /// `Tiling/` (#537), which measured their delta against the
    /// whole display and so understated every ratio nudge by the
    /// strip and stored the scrolling slot's points against the
    /// wrong length. `LayoutBoundsRoutingTests` fails on a raw
    /// `visibleBounds` consumer outside its allowlist.
    ///
    /// Not a *second* bounds hook: the display size still enters
    /// through `visibleBounds` alone (#531). This only reserves
    /// the strip on top of it, which is why the seam is one line.
    ///
    /// It is the region **before outer gaps**, while the layouts
    /// divide `area` = region minus those gaps
    /// (`LayoutSystem`). That is deliberate for a cap's
    /// `available:` — a superset must never block reaching the
    /// visible bound — but it does leave a `delta / span`
    /// division, and the scrolling seed, off by the outer gap.
    /// Much smaller than the strip this fixed, and not a
    /// licence to assume the seam is exact.
    func layoutBounds(on screen: NSScreen) -> CGRect {
        settings.layoutBounds(from: visibleBounds(screen))
    }

    /// The FOCUSED display's active-space layout inputs — the
    /// single source that the focused-space consumers
    /// (`persistScrollRest`, ZOrder, TrackSwap) read, so the
    /// screen pick, floating filter, and context can never drift
    /// between the frames we apply and the offset we store. Laid
    /// out on the focused space's OWN display (multi-monitor),
    /// falling back to the main screen when it has no display
    /// assigned. `nil` without an active space or a screen.
    func layoutInput(
        state: StateCoordinator
    ) -> (space: Space, tiled: [WindowID], context: LayoutContext)? {
        guard
            let spaceID = state.workspaces.activeSpace,
            let space = state.workspaces[spaceID],
            let screen = Self.screen(for: spaceID, in: state)
        else { return nil }
        return layoutInput(state: state, space: space, screen: screen)
    }

    /// Layout inputs for one `space` laid out on one `screen` —
    /// the shared core behind the focused `layoutInput` and the
    /// per-display retile loop. Pure over the passed screen, so a
    /// secondary display's space lays out against its own bounds.
    func layoutInput(
        state: StateCoordinator,
        space: Space,
        screen: NSScreen
    ) -> (space: Space, tiled: [WindowID], context: LayoutContext) {
        // Space-first reservation (#293): the Space Bar strip
        // comes off the visible frame before any layout — or
        // the App Bar — sees its bounds.
        let bounds = layoutBounds(on: screen)
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: state.workspaces.activeSpace
        )
        var context = settings.context(
            bounds: bounds,
            space: space,
            sticky: Set(
                state.windows.all
                    .filter(\.isSticky)
                    .map(\.id)
            ),
            // Surface a tiled-sticky traveler when it is the
            // frontmost window (#431): it has a slot in `tiled`
            // but can never be the membership-guarded `focused`
            // slot. Scrolling reads `context.focused` to pan
            // and Monocle's `park` reads it to pick the shown
            // member (#881); `persistScrollRest` reads this
            // same `layoutInput`, so the pan and the stored
            // offset stay consistent. For a monocle space the
            // anchor is HELD across a float focus — see
            // `heldMonocleAnchor`.
            focusedOverride: heldMonocleAnchor(
                state.focusAnchor(of: space, tiled: tiled),
                space: space,
                tiled: tiled
            ),
            // Freshly detected on every layout pass (#878):
            // adjacency is an input, never a cache, so a screen
            // plugged in or out is correct from the retile the
            // display change already triggers.
            screenNeighbors: ScreenNeighbors.detect(
                around: visibleBounds(screen),
                among: allScreenBounds()
            ),
            // Confirmed app-enforced bounds (#677), read fresh
            // from the learner like the neighbors above: these
            // frames reach real windows, so the residue of a
            // refusal is placed rather than left at the slot
            // origin.
            sizeBounds: sizeBounds(for: tiled)
        )
        // A FORCED (explicit-apply) pass probes past the
        // corroborated bounds once (#1055, owner ruling
        // 2026-08-28) — the flag is pass-scoped, set and
        // cleared by `retile(force:)` around its frame
        // computation, so every other `calculatedFrames`
        // caller keeps the generalized consume.
        context.probesBeyondBounds = probeBeyondBoundsPass
        return (space, tiled, context)
    }

    /// Every space shown in place this pass paired with the
    /// screen it lays out on: one entry per connected display
    /// (its `activeSpace(on:)`). Falls back to the focused
    /// `activeSpace` on the main screen when no displays are
    /// tracked yet (unit tests, early boot) — the single-monitor
    /// path. The focused active space is always included even if
    /// its display is momentarily untracked, so its windows are
    /// never left unplaced.
    func visiblePlacements(
        state: StateCoordinator
    ) -> [(space: Space, screen: NSScreen)] {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else {
            guard
                let id = state.workspaces.activeSpace,
                let space = state.workspaces[id],
                let screen = NSScreen.main ?? NSScreen.screens.first
            else { return [] }
            return [(space, screen)]
        }
        let fallback = NSScreen.main ?? NSScreen.screens.first
        // Keyed by physical screen (frame origin — stable across
        // the fresh `NSScreen` instances `NSScreen.screens` may
        // hand back), so a screen hosts exactly ONE space. Two
        // displays that both fall back to `main` (unresolvable), or
        // a focused active space whose display is untracked landing
        // on `main`, cannot double-place two different spaces on
        // one screen — the focused active space, written last, wins
        // its screen.
        var byScreen: [String: (space: Space, screen: NSScreen)] = [:]
        func key(_ s: NSScreen) -> String {
            "\(s.frame.origin.x),\(s.frame.origin.y)"
        }
        for display in displays {
            guard
                let id = state.workspaces.activeSpace(on: display.id),
                let space = state.workspaces[id],
                let screen = Self.screen(for: display.id) ?? fallback
            else { continue }
            byScreen[key(screen)] = (space, screen)
        }
        if let id = state.workspaces.activeSpace,
            let space = state.workspaces[id],
            let screen = Self.screen(for: id, in: state)
        {
            byScreen[key(screen)] = (space, screen)
        }
        return Array(byScreen.values)
    }

    /// The fill-then-spill capacity (#437) of every track-mode
    /// space, keyed by id: how many windows its focused track
    /// holds before a spawn spills into a new track. It is
    /// geometry-derived (the space's display, `min_window_size`,
    /// inner gap, axis), so it lives here and is mirrored into the
    /// pure `StateCoordinator` before each event — spawn then reads
    /// a plain Int and no geometry leaks into the state core. Empty
    /// (skipped) when no space is in track mode, the common case.
    func trackCapacities(
        state: StateCoordinator
    ) -> [SpaceID: Int] {
        var caps: [SpaceID: Int] = [:]
        for space in state.workspaces.allSpaces
        where space.mode == .track {
            caps[space.id] = trackCapacity(for: space, state: state)
        }
        return caps
    }

    /// One space's fill-then-spill capacity, laid out on its own
    /// display (multi-monitor), for the spawn mirror and the
    /// track-entry seed (#437). Works before the mode flips — it
    /// reads only the usable area, min size, gap, and resolved
    /// axis, none of which depend on the current partition.
    func trackCapacity(
        for space: Space,
        state: StateCoordinator
    ) -> Int {
        // No display at all → unbounded (never spill), a safe
        // fall back to join-and-pile.
        guard let screen = Self.screen(for: space.id, in: state)
        else { return .max }
        let context = settings.context(
            bounds: layoutBounds(on: screen),
            space: space,
            sticky: []
        )
        return TrackLayout.trackCapacity(for: context)
    }

    /// The `NSScreen` a space lays out on: its assigned display's
    /// screen, else the main screen.
    static func screen(
        for space: SpaceID,
        in state: StateCoordinator
    ) -> NSScreen? {
        if let display = state.workspaces.display(of: space),
            let screen = screen(for: display)
        {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    /// The `NSScreen` backing a display id, matched by
    /// `CGDirectDisplayID`.
    static func screen(for display: DisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.kiwiDisplay?.id == display }
    }

    /// The `NSScreen` a frame (AX coords) mostly sits on — the
    /// one whose visible area it overlaps most. Picks the
    /// animation's `DisplayLink` on multi-monitor. Nil when the
    /// frame overlaps no screen (a stashed corner may barely
    /// graze one; callers fall back to main).
    static func screen(containing frame: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        let rects = screens.map(GeometryUtils.axVisibleFrame)
        guard
            let rect = GeometryUtils.rect(
                mostlyContaining: frame,
                among: rects
            )
        else { return nil }
        return zip(screens, rects).first { $0.1 == rect }?.0
    }

    /// Applies one frame through the shared animate-or-instant
    /// policy: animated when asked (and a screen exists),
    /// otherwise an instant, echo-tracked set with any
    /// in-flight animation cancelled. The single authority for
    /// this policy — `retile` and the floating keyboard resize
    /// both route here; never copy the branch (a copy already
    /// drifted once, dropping the cancel). The animation screen
    /// is the display the target frame lands on (multi-monitor:
    /// one `DisplayLink` per monitor), falling back to main.
    ///
    /// `sizing` says why this frame is being applied (#593);
    /// it reaches `SizeStep` through the animation and decides
    /// whether a shrinking axis may slide instead of snapping.
    /// `.mayInstantSize` is the default because mismarking is asymmetric —
    /// see `BatchSizing`.
    public func applyFrame(
        _ id: WindowID,
        from current: CGRect,
        to target: CGRect,
        animated: Bool,
        isNewWindow: Bool = false,
        sizing: BatchSizing = .mayInstantSize
    ) {
        if animated,
            let screen = Self.screen(containing: target)
                ?? NSScreen.main
                ?? NSScreen.screens.first
        {
            animation.animate(
                window: id,
                on: screen,
                from: current,
                to: target,
                isNewWindow: isNewWindow,
                sizing: sizing
            )
        } else {
            animation.cancel(window: id)
            setFrame(id, target)
        }
    }

    /// The commanded frame of a recent instant set whose echo
    /// is still pending, nil otherwise (#881). The overlay
    /// syncs read it (`FollowSource.syncFrame`'s `commanded`)
    /// so a ring moves at the instant switch; the first
    /// self-echo clears it (`KiwiCore+Events`), after which the
    /// echo-fed state frame is the better truth.
    func recentInstantTarget(_ id: WindowID) -> CGRect? {
        applier.instantTarget(id)
    }

    /// See `recentInstantTarget` — called on the first
    /// self-echo.
    func clearInstantTarget(_ id: WindowID) {
        applier.clearInstantTarget(id)
    }

    /// The frames every visible space's layout assigns right now,
    /// unioned across all displays, without applying them. Used
    /// by retiling and by drag / border / resize slot detection —
    /// a window on any display resolves to its correct slot.
    public func calculatedFrames(
        state: StateCoordinator
    ) -> [WindowID: CGRect] {
        var frames: [WindowID: CGRect] = [:]
        for placement in visiblePlacements(state: state) {
            let input = layoutInput(
                state: state,
                space: placement.space,
                screen: placement.screen
            )
            let computed = LayoutEngine.calculate(
                mode: input.space.mode,
                windows: input.tiled,
                context: input.context
            )
            // Each visible space is a distinct space on a distinct
            // display, so their window sets are disjoint and the
            // union is lossless — the `new` tie-break never fires
            // in practice. It guards only the degenerate case of
            // the same space resolving onto two displays, which
            // `activeSpace(on:)` already self-heals against.
            frames.merge(computed) { _, new in new }
        }
        return frames
    }
}

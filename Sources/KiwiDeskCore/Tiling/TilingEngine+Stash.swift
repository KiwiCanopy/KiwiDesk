import AppKit
import CoreGraphics

// MARK: - Hiding inactive Spaces

extension TilingEngine {
    /// Visible sliver of a stashed window — asymmetric on
    /// purpose (#410), confirmed on device.
    ///
    /// **Width = 1 pt.** A stashed window hangs off *two* edges
    /// (a bottom corner); that corner overhang escapes the
    /// ~32–40 pt single-edge visibility floor, so the horizontal
    /// remnant reaches a barely-perceptible 1 pt (AeroSpace/rift
    /// ship the same 1 px).
    ///
    /// **Height = `visibilityFloor + 8`.** The vertical does not
    /// escape: parking at the bottom puts the title bar at the
    /// screen edge, and macOS lifts the window to keep it
    /// grabbable — the #142/#148 clamp (verified: at a 1 pt ask
    /// the OS floored the height back to ~floor anyway). So 1 pt
    /// buys no visual gain vertically, only thrash (the frame
    /// re-issued every retile, the ±2 pt tolerance never passing)
    /// and a #412 stranding risk. We ship the reachable value
    /// instead: same ~floor-tall look, no thrash. Net: a
    /// 1 × ~48 pt tab, not the old 48 × 48 slab.
    nonisolated static let stashPeekX: CGFloat = 1
    nonisolated static let stashPeekY: CGFloat =
        WindowServerFacts.visibilityFloor + 8

    /// The bottom corner a stashed window parks in. Chosen per
    /// monitor (`optimalHideCorner`) so the window's body — which
    /// hangs ~its full width off the parked side — spills into
    /// dead space, not onto a neighbor display (#410).
    enum HideCorner {
        case bottomLeft
        case bottomRight
    }

    /// Picks the bottom corner whose horizontal overhang misses
    /// every adjacent display (#410, AeroSpace's `OptimalHide
    /// Corner` scan). A stashed window's body hangs off the
    /// parked side; parking toward a neighbor monitor would show
    /// that body on the neighbor. Prefer the side with no
    /// adjacent display; default bottom-right when both or
    /// neither side has one. The scan itself is
    /// `ScreenNeighbors.detect` (#878 generalized it to all
    /// four edges; this consumes the left/right pair) — one
    /// adjacency predicate, not two drifting copies.
    nonisolated static func optimalHideCorner(
        for screen: CGRect,
        among others: [CGRect]
    ) -> HideCorner {
        optimalHideCorner(
            neighbors: ScreenNeighbors.detect(
                around: screen,
                among: others
            )
        )
    }

    /// The corner PREFERENCE, one copy: the stash resolves its
    /// neighbors from screen rects above, while `MonocleLayout`'s
    /// park (#881) arrives with the flags already threaded
    /// through its context (#878) — both must answer alike for
    /// one arrangement, so the choice lives here and not beside
    /// either caller.
    nonisolated static func optimalHideCorner(
        neighbors: ScreenNeighbors
    ) -> HideCorner {
        if !neighbors.right { return .bottomRight }
        if !neighbors.left { return .bottomLeft }
        return .bottomRight
    }

    /// Where a hidden window parks: a bottom corner of its
    /// screen, `stashPeekX × stashPeekY` remaining visible, the
    /// body spilling off the parked side and the bottom. Size
    /// unchanged. `.bottomLeft` anchors the window's right edge
    /// so the visible remnant is its top-right corner.
    nonisolated static func stashFrame(
        _ frame: CGRect,
        in bounds: CGRect,
        corner: HideCorner
    ) -> CGRect {
        let x: CGFloat
        switch corner {
        case .bottomRight:
            x = bounds.maxX - stashPeekX
        case .bottomLeft:
            x = bounds.minX + stashPeekX - frame.width
        }
        return CGRect(
            x: x,
            y: bounds.maxY - stashPeekY,
            width: frame.width,
            height: frame.height
        )
    }

    /// Hides every inactive Space's windows — tiled
    /// AND floating (#412): a floating window belongs to one
    /// space and hides with it, exactly like a tiled one.
    /// (Windows meant to be visible everywhere are the Sticky
    /// capability, #414 — not a floating side effect.)
    ///
    /// Tiled windows come back through the normal retile when
    /// their space is activated again; floating windows come
    /// back through `restoreStashed`, from the frame captured
    /// here on their first stash.
    ///
    /// `animated: true` is the exit half of a coordinated
    /// space switch (#207): the park becomes a visible slide
    /// to the corner, running concurrently with the entrance
    /// in the same retile pass. Every other caller keeps the
    /// instant default.
    func stashInactive(
        state: StateCoordinator,
        fallback: NSScreen,
        force: Bool,
        animated: Bool = false
    ) {
        // Every space shown on some display stays in place; only
        // spaces visible on NO display are parked. On one monitor
        // this is exactly `{activeSpace}` — unchanged. On several,
        // each display keeps its own shown space (#multi-monitor).
        let visible = state.workspaces.visibleSpaces
        guard !visible.isEmpty else { return }
        // The corner scan's screen list comes from the SAME
        // topology seam the scrolling walls read (#878), so the
        // two consumers of `ScreenNeighbors.detect` can never
        // disagree about the arrangement, and a pinned fixture
        // pins them together. The per-window screen PICK below
        // legitimately stays on `NSScreen.screens` — it needs
        // screen objects, not rects.
        let allVisible = allScreenBounds()
        for space in state.workspaces.allSpaces
        where !visible.contains(space.id) {
            for id in space.windows {
                guard let window = state.windows[id],
                    id != dragExemptWindow,
                    // A native-fullscreen window lives on its
                    // own macOS Space (#670): there is nothing
                    // on this desktop to park, and the frame-set
                    // would poke the fullscreen app for nothing.
                    !window.isFullscreen,
                    // Sticky exemption is scope-aware (#445): a
                    // global sticky never parks; a display sticky
                    // parks only off its own monitor.
                    !state.stickyExemptFromStash(
                        window,
                        onSpace: space.id
                    )
                else { continue }
                let screen =
                    NSScreen.screens.first {
                        GeometryUtils.axVisibleFrame(of: $0)
                            .intersects(window.frame)
                    } ?? fallback
                let bounds = GeometryUtils.axVisibleFrame(
                    of: screen
                )
                // No self-filter: `detect` excludes the screen
                // geometrically (a rect cannot lie past its own
                // edge), and a rect *equal* to `bounds` overlaps
                // it entirely, so it can qualify on no side.
                let corner = Self.optimalHideCorner(
                    for: bounds,
                    among: allVisible
                )
                stash(
                    window,
                    in: bounds,
                    corner: corner,
                    force: force,
                    animated: animated,
                    // A floating-MODE space's members ride the
                    // float capture/restore cycle whatever their
                    // own flag (#500): its layout places nothing
                    // on return, so without a capture nothing
                    // would ever bring them back from the corner.
                    capturesOriginal: EffectiveFloat.applies(
                        isFloating: window.isFloating,
                        mode: space.mode
                    )
                )
            }
        }
    }

    /// Parks one window at the stash corner of `bounds`. Sticky
    /// exemption is decided by the caller (`stickyExemptFromStash`,
    /// #445) before this runs — present on every space is the whole
    /// feature (#414), so a sticky window stays in place when its
    /// home space goes inactive. A floating window's original frame
    /// is captured on its first stash — no layout recomputes a
    /// floating frame, so the restore pass needs it. Guarded on
    /// nil: a later forced re-stash (whose state frame is
    /// already the AX echo of the corner) must not overwrite
    /// the original.
    /// `capturesOriginal` is REQUIRED so every call site chooses
    /// (the `forceRetile` pattern, §5): `stashInactive` passes
    /// the EFFECTIVE-float verdict — flag OR floating-mode space
    /// (#500/#1178) — since a floating layout places nothing on
    /// return and the restore pass is such a window's only way
    /// back. A flag-only default would silently come back
    /// through the next caller that omitted it.
    func stash(
        _ window: ManagedWindow,
        in bounds: CGRect,
        corner: HideCorner,
        force: Bool,
        animated: Bool = false,
        capturesOriginal: Bool
    ) {
        let target = Self.stashFrame(
            window.frame,
            in: bounds,
            corner: corner
        )
        if !force, Self.close(window.frame, to: target) {
            return
        }
        if capturesOriginal,
            stashedFrames[window.id] == nil
        {
            stashedFrames[window.id] = window.frame
        }
        if animated {
            // The exit half of a coordinated switch (#207):
            // slide to the corner. A window still flying IN
            // retargets in place (spring carry-over), so a
            // rapid bounce stays smooth.
            applyFrame(
                window.id,
                from: window.frame,
                to: target,
                animated: true
            )
            return
        }
        // An instant park must not snap a window already
        // sliding to this corner (#207): an event-driven retile
        // or the 300 ms settle landing mid-exit would otherwise
        // cancel the slide and teleport the window. Let the
        // animation finish; it ends at this exact target.
        if let inFlight = animation.targetFrame(
            window: window.id
        ), Self.close(inFlight, to: target) {
            return
        }
        animation.cancel(window: window.id)
        setFrame(window.id, target)
    }
}

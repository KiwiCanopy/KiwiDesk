import AppKit
import CoreGraphics

// MARK: - Hiding inactive virtual spaces

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
    /// neither side has one. All frames are AX visible frames;
    /// x is shared with Cocoa, so left/right adjacency is exact.
    nonisolated static func optimalHideCorner(
        for screen: CGRect,
        among others: [CGRect]
    ) -> HideCorner {
        func hasNeighbor(onRight: Bool) -> Bool {
            others.contains { other in
                let touchesX =
                    onRight
                    ? other.minX >= screen.maxX - 1
                    : other.maxX <= screen.minX + 1
                let overlapsY =
                    other.minY < screen.maxY
                    && other.maxY > screen.minY
                return touchesX && overlapsY
            }
        }
        if !hasNeighbor(onRight: true) { return .bottomRight }
        if !hasNeighbor(onRight: false) { return .bottomLeft }
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

    /// Hides every inactive virtual space's windows — tiled
    /// AND floating (#412): a floating window belongs to one
    /// space and hides with it, exactly like a tiled one.
    /// (Windows meant to be visible everywhere are the Sticky
    /// capability, #414 — not a floating side effect.)
    ///
    /// Tiled windows come back through the normal retile when
    /// their space is activated again; floating windows come
    /// back through `restoreStashed`, from the frame captured
    /// here on their first stash.
    func stashInactive(
        state: StateCoordinator,
        fallback: NSScreen,
        force: Bool
    ) {
        // Every space shown on some display stays in place; only
        // spaces visible on NO display are parked. On one monitor
        // this is exactly `{activeSpace}` — unchanged. On several,
        // each display keeps its own shown space (#multi-monitor).
        let visible = state.workspaces.visibleSpaces
        guard !visible.isEmpty else { return }
        let allVisible = NSScreen.screens.map {
            GeometryUtils.axVisibleFrame(of: $0)
        }
        for space in state.workspaces.allSpaces
        where !visible.contains(space.id) {
            for id in space.windows {
                guard let window = state.windows[id],
                    id != dragExemptWindow,
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
                let corner = Self.optimalHideCorner(
                    for: bounds,
                    among: allVisible.filter { $0 != bounds }
                )
                stash(
                    window,
                    in: bounds,
                    corner: corner,
                    force: force
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
    func stash(
        _ window: ManagedWindow,
        in bounds: CGRect,
        corner: HideCorner,
        force: Bool
    ) {
        let target = Self.stashFrame(
            window.frame,
            in: bounds,
            corner: corner
        )
        if !force, Self.close(window.frame, to: target) {
            return
        }
        if window.isFloating,
            stashedFrames[window.id] == nil
        {
            stashedFrames[window.id] = window.frame
        }
        animation.cancel(window: window.id)
        setFrame(window.id, target)
    }

    /// Restores the active space's stashed floating windows to
    /// their captured frames. Runs on every retile after the
    /// layout frames apply; every space switch retiles with
    /// `force: true`, which bypasses the ±2 pt tolerance — the
    /// restore itself is deliberately NOT gated behind that
    /// tolerance, so it cannot be swallowed by echo lag.
    ///
    /// A capture is consumed only once the window's STATE frame
    /// reads back at the original — i.e. the restore's AX echo
    /// landed. Consuming eagerly opened an echo-lag hole: on a
    /// rapid space bounce (A→B→A→B on a held hotkey) the next
    /// stash saw a nil entry while the state frame still read
    /// the corner, captured the corner as the new "original",
    /// and the window was restored to the corner forever. Until
    /// the echo lands the entry survives, re-stashes cannot
    /// re-capture (nil guard), and each activation simply
    /// re-issues the idempotent restore. A genuine user move
    /// consumes the entry instead (`forgetStash`, wired to
    /// non-echo `windowMoved` events): the user took over.
    ///
    /// A window that got a layout frame this retile (unfloated
    /// while stashed) is the layout's to place: its entry is
    /// dropped, not re-applied. A drag-exempt window keeps its
    /// entry untouched — the pointer owns it mid-gesture, and a
    /// cancelled gesture must not have lost the original.
    /// Entries for windows that left the state (closed) are
    /// swept — before the active-space guard, so a reused
    /// WindowID (#152) cannot inherit a dead capture — and a
    /// native-tab re-key migrates its entry to the new id
    /// (`KiwiCore.handle`, #308).
    func restoreStashed(
        state: StateCoordinator,
        frames: [WindowID: CGRect]
    ) {
        stashedFrames = stashedFrames.filter {
            state.windows[$0.key] != nil
        }
        // Restore floats for every space currently shown on some
        // display, not just the focused one (#multi-monitor): a
        // secondary display's space activating must un-park its
        // floating windows too.
        let visibleWindows = state.workspaces.visibleSpaces
            .compactMap { state.workspaces[$0]?.windows }
            .flatMap { $0 }
        for id in visibleWindows {
            guard let original = stashedFrames[id]
            else { continue }
            if frames[id] != nil {
                stashedFrames[id] = nil
                continue
            }
            guard id != dragExemptWindow else { continue }
            if let current = state.windows[id]?.frame,
                Self.close(current, to: original)
            {
                stashedFrames[id] = nil
                continue
            }
            // An original whose display is gone can never be
            // reached — the OS clamps every set elsewhere, the
            // clamp echoes within grace, and the retry would
            // loop forever. Consume; the OS-relocated frame is
            // the best remaining truth (the user can move it).
            if !NSScreen.screens.contains(where: {
                GeometryUtils.axVisibleFrame(of: $0)
                    .intersects(original)
            }) {
                stashedFrames[id] = nil
                continue
            }
            animation.cancel(window: id)
            setFrame(id, original)
        }
    }

    /// Migrates a stashed frame capture when a native-tab rekeys
    /// a window id (#308/#412).
    public func rekeyStash(oldID: WindowID, newID: WindowID) {
        guard let capture = stashedFrames.removeValue(forKey: oldID)
        else { return }
        stashedFrames[newID] = capture
    }

    /// Whether a frame sits at some screen's stash corner.
    /// Keeps a LATE stash echo — one landing past the applier's
    /// 1 s grace, so `didRecentlySetFrame` no longer vouches
    /// for it — from classifying as a user move and consuming
    /// the capture (which would strand the window at the
    /// corner, the #412 failure mode). A genuine user drag TO
    /// the exact corner is indistinguishable and keeps its
    /// capture — harmless: the next activation restores it.
    /// Checks both bottom corners (which one a window parked in
    /// depends on its monitor's neighbors, `optimalHideCorner`),
    /// with the asymmetric peek: `.bottomLeft` anchors the right
    /// edge, so its x depends on the frame width.
    static func looksStashed(_ frame: CGRect) -> Bool {
        NSScreen.screens.contains { screen in
            let bounds = GeometryUtils.axVisibleFrame(
                of: screen
            )
            let atBottom =
                abs(frame.minY - (bounds.maxY - stashPeekY))
                <= retileTolerance
            let atRight =
                abs(frame.minX - (bounds.maxX - stashPeekX))
                <= retileTolerance
            let atLeft =
                abs(
                    frame.minX
                        - (bounds.minX + stashPeekX
                            - frame.width)
                ) <= retileTolerance
            return atBottom && (atRight || atLeft)
        }
    }

    /// Drops a window's stash capture: the user moved it
    /// (a non-echo `windowMoved`), so the captured frame no
    /// longer represents where the window belongs.
    func forgetStash(_ id: WindowID) {
        stashedFrames[id] = nil
    }
}

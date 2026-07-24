import AppKit
import CoreGraphics

// MARK: - Restoring stashed floating windows

/// The restore/capture side of the stash: split from
/// `TilingEngine+Stash.swift` (350-line ceiling) along the
/// park-vs-restore seam. Parking lives there; the float
/// frame-capture bookkeeping and its restore pass live here.
extension TilingEngine {
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

    /// A float's captured original frame, if one is pending —
    /// the frame `restoreStashed` will deliver. Read-side
    /// companion to `seedStash`/`forgetStash`, so callers never
    /// touch `stashedFrames` directly.
    func stashOriginal(_ id: WindowID) -> CGRect? {
        stashedFrames[id]
    }

    /// Seeds (or overwrites) a float's capture with a
    /// re-anchored frame (#444): the translated frame becomes
    /// the "original" that `restoreStashed` delivers — on the
    /// very next retile when the target space is visible, or on
    /// the activation that un-parks it. Overwriting is the
    /// point: a pre-existing capture holds source-display
    /// coordinates that are no longer where the window belongs.
    /// Known fragilities (accepted): any non-echo `windowMoved`
    /// landing before the delivery echo — a user drag, or an
    /// app spontaneously moving its own parked window —
    /// consumes the seed via `forgetStash`, cancelling the
    /// re-anchor; and a relocation landing MID-DRAG never seeds
    /// at all (`reanchorFloat` skips the drag-exempt window),
    /// so that float can restore to its old monitor later.
    /// Both are consistent with "the pointer took over".
    func seedStash(_ id: WindowID, frame: CGRect) {
        stashedFrames[id] = frame
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

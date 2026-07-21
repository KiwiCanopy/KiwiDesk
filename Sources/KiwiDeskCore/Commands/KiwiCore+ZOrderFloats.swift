import Accessibility
import AppKit
import Foundation

extension KiwiCore {
    /// Quiet-raises the windows that belong ABOVE the tiled
    /// plane: the active space's floating windows — their stash
    /// restore repositions but cannot re-order, so a focus raise
    /// buries them behind full-frame tiled windows — and every
    /// FLOATING sticky window (visible on all spaces, never
    /// stashed, equally buried). The target set gates on
    /// `isFloating`, never `isSticky` alone (#418 tier model): a
    /// tiled-sticky window is a real layout participant on the
    /// active space (#414 v2) and stays on the tiled plane —
    /// raising it would pop a tile over its neighbors.
    ///
    /// Then hands focus over as the sequence's ordered final step
    /// (the `raiseSequentially` pattern: AXRaise on a foreign
    /// window activates its app and steals focus window by window,
    /// so the intended focus must be re-asserted after the raises).
    /// The raised floats are recorded in `floatRaisesInFlight` so
    /// their focus echoes are reverted rather than moving the ring
    /// onto them (see `KiwiCore+Events`); the re-assert never warps
    /// — it runs while `zOrderRestoresInFlight` holds, where
    /// `mouseWarpEligible` swallows warps by design — so callers
    /// that want the pointer to follow warp at INTENT time, before
    /// calling this (as `focusSpace` does). With nothing to raise,
    /// focus is handed over directly.
    func raiseFloatsAndSticky(
        thenFocus focused: WindowID?
    ) {
        let pairs = floatLayerTargets().compactMap {
            id -> (WindowID, AXUIElement)? in
            eventLoop.element(for: id).map { (id, $0) }
        }
        guard !pairs.isEmpty else {
            if let focused {
                focusWindow(
                    focused,
                    refocusRetile: false,
                    warp: false
                )
            }
            return
        }
        // Stamp the floats so the focus echoes their AX raises emit
        // (AX couples raise with app activation) are reverted to the
        // real focus instead of moving the ring onto a float — but
        // only within `floatRaiseEchoWindow`, so a later deliberate
        // float focus is never mistaken for the echo (#418). Prune by
        // age, then restamp: overlapping sequences must not orphan
        // each other's entries (a plain reset let a prior sequence's
        // late echoes consume the new sequence's entries).
        let now = Date()
        floatRaisesInFlight = floatRaisesInFlight.filter {
            now.timeIntervalSince($0.value) < Self.floatRaiseEchoWindow
        }
        for id in pairs.map(\.0) { floatRaisesInFlight[id] = now }
        // Guard the focus handoff by generation + live focus: a stale
        // sequence (superseded by a newer focus) must not steal focus
        // back, and must not fight a concurrent sequence.
        floatRaiseGeneration += 1
        let generation = floatRaiseGeneration
        performZOrderSequence(elements: pairs.map(\.1)) {
            [weak self] in
            guard let self,
                generation == self.floatRaiseGeneration
            else { return }
            if let focused, focused == self.activeSpace?.focused {
                self.focusWindow(
                    focused,
                    refocusRetile: false,
                    warp: false
                )
            }
        }
    }

    /// Re-raises the float layer after focus lands on a tiled
    /// window, keeping floats above the just-focused window (#418).
    /// AX couples raise and focus, so the raised floats' apps
    /// activate; `raiseFloatsAndSticky` hands focus back and the
    /// float echoes are reverted (`floatRaisesInFlight`), so the
    /// ring stays on the focused tiled window while the floats keep
    /// their z-order above it. Gated by the caller to genuine
    /// (non-echo) focus changes so the focus-handoff's own echo
    /// cannot re-trigger the raise, and skipped when the focused
    /// window is itself a float (it is already on the float layer).
    ///
    /// Coalesced through the `.floatRaise` deferred slot: a burst of
    /// focus changes (rapid clicks, held focus-nav) would otherwise
    /// pile one full raise sequence per focus, and their intermediate
    /// raises thrash the z-order — more than one tile transiently
    /// ends up over the float. The slot self-cancels on reschedule,
    /// so only the window focus finally settles on raises the floats,
    /// leaving exactly the focused tile above them. The body re-reads
    /// `activeSpace?.focused` so a stale target no-ops.
    func raiseFloatsAbove(afterFocusing id: WindowID) {
        guard state.windows[id]?.isFloating != true,
            !floatLayerTargets().isEmpty
        else { return }
        deferred.schedule(.floatRaise, after: .milliseconds(50)) {
            [weak self] in
            guard let self, id == self.activeSpace?.focused
            else { return }
            self.raiseFloatsAndSticky(thenFocus: id)
        }
    }

    /// The ids of the windows that belong ABOVE the tiled plane:
    /// the active space's floating windows plus every floating
    /// sticky window (visible on all spaces, never stashed). The
    /// gate is `isFloating`, never `isSticky` alone — a tiled-sticky
    /// window is a real layout participant (#414 v2) and stays on
    /// the tiled plane. Sorted by id so overlapping floats keep a
    /// stable order across passes.
    func floatLayerTargets() -> [WindowID] {
        var targets: [WindowID] = []
        if let space = activeSpace {
            targets = space.windows.filter {
                state.windows[$0]?.isFloating == true
            }
        }
        for window in state.windows.all
            .sorted(by: { $0.id.raw < $1.id.raw })
        where window.isSticky && window.isFloating
            && !targets.contains(window.id)
        {
            targets.append(window.id)
        }
        return targets
    }

    /// Runs a serial Z-order raise sequence on `zOrderQueue`,
    /// holding `zOrderRestoresInFlight` until the main-actor
    /// completion block finishes (#415 architect follow-up).
    func performZOrderSequence(
        elements: [AXUIElement],
        completion: @MainActor @escaping () -> Void
    ) {
        zOrderRestoresInFlight += 1
        nonisolated(unsafe) let elements = elements
        zOrderQueue.async { [weak self] in
            for element in elements {
                AXHelper.raiseQuietly(element)
            }
            Task { @MainActor [weak self] in
                completion()
                self?.zOrderRestoresInFlight -= 1
            }
        }
    }
}

import Accessibility
import AppKit
import Foundation

extension KiwiCore {
    /// Quiet-raises the windows that belong ABOVE the tiled
    /// plane after a space activation (#412/#414 QA): the
    /// active space's floating windows — their stash restore
    /// repositions but cannot re-order, so the switch's focus
    /// raise buried them behind full-frame tiled windows —
    /// and every FLOATING sticky window (visible on all
    /// spaces, never stashed, equally buried). The target set
    /// (`floatLayerElements`) gates on `isFloating`, never
    /// `isSticky` alone (#418 tier model): a tiled-sticky
    /// window is a real layout participant on the active space
    /// (#414 v2) and stays on the tiled plane — raising it
    /// would pop a tile over its neighbors. On the #418 fast
    /// path the floats' window level already holds them above
    /// the tiled plane across the switch, so the raise is
    /// skipped and only the focus handoff runs; the raise is
    /// the §5 fallback for a macOS without the level symbol.
    /// Then hands focus over as the sequence's ordered final
    /// step (the `raiseSequentially` pattern: AXRaise on the
    /// active app's windows steals focus window by window, so
    /// the intended focus must be re-asserted after the
    /// raises, and the focused window ends on top). The
    /// re-assert never warps — it runs while
    /// `zOrderRestoresInFlight` holds, where `mouseWarpEligible`
    /// swallows warps by design — so callers that want the
    /// pointer to follow warp at INTENT time, before calling
    /// this (as `focusSpace` does). With nothing to raise,
    /// focus is handed over directly.
    func raiseFloatsAndSticky(
        thenFocus focused: WindowID?
    ) {
        // Fast path (#418): a floating window's window-server level
        // is pinned above the tiled plane and survives space
        // switches, so the per-switch AX raise is redundant — hand
        // focus over directly. The raise machinery below stays as
        // the §5 fallback for a macOS that drops the level symbol.
        let ordered =
            WindowLevel.isAvailable ? [] : floatLayerElements()
        guard !ordered.isEmpty else {
            if let focused {
                focusWindow(
                    focused,
                    refocusRetile: false,
                    warp: false
                )
            }
            return
        }
        performZOrderSequence(elements: ordered) { [weak self] in
            if let focused {
                self?.focusWindow(
                    focused,
                    refocusRetile: false,
                    warp: false
                )
            }
        }
    }

    /// Re-raises the float layer after focus lands on a tiled
    /// window, on the AX fallback only (#418). The fast path keeps
    /// floats above the tiled plane via their window level, so this
    /// is a no-op there. AX couples raise and focus, so the raised
    /// floats' apps activate; `raiseFloatsAndSticky` hands focus
    /// back, degrading to "floats above every UNfocused tiled
    /// window" — the fast path is the fully-correct version. Gated
    /// by the caller to genuine (non-echo) focus changes so the
    /// focus-handoff's own echo cannot re-trigger the raise. Best
    /// effort by nature: the float raises emit non-self focus
    /// echoes that warp the mouse onto the last-raised float, and
    /// the handoff does not warp back — an accepted artifact of a
    /// macOS that has dropped the level symbol entirely.
    func raiseFloatsIfFallback(afterFocusing id: WindowID) {
        guard !WindowLevel.isAvailable,
            state.windows[id]?.isFloating != true,
            !floatLayerElements().isEmpty
        else { return }
        raiseFloatsAndSticky(thenFocus: id)
    }

    /// The AX elements of the windows that belong ABOVE the tiled
    /// plane: the active space's floating windows plus every
    /// floating sticky window (visible on all spaces, never
    /// stashed). The gate is `isFloating`, never `isSticky` alone —
    /// a tiled-sticky window is a real layout participant (#414 v2)
    /// and stays on the tiled plane. Sorted by id so overlapping
    /// floats keep a stable order across passes.
    private func floatLayerElements() -> [AXUIElement] {
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
        return targets.compactMap { eventLoop.element(for: $0) }
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

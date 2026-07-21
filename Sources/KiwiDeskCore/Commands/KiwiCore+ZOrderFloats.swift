import Accessibility
import AppKit
import Foundation

extension KiwiCore {
    /// Quiet-raises the windows that belong ABOVE the tiled
    /// plane after a space activation (#412/#414 QA): the
    /// active space's floating windows — their stash restore
    /// repositions but cannot re-order, so the switch's focus
    /// raise buried them behind full-frame tiled windows —
    /// and every sticky window (visible on all spaces, never
    /// stashed, equally buried). Then hands focus over as the
    /// sequence's ordered final step (the `raiseSequentially`
    /// pattern: AXRaise on the active app's windows steals
    /// focus window by window, so the intended focus must be
    /// re-asserted after the raises, and the focused window
    /// ends on top). The re-assert never warps — it runs while
    /// `zOrderRestoresInFlight` holds, where `mouseWarpEligible`
    /// swallows warps by design — so callers that want the
    /// pointer to follow warp at INTENT time, before calling
    /// this (as `focusSpace` does). With nothing to raise,
    /// focus is handed over directly.
    func raiseFloatsAndSticky(
        thenFocus focused: WindowID?
    ) {
        var targets: [WindowID] = []
        if let space = activeSpace {
            targets = space.windows.filter {
                state.windows[$0]?.isFloating == true
            }
        }
        // Sorted: `all` is dictionary-ordered, and overlapping
        // sticky windows must not shuffle z-order per switch.
        for window in state.windows.all
            .sorted(by: { $0.id.raw < $1.id.raw })
        where window.isSticky && !targets.contains(window.id) {
            targets.append(window.id)
        }
        let ordered = targets.compactMap {
            eventLoop.element(for: $0)
        }
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

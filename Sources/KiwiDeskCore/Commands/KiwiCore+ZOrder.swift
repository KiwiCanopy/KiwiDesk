import AppKit
import Foundation

/// Serial queue for z-order raises. AX raise calls are
/// blocking IPC; running them here keeps the main thread free
/// and their order strict.
private let zOrderQueue = DispatchQueue(
    label: "org.kiwidesk.zorder",
    qos: .userInteractive
)

/// Z-order maintenance for the layouts whose windows overlap:
/// stack's cascade and scrolling's edge piles.
extension KiwiCore {
    /// Requests a z-order restore after something scrambled
    /// the stacking (zone crossings, mode switches, native
    /// space switches, profile loads). Deferred until all
    /// animations settle: a raise is only processed once the
    /// target app's main thread is free, and while frames are
    /// still being applied, slow apps process their raise
    /// late and end up out of order.
    func scheduleZOrderRestore() {
        pendingZOrderRestore = true
        if tiler.animation.activeCount == 0 {
            runPendingZOrderRestore()
        }
    }

    /// Runs a scheduled restore (called when animations end).
    func runPendingZOrderRestore() {
        guard pendingZOrderRestore else { return }
        pendingZOrderRestore = false
        guard let space = activeSpace else { return }
        switch space.mode {
        case .stack:
            restoreStackZOrder(space)
        case .scrolling:
            restoreScrollingZOrder(space)
        default:
            break
        }
    }

    /// Re-raises the stack zone top to bottom, so upper
    /// windows sit behind lower ones and every title bar of
    /// the cascade stays visible. A plain focus change still
    /// brings the focused window to the front, which is the
    /// expected override.
    private func restoreStackZOrder(_ space: Space) {
        let boundary = max(1, tiler.settings.stack.masterCount)
        guard space.windows.count > boundary else { return }
        raiseSequentially(
            Array(space.windows[boundary...]),
            thenFocus: space.focused
        )
    }

    /// Scrolling: columns pushed past the screen edges are
    /// clamped there by macOS and pile up, overlapping. Each
    /// side must stack toward its own edge — the column
    /// nearest the focus on top, farther ones underneath —
    /// so the piles read as the row receding to the left and
    /// to the right of the viewport.
    private func restoreScrollingZOrder(_ space: Space) {
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard tiled.count > 1 else { return }
        let focusIndex =
            space.focused.flatMap {
                tiled.firstIndex(of: $0)
            } ?? 0
        raiseSequentially(
            Self.scrollingRaiseOrder(
                tiled,
                focusIndex: focusIndex
            ),
            thenFocus: space.focused
        )
    }

    /// The raise sequence for the scrolling piles: both sides
    /// run farthest-from-focus first, so every raise lands on
    /// top of the previous one — the left pile ascending, the
    /// right pile descending. The focused window itself is
    /// left out; the closing focus re-assert puts it on top.
    /// Pure math, unit-tested.
    nonisolated static func scrollingRaiseOrder(
        _ windows: [WindowID],
        focusIndex: Int
    ) -> [WindowID] {
        guard windows.indices.contains(focusIndex) else {
            return windows
        }
        return Array(windows[..<focusIndex])
            + windows[(focusIndex + 1)...].reversed()
    }

    /// Raises the windows in exactly the given order. Raises
    /// run sequentially on one queue: each call returns only
    /// after the target app processed it, which keeps the
    /// order across apps.
    private func raiseSequentially(
        _ ids: [WindowID],
        thenFocus focused: WindowID?
    ) {
        let ordered = ids.compactMap {
            eventLoop.element(for: $0)
        }
        guard !ordered.isEmpty else { return }
        nonisolated(unsafe) let elements = ordered
        zOrderQueue.async { [weak self] in
            for element in elements {
                AXHelper.raiseQuietly(element)
            }
            // AXRaise on a window of the ACTIVE app makes it
            // key (AppKit's handler does makeKeyAndOrderFront),
            // so the sequence steals focus window by window.
            // Re-assert the intended focus as the ordered
            // final step of the same sequence.
            guard let focused else { return }
            Task { @MainActor [weak self] in
                self?.focusWindow(focused)
            }
        }
    }

    /// Whether swapping these two windows moves one across
    /// the stack layout's master/stack boundary.
    func crossesStackBoundary(
        _ a: WindowID,
        _ b: WindowID,
        in space: Space
    ) -> Bool {
        guard space.mode == .stack else { return false }
        let boundary = max(1, tiler.settings.stack.masterCount)
        guard let indexA = space.windows.firstIndex(of: a),
            let indexB = space.windows.firstIndex(of: b)
        else { return false }
        return (indexA < boundary) != (indexB < boundary)
    }
}

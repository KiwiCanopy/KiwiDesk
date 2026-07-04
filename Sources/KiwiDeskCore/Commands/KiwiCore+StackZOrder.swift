import AppKit
import Foundation

/// Serial queue for z-order raises. AX raise calls are
/// blocking IPC; running them here keeps the main thread free
/// and their order strict.
private let zOrderQueue = DispatchQueue(
    label: "org.kiwidesk.zorder",
    qos: .userInteractive
)

/// Stack-mode z-order maintenance: cascaded windows must be
/// raised top to bottom so every title bar stays visible.
extension KiwiCore {
    /// Requests a stack z-order restore after a window
    /// crossed the master/stack boundary. Deferred until all
    /// animations settle: a raise is only processed once the
    /// target app's main thread is free, and while frames are
    /// still being applied, slow apps process their raise
    /// late and end up out of order.
    func scheduleStackZOrderRestore() {
        pendingStackZOrderRestore = true
        if tiler.animation.activeCount == 0 {
            runPendingStackZOrderRestore()
        }
    }

    /// Runs a scheduled restore (called when animations end).
    func runPendingStackZOrderRestore() {
        guard pendingStackZOrderRestore else { return }
        pendingStackZOrderRestore = false
        restoreStackZOrder()
    }

    /// Re-raises the stack zone top to bottom, so upper
    /// windows sit behind lower ones and every title bar of
    /// the cascade stays visible. A plain focus change still
    /// brings the focused window to the front, which is the
    /// expected override. Raises run sequentially on one
    /// queue: each call returns only after the target app
    /// processed it, which keeps the order across apps.
    private func restoreStackZOrder() {
        guard let space = activeSpace, space.mode == .stack
        else { return }
        let boundary = max(1, tiler.settings.stack.masterCount)
        guard space.windows.count > boundary else { return }
        let ordered = space.windows[boundary...].compactMap {
            eventLoop.element(for: $0)
        }
        guard !ordered.isEmpty else { return }
        let focused = space.focused
        nonisolated(unsafe) let elements = ordered
        zOrderQueue.async { [weak self] in
            for element in elements {
                AXHelper.raiseQuietly(element)
            }
            // AXRaise on a window of the ACTIVE app makes it
            // key (AppKit's handler does makeKeyAndOrderFront),
            // so the cascade steals focus window by window.
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

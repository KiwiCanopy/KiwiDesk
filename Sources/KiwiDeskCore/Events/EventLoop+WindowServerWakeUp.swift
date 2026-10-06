import Foundation

/// The destroy half of the WindowServer wake-up (#1877): a
/// tracked window WindowServer destroyed while no AX destroy
/// arrived. The create half pulls the adoption heal forward
/// (`KiwiCore+WindowServerWakeUp`).
extension EventLoop {
    /// Re-reads the app tracking `id`, off the main actor, when
    /// it still tracks it; reads nothing from WindowServer.
    func windowServerDestroyed(_ id: WindowID) {
        guard isRunning,
            let pid = elements.first(where: { $0.value[id] != nil })?.key
        else { return }
        onLog("wake-up: w\(id.raw) destroyed unanswered, pid \(pid)")
        reconcileOffMain(pid: pid, app: appRef(of: pid))
    }
}

import ApplicationServices
import Foundation

/// A window list read off the main actor for an event-driven
/// reconcile (#1930), and the tracked set it was read beside.
/// The list is up to one read old when the reconcile applies it,
/// so it speaks only for windows tracked across the whole read.
struct PrefetchedWindows {
    let elements: [AXUIElement]
    /// The app's tracked ids when the read was requested.
    let trackedAtRequest: Set<WindowID>

    /// Keeps the flight out of the sweep: a window tracked during
    /// the read stays live (the list predates it), and one that
    /// left during the read is not re-adopted from the list.
    func excuseFlight(
        tracked: Set<WindowID>,
        live: inout Set<WindowID>,
        appeared: inout [(element: AXUIElement, id: WindowID)]
    ) {
        live.formUnion(tracked.subtracting(trackedAtRequest))
        let left = trackedAtRequest.subtracting(tracked)
        guard !left.isEmpty else { return }
        live.subtract(left)
        appeared.removeAll { left.contains($0.id) }
    }
}

extension EventLoop {
    /// Reconciles `pid` with its window list read OFF the main
    /// actor, on the app's `AXReadCoalescer` lane (#1930): a slow
    /// app's list read held the main actor on every activation
    /// and focus change. `then` runs after the reconcile, on the
    /// main actor. Boot, the heal and `reconcileAll` keep the
    /// synchronous `reconcile`.
    func reconcileOffMain(
        pid: pid_t,
        app: AppRef,
        then: (@MainActor () -> Void)? = nil
    ) {
        let tracked = Set(elements[pid]?.keys ?? [:].keys)
        nonisolated(unsafe) let read = axWindows
        axReads.requestWindows(pid: pid) {
            read(pid)
        } onList: { [weak self] list in
            guard let self else { return }
            reconcile(
                pid: pid,
                app: app,
                prefetched: PrefetchedWindows(
                    elements: list,
                    trackedAtRequest: tracked
                )
            )
            then?()
        }
    }
}

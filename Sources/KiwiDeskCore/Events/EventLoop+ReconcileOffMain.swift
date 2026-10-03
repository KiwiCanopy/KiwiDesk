import ApplicationServices
import Foundation

/// A window list read off the main actor for an event-driven
/// reconcile (#1930), and the tracked set taken as the read
/// STARTED. The list is up to one read old when the reconcile
/// applies it, so it speaks only for windows tracked across the
/// whole read.
struct PrefetchedWindows {
    let elements: [AXUIElement]
    /// The app's tracked ids when the read started.
    let trackedAtRead: Set<WindowID>

    /// Keeps the flight out of the sweep: a window tracked during
    /// the read stays live (the list predates it), and one that
    /// left during the read is not re-adopted from the list.
    func excuseFlight(
        tracked: Set<WindowID>,
        live: inout Set<WindowID>,
        appeared: inout [(element: AXUIElement, id: WindowID)]
    ) {
        live.formUnion(tracked.subtracting(trackedAtRead))
        let left = trackedAtRead.subtracting(tracked)
        guard !left.isEmpty else { return }
        live.subtract(left)
        appeared.removeAll { left.contains($0.id) }
    }
}

/// The off-main reconciles owed per app, and each app's newest
/// focus report (#1930). One list read is outstanding per app;
/// what waits on it is owed by THAT read's one reconcile, and a
/// request landing mid-read is owed by the read after it, since a
/// read that began first cannot answer it.
struct OffMainReconcile {
    struct Debt {
        var app: AppRef
        var then: [@MainActor () -> Void]
    }

    var reading: [pid_t: [@MainActor () -> Void]] = [:]
    var next: [pid_t: Debt] = [:]
    /// Per app: the generation of the newest focus report asked
    /// for. A report delivered late stands only while it is the
    /// newest, so it can never land after a newer one.
    private(set) var focusReports: [pid_t: Int] = [:]

    mutating func stampFocusReport(pid: pid_t) -> Int {
        let stamp = (focusReports[pid] ?? 0) + 1
        focusReports[pid] = stamp
        return stamp
    }

    func isNewestFocusReport(_ stamp: Int, pid: pid_t) -> Bool {
        focusReports[pid] == stamp
    }
}

extension EventLoop {
    /// Reconciles `pid` with its window list read OFF the main
    /// actor, on the app's `AXReadCoalescer` lane (#1930): a slow
    /// app's list read held the main actor on every activation
    /// and focus change. `then` runs after a reconcile whose read
    /// began after this request, on the main actor. An app
    /// KiwiDesk does not observe is reconciled at once, which
    /// reads nothing of it.
    func reconcileOffMain(
        pid: pid_t,
        app: AppRef,
        then: (@MainActor () -> Void)? = nil
    ) {
        guard observers[pid] != nil else {
            reconcile(pid: pid, app: app)
            then?()
            return
        }
        let owed = then.map { [$0] } ?? []
        guard offMain.reading[pid] == nil else {
            offMain.next[pid, default: .init(app: app, then: [])]
                .then += owed
            offMain.next[pid]?.app = app
            return
        }
        readWindowList(pid: pid, app: app, then: owed)
    }

    /// Runs `then` once the reconcile in flight for `pid` lands,
    /// or at once when none is — for a reader that needs tracking
    /// settled by the read already asked, not a fresh one.
    func afterPendingReconcile(
        pid: pid_t,
        then: @escaping @MainActor () -> Void
    ) {
        guard offMain.reading[pid] != nil else {
            then()
            return
        }
        offMain.reading[pid]?.append(then)
    }

    private func readWindowList(
        pid: pid_t,
        app: AppRef,
        then: [@MainActor () -> Void]
    ) {
        offMain.reading[pid] = then
        let tracked = Set(elements[pid]?.keys ?? [:].keys)
        nonisolated(unsafe) let read = axWindows
        axReads.requestWindows(pid: pid) {
            read(pid)
        } onList: { [weak self] list in
            self?.applyWindowList(
                list,
                pid: pid,
                app: app,
                tracked: tracked
            )
        }
    }

    private func applyWindowList(
        _ list: [AXUIElement],
        pid: pid_t,
        app: AppRef,
        tracked: Set<WindowID>
    ) {
        let owed = offMain.reading.removeValue(forKey: pid) ?? []
        reconcile(
            pid: pid,
            app: app,
            prefetched: PrefetchedWindows(
                elements: list,
                trackedAtRead: tracked
            )
        )
        for then in owed { then() }
        if let debt = offMain.next.removeValue(forKey: pid) {
            reconcileOffMain(pid: pid, app: debt.app)
            offMain.reading[pid]? += debt.then
            if offMain.reading[pid] == nil {
                for then in debt.then { then() }
            }
        }
    }

    /// Whether KiwiDesk commanded a focus after `requested`: a
    /// report asked before it describes a state the command
    /// superseded, and the command's own echo follows (#1088).
    func focusCommanded(since requested: ContinuousClock.Instant)
        -> Bool
    {
        guard let commanded = lastCommandedFocus else { return false }
        return requested < commanded
    }
}

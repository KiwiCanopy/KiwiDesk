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

/// The off-main reconciles owed per app (#1930). One list read is
/// outstanding per app; what waits on it is owed by THAT read's
/// one reconcile, and a request landing mid-read is owed by the
/// read after it, since a read that began first cannot answer it.
struct OffMainReconcile {
    struct Read {
        /// Names the read, so a delivery from a read the loop no
        /// longer waits on — one from before a stop — pays nothing.
        let ticket: Int
        var then: [@MainActor () -> Void]
    }

    struct Debt {
        var app: AppRef
        var then: [@MainActor () -> Void]
    }

    var reading: [pid_t: Read] = [:]
    var next: [pid_t: Debt] = [:]
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

    /// Runs `then` after the reconcile last asked for `pid` — the
    /// one parked behind a read in flight, else that read — or
    /// after a fresh one when none is pending: a reader that needs
    /// tracking settled by a read begun after its own event.
    func afterPendingReconcile(
        pid: pid_t,
        app: AppRef,
        then: @escaping @MainActor () -> Void
    ) {
        if offMain.next[pid] != nil {
            offMain.next[pid]?.then.append(then)
        } else if offMain.reading[pid] != nil {
            offMain.reading[pid]?.then.append(then)
        } else {
            reconcileOffMain(pid: pid, app: app, then: then)
        }
    }

    private func readWindowList(
        pid: pid_t,
        app: AppRef,
        then: [@MainActor () -> Void]
    ) {
        let ticket = focusOrder.issueTicket()
        offMain.reading[pid] = .init(ticket: ticket, then: then)
        let tracked = Set(elements[pid]?.keys ?? [:].keys)
        nonisolated(unsafe) let read = axWindows
        axReads.requestWindows(pid: pid) {
            read(pid)
        } onList: { [weak self] list in
            self?.applyWindowList(
                list,
                pid: pid,
                app: app,
                tracked: tracked,
                ticket: ticket
            )
        }
    }

    private func applyWindowList(
        _ list: [AXUIElement],
        pid: pid_t,
        app: AppRef,
        tracked: Set<WindowID>,
        ticket: Int
    ) {
        guard offMain.reading[pid]?.ticket == ticket else { return }
        let owed = offMain.reading.removeValue(forKey: pid)?.then ?? []
        let debt = offMain.next.removeValue(forKey: pid)
        reconcile(
            pid: pid,
            app: app,
            prefetched: PrefetchedWindows(
                elements: list,
                trackedAtRead: tracked
            )
        )
        // The next read starts before the owed run, so a `then`
        // asking again joins the read after it.
        if let debt {
            reconcileOffMain(pid: pid, app: debt.app)
            if offMain.reading[pid] != nil {
                offMain.reading[pid]?.then += debt.then
            } else {
                for then in debt.then { then() }
            }
        }
        for then in owed { then() }
    }
}

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
    /// Parallel to `elements`; empty where no window was read.
    var windows: [ListedWindow] = []
    var layers: [WindowID: Int] = [:]

    /// What was read of the `index`th listed window, if anything.
    func window(at index: Int) -> ListedWindow? {
        windows.indices.contains(index) ? windows[index] : nil
    }

    /// Whether the read found a standard window; nil where it read
    /// none, so the caller asks the elements.
    var listsStandardWindow: Bool? {
        windows.isEmpty
            ? nil : windows.contains(where: \.isStandardWindow)
    }

    /// The shadow traits read of each tracked window.
    var traits: [WindowID: WindowTraits] {
        windows.reduce(into: [:]) { traits, window in
            if let id = window.id, let read = window.tracked?.traits {
                traits[id] = read
            }
        }
    }

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
    /// When each app's last list read began.
    private(set) var readStarted: [pid_t: ContinuousClock.Instant] =
        [:]
    /// Outlives `dropDebts`, or a read from before a stop could
    /// carry the ticket of one asked after it.
    private var issued = 0

    mutating func startRead(
        pid: pid_t,
        then: [@MainActor () -> Void]
    ) -> Int {
        issued += 1
        reading[pid] = Read(ticket: issued, then: then)
        readStarted[pid] = .now
        return issued
    }

    /// Forgets what waits, at a stop; the counter stays.
    mutating func dropDebts() {
        reading = [:]
        next = [:]
        readStarted = [:]
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

    /// Runs `then` once tracking is settled by a read begun after
    /// `event`: the one parked behind a read in flight, else that
    /// read; at once when the app's last read began after `event`
    /// and has landed; else after a fresh one.
    func afterPendingReconcile(
        pid: pid_t,
        app: AppRef,
        since event: ContinuousClock.Instant,
        then: @escaping @MainActor () -> Void
    ) {
        if offMain.next[pid] != nil {
            offMain.next[pid]?.then.append(then)
        } else if offMain.reading[pid] != nil {
            offMain.reading[pid]?.then.append(then)
        } else if let started = offMain.readStarted[pid],
            started >= event
        {
            then()
        } else {
            reconcileOffMain(pid: pid, app: app, then: then)
        }
    }

    private func readWindowList(
        pid: pid_t,
        app: AppRef,
        then: [@MainActor () -> Void]
    ) {
        let ticket = offMain.startRead(pid: pid, then: then)
        let tracked = Set(elements[pid]?.keys ?? [:].keys)
        let reader = listedWindowReader(pid: pid, bundleID: app.bundleID)
        nonisolated(unsafe) let read = axWindows
        axReads.requestWindows(pid: pid) {
            let elements = read(pid)
            let layers = FloatDetection.windowLayers(pid: pid)
            return WindowListReading(
                elements: elements,
                windows: reader.read(elements, layers: layers),
                layers: layers
            )
        } onList: { [weak self] reading in
            self?.applyWindowList(
                reading,
                pid: pid,
                app: app,
                tracked: tracked,
                ticket: ticket
            )
        }
    }

    private func applyWindowList(
        _ reading: WindowListReading,
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
                elements: reading.elements,
                trackedAtRead: tracked,
                windows: reading.windows,
                layers: reading.layers
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

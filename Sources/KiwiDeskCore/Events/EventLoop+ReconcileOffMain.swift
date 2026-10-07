import AppKit
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
    /// `OffMainReconcile.writes` when the read was asked.
    var writesAtRead = 0
    /// The app's policy and hidden state, read with the list
    /// (#1936); a nil `hidden` asks the main-actor seam.
    var policy: NSApplication.ActivationPolicy?
    var hidden: Bool?

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
        /// False once any request asked the bulk shape (#308).
        var coalesceTabs = true
    }

    var reading: [pid_t: Read] = [:]
    var next: [pid_t: Debt] = [:]
    /// When each app's last list read began.
    private(set) var readStarted: [pid_t: ContinuousClock.Instant] =
        [:]
    /// Outlives `dropDebts`, or a read from before a stop could
    /// carry the ticket of one asked after it.
    private var issued = 0
    /// What a main-actor read wrote of a window: its frame, or
    /// its detection (fullscreen state and float verdict).
    enum FreshValue: CaseIterable {
        case frame
        case detection
    }

    /// Per window and value, when a main-actor read last wrote it
    /// — fresher than any off-main reading begun before (#1933).
    private(set) var writes = 0
    private var lastWrite: [FreshValue: [WindowID: Int]] = [:]

    mutating func noteFreshWrite(
        _ id: WindowID,
        _ values: [FreshValue] = FreshValue.allCases
    ) {
        writes += 1
        for value in values { lastWrite[value, default: [:]][id] = writes }
    }

    /// Whether a main-actor read wrote `value` of `id` after `mark`.
    func wroteFresh(
        _ value: FreshValue,
        of id: WindowID,
        since mark: Int
    ) -> Bool {
        (lastWrite[value]?[id] ?? 0) > mark
    }

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
        coalesceTabs: Bool = true,
        then: (@MainActor () -> Void)? = nil
    ) {
        guard observers[pid] != nil else {
            reconcile(pid: pid, app: app, coalesceTabs: coalesceTabs)
            then?()
            return
        }
        let owed = then.map { [$0] } ?? []
        guard offMain.reading[pid] == nil else {
            offMain.next[pid, default: .init(app: app, then: [])]
                .then += owed
            offMain.next[pid]?.app = app
            if !coalesceTabs { offMain.next[pid]?.coalesceTabs = false }
            return
        }
        readWindowList(
            pid: pid,
            app: app,
            coalesceTabs: coalesceTabs,
            then: owed
        )
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
        coalesceTabs: Bool,
        then: [@MainActor () -> Void]
    ) {
        let ticket = offMain.startRead(pid: pid, then: then)
        let tracked = Set(elements[pid]?.keys ?? [:].keys)
        let writesAtRead = offMain.writes
        let reader = listedWindowReader(
            bundleID: app.bundleID,
            tracked: tracked
        )
        nonisolated(unsafe) let read = axWindows
        nonisolated(unsafe) let readPolicy = activationPolicy
        nonisolated(unsafe) let readHidden = appIsHidden
        axReads.requestWindows(pid: pid) {
            let elements = read(pid)
            let layers = FloatDetection.windowLayers(pid: pid)
            return WindowListReading(
                elements: elements,
                windows: reader.read(elements, layers: layers),
                layers: layers,
                policy: readPolicy(pid),
                hidden: readHidden(pid)
            )
        } onList: { [weak self] reading in
            self?.applyWindowList(
                reading,
                pid: pid,
                app: app,
                coalesceTabs: coalesceTabs,
                tracked: tracked,
                writesAtRead: writesAtRead,
                ticket: ticket
            )
        }
    }

    private func applyWindowList(
        _ reading: WindowListReading,
        pid: pid_t,
        app: AppRef,
        coalesceTabs: Bool,
        tracked: Set<WindowID>,
        writesAtRead: Int,
        ticket: Int
    ) {
        guard offMain.reading[pid]?.ticket == ticket else { return }
        let owed = offMain.reading.removeValue(forKey: pid)?.then ?? []
        let debt = offMain.next.removeValue(forKey: pid)
        reconcile(
            pid: pid,
            app: app,
            coalesceTabs: coalesceTabs,
            prefetched: PrefetchedWindows(
                elements: reading.elements,
                trackedAtRead: tracked,
                windows: reading.windows,
                layers: reading.layers,
                writesAtRead: writesAtRead,
                policy: reading.policy,
                hidden: reading.hidden
            )
        )
        // The next read starts before the owed run, so a `then`
        // asking again joins the read after it.
        if let debt {
            reconcileOffMain(
                pid: pid,
                app: debt.app,
                coalesceTabs: debt.coalesceTabs
            )
            if offMain.reading[pid] != nil {
                offMain.reading[pid]?.then += debt.then
            } else {
                for then in debt.then { then() }
            }
        }
        for then in owed { then() }
    }
}

extension EventLoop {
    /// The reader for `pid`'s next off-main list read.
    func listedWindowReader(
        bundleID: String?,
        tracked: Set<WindowID>
    ) -> ListedWindowReader {
        ListedWindowReader(
            resolve: resolveWindowID,
            fullscreen: readFullscreen,
            traits: shadows.traits,
            bundleID: bundleID,
            rules: floatRules,
            tracked: tracked
        )
    }
}

import ApplicationServices

/// Windows that departed, and when: an arrival an off-main list
/// read found before that is not adopted from the reading. `track`
/// reads it live instead, and a dead or minimized element refuses
/// itself there. Two sources, since an AX close reaches the loop
/// only for a window observed at `track`: the AX destroy and
/// minimize arm, by element and app, and WindowServer's destroy
/// wake-up (#1877), by id, for a window untracked through the read.
struct FlightDepartures {
    private typealias Element = (
        element: AXUIElement, at: ContinuousClock.Instant
    )
    /// Bounded by consumption: an app's entries live until its
    /// next off-main apply, its detach or a stop.
    private var elements: [pid_t: [Element]] = [:]
    /// Bounded by age, as WindowServer names no app: longer than
    /// any read's flight (`SwitchReconcile.bound`).
    private var ids: [(id: WindowID, at: ContinuousClock.Instant)] = []
    static let idBound: Duration = .seconds(10)

    mutating func note(_ element: AXUIElement, pid: pid_t) {
        elements[pid, default: []].append((element, .now))
    }

    mutating func note(id: WindowID) {
        let now = ContinuousClock.now
        ids.removeAll { $0.at.duration(to: now) > Self.idBound }
        ids.append((id, now))
    }

    /// The elements of `pid`, and the ids, that departed after a
    /// read begun at `started`; an app's older entries speak for
    /// no later read either.
    mutating func take(
        pid: pid_t,
        since started: ContinuousClock.Instant
    ) -> (elements: [AXUIElement], ids: Set<WindowID>) {
        let recent = (elements[pid] ?? []).filter { $0.at >= started }
        elements[pid] = recent.isEmpty ? nil : recent
        return (
            recent.map(\.element),
            Set(ids.filter { $0.at >= started }.map(\.id))
        )
    }

    mutating func forget(pid: pid_t) { elements[pid] = nil }

    mutating func forgetAll() {
        elements = [:]
        ids = []
    }
}

extension PrefetchedWindows {
    /// What the read found of each window untracked when it began;
    /// read only through `adoptableArrivals`.
    fileprivate var arrivals: [WindowID: ArrivalReading] {
        windows.reduce(into: [:]) { arrivals, window in
            if let id = window.id, let read = window.arrival {
                arrivals[id] = read
            }
        }
    }
}

extension EventLoop {
    /// The readings of `appeared` a reconcile may adopt from: none
    /// whose window departed while the read ran.
    func adoptableArrivals(
        _ prefetched: PrefetchedWindows?,
        pid: pid_t,
        appeared: [(element: AXUIElement, id: WindowID)]
    ) -> [WindowID: ArrivalReading] {
        guard let prefetched, let started = prefetched.readStarted else {
            return [:]
        }
        var arrivals = prefetched.arrivals
        let gone = offMain.departures.take(pid: pid, since: started)
        for pair in appeared
        where gone.ids.contains(pair.id)
            || gone.elements.contains(where: { CFEqual($0, pair.element) })
        {
            arrivals[pair.id] = nil
        }
        return arrivals
    }
}

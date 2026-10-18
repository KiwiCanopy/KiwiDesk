import ApplicationServices

/// Untracked windows whose destroy or minimize landed, per app and
/// when. An arrival an off-main list read found before that is not
/// adopted from the reading: `track` reads it live, and a dead or
/// minimized element refuses itself there.
struct FlightDepartures {
    private typealias Departure = (
        element: AXUIElement, at: ContinuousClock.Instant
    )
    private var noted: [pid_t: [Departure]] = [:]

    mutating func note(_ element: AXUIElement, pid: pid_t) {
        noted[pid, default: []].append((element, .now))
    }

    /// The elements that departed after a read begun at `started`;
    /// entries older than it can speak for no later read either.
    mutating func take(
        pid: pid_t,
        since started: ContinuousClock.Instant
    ) -> [AXUIElement] {
        let recent = (noted[pid] ?? []).filter { $0.at >= started }
        noted[pid] = recent.isEmpty ? nil : recent
        return recent.map(\.element)
    }

    mutating func forgetAll() { noted = [:] }
}

extension PrefetchedWindows {
    /// What the read found of each window untracked when it began.
    var arrivals: [WindowID: ArrivalReading] {
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
        where gone.contains(where: { CFEqual($0, pair.element) }) {
            arrivals[pair.id] = nil
        }
        return arrivals
    }
}

import Foundation

/// The logout freeze's rollback (#1385): macOS quits the other
/// apps ~14 s before KiwiDesk hears the power-off, so the autosave
/// the freeze keeps already holds an emptied desk. This keeps the
/// recent autosaves and departures, age-bounded on the caller's
/// clock, and names the autosave written before a burst of closes.
struct LogoutRollback {
    /// How far back from the freeze a departure belongs to the
    /// logout's burst — the owner's "~30 s" (#1385 ruling).
    static let burstWindow: TimeInterval = 30
    /// How long an autosave is kept: the burst window, one
    /// autosave interval before it, and slack for a late timer.
    static let historyBound: TimeInterval = 120

    struct Autosave {
        let at: Date
        let snapshot: StateSnapshot
    }

    struct Departure: Equatable {
        let at: Date
        /// The gone handler's `closed` arm; a hide, a minimize or
        /// a Desktop departure (`vanished`) is false.
        let closed: Bool
    }

    private(set) var autosaves: [Autosave] = []
    private(set) var departures: [Departure] = []

    /// Records an autosave that landed, pruning past the bound.
    mutating func noteAutosave(_ snapshot: StateSnapshot, at now: Date) {
        autosaves.removeAll {
            now.timeIntervalSince($0.at) > Self.historyBound
        }
        autosaves.append(Autosave(at: now, snapshot: snapshot))
    }

    /// Records one window departure, pruning past the window.
    mutating func noteDeparture(closed: Bool, at now: Date) {
        departures.removeAll {
            now.timeIntervalSince($0.at) > Self.burstWindow
        }
        departures.append(Departure(at: now, closed: closed))
    }

    /// The autosave written before the burst, or nil: every
    /// departure inside the window is a close, there is at least
    /// one, and an autosave younger than the bound precedes the
    /// first of them.
    func preBurst(at now: Date) -> Autosave? {
        let burst = departures.filter {
            now.timeIntervalSince($0.at) <= Self.burstWindow
        }
        guard let first = burst.map(\.at).min(),
            burst.allSatisfy(\.closed)
        else { return nil }
        return autosaves.last {
            $0.at < first
                && now.timeIntervalSince($0.at) <= Self.historyBound
        }
    }
}

import Foundation

/// When the visibility settle pass runs during a burst of steps
/// (#2659): an ask within `gap` of the pass last running waits
/// `gap` out, as does every ask until the pass runs, and no ask
/// waits past `maxWait` from the first ask the pass has not yet
/// answered. Asks before a lone pass runs — a drop's retile and
/// its own defer — stay lone.
struct DropSettleBurst {
    static let gap: TimeInterval = 1
    static let maxWait: TimeInterval = 3

    private(set) var ranAt: Date?
    private(set) var pendingSince: Date?
    private var burstPending = false

    /// The wait for an ask at `now`, whose lone wait is `early`.
    mutating func wait(asking now: Date, early: TimeInterval) -> TimeInterval {
        let since = pendingSince ?? now
        pendingSince = since
        if let ranAt, now.timeIntervalSince(ranAt) < Self.gap {
            burstPending = true
        }
        let wanted = burstPending ? Self.gap : early
        let left = Self.maxWait - now.timeIntervalSince(since)
        return max(0, min(wanted, left))
    }

    /// Records the pass running at `now`, which answers every ask.
    mutating func ran(at now: Date) {
        ranAt = now
        pendingSince = nil
        burstPending = false
    }
}

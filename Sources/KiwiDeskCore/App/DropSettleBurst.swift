import Foundation

/// When the visibility settle pass runs during a burst of steps
/// (#2659): an ask within `gap` of the pass last running, or while
/// a burst's pass is pending, waits `gap` out, and a burst runs
/// its pass at least every `maxWait`. Several asks before a pass
/// runs — a drop's retile and its own defer — are one ask.
struct DropSettleBurst {
    static let gap: TimeInterval = 1
    static let maxWait: TimeInterval = 3

    private(set) var ranAt: Date?
    private(set) var burstSince: Date?

    /// The wait for an ask at `now`, whose lone wait is `early`.
    mutating func wait(asking now: Date, early: TimeInterval) -> TimeInterval {
        let recent = ranAt.map { now.timeIntervalSince($0) < Self.gap }
        guard burstSince != nil || recent == true else { return early }
        let since = burstSince ?? now
        burstSince = since
        let left = Self.maxWait - now.timeIntervalSince(since)
        return max(early, min(Self.gap, left))
    }

    /// Records the pass running at `now`, which ends the burst.
    mutating func ran(at now: Date) {
        ranAt = now
        burstSince = nil
    }
}

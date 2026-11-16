import Foundation

/// The pocket's rise as its approach's countdown (#3368 ruling 3):
/// the revealer stamps the pocket's key a `ShelfHandleSpec.Fill` as
/// it stamps a bar's, and the pocket reads it as a timeline — it
/// waits `revealDelay`, then rises over the rest of the dwell, so a
/// rise that runs out is the pocket standing. Pure over the fill's
/// stamps: the revealer reads it against its own `now`, and the view
/// plays a rise's delay and length from when it is handed one.
enum PocketRiseTimeline {
    /// How long a full rise takes, lingering near the tab: the
    /// dwell past the no-twitch delay (#2807).
    static let span: TimeInterval =
        ShelfReveal.dwellDelay - ShelfReveal.revealDelay
    /// How long a full rise takes on the tab: the fast pace.
    static let fastSpan: TimeInterval = ShelfReveal.revealDelay

    /// When `fill`'s rise begins: `span` before it ends, never
    /// before it started.
    static func start(of fill: ShelfHandleSpec.Fill) -> Date {
        max(fill.started, fill.until.addingTimeInterval(-span))
    }

    /// How long `fill` holds still before its rise, from its start.
    static func delay(of fill: ShelfHandleSpec.Fill) -> TimeInterval {
        start(of: fill).timeIntervalSince(fill.started)
    }

    /// How far `fill`'s rise has come at `now`, 0...1.
    static func progress(
        of fill: ShelfHandleSpec.Fill,
        at now: Date
    ) -> Double {
        let start = start(of: fill)
        let length = fill.until.timeIntervalSince(start)
        guard length > 0 else { return now >= fill.until ? 1 : 0 }
        let share = now.timeIntervalSince(start) / length
        return min(max(share, 0), 1)
    }

    /// `fill` moved onto the tab at `now`: the rest of the rise at
    /// the fast pace from where it is, with no restart (ruling 3).
    static func hurried(
        _ fill: ShelfHandleSpec.Fill,
        at now: Date
    ) -> ShelfHandleSpec.Fill {
        let left = 1 - progress(of: fill, at: now)
        return .init(
            origin: fill.origin,
            started: now,
            until: now.addingTimeInterval(left * fastSpan)
        )
    }
}

import Foundation

/// The focus command's raise in flight (#1812): which window it
/// raises, the frontmost process when it was issued — the app
/// the raise leaves — and when the raise was sent. The #292
/// preflight reads it to let `focus` through while that app is
/// still in front; it is never an echo ledger.
struct RaiseFlight: Equatable {
    let target: WindowID
    let leftPID: pid_t
    var raisedAt: Date

    /// Restamps a deferred raise when it is actually sent.
    mutating func raised(_ id: WindowID, at now: Date) {
        if id == target { raisedAt = now }
    }

    /// Whether the raise toward `anchor` is still in flight:
    /// waiting on its pan, or sent less than `bound` ago.
    func inFlight(
        toward anchor: WindowID,
        pending: WindowID?,
        now: Date,
        bound: TimeInterval
    ) -> Bool {
        guard anchor == target else { return false }
        if pending == target { return true }
        return now.timeIntervalSince(raisedAt) < bound
    }
}

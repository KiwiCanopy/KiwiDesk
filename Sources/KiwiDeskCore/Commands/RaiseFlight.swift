import Foundation

/// A `focus` verb's raise in flight (#1812): which window it
/// raises, the frontmost process when the press ran — the app
/// the raise leaves — when the press ran, and when the raise was
/// sent. Written by the verb alone, never by a `focusWindow`
/// re-assert; any app activation ends it (`endRaiseFlight`). The
/// #292 preflight reads it to let `focus` through while that app
/// is still in front; it is never an echo ledger.
struct RaiseFlight: Equatable {
    private(set) var target: WindowID
    let leftPID: pid_t
    let issuedAt: Date
    private(set) var raisedAt: Date

    init(target: WindowID, leftPID: pid_t, issuedAt: Date) {
        self.target = target
        self.leftPID = leftPID
        self.issuedAt = issuedAt
        raisedAt = issuedAt
    }

    /// Follows a native tab switch's fresh id (#308).
    mutating func rekey(old: WindowID, new: WindowID) {
        if target == old { target = new }
    }

    /// Restamps the flight when `raiseWindow` sends its raise.
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

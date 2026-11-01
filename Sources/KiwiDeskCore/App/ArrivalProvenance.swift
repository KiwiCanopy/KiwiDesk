import Foundation

/// Whether an arriving window was CREATED or is only now adopted
/// (#2478, #2629, #2630). `.windowCreated` carries no such fact:
/// a boot sweep, an unlock's heal, a re-track and a Desktop
/// reveal emit it too.
enum ArrivalProvenance: Equatable {
    /// WindowServer reported its create while KiwiDesk watched.
    case created
    /// KiwiDesk's own window, which the ledger never records.
    case own
    /// No create route on this host: nothing tells the two apart.
    case unreported
    /// Adopted by a boot step, or no create within the bound.
    case existing
    /// The route is live and no create has landed yet.
    case awaitingCreate

    /// The event's reading: whether the window opens as `new`;
    /// nil while the create may still land. Another consumer
    /// switches over the cases itself.
    var isNew: Bool? {
        switch self {
        case .created, .own, .unreported: true
        case .existing: false
        case .awaitingCreate: nil
        }
    }
}

/// The one door every reader of "was this arrival created" goes
/// through — the #2478 follow, the pocket (#2629), the
/// `window_created` reason (#2630) — and its one late-create
/// resolution: an arrival `.awaitingCreate` waits here until its
/// create lands or `LaunchFollowIntent.lateCreateBound` passes.
/// The only reader of `WindowCreateLedger.createdAt`
/// (`ArrivalProvenanceSeamTests`).
@MainActor
final class ArrivalProvenanceDoor {
    /// An arrival whose provenance waits on its create.
    struct Waiting {
        let window: ManagedWindow
        /// Its Space at the arrival, for an emission after the
        /// window left state.
        let space: SpaceID?
        /// Whether its `window_created` waits on the create.
        let eventOwed: Bool
        /// Whether an AX create notification adopted it, rather
        /// than a sweep or a heal (#2867's log line).
        let axCreate: Bool
        let at: Date
    }

    /// WindowServer's creates; fed by `windowServerChanged` alone.
    let ledger = WindowCreateLedger()
    private(set) var waiting: [WindowID: Waiting] = [:]
    /// Created within the bound, settling on the next turn.
    private(set) var landed: [WindowID: Waiting] = [:]

    /// `window`'s provenance at `now`. `bootStep` is an adoption
    /// by the boot scan or its deferred steps, `existing` on every
    /// host; `own` a window of KiwiDesk's process.
    func provenance(
        of window: WindowID,
        bootStep: Bool,
        own: Bool,
        now: Date
    ) -> ArrivalProvenance {
        if bootStep { return .existing }
        if own { return .own }
        guard ledger.isLive else { return .unreported }
        if ledger.createdAt(window, now: now) != nil { return .created }
        return .awaitingCreate
    }

    /// Holds `waiting` for its create or the bound.
    func hold(_ waiting: Waiting) {
        self.waiting[waiting.window.id] = waiting
    }

    /// Moves `id` to the landed list on its create; false when it
    /// was not held.
    func land(_ id: WindowID) -> Bool {
        guard let entry = waiting.removeValue(forKey: id) else {
            return false
        }
        landed[id] = entry
        return true
    }

    /// The landed arrivals, in arrival order, emptied.
    func takeLanded() -> [Waiting] {
        defer { landed = [:] }
        return landed.values.sorted { $0.at < $1.at }
    }

    /// Releases `id`, held or landed, for a destroy or re-key that
    /// cannot wait.
    func release(_ id: WindowID) -> (waiting: Waiting, landed: Bool)? {
        if let entry = landed.removeValue(forKey: id) {
            return (entry, true)
        }
        return waiting.removeValue(forKey: id).map { ($0, false) }
    }

    /// The held or landed arrivals of `pid`.
    func held(pid: pid_t) -> [WindowID] {
        (Array(waiting.values) + Array(landed.values))
            .filter { $0.window.pid == pid }
            .sorted { $0.at < $1.at }
            .map(\.window.id)
    }

    /// Releases every held arrival the bound has passed at `now`.
    func releaseExpired(at now: Date) -> [Waiting] {
        let expired = waiting.values.filter {
            now.timeIntervalSince($0.at)
                >= LaunchFollowIntent.lateCreateBound
        }
        for entry in expired { waiting[entry.window.id] = nil }
        return expired.sorted { $0.at < $1.at }
    }

    /// When the earliest held arrival's bound passes.
    var nextDeadline: Date? {
        waiting.values.map(\.at).min().map {
            $0.addingTimeInterval(LaunchFollowIntent.lateCreateBound)
        }
    }

    /// Drops every held arrival: the core stopped.
    func reset() {
        waiting = [:]
        landed = [:]
    }
}

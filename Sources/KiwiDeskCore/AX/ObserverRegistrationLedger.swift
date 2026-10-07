/// What an app observer knows of its app-level registration
/// (#675, #837): the notifications still unregistered, and the
/// last stall. A stalled app is left alone for `repairBackoff`,
/// since each repair costs the main actor a messaging timeout and
/// every reconcile touchpoint asks; the add that stalled is
/// retried last so the others get asked.
struct ObserverRegistrationLedger {
    private(set) var failed: Set<String> = []
    private(set) var stalledAt: ContinuousClock.Instant?
    private(set) var stalledName: String?

    static let repairBackoff = Duration.seconds(30)

    /// Files a registration's outcome, read at `now`.
    mutating func record(
        _ result: AXApplicationObserver.Registration,
        at now: ContinuousClock.Instant
    ) {
        failed = result.failed
        stalledName = result.stalled
        stalledAt = result.stalled == nil ? nil : now
    }

    /// Whether a repair is owed: something failed, and no stall
    /// inside the back-off says the app will not answer.
    func needsRepair(now: ContinuousClock.Instant) -> Bool {
        guard !failed.isEmpty else { return false }
        guard let stalledAt else { return true }
        return stalledAt.duration(to: now) >= Self.repairBackoff
    }

    /// The failed names of `declared`, in its order, the one that
    /// stalled last moved to the back.
    func repairOrder(of declared: [String]) -> [String] {
        let names = declared.filter(failed.contains)
        return names.filter { $0 != stalledName }
            + names.filter { $0 == stalledName }
    }

    /// A stall read while the session rested is no evidence
    /// (#1285): the next touchpoint repairs again.
    mutating func forgetStall() { stalledAt = nil }
}

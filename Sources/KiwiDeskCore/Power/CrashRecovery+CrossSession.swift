import Foundation

/// Which refused file crosses a boot or a login (#1385): its ids
/// are never replayed, only its stable keys matched, once.
extension CrashRecovery {
    /// How soon after a plain Quit the next boot or login must
    /// begin for that Quit's file to cross it (#1864 ruling,
    /// 2026-10-09). A Quit and then a restart inside it is one
    /// gesture — the user closing up — and the quit gathered every
    /// window, floats included, so letting the file go would leave
    /// them in the quit grid. Past it, someone who quit, worked
    /// without KiwiDesk and restarted much later has not asked
    /// for an old arrangement back, which is #1385's ruling.
    public static let quitCrossingBound: TimeInterval = 10 * 60

    /// Hands over the file the id gates refused at boot, once.
    func takeCrossSessionCandidate() -> StateSnapshot? {
        defer { crossSessionCandidate = nil }
        return crossSessionCandidate
    }

    /// Keeps the newer of the refused files that may cross: one a
    /// logout's freeze wrote, or a Quit's (`quit`) whose boot or
    /// login began inside `quitCrossingBound`.
    func keepForCrossSession(_ snapshot: StateSnapshot, quit: Bool) {
        guard
            snapshot.frozenForLogout
                || quit && quitBeganInBound(snapshot)
        else { return }
        guard
            crossSessionCandidate.map({
                snapshot.capturedAt > $0.capturedAt
            }) ?? true
        else { return }
        crossSessionCandidate = snapshot
    }

    /// When this session began, against the Quit's write: the boot
    /// time across a boot; within one boot the login's start is not
    /// readable, so this launch stands in for it — never earlier
    /// than the login, so it can only refuse more.
    private func quitBeganInBound(_ snapshot: StateSnapshot) -> Bool {
        let boot = bootTime()
        let began = snapshot.capturedAt < boot ? boot : now()
        return began.timeIntervalSince(snapshot.capturedAt)
            <= Self.quitCrossingBound
    }
}

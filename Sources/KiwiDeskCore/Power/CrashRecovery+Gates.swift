import Foundation

/// The read gates' pure predicates: which login a file belongs to
/// (#1385) and when a plain Quit's file may cross a boot or a login
/// (#1864). The candidate's writers stay in `CrashRecovery.swift`.
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

    /// When this session began, against the Quit's write: the boot
    /// time across a boot; within one boot the login's start is not
    /// readable, so this launch stands in for it — never earlier
    /// than the login, so it can only refuse more.
    func quitBeganInBound(_ snapshot: StateSnapshot) -> Bool {
        let boot = bootTime()
        let began = snapshot.capturedAt < boot ? boot : now()
        return began.timeIntervalSince(snapshot.capturedAt)
            <= Self.quitCrossingBound
    }

    /// A stamp matches only a readable, equal live id. An
    /// unstamped file is an older build's: admitted only as its
    /// announced relaunch (#930), in-place and inside its bound.
    func isThisLogin(_ snapshot: StateSnapshot) -> Bool {
        guard let stamp = snapshot.loginSession else {
            return snapshot.carriesSessions
                && now().timeIntervalSince(snapshot.capturedAt)
                    <= Self.inPlaceSessionBound
        }
        return stamp == loginSession()
    }
}

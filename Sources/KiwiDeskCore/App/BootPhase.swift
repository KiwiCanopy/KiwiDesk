import Foundation

/// How far the boot has got (#802) — structure the GUI narrates,
/// never a sentence Core built (core-boundaries.md).
///
/// The count is `scanned` of `total`, not attached-of-running: on
/// the measured heavy session 51 of 109 apps ever attach (the
/// rest are windowless or ignored), so an attach counter tops out
/// at 47% and reads as a progress bar that stalled. Apps
/// *visited* reaches its total, which is what makes the quick
/// menu's row honest rather than merely accurate.
public enum BootPhase: Equatable, Sendable {
    /// Nothing started yet, or management is paused (no AX
    /// permission, a mid-session revoke).
    case idle
    /// The startup scan is walking the running apps.
    case scanning(scanned: Int, total: Int)
    /// The scan finished and the first arrangement has landed —
    /// the mark returning to full strength IS this.
    case ready

    /// Whether a readiness signal is owed. One predicate so the
    /// status mark, the menu's count row and its greyed rows
    /// cannot disagree about when boot is over.
    public var isStarting: Bool {
        if case .scanning = self { return true }
        return false
    }
}

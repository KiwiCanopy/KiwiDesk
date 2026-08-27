import Foundation

/// How far the boot has got (#802) — structure the GUI narrates,
/// never a sentence Core built (core-boundaries.md).
///
/// The count is `scanned` of `total`, and both halves of it are
/// deliberate. `total` is the boot QUEUE, which admits only apps
/// a pass can act on (`EventLoop.bootPassAdmits`): faceless
/// helpers and ignore-listed apps are filtered at queue build,
/// because counting them narrated the whole process table —
/// "apps: 3 of 145" over a desk showing five. And `scanned`
/// counts apps *visited*, never apps attached: an app can
/// refuse its observer, so an attach tally can stop short of
/// its total and read as a progress bar that stalled. Visited
/// reaches its total, which is what makes the quick menu's row
/// honest rather than merely accurate.
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

import Foundation

/// Startup boot phase progression state (#802). `total` is the
/// boot QUEUE (`EventLoop.bootPassAdmits` filters what a pass can
/// act on, so the count never narrates the whole process table);
/// `scanned` counts apps VISITED, never attached — an app can
/// refuse its observer, and an attach tally reads as a stalled
/// progress bar.
public enum BootPhase: Equatable, Sendable {
    case idle
    case scanning(scanned: Int, total: Int)
    case ready

    /// Whether a readiness signal is owed. One predicate so the
    /// status mark, the menu's count row and its greyed rows
    /// cannot disagree about when boot is over.
    public var isStarting: Bool {
        if case .scanning = self { return true }
        return false
    }
}

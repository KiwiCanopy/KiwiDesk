import Foundation

/// Startup boot phase progression state (`EventLoop.bootPassAdmits`, #802).
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

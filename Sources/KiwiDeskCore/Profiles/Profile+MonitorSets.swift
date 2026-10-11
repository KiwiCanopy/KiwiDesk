import Foundation

/// Reads of the monitor combinations a profile covers (#1530).
extension Profile {
    /// Number of monitors covered by profile sets.
    public var monitorCount: Int {
        monitorSets.first?.monitors.count
            ?? dormantMonitorCount ?? 0
    }

    /// Holds no monitor combination: never auto-matched, loadable
    /// by hand, re-claiming a set on its next save or load (#1530).
    public var isDormant: Bool { monitorSets.isEmpty }

    /// Is its screen count's default AND can load as one: a
    /// dormant profile is never a count's fallback (#1530).
    public var isUsableDefault: Bool { isDefault && !isDormant }

    /// The stored set covering `fingerprints` (compared as
    /// sorted arrays, not sets), if any.
    public func set(
        matching fingerprints: [String]
    ) -> MonitorSet? {
        let wanted = fingerprints.sorted()
        return monitorSets.first { $0.monitors == wanted }
    }
}

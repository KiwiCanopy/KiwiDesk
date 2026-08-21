import Foundation

/// One concrete monitor combination a profile covers, together
/// with the space→monitor pins valid for that arrangement (#36).
///
/// `monitors` is stored canonically sorted and compared as a
/// sorted array (a multiset — two identical monitors must not
/// collapse the way a `Set` would). The pin map is nested here
/// because a space→fingerprint pair only has meaning inside the
/// set that contains that fingerprint.
public struct MonitorSet: Codable, Sendable, Equatable {
    /// Fingerprints (`Name:WxH`) of the covered monitors,
    /// canonically sorted.
    public private(set) var monitors: [String]
    /// Explicit fingerprint pin per space (sparse; unpinned
    /// spaces resolve via Main and the positional default).
    /// Read-only so the init-time invariant (pins reference
    /// only monitors inside the set) cannot be bypassed.
    public private(set) var spaceMonitorMap: [SpaceID: String]

    private enum CodingKeys: String, CodingKey {
        case monitors
        case spaceMonitorMap = "space_monitor_map"
    }

    public init(
        monitors: [String],
        spaceMonitorMap: [SpaceID: String] = [:]
    ) {
        self.monitors = monitors.sorted()
        // A pin to a monitor outside the set is meaningless;
        // drop it so integrity stays structural.
        self.spaceMonitorMap = spaceMonitorMap.filter {
            monitors.contains($0.value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let rawMonitors = try container.decode(
            [String].self,
            forKey: .monitors
        )
        let rawMap =
            try container.decodeIfPresent(
                [SpaceID: String].self,
                forKey: .spaceMonitorMap
            ) ?? [:]
        self.init(
            monitors: rawMonitors,
            spaceMonitorMap: rawMap
        )
    }
}

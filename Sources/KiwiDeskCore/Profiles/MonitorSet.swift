import Foundation

/// Monitor setup combination and space-to-monitor pin mapping (#36).
public struct MonitorSet: Codable, Sendable, Equatable {
    /// Fingerprints (`Name:WxH`) of covered monitors, canonically sorted.
    public private(set) var monitors: [String]
    /// Explicit fingerprint pin per space.
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

import Foundation

/// A saved KiwiDesk configuration: layout modes per space plus
/// all tiling settings, tagged with the monitor setup it was
/// created for (see 05_GUI_Concept §1).
public struct Profile: Codable, Sendable, Equatable {
    public var name: String
    /// Fingerprints of the monitors present when saved.
    public var fingerprints: [String]
    public var monitorCount: Int
    /// Space id (raw) -> layout mode.
    public var spaceModes: [String: LayoutMode]
    public var settings: TilingSettings
    public var savedAt: Date

    private enum CodingKeys: String, CodingKey {
        case name
        case fingerprints
        case monitorCount = "monitor_count"
        case spaceModes = "space_modes"
        case settings
        case savedAt = "saved_at"
    }

    public init(
        name: String,
        fingerprints: [String],
        monitorCount: Int,
        spaceModes: [String: LayoutMode],
        settings: TilingSettings,
        savedAt: Date = .now
    ) {
        self.name = name
        self.fingerprints = fingerprints
        self.monitorCount = monitorCount
        self.spaceModes = spaceModes
        self.settings = settings
        self.savedAt = savedAt
    }
}

/// Two-tier monitor fallback resolution (04_API_Contract §5).
/// Pure so it is fully testable.
public enum MonitorFallback {
    /// Picks the display a space should live on.
    ///
    /// Order: per-space rule -> per-monitor rule -> primary.
    /// Rules list monitor names by preference.
    public static func resolve(
        space: SpaceID,
        preferredMonitor: String?,
        displays: [Display],
        perSpace: [SpaceID: [String]],
        perMonitor: [String: [String]]
    ) -> DisplayID? {
        func find(_ name: String) -> DisplayID? {
            displays.first { $0.name == name }?.id
        }
        if let chain = perSpace[space] {
            for name in chain {
                if let id = find(name) { return id }
            }
        }
        if let preferred = preferredMonitor {
            if let id = find(preferred) { return id }
            for name in perMonitor[preferred] ?? [] {
                if let id = find(name) { return id }
            }
        }
        return displays.first?.id
    }
}

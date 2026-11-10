import Foundation

/// A profile's tiling-toggle settings (#3008): where its Spaces
/// start, and what a Space with tiling off hides.
public struct TilingToggleSettings: Sendable, Equatable {
    /// Whether the profile's Spaces start tiled (`tiling.start`);
    /// nil follows the app-wide `tiling.start_global`.
    public var start: Bool?
    /// Per Space (`tiling.start_override`), over `start`.
    public var startOverride: [SpaceID: Bool] = [:]
    /// Whether a Space with tiling off hides its focus border
    /// (`tiling.off_hides_borders`); nil follows the app-wide base
    /// (#3089), read through `offHidesBorders(base:)`.
    public var offHidesBorders: Bool?
    /// Whether a Space with tiling off hides the bars on its
    /// screen (`tiling.off_hides_bars`); nil follows the base.
    public var offHidesBars: Bool?

    public init() {}

    /// The start-tiled value over the app-wide `global`.
    public func start(global: Bool) -> TilingStart {
        TilingStart(global: global, profile: start, spaces: startOverride)
    }

    /// The border tick over the app-wide `base` — its one reading,
    /// so nil is never read as false (#3089).
    public func offHidesBorders(base: Bool) -> Bool {
        offHidesBorders ?? base
    }

    /// The bars tick over the app-wide `base` (#3089).
    public func offHidesBars(base: Bool) -> Bool {
        offHidesBars ?? base
    }
}

extension TilingToggleSettings: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case start
        case startOverride = "start_override"
        case offHidesBorders = "off_hides_borders"
        case offHidesBars = "off_hides_bars"
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decodeIfPresent(Bool.self, forKey: .start)
        startOverride =
            try container.decodeIfPresent(
                [SpaceID: Bool].self,
                forKey: .startOverride
            ) ?? defaults.startOverride
        offHidesBorders = try container.decodeIfPresent(
            Bool.self,
            forKey: .offHidesBorders
        )
        offHidesBars = try container.decodeIfPresent(
            Bool.self,
            forKey: .offHidesBars
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(start, forKey: .start)
        try container.encode(startOverride, forKey: .startOverride)
        try container.encodeIfPresent(
            offHidesBorders,
            forKey: .offHidesBorders
        )
        try container.encodeIfPresent(offHidesBars, forKey: .offHidesBars)
    }
}

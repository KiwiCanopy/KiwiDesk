import Foundation

/// Per-space overrides of MonocleParams (`MonocleOverrideTests`, #17, #293).
public struct MonocleOverride: Sendable, Equatable {
    public var orientation: MonocleParams.Orientation?

    public init() {}

    /// Merges overrides onto global MonocleParams.
    public func resolved(
        onto global: MonocleParams
    ) -> MonocleParams {
        var out = global
        if let orientation { out.orientation = orientation }
        out.override = [:]
        return out
    }

    /// True when no field is set (drives sparse encoding).
    public var isEmpty: Bool {
        orientation == nil
    }
}

extension MonocleOverride: Codable {
    enum CodingKeys: String, CodingKey {
        case orientation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        orientation = try container.decodeIfPresent(
            MonocleParams.Orientation.self,
            forKey: .orientation
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(
            orientation,
            forKey: .orientation
        )
    }
}

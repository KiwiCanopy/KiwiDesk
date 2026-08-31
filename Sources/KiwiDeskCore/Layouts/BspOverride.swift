import Foundation

/// Per-space overrides of BspParams: optional mirror, nil
/// inherits (`BspOverrideTests`, #17). `newWindowPlacement` is
/// excluded — it has its own per-space override via
/// `new_window_placement_override`.
public struct BspOverride: Sendable, Equatable {
    public var strategy: BspParams.Strategy?
    public var splitRatioH: Double?
    public var splitRatioV: Double?

    public init() {}

    /// Merges overrides onto global BspParams.
    public func resolved(onto global: BspParams) -> BspParams {
        var out = global
        if let strategy { out.strategy = strategy }
        if let splitRatioH { out.splitRatioH = splitRatioH }
        if let splitRatioV { out.splitRatioV = splitRatioV }
        // Merged params hold no override map (see
        // ScrollingOverride).
        out.override = [:]
        return out
    }

    /// True when no field is set (drives sparse encoding).
    public var isEmpty: Bool {
        strategy == nil && splitRatioH == nil
            && splitRatioV == nil
    }
}

extension BspOverride: Codable {
    enum CodingKeys: String, CodingKey {
        case strategy
        case splitRatioH = "ratio_h"
        case splitRatioV = "ratio_v"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        strategy = try container.decodeIfPresent(
            BspParams.Strategy.self,
            forKey: .strategy
        )
        splitRatioH = try container.decodeIfPresent(
            Double.self,
            forKey: .splitRatioH
        )
        splitRatioV = try container.decodeIfPresent(
            Double.self,
            forKey: .splitRatioV
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(strategy, forKey: .strategy)
        try container.encodeIfPresent(
            splitRatioH,
            forKey: .splitRatioH
        )
        try container.encodeIfPresent(
            splitRatioV,
            forKey: .splitRatioV
        )
    }
}

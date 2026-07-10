import Foundation

/// Per-space overrides of `BspParams` (issue #17). Every field is
/// an *optional* mirror of the global bsp params: nil inherits the
/// global value (gray in the GUI), a value overrides just that
/// field for one space (black). Stored sparsely under
/// `layout.bsp.override[space_id]` and resolved with
/// `resolved(onto:)` — the same optional-mirror shape as
/// `LayoutAppBar`, but keyed by space instead of by layout.
///
/// Mirror-parity is guarded by a reflection-based test
/// (`BspOverrideTests`) per AGENTS.md §5: adding a user-tunable
/// field to `BspParams` without mirroring it here turns that test
/// red. `newWindowPlacement` is excluded (it already has a
/// per-space override via `new_window_placement_override`).
public struct BspOverride: Sendable, Equatable {
    public var strategy: BspParams.Strategy?
    public var splitRatioH: Double?
    public var splitRatioV: Double?

    public init() {}

    /// `global` (the layout's own params) with every non-nil
    /// override applied on top, per field.
    public func resolved(onto global: BspParams) -> BspParams {
        var out = global
        if let strategy { out.strategy = strategy }
        if let splitRatioH { out.splitRatioH = splitRatioH }
        if let splitRatioV { out.splitRatioV = splitRatioV }
        // Merged params hold no override map (see ScrollingOverride).
        out.override = [:]
        return out
    }

    /// True when no field is set — a fully-inherited space needs
    /// no stored override (drives sparse encoding).
    public var isEmpty: Bool {
        strategy == nil && splitRatioH == nil
            && splitRatioV == nil
    }
}

// MARK: - Codable

extension BspOverride: Codable {
    /// Same JSON spelling as the `BspParams` fields (the
    /// `bsp.set_*` setters). Only set overrides are written;
    /// inherited fields stay absent.
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

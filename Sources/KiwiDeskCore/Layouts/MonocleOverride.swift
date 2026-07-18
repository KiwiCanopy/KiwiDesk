import Foundation

/// Per-space overrides of `MonocleParams` (issue #17). Every field
/// is an *optional* mirror of the global monocle params: nil
/// inherits the global value (gray in the GUI), a value overrides
/// just that field for one space (black). Stored sparsely under
/// `layout.monocle.override[space_id]` and resolved with
/// `resolved(onto:)` — the same optional-mirror shape as
/// `LayoutAppBar`, but keyed by space instead of by layout.
///
/// Mirror-parity is guarded by a reflection-based test
/// (`MonocleOverrideTests`) per AGENTS.md §5: adding a user-tunable
/// field to `MonocleParams` without mirroring it here turns that
/// test red. `appBar` is excluded — per-space bar *look* overrides
/// land with the app-bar tier; only the orientation is per-space
/// here (since #293 it no longer affects the bar edge).
public struct MonocleOverride: Sendable, Equatable {
    public var orientation: MonocleParams.Orientation?

    public init() {}

    /// `global` (the layout's own params) with every non-nil
    /// override applied on top, per field.
    public func resolved(
        onto global: MonocleParams
    ) -> MonocleParams {
        var out = global
        if let orientation { out.orientation = orientation }
        // Merged params hold no override map (see ScrollingOverride).
        out.override = [:]
        return out
    }

    /// True when no field is set — a fully-inherited space needs
    /// no stored override (drives sparse encoding).
    public var isEmpty: Bool {
        orientation == nil
    }
}

// MARK: - Codable

extension MonocleOverride: Codable {
    /// Same JSON spelling as the `MonocleParams` fields (the
    /// `monocle.set_*` setters). Only set overrides are written;
    /// inherited fields stay absent.
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

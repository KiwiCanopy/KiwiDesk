import Foundation

/// Per-space overrides of `StackParams` (issue #17). Every field
/// is an *optional* mirror of the global stack params: nil
/// inherits the global value (gray in the GUI), a value overrides
/// just that field for one space (black). Stored sparsely under
/// `layout.stack.override[space_id]` and resolved with
/// `resolved(onto:)` — the same optional-mirror shape as
/// `LayoutAppBar`, but keyed by space instead of by layout.
///
/// Mirror-parity is guarded by a reflection-based test
/// (`StackOverrideTests`) per AGENTS.md §5: adding a user-tunable
/// field to `StackParams` without mirroring it here turns that
/// test red. `newWindowPlacement` is excluded (it already has a
/// per-space override via `new_window_placement_override`).
public struct StackOverride: Sendable, Equatable {
    public var masterCount: Int?
    public var masterRatio: Double?
    public var overflowStyle: StackParams.OverflowStyle?

    public init() {}

    /// `global` (the layout's own params) with every non-nil
    /// override applied on top, per field.
    public func resolved(onto global: StackParams) -> StackParams {
        var out = global
        if let masterCount { out.masterCount = masterCount }
        if let masterRatio { out.masterRatio = masterRatio }
        if let overflowStyle { out.overflowStyle = overflowStyle }
        return out
    }

    /// True when no field is set — a fully-inherited space needs
    /// no stored override (drives sparse encoding).
    public var isEmpty: Bool {
        masterCount == nil && masterRatio == nil
            && overflowStyle == nil
    }
}

// MARK: - Codable

extension StackOverride: Codable {
    /// Same JSON spelling as the `StackParams` fields (the
    /// `stack.set_*` setters). Only set overrides are written;
    /// inherited fields stay absent.
    enum CodingKeys: String, CodingKey {
        case masterCount = "master_count"
        case masterRatio = "master_ratio"
        case overflowStyle = "overflow_style"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        masterCount = try container.decodeIfPresent(
            Int.self,
            forKey: .masterCount
        )
        masterRatio = try container.decodeIfPresent(
            Double.self,
            forKey: .masterRatio
        )
        overflowStyle = try container.decodeIfPresent(
            StackParams.OverflowStyle.self,
            forKey: .overflowStyle
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(
            masterCount,
            forKey: .masterCount
        )
        try container.encodeIfPresent(
            masterRatio,
            forKey: .masterRatio
        )
        try container.encodeIfPresent(
            overflowStyle,
            forKey: .overflowStyle
        )
    }
}

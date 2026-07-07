import Foundation

/// Per-space overrides of `ScrollingParams` (issue #17). Every
/// field is an *optional* mirror of the global scrolling params:
/// nil inherits the global value (gray in the GUI), a value
/// overrides just that field for one space (black). Stored
/// sparsely under `layout.scroll.override[space_id]` and resolved
/// with `resolved(onto:)` — the same optional-mirror shape as
/// `LayoutAppBar`, but keyed by space instead of by layout.
///
/// Mirror-parity is guarded by a reflection-based test
/// (`ScrollingOverrideTests`) per AGENTS.md §5: adding a
/// user-tunable field to `ScrollingParams` without mirroring it
/// here turns that test red. `newWindowPlacement` is excluded (it
/// already has a per-space override via
/// `new_window_placement_override`); `appBar` look overrides land
/// with the per-space app-bar tier.
public struct ScrollingOverride: Sendable, Equatable {
    public var slotSize: ScrollSize?
    public var anchor: ScrollingParams.Anchor?
    public var orientation: ScrollingParams.Orientation?

    public init() {}

    /// `global` (the layout's own params) with every non-nil
    /// override applied on top, per field. Cross-field clamps
    /// that depend on the merged result (e.g. the bar edge vs
    /// the effective orientation) run downstream on the resolved
    /// params, so this stays a straight per-field merge.
    public func resolved(
        onto global: ScrollingParams
    ) -> ScrollingParams {
        var out = global
        if let slotSize { out.slotSize = slotSize }
        if let anchor { out.anchor = anchor }
        if let orientation { out.orientation = orientation }
        return out
    }

    /// True when no field is set — a fully-inherited space needs
    /// no stored override (drives sparse encoding).
    public var isEmpty: Bool {
        slotSize == nil && anchor == nil && orientation == nil
    }
}

// MARK: - Codable

extension ScrollingOverride: Codable {
    /// Same JSON spelling as the `ScrollingParams` fields (the
    /// `scroll.set_*` setters). Only set overrides are written;
    /// inherited fields stay absent.
    enum CodingKeys: String, CodingKey {
        case slotSize = "slot_size"
        case anchor
        case orientation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        slotSize = try container.decodeIfPresent(
            ScrollSize.self,
            forKey: .slotSize
        )
        anchor = try container.decodeIfPresent(
            ScrollingParams.Anchor.self,
            forKey: .anchor
        )
        orientation = try container.decodeIfPresent(
            ScrollingParams.Orientation.self,
            forKey: .orientation
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(slotSize, forKey: .slotSize)
        try container.encodeIfPresent(anchor, forKey: .anchor)
        try container.encodeIfPresent(
            orientation,
            forKey: .orientation
        )
    }
}

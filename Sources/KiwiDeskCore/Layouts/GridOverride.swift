import Foundation

/// Per-space overrides of `GridParams` (issue #17). Every field is
/// an *optional* mirror of the global grid params: nil inherits
/// the global value (gray in the GUI), a value overrides just that
/// field for one space (black). Stored sparsely under
/// `layout.grid.override[space_id]` and resolved with
/// `resolved(onto:)` — the same optional-mirror shape as
/// `LayoutAppBar`, but keyed by space instead of by layout.
///
/// Mirror-parity is guarded by a reflection-based test
/// (`GridOverrideTests`) per AGENTS.md §5: adding a user-tunable
/// field to `GridParams` without mirroring it here turns that test
/// red. `newWindowPlacement` is excluded (it already has a
/// per-space override via `new_window_placement_override`).
public struct GridOverride: Sendable, Equatable {
    public var type: GridParams.GridType?
    public var fillEmptyCells: Bool?
    public var splitDirection: GridParams.SplitDirection?
    public var columns: Int?
    public var rows: Int?
    public var autoSize: Bool?

    public init() {}

    /// `global` (the layout's own params) with every non-nil
    /// override applied on top, per field.
    public func resolved(onto global: GridParams) -> GridParams {
        var out = global
        if let type { out.type = type }
        if let fillEmptyCells {
            out.fillEmptyCells = fillEmptyCells
        }
        if let splitDirection {
            out.splitDirection = splitDirection
        }
        if let columns { out.columns = columns }
        if let rows { out.rows = rows }
        if let autoSize { out.autoSize = autoSize }
        // Merged params hold no override map (see ScrollingOverride).
        out.override = [:]
        return out
    }

    /// True when no field is set — a fully-inherited space needs
    /// no stored override (drives sparse encoding).
    public var isEmpty: Bool {
        type == nil && fillEmptyCells == nil
            && splitDirection == nil && columns == nil
            && rows == nil && autoSize == nil
    }
}

// MARK: - Codable

extension GridOverride: Codable {
    /// Same JSON spelling as the `GridParams` fields (the
    /// `grid.set_*` setters). Only set overrides are written;
    /// inherited fields stay absent.
    enum CodingKeys: String, CodingKey {
        case type
        case fillEmptyCells = "fill_empty_cells"
        case splitDirection = "split_direction"
        case columns
        case rows
        case autoSize = "auto_size"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        type = try container.decodeIfPresent(
            GridParams.GridType.self,
            forKey: .type
        )
        fillEmptyCells = try container.decodeIfPresent(
            Bool.self,
            forKey: .fillEmptyCells
        )
        splitDirection = try container.decodeIfPresent(
            GridParams.SplitDirection.self,
            forKey: .splitDirection
        )
        columns = try container.decodeIfPresent(
            Int.self,
            forKey: .columns
        )
        rows = try container.decodeIfPresent(
            Int.self,
            forKey: .rows
        )
        autoSize = try container.decodeIfPresent(
            Bool.self,
            forKey: .autoSize
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(
            fillEmptyCells,
            forKey: .fillEmptyCells
        )
        try container.encodeIfPresent(
            splitDirection,
            forKey: .splitDirection
        )
        try container.encodeIfPresent(columns, forKey: .columns)
        try container.encodeIfPresent(rows, forKey: .rows)
        try container.encodeIfPresent(autoSize, forKey: .autoSize)
    }
}

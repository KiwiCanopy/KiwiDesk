import Foundation

/// Configuration parameters for Grid layout.
public struct GridParams: Sendable, Equatable, Codable {
    public enum GridType: String, Sendable, Codable, CaseIterable {
        case dynamic
        case rigid
    }

    public enum SplitDirection: String, Sendable, Codable, CaseIterable {
        /// Column-first progression / horizontal filling.
        case horizontal
        /// Row-first progression / vertical filling.
        case vertical
    }

    public var type: GridType = .dynamic
    public var fillEmptyCells = true
    public var splitDirection: SplitDirection = .horizontal
    /// Rigid grid dimensions.
    public var columns: Int = 3
    public var rows: Int = 2
    /// Derives dimensions from the display (as many cells as fit
    /// at `min_window_size`). Orthogonal to `type`: it caps a
    /// dynamic grid and fixes a rigid one alike.
    public var autoSize = false
    /// Placement for newly created windows.
    public var newWindowPlacement: SpawnPlacement = .last
    /// Unnormalised weight per column index, `1.0` an equal
    /// share; a column past the end draws at `1.0`, and the list
    /// never shrinks with the column count (#763, `GridTracks`).
    public var columnWeights: [Double] = []
    /// The per-row twin of `columnWeights`.
    public var rowWeights: [Double] = []
    /// Per-space overrides resolved via `TilingSettings.resolvedGrid(for:)`.
    public var override: [SpaceID: GridOverride] = [:]

    public init() {}

    /// JSON keys follow the Lua setters (`grid.set_*`).
    private enum CodingKeys: String, CodingKey {
        case type
        case fillEmptyCells = "fill_empty_cells"
        case splitDirection = "split_direction"
        case columns
        case rows
        case autoSize = "auto_size"
        case newWindowPlacement = "new_window_placement"
        case columnWeights = "column_weight"
        case rowWeights = "row_weight"
        case override
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        type =
            try container.decodeIfPresent(
                GridType.self,
                forKey: .type
            ) ?? .dynamic
        fillEmptyCells =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .fillEmptyCells
            ) ?? true
        splitDirection =
            try container.decodeIfPresent(
                SplitDirection.self,
                forKey: .splitDirection
            ) ?? .horizontal
        columns =
            try container.decodeIfPresent(
                Int.self,
                forKey: .columns
            ) ?? 3
        rows =
            try container.decodeIfPresent(
                Int.self,
                forKey: .rows
            ) ?? 2
        autoSize =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .autoSize
            ) ?? false
        newWindowPlacement =
            try container.decodeIfPresent(
                SpawnPlacement.self,
                forKey: .newWindowPlacement
            ) ?? .last
        columnWeights =
            try container.decodeIfPresent(
                [Double].self,
                forKey: .columnWeights
            ) ?? []
        rowWeights =
            try container.decodeIfPresent(
                [Double].self,
                forKey: .rowWeights
            ) ?? []
        override =
            try container.decodeIfPresent(
                [SpaceID: GridOverride].self,
                forKey: .override
            ) ?? [:]
    }

    /// Manual encode so the per-space override map and the
    /// track weights stay sparse (absent when empty).
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(
            fillEmptyCells,
            forKey: .fillEmptyCells
        )
        try container.encode(
            splitDirection,
            forKey: .splitDirection
        )
        try container.encode(columns, forKey: .columns)
        try container.encode(rows, forKey: .rows)
        try container.encode(autoSize, forKey: .autoSize)
        try container.encode(
            newWindowPlacement,
            forKey: .newWindowPlacement
        )
        if !columnWeights.isEmpty {
            try container.encode(
                columnWeights,
                forKey: .columnWeights
            )
        }
        if !rowWeights.isEmpty {
            try container.encode(rowWeights, forKey: .rowWeights)
        }
        if !override.isEmpty {
            try container.encode(override, forKey: .override)
        }
    }
}

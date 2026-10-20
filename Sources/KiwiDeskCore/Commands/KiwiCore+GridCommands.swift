import Foundation

/// `grid.*` layout sub-API, split out of `KiwiCore+LayoutCommands`
/// for file size. Shares `parsePlacement` / `placementError` with
/// the other layout command groups; the value parsers are shared
/// by the global setters and their per-space `_override` siblings.
extension KiwiCore {
    func gridCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "grid.set_type":
            guard
                let type = Self.parseGridType(
                    args.first?.stringValue
                )
            else { return Self.typeError }
            tiler.settings.grid.type = type
        case "grid.set_fill_empty_cells":
            guard let fill = args.first?.boolValue else {
                return Self.fillError
            }
            tiler.settings.grid.fillEmptyCells = fill
        case "grid.set_split_direction":
            guard
                let direction = Self.parseSplitDirection(
                    args.first?.stringValue
                )
            else { return Self.splitDirectionError }
            tiler.settings.grid.splitDirection = direction
        case "grid.set_dimensions":
            guard let dims = Self.parseDimensions(args) else {
                return Self.dimensionsError
            }
            tiler.settings.grid.columns = dims.columns
            tiler.settings.grid.rows = dims.rows
        case "grid.set_auto_size":
            guard let auto = args.first?.boolValue else {
                return Self.autoSizeError
            }
            tiler.settings.grid.autoSize = auto
        case "grid.set_column_weight", "grid.set_row_weight":
            guard let (track, weight) = Self.parseTrackWeight(args)
            else { return Self.trackWeightError }
            if command == "grid.set_column_weight" {
                tiler.settings.grid.columnWeights = Self.setting(
                    tiler.settings.grid.columnWeights,
                    track: track,
                    to: weight
                )
                clearSessionRatios { $0.gridColumnWeights = nil }
            } else {
                tiler.settings.grid.rowWeights = Self.setting(
                    tiler.settings.grid.rowWeights,
                    track: track,
                    to: weight
                )
                clearSessionRatios { $0.gridRowWeights = nil }
            }
        case "grid.set_new_window_placement":
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.grid.newWindowPlacement = placement
        default:
            return gridFallback(command, args)
        }
        return .ok()
    }

    /// `_override` per-space setters, kept out of the main switch.
    private func gridFallback(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command.hasPrefix("grid.set_"),
            command.hasSuffix("_override")
        else { return .fail("unknown command: \(command)") }
        let field = String(
            command.dropFirst("grid.set_".count)
                .dropLast("_override".count)
        )
        return applyGridOverride(field: field, args)
    }

    /// `grid.set_<field>_override(space, value)` — the per-space
    /// sibling of the global grid setters (#17). Parses the same
    /// value via the shared parsers, writes it into that space's
    /// override, and clears the entry when it becomes empty.
    private func applyGridOverride(
        field: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let space = args.first?.stringValue, !space.isEmpty
        else { return .fail("expected space id and value") }
        let rest = Array(args.dropFirst())
        var over =
            tiler.settings.grid.override[SpaceID(space)]
            ?? GridOverride()
        switch field {
        case "type":
            guard
                let type = Self.parseGridType(rest.first?.stringValue)
            else { return Self.typeError }
            over.type = type
        case "fill_empty_cells":
            guard let fill = rest.first?.boolValue else {
                return Self.fillError
            }
            over.fillEmptyCells = fill
        case "split_direction":
            guard
                let direction = Self.parseSplitDirection(
                    rest.first?.stringValue
                )
            else { return Self.splitDirectionError }
            over.splitDirection = direction
        case "dimensions":
            guard let dims = Self.parseDimensions(rest) else {
                return Self.dimensionsError
            }
            over.columns = dims.columns
            over.rows = dims.rows
        case "auto_size":
            guard let auto = rest.first?.boolValue else {
                return Self.autoSizeError
            }
            over.autoSize = auto
        case "column_weight", "row_weight":
            guard let (track, weight) = Self.parseTrackWeight(rest)
            else { return Self.trackWeightError }
            // Starts from what the Space resolves to, so naming one
            // column keeps the others it drew.
            let global = tiler.settings.grid
            if field == "column_weight" {
                over.columnWeights = Self.setting(
                    over.columnWeights ?? global.columnWeights,
                    track: track,
                    to: weight
                )
                clearSessionRatios(for: SpaceID(space)) {
                    $0.gridColumnWeights = nil
                }
            } else {
                over.rowWeights = Self.setting(
                    over.rowWeights ?? global.rowWeights,
                    track: track,
                    to: weight
                )
                clearSessionRatios(for: SpaceID(space)) {
                    $0.gridRowWeights = nil
                }
            }
        default:
            return .fail(
                "unknown command: grid.set_\(field)_override"
            )
        }
        tiler.settings.grid.override[SpaceID(space)] =
            over.isEmpty ? nil : over
        return .ok()
    }

    // MARK: - Shared value parsers (global + per-space override)

    static func parseGridType(
        _ raw: String?
    ) -> GridParams.GridType? {
        raw.flatMap(GridParams.GridType.init(rawValue:))
    }

    static func parseSplitDirection(
        _ raw: String?
    ) -> GridParams.SplitDirection? {
        raw.flatMap(GridParams.SplitDirection.init(rawValue:))
    }

    /// Two positive integers (columns, rows), each floored at 1.
    static func parseDimensions(
        _ args: [JSONValue]
    ) -> (columns: Int, rows: Int)? {
        guard let cols = args.first?.intValue,
            let rows = args.dropFirst().first?.intValue
        else { return nil }
        return (max(1, cols), max(1, rows))
    }

    /// A 1-based track number and a positive weight, returned
    /// 0-based.
    static func parseTrackWeight(
        _ args: [JSONValue]
    ) -> (track: Int, weight: Double)? {
        guard let track = args.first?.intValue, track >= 1,
            let weight = args.dropFirst().first?.numberValue,
            weight.isFinite, weight > 0
        else { return nil }
        return (track - 1, weight)
    }

    /// `weights` with track `index` set, padded with equal shares
    /// and trimmed of trailing ones (`GridTracks.trimmed`).
    static func setting(
        _ weights: [Double],
        track index: Int,
        to weight: Double
    ) -> [Double] {
        var out = weights
        while out.count <= index { out.append(1) }
        out[index] = weight
        return GridTracks.trimmed(out)
    }

    private static let trackWeightError = CommandResponse.fail(
        "expected a track number (1 or more) and a positive weight"
    )
    private static let typeError = CommandResponse.expected(
        GridParams.GridType.self
    )
    private static let fillError = CommandResponse.fail(
        "expected boolean"
    )
    private static let autoSizeError = CommandResponse.fail(
        "expected boolean"
    )
    private static let splitDirectionError = CommandResponse.expected(
        GridParams.SplitDirection.self
    )
    private static let dimensionsError = CommandResponse.fail(
        "expected columns and rows"
    )
}

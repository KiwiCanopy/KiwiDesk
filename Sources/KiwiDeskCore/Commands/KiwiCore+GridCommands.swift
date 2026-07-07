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
        case "grid.set_fill_empty_space":
            guard let fill = args.first?.boolValue else {
                return Self.fillError
            }
            tiler.settings.grid.fillEmptySpace = fill
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
        case "fill_empty_space":
            guard let fill = rest.first?.boolValue else {
                return Self.fillError
            }
            over.fillEmptySpace = fill
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

    private static let typeError = CommandResponse.fail(
        "expected dynamic|rigid"
    )
    private static let fillError = CommandResponse.fail(
        "expected boolean"
    )
    private static let splitDirectionError = CommandResponse.fail(
        "expected horizontal|vertical"
    )
    private static let dimensionsError = CommandResponse.fail(
        "expected columns and rows"
    )
}

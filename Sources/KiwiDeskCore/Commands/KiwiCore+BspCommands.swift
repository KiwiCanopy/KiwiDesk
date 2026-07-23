import Foundation

/// `bsp.*` layout sub-API, split out of `KiwiCore+LayoutCommands`
/// for file size. Shares `parsePlacement` / `placementError` with
/// the other layout command groups; the value parsers are shared
/// by the global setters and their per-space `_override` siblings.
extension KiwiCore {
    func bspCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "bsp.set_strategy":
            guard
                let strategy = Self.parseStrategy(
                    args.first?.stringValue
                )
            else { return Self.strategyError }
            tiler.settings.bsp.strategy = strategy
        case "bsp.set_ratio_h":
            guard let ratio = Self.parseSplitRatio(args.first)
            else { return Self.ratioError }
            tiler.settings.bsp.splitRatioH = ratio
            // An explicit global write must show everywhere:
            // drop the session shadow (#458).
            clearSessionRatios { $0.splitRatioH = nil }
        case "bsp.set_ratio_v":
            guard let ratio = Self.parseSplitRatio(args.first)
            else { return Self.ratioError }
            tiler.settings.bsp.splitRatioV = ratio
            clearSessionRatios { $0.splitRatioV = nil }
        case "bsp.set_new_window_placement":
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.bsp.newWindowPlacement = placement
        default:
            return bspFallback(command, args)
        }
        return .ok()
    }

    /// `_override` per-space setters, kept out of the main switch.
    private func bspFallback(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command.hasPrefix("bsp.set_"),
            command.hasSuffix("_override")
        else { return .fail("unknown command: \(command)") }
        let field = String(
            command.dropFirst("bsp.set_".count)
                .dropLast("_override".count)
        )
        return applyBspOverride(field: field, args)
    }

    /// `bsp.set_<field>_override(space, value)` — the per-space
    /// sibling of the global bsp setters (#17). Parses the same
    /// value via the shared parsers, writes it into that space's
    /// override, and clears the entry when it becomes empty.
    private func applyBspOverride(
        field: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let space = args.first?.stringValue, !space.isEmpty
        else { return .fail("expected space id and value") }
        let rest = Array(args.dropFirst())
        var over =
            tiler.settings.bsp.override[SpaceID(space)]
            ?? BspOverride()
        switch field {
        case "strategy":
            guard
                let strategy = Self.parseStrategy(
                    rest.first?.stringValue
                )
            else { return Self.strategyError }
            over.strategy = strategy
        case "ratio_h":
            guard let ratio = Self.parseSplitRatio(rest.first)
            else { return Self.ratioError }
            over.splitRatioH = ratio
        case "ratio_v":
            guard let ratio = Self.parseSplitRatio(rest.first)
            else { return Self.ratioError }
            over.splitRatioV = ratio
        default:
            return .fail(
                "unknown command: bsp.set_\(field)_override"
            )
        }
        tiler.settings.bsp.override[SpaceID(space)] =
            over.isEmpty ? nil : over
        return .ok()
    }

    // MARK: - Shared value parsers (global + per-space override)

    static func parseStrategy(
        _ raw: String?
    ) -> BspParams.Strategy? {
        raw.flatMap(BspParams.Strategy.init(rawValue:))
    }

    static func parseSplitRatio(_ value: JSONValue?) -> Double? {
        value?.numberValue.map { min(max($0, 0.1), 0.9) }
    }

    private static let strategyError = CommandResponse.fail(
        "expected longest_side|alternating"
    )
    private static let ratioError = CommandResponse.fail(
        "expected ratio"
    )
}

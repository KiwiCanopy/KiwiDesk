import Foundation

/// `stack.*` layout sub-API, split out of `KiwiCore+LayoutCommands`
/// for file size. Shares `parsePlacement` / `placementError` with
/// the other layout command groups; the value parsers are shared
/// by the global setters and their per-space `_override` siblings.
extension KiwiCore {
    func stackCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "stack.promote", "stack.demote":
            return promoteDemote(command == "stack.promote")
        case "stack.set_master_count":
            guard let count = Self.parseMasterCount(args.first)
            else { return Self.masterCountError }
            tiler.settings.stack.masterCount = count
        case "stack.set_master_ratio":
            guard let ratio = Self.parseMasterRatio(args.first)
            else { return Self.masterRatioError }
            tiler.settings.stack.masterRatio = ratio
        case "stack.set_overflow_style":
            guard
                let style = Self.parseOverflowStyle(
                    args.first?.stringValue
                )
            else { return Self.overflowStyleError }
            tiler.settings.stack.overflowStyle = style
        case "stack.set_new_window_placement":
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.stack.newWindowPlacement = placement
        default:
            return stackFallback(command, args)
        }
        return .ok()
    }

    /// `_override` per-space setters, kept out of the main switch.
    private func stackFallback(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command.hasPrefix("stack.set_"),
            command.hasSuffix("_override")
        else { return .fail("unknown command: \(command)") }
        let field = String(
            command.dropFirst("stack.set_".count)
                .dropLast("_override".count)
        )
        return applyStackOverride(field: field, args)
    }

    /// `stack.set_<field>_override(space, value)` — the per-space
    /// sibling of the global stack setters (#17). Parses the same
    /// value via the shared parsers, writes it into that space's
    /// override, and clears the entry when it becomes empty.
    private func applyStackOverride(
        field: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let space = args.first?.stringValue, !space.isEmpty
        else { return .fail("expected space id and value") }
        let rest = Array(args.dropFirst())
        var over =
            tiler.settings.stack.override[SpaceID(space)]
            ?? StackOverride()
        switch field {
        case "master_count":
            guard let count = Self.parseMasterCount(rest.first)
            else { return Self.masterCountError }
            over.masterCount = count
        case "master_ratio":
            guard let ratio = Self.parseMasterRatio(rest.first)
            else { return Self.masterRatioError }
            over.masterRatio = ratio
        case "overflow_style":
            guard
                let style = Self.parseOverflowStyle(
                    rest.first?.stringValue
                )
            else { return Self.overflowStyleError }
            over.overflowStyle = style
        default:
            return .fail(
                "unknown command: stack.set_\(field)_override"
            )
        }
        tiler.settings.stack.override[SpaceID(space)] =
            over.isEmpty ? nil : over
        return .ok()
    }

    // MARK: - Shared value parsers (global + per-space override)

    static func parseMasterCount(_ value: JSONValue?) -> Int? {
        value?.intValue.map { max(1, $0) }
    }

    static func parseMasterRatio(_ value: JSONValue?) -> Double? {
        value?.numberValue.map { min(max($0, 0.1), 0.9) }
    }

    static func parseOverflowStyle(
        _ raw: String?
    ) -> StackParams.OverflowStyle? {
        raw.flatMap(StackParams.OverflowStyle.init(rawValue:))
    }

    private static let masterCountError = CommandResponse.fail(
        "expected count"
    )
    private static let masterRatioError = CommandResponse.fail(
        "expected ratio"
    )
    private static let overflowStyleError = CommandResponse.fail(
        "expected cascade_overflow | cascade_all"
    )

    private func promoteDemote(
        _ promote: Bool
    ) -> CommandResponse {
        guard let space = activeSpace,
            let focused = space.focused
        else {
            return .fail("no focused window")
        }
        // Stack-only: `promote`/`demote` reorder via raw
        // `swapAt`, which does not maintain the track layout's
        // positional break markers (#128) — a marker would ride
        // the swapped window and mangle the partition. Gated
        // like `move_to_track` gates to `.track`.
        guard space.mode == .stack else {
            return .fail(
                "promote/demote need a stack space"
            )
        }
        // Per-space master boundary (#17), matching layout math.
        let count =
            tiler.settings.resolvedStack(for: space.id).masterCount
        state.workspaces.withSpace(space.id) {
            if promote {
                $0.promote(focused, masterCount: count)
            } else {
                $0.demote(focused, masterCount: count)
            }
        }
        if activeSpace?.windows != space.windows {
            // Deferred, not armed here: this reorder's retile is
            // the dispatcher's trailing `retile(force:)`, so an
            // arm now could fire mid-retile off pre-reorder
            // frames (#153). `layoutCommand` fires it after.
            requestZOrderRestoreAfterDispatch()
        }
        return .ok()
    }
}

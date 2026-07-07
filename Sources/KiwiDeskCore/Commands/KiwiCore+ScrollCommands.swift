import AppKit
import Foundation

/// `scroll.*` layout sub-API, split out of `KiwiCore+LayoutCommands`
/// for file size. Shares `parsePlacement` / `placementError` with
/// the other layout command groups.
extension KiwiCore {
    func scrollCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "scroll.set_slot_size":
            guard let size = Self.parseSlotSize(args.first) else {
                return Self.slotSizeError
            }
            tiler.settings.scrolling.slotSize = size
        case "scroll.set_anchor":
            guard
                let anchor = Self.parseAnchor(args.first?.stringValue)
            else { return Self.anchorError }
            tiler.settings.scrolling.anchor = anchor
        case "scroll.set_orientation":
            guard
                let orientation = Self.parseOrientation(
                    args.first?.stringValue
                )
            else { return Self.orientationError }
            tiler.settings.scrolling.orientation = orientation
            warnOnScrollBarMismatch()
        case "scroll.set_speed":
            guard let ms = args.first?.intValue else {
                return .fail("expected milliseconds")
            }
            tiler.animation.durationMS = ms
        case "scroll.set_new_window_placement":
            guard let placement = parsePlacement(args) else {
                return placementError
            }
            tiler.settings.scrolling.newWindowPlacement =
                placement
        default:
            return scrollFallback(command, args)
        }
        return .ok()
    }

    /// `_override` per-space setters and `set_app_bar_*`, kept out
    /// of the main switch for size.
    private func scrollFallback(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        if command.hasPrefix("scroll.set_"),
            command.hasSuffix("_override")
        {
            let field = String(
                command.dropFirst("scroll.set_".count)
                    .dropLast("_override".count)
            )
            return applyScrollOverride(field: field, args)
        }
        guard command.hasPrefix("scroll.set_app_bar_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("scroll.set_app_bar_".count)
        )
        let response = applyBarOverride(
            field: field,
            args,
            into: &tiler.settings.scrolling.appBar
        )
        if response.isSuccess, field == "position" {
            warnOnScrollBarMismatch()
        }
        return response
    }

    /// `scroll.set_<field>_override(space, value)` — the per-space
    /// sibling of the global scroll setters (#17). Parses the same
    /// value via the shared parsers, writes it into that space's
    /// override, and clears the entry when it becomes empty.
    private func applyScrollOverride(
        field: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let space = args.first?.stringValue, !space.isEmpty
        else { return .fail("expected space id and value") }
        let rest = Array(args.dropFirst())
        var over =
            tiler.settings.scrolling.override[SpaceID(space)]
            ?? ScrollingOverride()
        switch field {
        case "slot_size":
            guard let size = Self.parseSlotSize(rest.first) else {
                return Self.slotSizeError
            }
            over.slotSize = size
        case "anchor":
            guard
                let anchor = Self.parseAnchor(rest.first?.stringValue)
            else { return Self.anchorError }
            over.anchor = anchor
        case "orientation":
            guard
                let orientation = Self.parseOrientation(
                    rest.first?.stringValue
                )
            else { return Self.orientationError }
            over.orientation = orientation
        default:
            return .fail(
                "unknown command: scroll.set_\(field)_override"
            )
        }
        tiler.settings.scrolling.override[SpaceID(space)] =
            over.isEmpty ? nil : over
        return .ok()
    }

    // MARK: - Shared value parsers (global + per-space override)

    static func parseSlotSize(_ value: JSONValue?) -> ScrollSize? {
        guard let value else { return nil }
        if let number = value.numberValue {
            return number <= 0
                ? .auto : .points(clamping: CGFloat(number))
        }
        if let string = value.stringValue,
            string.hasSuffix("%"),
            let percent = Double(string.dropLast())
        {
            return .fraction(clamping: percent / 100)
        }
        return nil
    }

    static func parseAnchor(
        _ raw: String?
    ) -> ScrollingParams.Anchor? {
        guard let raw else { return nil }
        // top/bottom are the vertical spellings of the
        // leading/trailing edge; the stored enum stays
        // center/left/right (see ScrollGridEditor labels).
        let normalized = ["top": "left", "bottom": "right"][raw] ?? raw
        return ScrollingParams.Anchor(rawValue: normalized)
    }

    static func parseOrientation(
        _ raw: String?
    ) -> ScrollingParams.Orientation? {
        raw.flatMap(ScrollingParams.Orientation.init(rawValue:))
    }

    private static let slotSizeError = CommandResponse.fail(
        "expected points, \"NN%\", or 0 for auto"
    )
    private static let anchorError = CommandResponse.fail(
        "expected center|left|right|top|bottom"
    )
    private static let orientationError = CommandResponse.fail(
        "expected horizontal|vertical"
    )

    private func warnOnScrollBarMismatch() {
        warnOnBarPositionMismatch(
            host: tiler.settings.scrolling,
            layout: "scroll",
            orientation: tiler.settings.scrolling.orientation
                .rawValue
        )
    }
}

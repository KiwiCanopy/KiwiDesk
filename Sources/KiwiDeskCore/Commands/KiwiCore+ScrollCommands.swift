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
            guard let first = args.first else {
                return .fail(
                    "expected points, \"NN%\", or 0 for auto"
                )
            }
            if let number = first.numberValue {
                tiler.settings.scrolling.slotSize =
                    number <= 0
                    ? .auto : .points(clamping: CGFloat(number))
            } else if let string = first.stringValue,
                string.hasSuffix("%"),
                let percent = Double(string.dropLast())
            {
                tiler.settings.scrolling.slotSize =
                    .fraction(clamping: percent / 100)
            } else {
                return .fail(
                    "expected points, \"NN%\", or 0 for auto"
                )
            }
        case "scroll.set_anchor":
            guard let raw = args.first?.stringValue else {
                return .fail(
                    "expected center|left|right|top|bottom"
                )
            }
            // top/bottom are the vertical spellings of the
            // leading/trailing edge; the stored enum stays
            // center/left/right (see ScrollGridEditor labels).
            let normalized =
                ["top": "left", "bottom": "right"][raw] ?? raw
            guard
                let anchor = ScrollingParams.Anchor(
                    rawValue: normalized
                )
            else {
                return .fail(
                    "expected center|left|right|top|bottom"
                )
            }
            tiler.settings.scrolling.anchor = anchor
        case "scroll.set_orientation":
            guard let raw = args.first?.stringValue,
                let orientation = ScrollingParams.Orientation(
                    rawValue: raw
                )
            else {
                return .fail("expected horizontal|vertical")
            }
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
        return .ok()
    }

    private func warnOnScrollBarMismatch() {
        warnOnBarPositionMismatch(
            host: tiler.settings.scrolling,
            layout: "scroll",
            orientation: tiler.settings.scrolling.orientation
                .rawValue
        )
    }
}

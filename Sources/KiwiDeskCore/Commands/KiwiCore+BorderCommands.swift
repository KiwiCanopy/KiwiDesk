import Foundation

/// `border.*` sub-API (#278): the focus-window border look. Each
/// setter writes one `BorderStyle` field; `layoutCommand` retiles
/// (forced) on success, and `updateBorders()` runs inside that
/// retile, so the trailer IS the apply path.
///
/// Out-of-range width is silently clamped (matching
/// `drag.set_border_thickness`); only a wrong *type* or an
/// unknown enum string fails.
extension KiwiCore {
    func borderCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        if command == "border.fit_gaps" {
            // One-shot: size the global gaps to clear the ring.
            // Shares BorderStyle.fittingGaps with the GUI button;
            // layoutCommand's forced retile applies it.
            tiler.settings.gapsGlobal =
                tiler.settings.borderStyle.fittingGaps()
            return .ok()
        }
        guard command.hasPrefix("border.set_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("border.set_".count)
        )
        switch field {
        case "enabled":
            return setBool(args) {
                tiler.settings.borderStyle.enabled = $0
            }
        case "unfocused_enabled":
            return setBool(args) {
                tiler.settings.borderStyle.unfocusedEnabled = $0
            }
        case "width":
            guard let width = args.first?.numberValue else {
                return .fail("expected width (pt)")
            }
            tiler.settings.borderStyle.width = min(
                BorderStyle.maxWidth,
                max(BorderStyle.minWidth, width)
            )
            return .ok()
        case "focused_color":
            return setColor(args) {
                tiler.settings.borderStyle.focusedColor = $0
            }
        case "unfocused_color":
            return setColor(args) {
                tiler.settings.borderStyle.unfocusedColor = $0
            }
        case "corner_style":
            guard let raw = args.first?.stringValue,
                let style = BorderStyle.CornerStyle(rawValue: raw)
            else {
                return .fail("expected 'rounded' or 'square'")
            }
            tiler.settings.borderStyle.cornerStyle = style
            return .ok()
        default:
            return .fail("unknown command: \(command)")
        }
    }

    private func setBool(
        _ args: [JSONValue],
        _ write: (Bool) -> Void
    ) -> CommandResponse {
        guard let flag = args.first?.boolValue else {
            return .fail("expected boolean")
        }
        write(flag)
        return .ok()
    }

    private func setColor(
        _ args: [JSONValue],
        _ write: (String) -> Void
    ) -> CommandResponse {
        guard let hex = args.first?.stringValue,
            DragVisual.parseHex(hex) != nil
        else {
            return .fail("expected hex color (#RRGGBB[AA])")
        }
        write(hex)
        return .ok()
    }
}

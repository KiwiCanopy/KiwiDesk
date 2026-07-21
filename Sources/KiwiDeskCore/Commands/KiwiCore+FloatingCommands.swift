import Foundation

/// `floating.*` sub-API (#429): the floating-window mark
/// settings. One setter today — the Space Bar floating badge
/// tint; `layoutCommand`'s forced retile applies it (the bar
/// re-renders inside the retile path, like the sticky badge).
///
/// Applies unconditionally (Lua is open; the `dim_factor`
/// precedent). `set_color` shares `setMarkColor` with
/// `sticky.set_color`, so an empty string is the "Automatic"
/// sentinel and any other value must parse as `#RRGGBB[AA]`.
extension KiwiCore {
    func floatingCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command.hasPrefix("floating.set_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("floating.set_".count)
        )
        switch field {
        case "color":
            return setMarkColor(args) {
                tiler.settings.floatingStyle.color = $0
            }
        default:
            return .fail("unknown command: \(command)")
        }
    }
}

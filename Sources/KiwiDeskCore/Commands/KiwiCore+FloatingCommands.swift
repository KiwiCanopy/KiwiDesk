import Foundation

/// `floating.*` sub-API (#429, #1799): the floating-window mark
/// settings — the on-window mark's switch and the tint it shares
/// with the Space Bar badge; `layoutCommand`'s forced retile
/// applies both (the marks sync inside the retile path).
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
        case "mark":
            guard let flag = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.settings.floatingStyle.mark = flag
            return .ok()
        case "color":
            return setMarkColor(args) {
                tiler.settings.floatingStyle.color = $0
            }
        default:
            return .fail("unknown command: \(command)")
        }
    }
}

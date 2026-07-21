import Foundation

/// `sticky.*` sub-API (#414): the sticky-window indicator
/// settings. Each setter writes one `StickyStyle` field;
/// `layoutCommand`'s forced retile applies it (the indicator
/// sync runs inside the retile path, like the borders).
///
/// Applies unconditionally — the GUI's "forced ON while the
/// Space Bar is off" coverage guard is a presentation decision,
/// never a setter clamp (Lua is open; `dim_factor` precedent).
extension KiwiCore {
    func stickyCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command.hasPrefix("sticky.set_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("sticky.set_".count)
        )
        switch field {
        case "indicator":
            guard let flag = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.settings.stickyStyle.indicator = flag
            return .ok()
        default:
            return .fail("unknown command: \(command)")
        }
    }
}

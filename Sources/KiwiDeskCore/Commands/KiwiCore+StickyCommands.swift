import Foundation

/// `sticky.*` sub-API (#414): the sticky-window mark
/// settings. Each setter writes one `StickyStyle` field;
/// `layoutCommand`'s forced retile applies it (the mark
/// sync runs inside the retile path, like the borders).
///
/// Applies unconditionally — no surface clamps the mark, the
/// GUI's "forced ON while the Space Bar is off" greying having
/// been dropped (Lua is open; `dim_factor` precedent).
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
        case "mark":
            guard let flag = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            tiler.settings.stickyStyle.mark = flag
            return .ok()
        case "color":
            return setMarkColor(args) {
                tiler.settings.stickyStyle.color = $0
            }
        default:
            return .fail("unknown command: \(command)")
        }
    }

    /// A state-mark color setter (#429), shared by `sticky.set_color`
    /// and `floating.set_color`: an EMPTY string is accepted as the
    /// "Automatic" sentinel (adaptive `.labelColor`), any other value
    /// must parse as `#RRGGBB[AA]`. Mirrors `border.set_*_color` but
    /// with the empty case that marks alone carry.
    func setMarkColor(
        _ args: [JSONValue],
        _ write: (String) -> Void
    ) -> CommandResponse {
        guard let hex = args.first?.stringValue else {
            return .fail("expected hex color (#RRGGBB[AA]) or \"\"")
        }
        guard hex.isEmpty || DragVisual.parseHex(hex) != nil else {
            return .fail("expected hex color (#RRGGBB[AA]) or \"\"")
        }
        write(hex)
        return .ok()
    }
}

import Foundation

/// `border.*` sub-API (#278): the focus-window border look. Each
/// setter writes one `BorderStyle` field; `layoutCommand` retiles
/// (forced) on success, and `updateBorders()` runs inside that
/// retile, so the trailer IS the apply path.
///
/// Every field but the colours parses through the one
/// `BorderCommandSetting` a look shares (#1739).
extension KiwiCore {
    func borderCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        if command == "border.fit_gaps" {
            // One-shot: size the global gaps to clear the ring,
            // keeping an optional remaining gap (pt) of
            // whitespace past the reach (#295) — command input,
            // not a persisted setting; the zero-argument form
            // stays valid. Shares BorderStyle.fittingGaps with
            // the GUI action; layoutCommand's forced retile
            // applies it.
            var remaining: CGFloat = 0
            if let first = args.first {
                guard
                    let raw = first.numberValue,
                    raw.isFinite
                else {
                    return .fail(
                        "expected remaining gap (pt)"
                    )
                }
                // Whole points, clamped like the other border
                // magnitudes; bounds shared with the GUI field.
                let range = BorderStyle.remainingGapRange
                remaining = min(
                    max(raw.rounded(), range.lowerBound),
                    range.upperBound
                )
            }
            tiler.settings.gapsGlobal =
                tiler.settings.borderStyle.fittingGaps(
                    remaining: remaining
                )
            return .ok()
        }
        guard command.hasPrefix("border.set_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("border.set_".count)
        )
        if let parsed = BorderCommandSetting.parse(
            field: field,
            args: args
        ) {
            switch parsed {
            case .success(let setting):
                setting.apply(to: &tiler.settings.borderStyle)
                return .ok()
            case .failure(let refusal):
                return refusal.response
            }
        }
        switch field {
        case "focused_color":
            return setColor(args) {
                tiler.settings.borderStyle.focusedColor = $0
            }
        case "unfocused_color":
            return setColor(args) {
                tiler.settings.borderStyle.unfocusedColor = $0
            }
        default:
            return .fail("unknown command: \(command)")
        }
    }

    /// One Bool argument written by `write`, or the type
    /// refusal. Shared with `animationsCommand`.
    func setBool(
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

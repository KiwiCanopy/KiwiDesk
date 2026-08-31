import CoreGraphics
import KiwiDeskCore

/// Borders section value formatters for SettingsValueReadout.
extension SettingsValueReadout {
    static func bordersRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        [
            .change(
                census,
                label: label(for: census),
                old: old,
                new: new
            )
        ]
    }

    static func bordersOnOffRow(
        _ census: SettingKey,
        _ old: Bool,
        _ new: Bool
    ) -> [SettingsDiffRow] {
        bordersRow(census, onOff(old), onOff(new))
    }

    static func bordersPointsRow(
        _ census: SettingKey,
        _ old: CGFloat,
        _ new: CGFloat
    ) -> [SettingsDiffRow] {
        bordersRow(census, points(old), points(new))
    }

    static func bordersHexRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        bordersRow(census, hexDisplay(old), hexDisplay(new))
    }

    /// Mark tint diff row formatting automatic sentinel.
    static func bordersAutoHexRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        bordersRow(
            census,
            bordersAutoHex(old),
            bordersAutoHex(new)
        )
    }

    static func bordersAutoHex(_ raw: String) -> String {
        raw.isEmpty
            ? L("color_field.hex.automatic", "Automatic")
            : hexDisplay(raw)
    }

    static func bordersCornerLabel(
        _ style: BorderStyle.CornerStyle
    ) -> String {
        switch style {
        case .rounded:
            return L("border.corner.rounded", "Rounded")
        case .square:
            return L("border.corner.square", "Square")
        }
    }

    /// Border draw order label (#367).
    static func bordersDrawOrderLabel(
        _ order: BorderStyle.DrawOrder
    ) -> String {
        switch order {
        case .behind:
            return L("diff.value.draw_order.behind", "Behind")
        case .front:
            return L("diff.value.draw_order.front", "In front")
        }
    }

    /// Border alignment label (#754).
    static func bordersAlignmentLabel(
        _ alignment: BorderAlignment
    ) -> String {
        switch alignment {
        case .inside:
            return L(
                "diff.value.border_alignment.inside",
                "Inside"
            )
        case .outside:
            return L(
                "diff.value.border_alignment.outside",
                "Outside"
            )
        }
    }

    /// Shared border width or mixed if strokes differ.
    static func bordersUnifiedWidth(
        _ settings: TilingSettings
    ) -> String {
        let widths = [
            settings.borderStyle.width,
            settings.dragGhost.borderWidth,
            settings.dragDropZone.borderWidth,
        ]
        guard let first = widths.first,
            widths.allSatisfy({ $0 == first })
        else {
            return L("diff.value.mixed", "mixed")
        }
        return points(first)
    }

    /// Unified corner shape across strokes (`GapsBordersGates`).
    static func bordersAgreedCorner(
        _ settings: TilingSettings
    ) -> String {
        guard
            let style = GapsBordersGates(settings: settings)
                .agreedCornerStyle
        else {
            return L("diff.value.mixed", "mixed")
        }
        return bordersCornerLabel(style)
    }
}

import CoreGraphics
import KiwiDeskCore

/// The Borders rows' value formatters and row shape, split
/// from `SettingsValueReadout+Borders.swift` so neither file
/// crosses the size ceiling (the `SettingKey+BordersText`
/// shape). Internal rather than private because the switch
/// consuming them lives in that sibling file; the `borders`
/// prefix keeps them scoped to this key slice.
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

    /// `0` is the glow-size auto sentinel (#551) — the GUI's
    /// slider readout prints "Automatic" there, so this does.
    static func bordersAutoPoints(_ value: CGFloat) -> String {
        value == 0
            ? L("settings.readout.auto", "Automatic")
            : points(value)
    }

    /// A stored hex, shown verbatim: uppercased, leading "#".
    static func bordersHex(_ raw: String) -> String {
        let digits =
            raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        return "#" + digits.uppercased()
    }

    static func bordersHexRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        bordersRow(census, bordersHex(old), bordersHex(new))
    }

    /// Empty is the mark tints' stored "Automatic" sentinel —
    /// shown the way the colour well's own hex field prints it.
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
            : bordersHex(raw)
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

    /// Lua-only (#367): no GUI option list to reuse, so the
    /// labels are the diff's own.
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

    /// Lua-only (#754): no GUI option list to reuse either.
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

    /// The width master's display value: the shared width while
    /// the three strokes agree, "mixed" once a Lua edit split
    /// them — matching the acknowledgement the card's `?` makes.
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

    /// The corner shape all three strokes agree on — read from
    /// `GapsBordersGates.agreedCornerStyle`, the one copy of
    /// that comparison — or "mixed" while the ring's style and
    /// the drag pair's radius disagree (the card's picker shows
    /// no segment there).
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

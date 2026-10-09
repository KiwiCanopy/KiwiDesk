import CoreGraphics
import KiwiDeskCore

/// Diff row readout generators for the `KiwiShelf` census keys
/// (#1517), on the Space Bar's row helpers — the same value kinds.
extension SettingsValueReadout {
    static func kiwishelfRows(
        _ key: KiwiShelfKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.kiwishelf(key)
        let o = old.settings.kiwishelf
        let n = new.settings.kiwishelf
        switch key {
        case .edge:
            return spaceBarRow(
                census,
                agreedEdge(old.settings),
                agreedEdge(new.settings)
            )
        case .spaceBarEdge:
            return spaceBarChoiceRow(
                census,
                old.settings.spaceBarStyle.edge,
                new.settings.spaceBarStyle.edge,
                AppBarOptions.edge
            )
        case .appBarEdge:
            return spaceBarChoiceRow(
                census,
                old.settings.appBarStyle.edge,
                new.settings.appBarStyle.edge,
                AppBarOptions.edge
            )
        case .spaceBarScreenEdge:
            return screenEdgeRows(
                census,
                bar: .spaceBarEdge,
                old.settings.spaceBarStyle,
                new.settings.spaceBarStyle
            )
        case .appBarScreenEdge:
            return screenEdgeRows(
                census,
                bar: .appBarEdge,
                old.settings.appBarStyle,
                new.settings.appBarStyle
            )
        case .alignment:
            return spaceBarChoiceRow(
                census,
                o.alignment,
                n.alignment,
                AppBarOptions.alignment
            )
        case .order:
            return spaceBarChoiceRow(
                census,
                o.order,
                n.order,
                AppBarOptions.order
            )
        case .minimum:
            return spaceBarRow(
                census,
                percent(Double(o.minimum) / 100),
                percent(Double(n.minimum) / 100)
            )
        case .thickness:
            return spaceBarPointsRow(census, o.thickness, n.thickness)
        case .outerMargin:
            return spaceBarPointsRow(census, o.outerMargin, n.outerMargin)
        case .innerMargin:
            return spaceBarPointsRow(census, o.innerMargin, n.innerMargin)
        case .background:
            return spaceBarChoiceRow(
                census,
                o.backgroundStyle,
                n.backgroundStyle,
                AppBarOptions.backgroundStyle
            )
        case .backgroundFit:
            return spaceBarChoiceRow(
                census,
                o.backgroundFit,
                n.backgroundFit,
                AppBarOptions.backgroundFit
            )
        case .cornerRoundness:
            return spaceBarRow(
                census,
                percent(Double(o.cornerRoundness) / 100),
                percent(Double(n.cornerRoundness) / 100)
            )
        case .border:
            return spaceBarOnOffRow(census, o.border, n.border)
        case .borderWidth:
            return spaceBarPointsRow(
                census,
                o.borderWidth,
                n.borderWidth
            )
        case .highlightWidth:
            return spaceBarPointsRow(
                census,
                o.highlightWidth,
                n.highlightWidth
            )
        case .itemGap:
            return spaceBarPointsRow(census, o.itemGap, n.itemGap)
        case .glyphSizeAuto:
            return spaceBarOnOffRow(
                census,
                o.glyphSize == 0,
                n.glyphSize == 0
            )
        case .glyphSize:
            return spaceBarAutoPointsRow(census, o.glyphSize, n.glyphSize)
        case .fontSizeAuto:
            return spaceBarOnOffRow(
                census,
                o.fontSize == 0,
                n.fontSize == 0
            )
        case .fontSize:
            return spaceBarAutoPointsRow(census, o.fontSize, n.fontSize)
        case .fontFamily:
            return spaceBarRow(
                census,
                BarFontText.familyName(o.fontFamily),
                BarFontText.familyName(n.fontFamily)
            )
        case .fontWeight:
            return spaceBarRow(
                census,
                String(o.fontWeight),
                String(n.fontWeight)
            )
        case .liquidGlass:
            return spaceBarOnOffRow(census, o.liquidGlass, n.liquidGlass)
        case .iconSource:
            return spaceBarChoiceRow(
                census,
                o.iconSource,
                n.iconSource,
                AppBarOptions.iconSource
            )
        case .dimFactor:
            return spaceBarRow(
                census,
                trimmed(o.dimFactor),
                trimmed(n.dimFactor)
            )
        case .fillColor, .borderColor, .itemColor, .activeItemColor,
            .highlightColor, .hoverFillColor, .hoverItemColor,
            .groupBadgeColor, .groupBadgeTextColor:
            let path = Self.shelfColor(key)
            return spaceBarHexRow(census, o[keyPath: path], n[keyPath: path])
        }
    }

    /// The stored colour a colour key narrates.
    private static func shelfColor(
        _ key: KiwiShelfKey
    ) -> KeyPath<KiwiShelf, String> {
        switch key {
        case .fillColor: return \.fillColor
        case .borderColor: return \.borderColor
        case .itemColor: return \.itemColor
        case .activeItemColor: return \.activeItemColor
        case .highlightColor: return \.highlightColor
        case .hoverFillColor: return \.hoverFillColor
        case .hoverItemColor: return \.hoverItemColor
        case .groupBadgeColor: return \.groupBadgeColor
        default: return \.groupBadgeTextColor
        }
    }

    /// The Position master's value: the edge both bars share, or
    /// "mixed" while they or their screens differ
    /// (`TilingSettings.uniformBarEdge`).
    static func agreedEdge(_ settings: TilingSettings) -> String {
        guard let edge = settings.uniformBarEdge else {
            return L("diff.value.mixed", "mixed")
        }
        return AppBarOptions.edge.first { $0.0 == edge }?.1 ?? ""
    }

    /// One row per screen whose own edge changed (#1948), under
    /// its bar's edge label and the screen's whole fingerprint —
    /// two models of one name differ by size — each side the
    /// edge that screen actually gets.
    private static func screenEdgeRows<Bar: ScreenEdged>(
        _ census: SettingKey,
        bar: KiwiShelfKey,
        _ old: Bar,
        _ new: Bar
    ) -> [SettingsDiffRow] {
        let base = label(for: .kiwishelf(bar))
        let name: (AppBarEdge) -> String = { edge in
            AppBarOptions.edge.first { $0.0 == edge }?.1 ?? ""
        }
        let screens = Set(old.edgeOverride.keys)
            .union(new.edgeOverride.keys)
        return
            screens
            .filter { old.edge(on: $0) != new.edge(on: $0) }
            .sorted()
            .map { screen in
                let parts = Display.fingerprintParts(screen)
                return .change(
                    census,
                    instance: screen,
                    label: instanceLabel(
                        base,
                        "\(parts.name) \(parts.size)"
                    ),
                    old: name(old.edge(on: screen)),
                    new: name(new.edge(on: screen))
                )
            }
    }
}

import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// The Bars tile's bar specs and items (#1517), scaled from the
/// draft.
extension HomeCardBarsTile {
    func spaceSpec(
        _ style: SpaceBarLook,
        vertical: Bool
    ) -> BarSpec {
        let cross = crossSize(style.thickness)
        let widths = indicatorWidths(style.shelf)
        let share = contentShare(style.shelf)
        var spec = BarSpec(
            fill: style.fillColor,
            highlight: style.highlightColor,
            items: spaceItems(style.shelf),
            alignment: style.alignment,
            spans: style.plateSpans,
            boxed: !style.shelf.drawsPlate,
            thickness: cross,
            corner: style.resolvedCornerRadius(forThickness: cross),
            itemCorner: style.resolvedCornerRadius(
                forThickness: cross * 0.56
            ),
            gap: gapSpacing(style.itemGap),
            indicator: style.activeIndicator,
            outlineWidth: widths.outline,
            edgeMarkWidth: widths.edgeMark,
            borderWidth: borderWidth(style.shelf),
            borderColor: style.borderColor,
            fontSize: style.identifierFontSize(
                forContentDepth: cross * share
            ),
            contentShare: share,
            shelf: style.shelf,
            sheen: style.sheen
        )
        // A labelled item measures what `BarStripView.pipBody` draws
        // along the bar, as the App Bar's mocks do (#2890).
        let pad = vertical ? Self.pipPad.vertical : Self.pipPad.horizontal
        for index in spec.items.indices
        where spec.items[index].glyph != nil
            || spec.items[index].label != nil
        {
            spec.items[index].length =
                spec.labelledLength(spec.items[index], vertical: vertical)
                + 2 * pad * scale
        }
        return spec
    }

    func appSpec(
        _ style: AppBarLook,
        vertical: Bool
    ) -> BarSpec {
        let cross = crossSize(style.thickness)
        let widths = indicatorWidths(style.shelf)
        let share = contentShare(style.shelf)
        var spec = BarSpec(
            fill: style.fillColor,
            highlight: style.highlightColor,
            items: appItems(style),
            alignment: style.alignment,
            spans: style.plateSpans,
            boxed: !style.shelf.drawsPlate,
            thickness: cross,
            corner: style.resolvedCornerRadius(forThickness: cross),
            itemCorner: style.resolvedCornerRadius(
                forThickness: cross * 0.56
            ),
            gap: gapSpacing(style.itemGap),
            indicator: style.activeIndicator,
            outlineWidth: widths.outline,
            edgeMarkWidth: widths.edgeMark,
            borderWidth: borderWidth(style.shelf),
            borderColor: style.borderColor,
            fontSize: style.resolvedFontSize(
                forContentDepth: cross * share
            ),
            contentShare: share,
            shelf: style.shelf,
            sheen: style.sheen,
            titleCap: style.resolvedTitleCap
        )
        // An art item measures what `BarStripView.pipBody` draws
        // along the bar: the art and its padding; the end insets
        // are `pipEndInsets`'.
        let pad = vertical ? Self.pipPad.vertical : Self.pipPad.horizontal
        for index in spec.items.indices where spec.items[index].art != nil {
            spec.items[index].length = spec.artSide + 2 * pad * scale
        }
        // An icon item measures the glyph `iconAndTitle` draws, as
        // drawn, and its padding (#2781).
        for index in spec.items.indices
        where spec.items[index].glyph != nil {
            spec.items[index].length =
                spec.glyphLength(spec.items[index], vertical: vertical)
                + 2 * pad * scale
        }
        return spec
    }

    /// Idle Spaces draw the shelf's idle ink, as the live bar does.
    func spaceItems(
        _ shelf: KiwiShelf
    ) -> [BarItem] {
        let count = min(max(spaceCount, 1), 8)
        // A window of the first eight, shifted so the active Space
        // is always among them (a card for Space 9 lights itself).
        let first = max(0, activeSpace - (count - 1))
        var items: [BarItem] = []
        for index in first..<(first + count) {
            let active = index == activeSpace
            var item = BarItem(
                color: active
                    ? shelf.activeItemColor
                    : shelf.idleItemColor,
                length: 12 * scale
            )
            if spaceLabels.indices.contains(index) {
                switch spaceLabels[index] {
                case .symbol(let name):
                    item.glyph = name
                    item.glyphRatio = 1
                case .text(let text, _):
                    item.label = text
                }
            }
            item.active = active
            items.append(item)
        }
        return items
    }

    /// Mock window items at panel scale (owner 2026-08-10).
    func appItems(_ style: AppBarLook) -> [BarItem] {
        let mocks = ["envelope", "globe", "folder"].prefix(mockApps)
        if let appArt {
            return appArt.enumerated().map { index, art in
                // `appSpec` sets the length once the font is known.
                var item = BarItem(
                    color: index == 0
                        ? style.activeItemColor
                        : style.idleItemColor,
                    length: 0
                )
                item.art = art
                item.active = index == 0
                return item
            }
        }
        var items: [BarItem] = []
        for (index, mock) in mocks.enumerated() {
            let active = index == 0
            var item = BarItem(
                color: active
                    ? style.activeItemColor
                    : style.idleItemColor,
                length: 20 * scale
            )
            if scale > 1 {
                // The icon alone: a preview strip has no room for
                // titles beside the Space Bar (owner, #2781).
                item.glyph = mock
            }
            item.active = active
            items.append(item)
        }
        return items
    }

    func gapSpacing(_ real: CGFloat) -> CGFloat {
        let t = min(max(real / 40, 0), 1)
        return (1 + t * 6) * scale
    }

    func crossSize(_ real: CGFloat) -> CGFloat {
        let t = min(max((real - 20) / 60, 0), 1)
        return (13 + t * 9) * scale
    }
}

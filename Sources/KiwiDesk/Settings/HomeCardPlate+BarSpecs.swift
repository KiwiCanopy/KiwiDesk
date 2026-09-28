import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// The Bars tile's bar specs and items (#1517), scaled from the
/// draft.
extension HomeCardBarsTile {
    func spaceSpec(_ style: SpaceBarLook) -> BarSpec {
        let cross = crossSize(style.thickness)
        let widths = indicatorWidths(style.shelf)
        let share = contentShare(style.shelf)
        return BarSpec(
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
    }

    func appSpec(
        _ style: AppBarLook,
        vertical: Bool
    ) -> BarSpec {
        let cross = crossSize(style.thickness)
        let widths = indicatorWidths(style.shelf)
        let share = contentShare(style.shelf)
        return BarSpec(
            fill: style.fillColor,
            highlight: style.highlightColor,
            items: appItems(style, vertical: vertical),
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
            sheen: style.sheen
        )
    }

    /// Idle Spaces draw the shelf's idle ink, as the live bar does.
    func spaceItems(
        _ shelf: KiwiShelf
    ) -> [BarItem] {
        let count = min(max(spaceCount, 1), 8)
        var items: [BarItem] = []
        for index in 0..<count {
            let active = index == 0
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
    func appItems(
        _ style: AppBarLook,
        vertical: Bool
    ) -> [BarItem] {
        let mocks: [(glyph: String, title: String)] = [
            ("envelope", L("bars_scene.title_mail", "Inbox")),
            ("globe", L("bars_scene.title_web", "News")),
            (
                "folder",
                L("bars_scene.title_files", "Downloads")
            ),
        ]
        let content = style.bar.content.rendered(
            horizontal: !vertical
        )
        var items: [BarItem] = []
        for (index, mock) in mocks.enumerated() {
            let active = index == 0
            var item = BarItem(
                color: active
                    ? style.activeItemColor
                    : style.itemColor,
                length: 20 * scale
            )
            if scale > 1 {
                item.glyph =
                    content == .title ? nil : mock.glyph
                item.label =
                    content.showsText ? mock.title : nil
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

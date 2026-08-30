import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// Schematic preview of configured App Bar and Space Bar strips
/// (#793, owner 2026-08-10).
struct HomeCardBarsTile: View {
    let settings: TilingSettings
    /// Real space count from draft (owner 2026-08-10).
    var spaceCount: Int = 3
    /// Scale factor (1 on home plate, larger in detail panel).
    var scale: CGFloat = 1
    /// Space identifiers for panel scale rendering.
    var spaceLabels: [String] = []
    @Environment(\.schematicPalette) private var palette

    struct BarItem {
        var color: String
        var length: CGFloat
        var label: String?
        var glyph: String?
        var active = false
    }

    struct BarSpec {
        var fill: String
        var highlight: String
        var items: [BarItem]
        var alignment: AppBarStyle.BarAlignment
        var spans: Bool
        var boxed: Bool
        var thickness: CGFloat
        var corner: CGFloat
        var itemCorner: CGFloat
        var gap: CGFloat
        var indicator: AppBarStyle.ActiveIndicator
        var fontSize: CGFloat
    }

    /// Distinct edges of enabled App Bar hosts (#708; review 2026-08-10).
    private var appBarEdges: Set<AppBarEdge> {
        Set(
            settings.appBarHosts
                .filter(\.enabled)
                .map {
                    $0.resolved(
                        with: settings.appBarStyle
                    ).edge
                }
        )
    }

    var body: some View {
        HStack(spacing: 3) {
            columnBars(.left)
            VStack(spacing: 3) {
                rowBars(.top)
                well
                rowBars(.bottom)
            }
            columnBars(.right)
        }
        .padding(3)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(
                    palette?.frame
                        ?? SettingsTheme.ink2.opacity(0.3)
                )
        )
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var well: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                palette?.ghostFill
                    ?? SettingsTheme.ink2.opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        palette?.frame
                            ?? SettingsTheme.ink2.opacity(0.3)
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func rowBars(_ edge: AppBarEdge) -> some View {
        if edge == .top {
            spaceStrip(on: edge)
            appStrip(on: edge)
        } else {
            appStrip(on: edge)
            spaceStrip(on: edge)
        }
    }

    @ViewBuilder
    private func columnBars(_ edge: AppBarEdge) -> some View {
        if edge == .left {
            spaceStrip(on: edge, vertical: true)
            appStrip(on: edge, vertical: true)
        } else {
            appStrip(on: edge, vertical: true)
            spaceStrip(on: edge, vertical: true)
        }
    }

    @ViewBuilder
    private func spaceStrip(
        on edge: AppBarEdge,
        vertical: Bool = false
    ) -> some View {
        let style = settings.spaceBarStyle
        if style.enabled, style.edge == edge {
            let cross = crossSize(style.thickness)
            BarStripView(
                spec: BarSpec(
                    fill: style.fillColor,
                    highlight: style.highlightColor,
                    items: spaceItems(style),
                    alignment: style.alignment,
                    spans: style.plateSpans,
                    boxed: style.hasBox,
                    thickness: cross,
                    corner: style.resolvedCornerRadius(
                        forThickness: cross
                    ),
                    itemCorner: style.resolvedCornerRadius(
                        forThickness: cross * 0.56
                    ),
                    gap: gapSpacing(style.itemGap),
                    indicator: style.activeIndicator,
                    fontSize: style.identifierFontSize(
                        forDepth: cross
                    )
                ),
                edge: edge,
                vertical: vertical,
                scale: scale
            )
        }
    }

    private func spaceItems(
        _ style: SpaceBarStyle
    ) -> [BarItem] {
        let count = min(max(spaceCount, 1), 8)
        var items: [BarItem] = []
        for index in 0..<count {
            let active = index == 0
            var item = BarItem(
                color: active
                    ? style.activeItemColor
                    : style.itemColor,
                length: 12 * scale
            )
            if spaceLabels.indices.contains(index) {
                item.label = spaceLabels[index]
            }
            item.active = active
            items.append(item)
        }
        return items
    }

    @ViewBuilder
    private func appStrip(
        on edge: AppBarEdge,
        vertical: Bool = false
    ) -> some View {
        let style = settings.appBarStyle
        if appBarEdges.contains(edge) {
            let cross = crossSize(style.thickness)
            BarStripView(
                spec: BarSpec(
                    fill: style.fillColor,
                    highlight: style.highlightColor,
                    items: appItems(style, vertical: vertical),
                    alignment: style.alignment,
                    spans: style.plateSpans,
                    boxed: style.hasBox,
                    thickness: cross,
                    corner: style.resolvedCornerRadius(
                        forThickness: cross
                    ),
                    itemCorner: style.resolvedCornerRadius(
                        forThickness: cross * 0.56
                    ),
                    gap: gapSpacing(style.itemGap),
                    indicator: style.activeIndicator,
                    fontSize: style.resolvedFontSize(
                        forThickness: cross
                    )
                ),
                edge: edge,
                vertical: vertical,
                scale: scale
            )
        }
    }

    /// Mock window items at panel scale (owner 2026-08-10).
    private func appItems(
        _ style: AppBarStyle,
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
        let content = style.content.rendered(
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

    private func gapSpacing(_ real: CGFloat) -> CGFloat {
        let t = min(max(real / 40, 0), 1)
        return (1 + t * 6) * scale
    }

    private func crossSize(_ real: CGFloat) -> CGFloat {
        let t = min(max((real - 20) / 60, 0), 1)
        return (13 + t * 9) * scale
    }
}

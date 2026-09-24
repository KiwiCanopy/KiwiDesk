import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// Schematic preview of the shelf and the bars on it (#793, owner
/// 2026-08-10, #1517): one strip on the shelf's edge, a lone bar
/// placed by the alignment, two at opposite ends in the shelf's
/// order. Not modelled: the margins and the outer gap (#1516) — a
/// few points draw as nothing at this scale — the identifier tint
/// flag, a schematic dims nothing (#1538), and the Full plate's
/// blend between the two fills.
struct HomeCardBarsTile: View {
    let settings: TilingSettings
    /// Real space count from draft (owner 2026-08-10).
    var spaceCount: Int = 3
    /// Scale factor (1 on home plate, larger in detail panel).
    var scale: CGFloat = 1
    /// Space identifiers for panel scale rendering — Core's own
    /// verdict per Space (#1538).
    var spaceLabels: [SpaceGlyph] = []
    @Environment(\.schematicPalette) private var palette

    struct BarItem {
        var color: String
        var length: CGFloat
        var label: String?
        var glyph: String?
        /// The glyph's size against `BarSpec.fontSize`: the App
        /// Bar's icon steps down by Core's slot ratio, a Space's
        /// symbol identifier draws at the identifier size.
        var glyphRatio: CGFloat = AppBarStyle.glyphSlotRatio
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

    /// The App Bar the preview draws: the first layout that
    /// shows one, or nil when none does.
    private var appBarLook: AppBarLook? {
        settings.appBarHosts.first(where: \.enabled).map {
            settings.appBarLook(for: $0)
        }
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
        shelfStrip(on: edge, vertical: false)
    }

    @ViewBuilder
    private func columnBars(_ edge: AppBarEdge) -> some View {
        shelfStrip(on: edge, vertical: true)
    }

    /// The shelf's one strip: a lone bar where the alignment puts
    /// it, two at opposite ends in the shelf's order.
    @ViewBuilder
    private func shelfStrip(
        on edge: AppBarEdge,
        vertical: Bool
    ) -> some View {
        let shelf = settings.kiwishelf
        if shelf.edge == edge {
            let specs = shelfSpecs(vertical: vertical)
            if specs.count == 2 {
                let stack =
                    vertical
                    ? AnyLayout(VStackLayout(spacing: 3 * scale))
                    : AnyLayout(HStackLayout(spacing: 3 * scale))
                stack {
                    strip(specs[0], .start, edge, vertical)
                    strip(specs[1], .end, edge, vertical)
                }
            } else if let spec = specs.first {
                strip(spec, shelf.alignment, edge, vertical)
            }
        }
    }

    private func strip(
        _ spec: BarSpec,
        _ alignment: AppBarStyle.BarAlignment,
        _ edge: AppBarEdge,
        _ vertical: Bool
    ) -> some View {
        var seated = spec
        seated.alignment = alignment
        return BarStripView(
            spec: seated,
            edge: edge,
            vertical: vertical,
            scale: scale
        )
    }

    /// The shown bars' specs in the shelf's order.
    private func shelfSpecs(vertical: Bool) -> [BarSpec] {
        let space =
            settings.spaceBarStyle.enabled
            ? spaceSpec(settings.spaceBarLook) : nil
        let app = appBarLook.map { appSpec($0, vertical: vertical) }
        let ordered =
            settings.kiwishelf.order == .spacesFirst
            ? [space, app] : [app, space]
        return ordered.compactMap { $0 }
    }

    private func spaceSpec(_ style: SpaceBarLook) -> BarSpec {
        let cross = crossSize(style.thickness)
        return BarSpec(
            fill: style.fillColor,
            highlight: style.highlightColor,
            items: spaceItems(style.bar),
            alignment: style.alignment,
            spans: style.plateSpans,
            boxed: style.hasBox,
            thickness: cross,
            corner: style.resolvedCornerRadius(forThickness: cross),
            itemCorner: style.resolvedCornerRadius(
                forThickness: cross * 0.56
            ),
            gap: gapSpacing(style.itemGap),
            indicator: style.activeIndicator,
            fontSize: style.identifierFontSize(forDepth: cross)
        )
    }

    private func appSpec(
        _ style: AppBarLook,
        vertical: Bool
    ) -> BarSpec {
        let cross = crossSize(style.thickness)
        return BarSpec(
            fill: style.fillColor,
            highlight: style.highlightColor,
            items: appItems(style.bar, vertical: vertical),
            alignment: style.alignment,
            spans: style.plateSpans,
            boxed: style.hasBox,
            thickness: cross,
            corner: style.resolvedCornerRadius(forThickness: cross),
            itemCorner: style.resolvedCornerRadius(
                forThickness: cross * 0.56
            ),
            gap: gapSpacing(style.itemGap),
            indicator: style.activeIndicator,
            fontSize: style.resolvedFontSize(forThickness: cross)
        )
    }

    func spaceItems(
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

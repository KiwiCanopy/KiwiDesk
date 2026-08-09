import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// The Bars picture: each bar the desktop actually shows, as a
/// plate on its own edge in its own fill, the desktop well
/// between them. The edge-most bar on a shared edge is the
/// Space Bar, matching `SpaceBarPreviewStrip`'s coexistence
/// order. The scene keeps a screen's shape (16:10, centred)
/// rather than stretching to its container, and the bars
/// answer their own Style rows: alignment seats the item run,
/// `background_fit` decides hug vs span, corner roundness and
/// item gap remap through the styles' own resolutions, and the
/// active item is marked per `active_indicator` (owner batch,
/// 2026-08-10).
struct HomeCardBarsTile: View {
    let settings: TilingSettings
    /// The DRAFT's real space count — the pips are an answer,
    /// not decoration (owner 2026-08-10: the mock's constant
    /// three lied next to a six-space profile). Capped in the
    /// drawing so a Lua-sized space list cannot overflow a
    /// plate.
    var spaceCount: Int = 3
    /// 1 on the Home plate; the Bars detail panel mounts this
    /// same scene larger — one renderer, two sizes, never a
    /// second drawing.
    var scale: CGFloat = 1
    /// Per-space identifiers, the real bar's two-accent model:
    /// the stored icon, else the space's number. Empty on the
    /// Home plate — a thumbnail drops a fact it has no room to
    /// render by not drawing it (the scale rule), so labels
    /// draw only where the panel passes them.
    var spaceLabels: [String] = []
    @Environment(\.schematicPalette) private var palette

    /// One bar item: the pip's colour and along-axis length,
    /// plus — at panel scale — the identifier it carries.
    struct BarItem {
        var color: String
        var length: CGFloat
        var label: String?
        var glyph: String?
        var active = false
    }

    /// The style facts one strip draws from — read off the real
    /// style struct at the call site, so the scene cannot
    /// answer a row the style did not.
    struct BarSpec {
        var fill: String
        var highlight: String
        var items: [BarItem]
        var alignment: AppBarStyle.BarAlignment
        /// `!hasBox && backgroundFit == .full` — the strip
        /// mock's own `plateSpansCanvas` rule.
        var spans: Bool
        /// Boxed draws no shared plate at all.
        var boxed: Bool
        var corner: CGFloat
        var gap: CGFloat
        var indicator: AppBarStyle.ActiveIndicator
    }

    /// The App Bar is shown per LAYOUT; whether any layout
    /// shows one is `BarsGates`' own block predicate, consulted
    /// rather than re-derived (the resolver rule) — a card that
    /// drew the bar anyway would assert a bar the desktop never
    /// shows.
    private var appBarShown: Bool {
        BarsGates(settings: settings).anyBarShown
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
        // A screen's own shape, centred — the scene never
        // stretches to its container (owner 2026-08-10; the
        // Gaps tile's precedent).
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var well: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                palette?.ghostFill
                    ?? Color.secondary.opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        palette?.frame
                            ?? Color.secondary.opacity(0.3)
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The bars on a horizontal edge, edge-most first for
    /// `.top` and window-most first for `.bottom`, so both hug
    /// the screen edge.
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
            BarStripView(
                spec: BarSpec(
                    fill: style.fillColor,
                    highlight: style.highlightColor,
                    items: spaceItems(style),
                    alignment: style.alignment,
                    spans: !style.hasBox
                        && style.backgroundFit == .full,
                    boxed: style.hasBox,
                    corner: style.resolvedCornerRadius(
                        forThickness: 16 * scale
                    ),
                    gap: gapSpacing(style.itemGap),
                    indicator: style.activeIndicator
                ),
                edge: edge,
                vertical: vertical,
                scale: scale
            )
        }
    }

    /// One active pip plus an inactive pip per further declared
    /// space, capped at eight so the strip never overflows its
    /// plate — the cap is a drawing limit, not a claim about
    /// the space list. With labels (panel scale) each pip
    /// carries its space's identifier in the bar's two-accent
    /// model.
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
        if appBarShown, style.edge == edge {
            BarStripView(
                spec: BarSpec(
                    fill: style.fillColor,
                    highlight: style.highlightColor,
                    items: appItems(style),
                    alignment: style.alignment,
                    spans: !style.hasBox
                        && style.backgroundFit == .full,
                    boxed: style.hasBox,
                    corner: style.resolvedCornerRadius(
                        forThickness: 16 * scale
                    ),
                    gap: gapSpacing(style.itemGap),
                    indicator: style.activeIndicator
                ),
                edge: edge,
                vertical: vertical,
                scale: scale
            )
        }
    }

    /// Three mock windows at panel scale — recognisable app
    /// shapes (mail, browser, files), never real app claims
    /// (owner 2026-08-10 over two identical windows); bare
    /// pips on the Home plate.
    private func appItems(
        _ style: AppBarStyle
    ) -> [BarItem] {
        let glyphs = ["envelope", "globe", "folder"]
        var items: [BarItem] = []
        for (index, glyph) in glyphs.enumerated() {
            let active = index == 0
            items.append(
                BarItem(
                    color: active
                        ? style.activeItemColor
                        : style.itemColor,
                    length: 20 * scale,
                    glyph: scale > 1 ? glyph : nil,
                    active: active
                )
            )
        }
        return items
    }

    /// The item-gap remap into the scene's own span, the strip
    /// mock's scale idiom: the stored 0–40 pt band lands on
    /// 1–7 scene points so a gap drag stays perceptible at
    /// either mount size.
    private func gapSpacing(_ real: CGFloat) -> CGFloat {
        let t = min(max(real / 40, 0), 1)
        return (1 + t * 6) * scale
    }
}

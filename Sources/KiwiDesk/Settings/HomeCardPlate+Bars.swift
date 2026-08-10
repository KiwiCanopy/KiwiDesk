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
        /// The style's own `plateSpans` — the one copy of the
        /// hug/span rule.
        var spans: Bool
        /// Boxed draws no shared plate; each ITEM wears its
        /// own box in the fill colour instead.
        var boxed: Bool
        /// The strip's cross size, the real thickness through
        /// the mock remap — the Thickness slider moves the
        /// scene (owner 2026-08-10).
        var thickness: CGFloat
        /// Corner roundness resolved PER SHAPE at its own
        /// cross size, the real bar's rule: the plate at the
        /// strip's thickness, an item at its own.
        var corner: CGFloat
        var itemCorner: CGFloat
        var gap: CGFloat
        var indicator: AppBarStyle.ActiveIndicator
    }

    /// Every DISTINCT edge an enabled bar-hosting layout's App
    /// Bar resolves to — `appBarHosts` is Core's one place that
    /// decides hosting, and `resolved(with:)` honors per-layout
    /// edge overrides, the same resolution
    /// `spaceBarSharesEdgeWithAppBar` reads (review 2026-08-10:
    /// the raw global edge previewed an overridden bar on the
    /// wrong side). Stated residue, the #708 shape: the real
    /// desktop shows ONE layout's bar at a time; this scene
    /// draws every enabled host's edge at once, because a
    /// picture of the draft cannot know which layout the user
    /// will stand in.
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
        // A screen's own shape, centred — the scene never
        // stretches to its container (owner 2026-08-10; the
        // Gaps tile's precedent).
        .padding(3)
        // The implied screen outline, the Gaps tile's idiom —
        // the scene reads as a display, not loose chrome
        // (owner 2026-08-10; deliberately no Monitors stand,
        // which claims physical-arrangement knowledge).
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(
                    palette?.frame
                        ?? Color.secondary.opacity(0.3)
                )
        )
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
    /// pips on the Home plate. What each item shows follows
    /// the style's own `content` row through the real
    /// `rendered(horizontal:)` remap, so a vertical bar drops
    /// names exactly like the real bar does.
    private func appItems(
        _ style: AppBarStyle,
        vertical: Bool
    ) -> [BarItem] {
        let mocks: [(glyph: String, name: String)] = [
            ("envelope", L("bars_scene.app_mail", "Mail")),
            ("globe", L("bars_scene.app_web", "Web")),
            ("folder", L("bars_scene.app_files", "Files")),
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
                    content == .name ? nil : mock.glyph
                item.label =
                    content == .icon ? nil : mock.name
            }
            item.active = active
            items.append(item)
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

    /// The thickness remap, same idiom: the stored 20–80 pt
    /// band lands on 13–22 scene points per mount scale, so
    /// the Thickness slider visibly moves the scene.
    private func crossSize(_ real: CGFloat) -> CGFloat {
        let t = min(max((real - 20) / 60, 0), 1)
        return (13 + t * 9) * scale
    }
}

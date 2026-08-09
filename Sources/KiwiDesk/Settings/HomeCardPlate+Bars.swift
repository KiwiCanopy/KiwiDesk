import KiwiDeskCore
import SwiftUI

/// The Bars picture: each bar the desktop actually shows, as a
/// plate on its own edge in its own fill, the desktop well
/// between them. The edge-most bar on a shared edge is the
/// Space Bar, matching `SpaceBarPreviewStrip`'s coexistence
/// order. Every plate wears the well's hairline — the DEFAULT
/// fill composites into the plate, the 13b invisible class
/// (ui-designer, 2026-08-09).
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
            barPlate(
                fill: style.fillColor,
                items: spaceItems(style),
                vertical: vertical
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
            barPlate(
                fill: style.fillColor,
                items: [
                    BarItem(
                        color: style.activeItemColor,
                        length: 20 * scale,
                        glyph: scale > 1 ? "macwindow" : nil,
                        active: true
                    ),
                    BarItem(
                        color: style.itemColor,
                        length: 20 * scale,
                        glyph: scale > 1 ? "macwindow" : nil
                    ),
                ],
                vertical: vertical
            )
        }
    }

    // Split into named halves for the type-checker budget
    // (gui.md ▸ shallow `body`): the pip branch made the one
    // chained expression die on CI-class machines.
    private func barPlate(
        fill: String,
        items: [BarItem],
        vertical: Bool
    ) -> some View {
        plateGround(fill: fill)
            .frame(
                width: vertical ? 16 * scale : nil,
                height: vertical ? nil : 16 * scale
            )
            .overlay(pipRow(items, vertical: vertical))
    }

    private func plateGround(fill: String) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(kiwiHex: fill))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        palette?.frame
                            ?? SettingsTheme.plateInk
                            .opacity(0.3)
                    )
            )
    }

    private func pipRow(
        _ items: [BarItem],
        vertical: Bool
    ) -> some View {
        stack(vertical: vertical) {
            ForEach(
                Array(items.enumerated()),
                id: \.offset
            ) { _, item in
                pip(item, vertical: vertical)
            }
        }
        .padding(vertical ? .vertical : .horizontal, 5)
    }

    /// A bare pip on the Home plate; at panel scale the item
    /// carries its identifier the way the real bar does — the
    /// active one as a filled chip with the plate's dark ink,
    /// an inactive one as the identifier painted in
    /// `itemColor` alone (the two-accent model).
    @ViewBuilder
    private func pip(
        _ item: BarItem,
        vertical: Bool
    ) -> some View {
        if let text = item.label {
            pipContent(item) {
                Text(text)
                    .font(
                        .system(
                            size: 7.5 * scale,
                            weight: .semibold
                        )
                    )
                    .lineLimit(1)
            }
        } else if let glyph = item.glyph {
            pipContent(item) {
                Image(systemName: glyph)
                    .font(.system(size: 7 * scale))
            }
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(kiwiHex: item.color))
                .frame(
                    width: vertical
                        ? 9 * scale : item.length,
                    height: vertical
                        ? item.length : 9 * scale
                )
        }
    }

    @ViewBuilder
    private func pipContent(
        _ item: BarItem,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        if item.active {
            content()
                .foregroundStyle(
                    palette?.base
                        ?? SettingsTheme.previewPlate
                )
                .padding(.horizontal, 4 * scale)
                .padding(.vertical, 1.5 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 3 * scale)
                        .fill(Color(kiwiHex: item.color))
                )
        } else {
            content()
                .foregroundStyle(Color(kiwiHex: item.color))
                .padding(.horizontal, 2 * scale)
        }
    }

    @ViewBuilder
    private func stack(
        vertical: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        if vertical {
            VStack(spacing: 4) {
                content()
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 4) {
                content()
                Spacer(minLength: 0)
            }
        }
    }
}

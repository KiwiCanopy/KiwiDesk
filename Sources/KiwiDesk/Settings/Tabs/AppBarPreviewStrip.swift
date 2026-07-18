import KiwiDeskCore
import SwiftUI

/// A static, in-window mock of the App Bar drawn from the staged
/// `AppBarStyle` (#125 Phase 2), the `DragVisualsEditor` preview
/// idiom applied to the bar: literal configured hex colors over
/// a neutral backdrop (judging the colors *is* the point), so
/// "what does this look like" is answered before Save without
/// touching live state. Pure SwiftUI — no AX, no runtime reads.
/// Three mock tabs (one grouped, one active, one plain) exercise
/// the normal / active / badge color sets in one glance; hover
/// colors have no static state to show and are left to the rows.
///
/// The strip is **edge-aware** (#293): the stored `edge` is
/// absolute (no longer resolved from the active layout's axis),
/// so the mock can honestly rotate — a vertical column for
/// left/right, a horizontal row for top/bottom — and the caption
/// names the chosen edge.
///
/// This is a **schematic, not a pixel-mirror**: it re-expresses
/// the runtime bar's field→look mapping (box color, active
/// accent, `.gap` hiding) in SwiftUI. The rendered truth lives
/// in `AppBarItemView` (KiwiDeskCore). Simplifications on
/// purpose: the group badge is always shown (the real bar hides
/// it below a count of 2), and hover states are omitted.
struct AppBarPreviewStrip: View {
    let style: AppBarStyle

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: canvasAlignment) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
                strip.padding(6)
            }
            .frame(height: 84)
            // Belt-and-braces (SpaceBar twin has the same):
            // a mock must never spill over the caption below.
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .animation(LayoutSchematic.damping, value: style)
            .accessibilityElement()
            .accessibilityLabel(axLabel)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Strip

    /// The strip hugs the canvas side matching the chosen
    /// edge (top bar sits at the canvas top), so the edge
    /// choice is visible, not just captioned. The off-axis
    /// emptiness is the point — it mirrors the bar's real
    /// relationship to the desktop.
    private var canvasAlignment: Alignment {
        switch style.edge {
        case .top: .top
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    private var strip: some View {
        stack {
            ForEach(mockTabs) { tab($0) }
        }
        .padding(4)
        .background(
            // Plain draws every name on one shared box (the strip
            // itself); Boxed keeps the strip in the background
            // color and boxes each tab.
            RoundedRectangle(
                cornerRadius: style.tabBackground == .plain
                    ? corner : 0
            )
            .fill(
                color(
                    style.tabBackground == .plain
                        ? style.boxColor : style.backgroundColor
                )
            )
        )
    }

    /// Row on top/bottom, column on left/right.
    @ViewBuilder private func stack<C: View>(
        @ViewBuilder content: () -> C
    ) -> some View {
        if style.edge.isHorizontal {
            HStack(spacing: gap) { content() }
        } else {
            VStack(spacing: gap) { content() }
        }
    }

    @ViewBuilder private func tab(_ t: MockTab) -> some View {
        if t.active, style.activeIndicator == .gap {
            // Active item hidden — leave the gap it would occupy.
            Color.clear.frame(width: slotWidth, height: slotHeight)
        } else {
            tabBox(t)
        }
    }

    private func tabBox(_ t: MockTab) -> some View {
        tabContent(t)
            .frame(width: slotWidth, height: slotHeight)
            .background(
                RoundedRectangle(
                    cornerRadius: style.tabBackground == .boxed
                        ? corner : 0
                )
                .fill(boxColor(t))
            )
            .overlay(activeAccent(t))
            .overlay(alignment: .topTrailing) { badge(t) }
    }

    @ViewBuilder private func tabContent(
        _ t: MockTab
    ) -> some View {
        HStack(spacing: 3) {
            if style.content != .name {
                Image(systemName: t.icon)
                    .font(.system(size: font))
                    .foregroundStyle(iconColor(t))
            }
            if style.content != .icon {
                Text(t.name)
                    .font(.system(size: font))
                    .lineLimit(1)
                    .foregroundStyle(textColor(t))
            }
        }
        .padding(.horizontal, 4)
    }

    private func textColor(_ t: MockTab) -> Color {
        color(
            t.active ? style.activeTextColor : style.textColor
        )
    }

    /// #294 `icon_source`, schematically: System default keeps
    /// each mock icon's own color (full-color app images);
    /// Glyphs recolor into the state text ladder — the same
    /// colors the real glyph labels follow.
    private func iconColor(_ t: MockTab) -> Color {
        style.iconSource == .appImage
            ? t.nativeColor
            : textColor(t)
    }

    /// The active indicator, orthogonal to the tab background:
    /// `ring` outlines the active tab (flush on Boxed, an inset
    /// capsule on Plain), `edgeMark` draws a bar on the
    /// window-facing edge inset to the box corner. `gap` never
    /// reaches here (the slot is hidden).
    @ViewBuilder private func activeAccent(
        _ t: MockTab
    ) -> some View {
        if t.active {
            switch style.activeIndicator {
            case .ring: ringAccent
            case .edgeMark: edgeMarkAccent
            case .gap: EmptyView()
            }
        }
    }

    @ViewBuilder private var ringAccent: some View {
        if style.tabBackground == .boxed {
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(
                    color(style.highlightColor),
                    lineWidth: 2
                )
        } else {
            RoundedRectangle(
                cornerRadius: min(slotWidth, slotHeight) / 2
            )
            .strokeBorder(
                color(style.highlightColor),
                lineWidth: 2
            )
            .padding(1.5)
        }
    }

    @ViewBuilder private var edgeMarkAccent: some View {
        // The mark sits on the tab's window-facing side: a top
        // bar faces down, a bottom bar up, a left bar right, a
        // right bar left. Inset to the box corner on Boxed so it
        // sits flush inside the curve.
        let inset = style.tabBackground == .boxed ? corner : 0
        if style.edge.isHorizontal {
            Rectangle()
                .fill(color(style.highlightColor))
                .frame(height: 2)
                .padding(.horizontal, inset)
                .frame(
                    maxHeight: .infinity,
                    alignment: style.edge == .top
                        ? .bottom : .top
                )
        } else {
            Rectangle()
                .fill(color(style.highlightColor))
                .frame(width: 2)
                .padding(.vertical, inset)
                .frame(
                    maxWidth: .infinity,
                    alignment: style.edge == .left
                        ? .trailing : .leading
                )
        }
    }

    @ViewBuilder private func badge(_ t: MockTab) -> some View {
        if let count = t.badge {
            Text("\(count)")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(color(style.groupBadgeTextColor))
                .padding(2)
                .background(
                    Circle().fill(color(style.groupBadgeColor))
                )
                .offset(x: 3, y: -3)
        }
    }

    // MARK: - Colors

    private func boxColor(_ t: MockTab) -> Color {
        switch style.tabBackground {
        case .plain:
            return .clear
        case .boxed:
            return color(
                t.active ? style.activeBoxColor : style.boxColor
            )
        }
    }

    private func color(_ hex: String) -> Color {
        // Same parser the runtime bar uses (`Color(kiwiHex:)`
        // wraps `DragVisual.parseHex`), so a valid color matches
        // the rendered bar. See `Color+KiwiHex` on the failure
        // path.
        Color(kiwiHex: hex)
    }

    // MARK: - Geometry

    // The mock can't be to-scale (a 200 pt tab won't fit an 84 pt
    // canvas), so each dimension maps its full real range onto a
    // legible preview range *proportionally* — dragging any
    // slider always keeps moving the mock, rather than hitting a
    // hard cap partway (which read as "the setting stopped
    // working"). Relative, not absolute; the slider readouts show
    // the true pt values.

    /// Real thickness 8–80 pt → 14–44 pt of canvas depth.
    private var thickness: CGFloat {
        scale(style.thickness, from: 8...80, to: 14...44)
    }

    /// Real gap 0–40 pt → 0–16 pt (0–8 pt on a vertical bar,
    /// where the canvas height budgets the axis).
    private var gap: CGFloat {
        style.edge.isHorizontal
            ? scale(style.itemGap, from: 0...40, to: 0...16)
            : scale(style.itemGap, from: 0...40, to: 0...5)
    }

    /// The shared %-resolve against the preview's own (scaled)
    /// thickness, so the mock rounds like the runtime bar;
    /// clamped to the slot's smaller dimension so a vertical
    /// bar's short slots keep sane corners.
    private var corner: CGFloat {
        min(
            style.resolvedCornerRadius(forThickness: thickness),
            min(slotWidth, slotHeight) / 2
        )
    }

    /// Item length along the bar axis: honor an explicit
    /// `itemSize` (mapped 1–200 pt → 20–72 pt), else size to the
    /// content kind.
    private var slotLength: CGFloat {
        if style.itemSize > 0 {
            return scale(style.itemSize, from: 1...200, to: 20...72)
        }
        switch style.content {
        case .icon: return max(thickness, 22)
        case .name: return 44
        case .iconAndName: return 56
        }
    }

    /// Length along a **vertical** bar's axis, compressed so
    /// three slots plus gaps stay inside the 72 pt inner box
    /// (the 84 pt canvas minus the 12 pt edge-hug inset):
    /// 3 × 18 + 2 × 5 + 8 strip padding = 72 at the maxima.
    /// The item-size slider still visibly moves the mock.
    private var verticalSlotLength: CGFloat {
        if style.itemSize > 0 {
            return scale(style.itemSize, from: 1...200, to: 14...18)
        }
        return 16
    }

    /// Concrete slot frame for the current orientation: along a
    /// horizontal bar the length runs in x and the thickness in
    /// y; a vertical bar swaps them.
    private var slotWidth: CGFloat {
        style.edge.isHorizontal ? slotLength : thickness
    }
    private var slotHeight: CGFloat {
        style.edge.isHorizontal ? thickness : verticalSlotLength
    }

    /// Linear map of `value` from one closed range onto another,
    /// clamped to the target range at the ends.
    private func scale(
        _ value: CGFloat,
        from src: ClosedRange<CGFloat>,
        to dst: ClosedRange<CGFloat>
    ) -> CGFloat {
        let span = src.upperBound - src.lowerBound
        guard span > 0 else { return dst.lowerBound }
        let t = (value - src.lowerBound) / span
        let mapped =
            dst.lowerBound
            + min(max(t, 0), 1) * (dst.upperBound - dst.lowerBound)
        return mapped
    }

    private var font: CGFloat {
        let base =
            style.fontSize > 0
            ? style.fontSize : thickness * 0.42
        return min(base, thickness * 0.55, slotHeight * 0.55)
    }
}

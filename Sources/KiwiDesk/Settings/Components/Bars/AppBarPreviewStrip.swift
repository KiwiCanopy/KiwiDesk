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

    /// Edge picks the hugged canvas side, alignment the
    /// along-axis seat — the shared mapping in
    /// `BarCanvasAlignment.swift`.
    private var canvasAlignment: Alignment {
        style.edge.canvasAlignment(style.alignment)
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
                cornerRadius: style.tabBackground != .boxed
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

    /// Vertical edges render icon-only — the real bar
    /// collapses every content mode to `.icon` there
    /// (`Content.rendered(horizontal:)`, QA 2026-07-19), so
    /// the mock shows exactly that.
    @ViewBuilder private func tabContent(
        _ t: MockTab
    ) -> some View {
        if style.edge.isHorizontal {
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
        } else {
            Image(systemName: t.icon)
                .font(.system(size: font))
                .foregroundStyle(iconColor(t))
        }
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
        // Glass renders boxless like plain in the static preview.
        case .plain, .material:
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

    // Geometry/scale mapping lives in
    // AppBarPreviewStrip+Geometry.swift.
}

import KiwiDeskCore
import SwiftUI

/// A static, in-window mock of the Space Bar (#293) — the
/// `AppBarPreviewStrip` idiom: literal configured hex colors
/// over a neutral backdrop, pure SwiftUI, no runtime reads.
/// Three mock Space items exercise the states in one glance:
/// an inactive space with two glyphs (one wearing a count
/// badge, muted), the active space showing both accents (its
/// identifier + a focused glyph), and an empty space
/// (identifier only). Edge-aware: rotates into a column for
/// left/right. When both enabled bars share an edge, a thin
/// App Bar stand-in draws on the window-facing side so the
/// stacking order is seen, not described.
///
/// A schematic, not a pixel-mirror — the rendered truth lives
/// in `SpaceBarItemView` (KiwiDeskCore); keep the two in sync.
struct SpaceBarPreviewStrip: View {
    let style: SpaceBarStyle
    let appBar: AppBarStyle

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
                content
            }
            .frame(height: 96)
            .animation(LayoutSchematic.damping, value: style)
            .accessibilityElement()
            .accessibilityLabel(axLabel)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Composition

    private var sameEdge: Bool {
        style.enabled && style.edge == appBar.edge
    }

    /// The strip plus, when stacked, the App Bar stand-in on
    /// the window-facing side of the shared edge.
    @ViewBuilder private var content: some View {
        if style.edge.isHorizontal {
            VStack(spacing: 3) {
                if style.edge == .bottom { coexistence }
                strip
                if style.edge == .top { coexistence }
            }
        } else {
            HStack(spacing: 3) {
                if style.edge == .right { coexistence }
                strip
                if style.edge == .left { coexistence }
            }
        }
    }

    /// A muted App Bar stand-in — order only, no detail.
    @ViewBuilder private var coexistence: some View {
        if sameEdge {
            RoundedRectangle(cornerRadius: 3)
                .fill(color(appBar.boxColor))
                .frame(
                    width: style.edge.isHorizontal
                        ? nil : thickness * 0.6,
                    height: style.edge.isHorizontal
                        ? thickness * 0.6 : nil
                )
                .opacity(0.6)
        }
    }

    private var strip: some View {
        stack {
            item(.inactive)
            item(.active)
            item(.empty)
        }
        .padding(4)
        .background(
            RoundedRectangle(
                cornerRadius: style.tabBackground == .plain
                    ? corner : 0
            )
            .fill(
                color(
                    style.tabBackground == .plain
                        ? style.boxColor
                        : style.backgroundColor
                )
            )
        )
    }

    @ViewBuilder private func stack<C: View>(
        @ViewBuilder content: () -> C
    ) -> some View {
        if style.edge.isHorizontal {
            HStack(spacing: gap) { content() }
        } else {
            VStack(spacing: gap) { content() }
        }
    }

    // MARK: - Mock items

    private enum MockState { case inactive, active, empty }

    @ViewBuilder private func item(
        _ state: MockState
    ) -> some View {
        let cells = cellViews(state)
        Group {
            if style.edge.isHorizontal {
                HStack(spacing: 2) { cells }
            } else {
                VStack(spacing: 2) { cells }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(
                cornerRadius: style.tabBackground == .boxed
                    ? corner : 0
            )
            .fill(itemBox(state))
        )
        .overlay(indicator(state))
    }

    @ViewBuilder private func cellViews(
        _ state: MockState
    ) -> some View {
        // Identifier leads; the active item shows the
        // two-accent pair, the inactive one a muted badge.
        identifierCell(state)
        switch state {
        case .inactive:
            glyphCell(tint: mutedColor, badge: true)
            glyphCell(tint: mutedColor, badge: false)
        case .active:
            glyphCell(
                tint: color(style.activeTextColor),
                badge: false
            )
            glyphCell(
                tint: color(style.focusedItemColor),
                badge: false
            )
        case .empty:
            EmptyView()
        }
    }

    private func identifierCell(_ state: MockState) -> some View {
        Image(
            systemName: state == .active
                ? "2.square"
                : state == .empty
                    ? "3.square" : "1.square"
        )
        .font(.system(size: font))
        .foregroundStyle(
            state == .active
                ? color(style.activeTextColor) : mutedColor
        )
        .frame(width: cell, height: cell)
    }

    private func glyphCell(
        tint: Color,
        badge: Bool
    ) -> some View {
        Circle()
            .fill(tint)
            .frame(width: cell * 0.55, height: cell * 0.55)
            .frame(width: cell, height: cell)
            .overlay(alignment: .topTrailing) {
                if badge { badgeDot }
            }
    }

    /// The count badge, muted on the inactive mock item —
    /// the same derivation the runtime uses.
    private var badgeDot: some View {
        Text("2")
            .font(.system(size: 6, weight: .bold))
            .foregroundStyle(color(style.textColor))
            .padding(2)
            .background(
                Circle().fill(
                    color(style.textColor).opacity(0.3)
                )
            )
    }

    @ViewBuilder private func indicator(
        _ state: MockState
    ) -> some View {
        if state == .active {
            switch style.activeIndicator {
            case .ring:
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(
                        color(style.highlightColor),
                        lineWidth: 2
                    )
            case .edgeMark:
                edgeMark
            case .gap:
                EmptyView()
            }
        }
    }

    @ViewBuilder private var edgeMark: some View {
        if style.edge.isHorizontal {
            Rectangle()
                .fill(color(style.highlightColor))
                .frame(height: 2)
                .frame(
                    maxHeight: .infinity,
                    alignment: style.edge == .top
                        ? .bottom : .top
                )
        } else {
            Rectangle()
                .fill(color(style.highlightColor))
                .frame(width: 2)
                .frame(
                    maxWidth: .infinity,
                    alignment: style.edge == .left
                        ? .trailing : .leading
                )
        }
    }

    // MARK: - Metrics

    private var thickness: CGFloat {
        scale(style.thickness, from: 8...80, to: 16...40)
    }
    private var cell: CGFloat { thickness * 0.62 }
    private var gap: CGFloat {
        style.edge.isHorizontal
            ? scale(style.itemGap, from: 0...40, to: 0...14)
            : scale(style.itemGap, from: 0...40, to: 0...6)
    }
    private var corner: CGFloat {
        min(
            style.resolvedCornerRadius(
                forThickness: thickness
            ),
            thickness / 2
        )
    }
    private var font: CGFloat {
        let base =
            style.fontSize > 0
            ? style.fontSize : thickness * 0.4
        return min(base, thickness * 0.5)
    }
    private var mutedColor: Color { color(style.textColor) }

    private func itemBox(_ state: MockState) -> Color {
        guard style.tabBackground == .boxed else {
            return .clear
        }
        return color(
            state == .active
                ? style.activeBoxColor : style.boxColor
        )
    }

    private func scale(
        _ value: CGFloat,
        from src: ClosedRange<CGFloat>,
        to dst: ClosedRange<CGFloat>
    ) -> CGFloat {
        let span = src.upperBound - src.lowerBound
        guard span > 0 else { return dst.lowerBound }
        let t = (value - src.lowerBound) / span
        return dst.lowerBound
            + min(max(t, 0), 1)
            * (dst.upperBound - dst.lowerBound)
    }

    private func color(_ hex: String) -> Color {
        Color(kiwiHex: hex)
    }

    // MARK: - Caption & AX

    private var caption: String {
        L(
            "space_bar.preview.caption",
            "Position: %1$@ · %2$@",
            edgeName,
            styleName
        )
    }

    private var axLabel: String {
        L(
            "space_bar.preview.ax",
            "Space bar preview: %1$@ position, %2$@ style.",
            edgeName,
            styleName
        )
    }

    private var edgeName: String {
        switch style.edge {
        case .top: return L("app_bar.edge.top", "Top")
        case .bottom: return L("app_bar.edge.bottom", "Bottom")
        case .left: return L("app_bar.edge.left", "Left")
        case .right: return L("app_bar.edge.right", "Right")
        }
    }

    private var styleName: String {
        switch style.tabBackground {
        case .boxed:
            return L("app_bar.tab_background.boxed", "Boxed")
        case .plain:
            return L("app_bar.tab_background.plain", "Plain")
        }
    }
}

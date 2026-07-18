import KiwiDeskCore
import SwiftUI

/// A static, in-window mock of the Space Bar (#293) — the
/// `AppBarPreviewStrip` idiom: literal configured hex colors
/// over a neutral backdrop, pure SwiftUI, no runtime reads.
/// Edge-aware: a row for top/bottom, a column for left/right.
/// When both enabled bars share an edge (`sameEdge`, resolved
/// by `TilingSettings.spaceBarSharesEdgeWithAppBar`), a muted
/// App Bar stand-in draws on the window-facing side so the
/// stacking order is seen, not described.
///
/// Horizontal shows three mock Spaces (inactive with a muted
/// count badge, active with both accents, empty); the vertical
/// budget is tighter — 96 pt must hold whole items — so it
/// shows the two state-bearing items with one glyph each
/// (`AppBarPreviewStrip.verticalSlotLength` precedent). Mock
/// content lives in SpaceBarPreviewStrip+Mock.swift; keep in
/// sync with `SpaceBarItemView` (the rendered truth).
struct SpaceBarPreviewStrip: View {
    let style: SpaceBarStyle
    let appBar: AppBarStyle
    let sameEdge: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
                content
            }
            .frame(height: 96)
            // Belt-and-braces: a mock must never spill over
            // the caption and controls below.
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

    // MARK: - Composition

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
            if style.edge.isHorizontal { item(.empty) }
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

    // MARK: - Metrics

    /// Cross-axis depth. The vertical range is tighter so two
    /// whole items + the strip padding stay inside the 96 pt
    /// canvas at every thickness.
    var thickness: CGFloat {
        style.edge.isHorizontal
            ? scale(style.thickness, from: 8...80, to: 16...40)
            : scale(style.thickness, from: 8...80, to: 14...24)
    }

    /// Square glyph cell. Vertical budget: two items of
    /// (2 cells + 2 spacing + 6 padding) + one gap + 8 strip
    /// padding ≤ 96 → cell ≤ 13 at the maxima.
    var cell: CGFloat {
        style.edge.isHorizontal
            ? thickness * 0.62
            : min(thickness * 0.62, 13)
    }

    var gap: CGFloat {
        style.edge.isHorizontal
            ? scale(style.itemGap, from: 0...40, to: 0...14)
            : scale(style.itemGap, from: 0...40, to: 0...4)
    }

    var corner: CGFloat {
        min(
            style.resolvedCornerRadius(
                forThickness: thickness
            ),
            thickness / 2
        )
    }

    var font: CGFloat {
        let base =
            style.fontSize > 0
            ? style.fontSize : thickness * 0.4
        return min(base, thickness * 0.5, cell)
    }

    var mutedColor: Color { color(style.textColor) }

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

    func color(_ hex: String) -> Color {
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

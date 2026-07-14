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
/// The strip always draws **horizontally** and names the chosen
/// position in the caption, rather than rotating to a vertical
/// bar for left/right. Reason: the real bar's edge is decided by
/// the *active layout's* axis (`resolvedPosition`), which a
/// layout-agnostic global preview can't know — a vertical mock
/// would confidently show a left bar the running layout renders
/// on top. A horizontal sample + a "Position: Left" label is
/// honest about what's a color/style choice (shown) vs. an
/// edge the layout resolves (named).
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
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
                strip
            }
            .frame(height: 84)
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

    private var strip: some View {
        HStack(spacing: gap) {
            ForEach(mockTabs) { tab($0) }
        }
        .padding(4)
        .background(color(style.backgroundColor))
    }

    @ViewBuilder private func tab(_ t: MockTab) -> some View {
        if t.active, style.activeStyle == .gap {
            // Active item hidden — leave the gap it would occupy.
            Color.clear.frame(width: slotLength, height: thickness)
        } else {
            tabBox(t)
        }
    }

    private func tabBox(_ t: MockTab) -> some View {
        tabContent(t)
            .frame(width: slotLength, height: thickness)
            .background(
                RoundedRectangle(cornerRadius: corner)
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
            }
            if style.content != .icon {
                Text(t.name)
                    .font(.system(size: font))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(
            color(t.active ? style.activeTextColor : style.textColor)
        )
        .padding(.horizontal, 4)
    }

    /// Pills ring the active tab in the highlight color; segments
    /// and underline draw a bar on the window-facing edge (drawn
    /// here as the strip's inner edge) — both only when the active
    /// style is `highlight` (a `gap` never reaches here).
    @ViewBuilder private func activeAccent(
        _ t: MockTab
    ) -> some View {
        if t.active, style.activeStyle == .highlight {
            if style.style == .pills {
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(
                        color(style.highlightColor),
                        lineWidth: 2
                    )
            } else {
                Rectangle()
                    .fill(color(style.highlightColor))
                    .frame(height: 2)
                    .frame(
                        maxHeight: .infinity,
                        alignment: .bottom
                    )
            }
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
        switch style.style {
        case .underline:
            return .clear
        case .pills, .segments:
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

    /// Real gap 0–40 pt → 0–16 pt.
    private var gap: CGFloat {
        scale(style.itemGap, from: 0...40, to: 0...16)
    }

    private var corner: CGFloat {
        min(style.cornerRadius, thickness / 2)
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
        return min(base, thickness * 0.55)
    }

    // MARK: - Mock content

    private struct MockTab: Identifiable {
        let id: Int
        let icon: String
        let name: String
        let active: Bool
        let badge: Int?
    }

    private var mockTabs: [MockTab] {
        [
            MockTab(
                id: 0,
                icon: "globe",
                name: L("app_bar.preview.app_web", "Web"),
                active: false,
                badge: 2
            ),
            MockTab(
                id: 1,
                icon: "envelope",
                name: L("app_bar.preview.app_mail", "Mail"),
                active: true,
                badge: nil
            ),
            MockTab(
                id: 2,
                icon: "terminal",
                name: L("app_bar.preview.app_code", "Code"),
                active: false,
                badge: nil
            ),
        ]
    }

    // MARK: - Caption & accessibility

    private var caption: String {
        L(
            "app_bar.preview.caption",
            "Position: %1$@ · %2$@",
            positionName,
            styleName
        )
    }

    private var axLabel: String {
        L(
            "app_bar.preview.ax",
            "App bar preview: %1$@ position, %2$@ style.",
            positionName,
            styleName
        )
    }

    private var positionName: String {
        switch style.position {
        case .top: return L("app_bar.position.top", "Top")
        case .bottom:
            return L("app_bar.position.bottom", "Bottom")
        case .left: return L("app_bar.position.left", "Left")
        case .right: return L("app_bar.position.right", "Right")
        }
    }

    private var styleName: String {
        switch style.style {
        case .pills: return L("app_bar.style.pills", "Pills")
        case .segments:
            return L("app_bar.style.segments", "Segments")
        case .underline:
            return L("app_bar.style.underline", "Underline")
        }
    }
}

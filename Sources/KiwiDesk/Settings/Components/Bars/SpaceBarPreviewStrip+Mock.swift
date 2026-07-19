import KiwiDeskCore
import SwiftUI

/// The preview's mock Space items, split from the strip's
/// composition (file-size ceiling). Horizontal items carry two
/// glyphs; vertical ones carry one (the 96 pt budget — see the
/// metrics in the main file).
extension SpaceBarPreviewStrip {
    enum MockState { case inactive, active, empty }

    @ViewBuilder func item(_ state: MockState) -> some View {
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

    /// Identifier leads; occupied items add the divider rule
    /// then glyphs — the active item shows the two-accent
    /// pair, the inactive one a muted count badge. Vertical
    /// bars show one glyph per item (budget).
    @ViewBuilder private func cellViews(
        _ state: MockState
    ) -> some View {
        identifierCell(state)
        switch state {
        case .inactive:
            dividerRule
            glyphCell(tint: mutedColor, badge: true)
            if style.edge.isHorizontal {
                glyphCell(tint: mutedColor, badge: false)
            }
        case .active:
            dividerRule
            if style.edge.isHorizontal {
                glyphCell(
                    tint: color(style.activeTextColor),
                    badge: false
                )
            }
            glyphCell(
                tint: color(style.focusedItemColor),
                badge: false
            )
        case .empty:
            EmptyView()
        }
    }

    private func identifierCell(
        _ state: MockState
    ) -> some View {
        // Plain digits, matching the runtime's fallback — the
        // old bordered N.square read as a box-in-a-box
        // (QA 2026-07-19).
        Text(
            state == .active
                ? "2" : state == .empty ? "3" : "1"
        )
        .font(.system(size: font))
        .foregroundStyle(
            state == .active
                ? color(style.activeTextColor) : mutedColor
        )
        .frame(width: cell, height: cell)
    }

    /// The identifier↔glyphs rule occupied items draw — the
    /// runtime's `BarDivider` treatment.
    @ViewBuilder private var dividerRule: some View {
        let rule = color(style.textColor)
            .opacity(SpaceBarStyle.dividerAlpha)
        if style.edge.isHorizontal {
            Rectangle().fill(rule)
                .frame(width: 1, height: cell * 0.8)
        } else {
            Rectangle().fill(rule)
                .frame(width: cell * 0.8, height: 1)
        }
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

    /// The count badge, muted on the inactive mock item — the
    /// runtime's own derivation (`SpaceBarStyle.mutedBadgeAlpha`).
    private var badgeDot: some View {
        Text("2")
            .font(.system(size: 6, weight: .bold))
            .foregroundStyle(color(style.textColor))
            .padding(2)
            .background(
                Circle().fill(
                    color(style.textColor)
                        .opacity(SpaceBarStyle.mutedBadgeAlpha)
                )
            )
    }

    private func itemBox(_ state: MockState) -> Color {
        guard style.tabBackground == .boxed else {
            return .clear
        }
        return color(
            state == .active
                ? style.activeBoxColor : style.boxColor
        )
    }

    @ViewBuilder private func indicator(
        _ state: MockState
    ) -> some View {
        if state == .active {
            switch style.activeIndicator {
            case .ring:
                // Runtime twin: flush box ring when Boxed, the
                // App Bar's inset capsule on Plain/Liquid Glass
                // (QA 2026-07-19).
                if style.tabBackground == .boxed {
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(
                            color(style.highlightColor),
                            lineWidth: 2
                        )
                } else {
                    Capsule()
                        .strokeBorder(
                            color(style.highlightColor),
                            lineWidth: 2
                        )
                        .padding(1.5)
                }
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
}

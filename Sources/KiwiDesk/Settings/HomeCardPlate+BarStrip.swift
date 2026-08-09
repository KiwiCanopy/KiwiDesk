import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// One bar strip of the fused Bars scene
/// (`HomeCardBarsTile`), split at the file-size target: the
/// seat, the plate and the item marks. Everything here derives
/// from the `BarSpec` the tile read off the real style struct.
struct BarStripView: View {
    let spec: HomeCardBarsTile.BarSpec
    let edge: AppBarEdge
    let vertical: Bool
    let scale: CGFloat
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        Group {
            if spec.spans {
                // `full`: the plate runs edge-to-edge and the
                // item run seats INSIDE it.
                plate(spanning: true)
                    .overlay(seated { run })
            } else if spec.boxed {
                // Boxed draws no shared plate — the run seats
                // bare on the screen.
                seated { run }
            } else {
                // `hug`: the plate wraps the run plus one gap
                // of air per end (the Dock's read), and the
                // WRAPPED plate seats.
                seated {
                    run
                        .padding(
                            vertical
                                ? .vertical : .horizontal,
                            spec.gap
                        )
                        .background(plate(spanning: false))
                }
            }
        }
        .frame(
            width: vertical ? 16 * scale : nil,
            height: vertical ? nil : 16 * scale
        )
    }

    // MARK: - Plate & run

    private func plate(spanning: Bool) -> some View {
        RoundedRectangle(cornerRadius: spec.corner)
            .fill(Color(kiwiHex: spec.fill))
            .overlay(
                RoundedRectangle(cornerRadius: spec.corner)
                    .strokeBorder(
                        palette?.frame
                            ?? SettingsTheme.plateInk
                            .opacity(0.3)
                    )
            )
    }

    private var run: some View {
        stack(spacing: spec.gap) {
            ForEach(
                Array(spec.items.enumerated()),
                id: \.offset
            ) { _, item in
                pip(item)
            }
        }
        .padding(vertical ? .vertical : .horizontal, 3 * scale)
    }

    /// The item run's seat along the bar — the style's own
    /// `alignment`, edge-relative exactly like the real bar's
    /// (`start` is a top bar's left and a left bar's top, which
    /// is the stacks' natural reading order).
    @ViewBuilder
    private func seated(
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        stack(spacing: 0) {
            if spec.alignment != .start {
                Spacer(minLength: 0)
            }
            content()
            if spec.alignment != .end {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func stack(
        spacing: CGFloat,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        if vertical {
            VStack(spacing: spacing) { content() }
        } else {
            HStack(spacing: spacing) { content() }
        }
    }

    // MARK: - Items

    /// A bare pip on the Home plate; at panel scale the item
    /// carries its identifier in the bar's two-accent model.
    /// The active item is marked per the style's own
    /// `active_indicator`: an outline traced at the bar's
    /// roundness, an accent bar on the window-facing edge, or
    /// an empty slot.
    @ViewBuilder
    private func pip(
        _ item: HomeCardBarsTile.BarItem
    ) -> some View {
        if item.active, spec.indicator == .gap {
            Color.clear
                .frame(
                    width: vertical ? 9 * scale : item.length,
                    height: vertical ? item.length : 9 * scale
                )
        } else {
            pipBody(item)
                .overlay(indicatorMark(item))
        }
    }

    @ViewBuilder
    private func pipBody(
        _ item: HomeCardBarsTile.BarItem
    ) -> some View {
        if let text = item.label {
            Text(text)
                .font(
                    .system(
                        size: 7.5 * scale,
                        weight: .semibold
                    )
                )
                .lineLimit(1)
                .foregroundStyle(Color(kiwiHex: item.color))
                .padding(.horizontal, 2.5 * scale)
                .padding(.vertical, 1.5 * scale)
        } else if let glyph = item.glyph {
            Image(systemName: glyph)
                .font(.system(size: 7 * scale))
                .foregroundStyle(Color(kiwiHex: item.color))
                .padding(.horizontal, 2.5 * scale)
                .padding(.vertical, 1.5 * scale)
        } else {
            RoundedRectangle(cornerRadius: pipCorner)
                .fill(Color(kiwiHex: item.color))
                .frame(
                    width: vertical ? 9 * scale : item.length,
                    height: vertical ? item.length : 9 * scale
                )
        }
    }

    /// The item's own corner from the same roundness the plate
    /// resolves, at the pip's cross size.
    private var pipCorner: CGFloat {
        min(spec.corner, 4.5 * scale)
    }

    @ViewBuilder
    private func indicatorMark(
        _ item: HomeCardBarsTile.BarItem
    ) -> some View {
        if item.active {
            switch spec.indicator {
            case .outline:
                RoundedRectangle(cornerRadius: pipCorner)
                    .strokeBorder(
                        Color(kiwiHex: spec.highlight),
                        lineWidth: max(1, scale)
                    )
            case .edgeMark:
                Rectangle()
                    .fill(Color(kiwiHex: spec.highlight))
                    .frame(
                        width: vertical
                            ? 1.5 * scale : nil,
                        height: vertical
                            ? nil : 1.5 * scale
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: windowFacing
                    )
            case .gap:
                EmptyView()
            }
        }
    }

    /// The window-facing side of this bar's items — where the
    /// real `edge_mark` draws: a top bar marks its items'
    /// bottom edge, a left bar their trailing edge.
    private var windowFacing: Alignment {
        switch edge {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .trailing
        case .right: return .leading
        }
    }
}

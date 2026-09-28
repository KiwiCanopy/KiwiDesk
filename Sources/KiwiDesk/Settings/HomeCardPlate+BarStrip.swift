import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// Bar strip view component for Home plate bars tile (`HomeCardBarsTile`).
struct BarStripView: View {
    let spec: HomeCardBarsTile.BarSpec
    let edge: AppBarEdge
    let vertical: Bool
    let scale: CGFloat
    /// False where the shelf draws one plate under both bars and
    /// this strip draws only its run (`ShelfStripPreview`).
    var drawsPlate = true

    var body: some View {
        Group {
            if !drawsPlate && !spec.boxed {
                seated {
                    run.padding(
                        vertical ? .vertical : .horizontal,
                        spec.gap
                    )
                }
            } else if spec.spans {
                plate
                    .overlay(seated { run })
            } else if spec.boxed {
                seated { run }
            } else {
                seated {
                    run
                        .padding(
                            vertical
                                ? .vertical : .horizontal,
                            spec.gap
                        )
                        .frame(
                            width: vertical
                                ? spec.thickness : nil,
                            height: vertical
                                ? nil : spec.thickness
                        )
                        .background(plate)
                }
            }
        }
        .frame(
            width: vertical ? spec.thickness : nil,
            height: vertical ? nil : spec.thickness
        )
    }

    /// Computed cross dimension for bar pips — content, so it
    /// follows the glyph size (#1713).
    var pipCross: CGFloat {
        spec.thickness * 0.56 * spec.contentShare
    }

    // MARK: - Plate & run

    private var plate: some View {
        RoundedRectangle(cornerRadius: spec.corner)
            .fill(Color(kiwiHex: spec.fill))
            .overlay(PreviewPlateEdge(spec: spec, corner: spec.corner))
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

    /// Positions item run along the bar according to alignment spec.
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

    /// Renders individual bar item with active indicator and optional boxing.
    @ViewBuilder
    private func pip(
        _ item: HomeCardBarsTile.BarItem
    ) -> some View {
        if spec.boxed {
            // Boxed: each item wears its own box in the fill
            // colour — the shared plate the style refuses is
            // paid back per item (owner 2026-08-10).
            pipBody(item)
                .padding(1.5 * scale)
                .background(
                    RoundedRectangle(
                        cornerRadius: spec.itemCorner
                    )
                    .fill(Color(kiwiHex: spec.fill))
                    .overlay(
                        PreviewPlateEdge(
                            spec: spec,
                            corner: spec.itemCorner
                        )
                    )
                )
                .overlay(indicatorMark(item))
        } else {
            pipBody(item)
                .overlay(indicatorMark(item))
        }
    }

    @ViewBuilder
    private func pipBody(
        _ item: HomeCardBarsTile.BarItem
    ) -> some View {
        if item.label != nil || item.glyph != nil {
            // Icon and name together when the item carries
            // both — the App Bar's `icon_and_title` content;
            // truncation only ever eats the name, the real
            // bar's rule.
            // Sizes come through the bar's OWN font ladder
            // (`BarSpec.fontSize`, resolved at the scene's
            // cross), so the Thickness slider moves the
            // symbols with the plate; the glyph steps down by
            // the Space Bar's own glyph ratio.
            HStack(spacing: 2 * scale) {
                if let glyph = item.glyph {
                    Image(systemName: glyph)
                        .font(
                            .system(
                                size: spec.fontSize * item.glyphRatio
                            )
                        )
                }
                if let text = item.label {
                    Text(text)
                        .font(spec.textFont(size: spec.fontSize))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(Color(kiwiHex: item.color))
            .padding(.horizontal, 2.5 * scale)
            .padding(.vertical, 1.5 * scale)
            // Rounded ends pad the axis, as the live item (#1763).
            .padding(
                vertical ? .vertical : .horizontal,
                KiwiShelf.cornerCut(radius: spec.itemCorner)
            )
            .frame(
                minWidth: vertical ? pipCross : nil,
                minHeight: vertical ? nil : pipCross
            )
        } else {
            RoundedRectangle(cornerRadius: spec.itemCorner)
                .fill(Color(kiwiHex: item.color))
                .frame(
                    width: vertical ? pipCross : item.length,
                    height: vertical ? item.length : pipCross
                )
        }
    }

    @ViewBuilder
    private func indicatorMark(
        _ item: HomeCardBarsTile.BarItem
    ) -> some View {
        if item.active {
            switch spec.indicator {
            case .outline:
                RoundedRectangle(cornerRadius: spec.itemCorner)
                    .strokeBorder(
                        SheenPaint.style(spec.highlight, sheen: spec.sheen),
                        lineWidth: spec.outlineWidth
                    )
            case .edgeMark:
                Rectangle()
                    .fill(
                        SheenPaint.style(spec.highlight, sheen: spec.sheen)
                    )
                    .frame(
                        width: vertical
                            ? spec.edgeMarkWidth : nil,
                        height: vertical
                            ? nil : spec.edgeMarkWidth
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: windowFacing
                    )
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

import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// The shelf's strip in the Bars preview (#1517): each shown bar
/// drawn in the segment `ShelfArrangement` gives it, measured on
/// the strip's drawn length, so a lone bar sits at the alignment
/// and two take opposite ends exactly as the live bars do.
struct ShelfStripPreview: View {
    let shelf: KiwiShelf
    let space: HomeCardBarsTile.BarSpec?
    let app: HomeCardBarsTile.BarSpec?
    let edge: AppBarEdge
    let vertical: Bool
    let scale: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let length =
                vertical ? geometry.size.height : geometry.size.width
            let placed = arrangement(length: length)
            ZStack(alignment: .topLeading) {
                segment(space, placed.space)
                segment(app, placed.app)
            }
        }
        .frame(
            width: vertical ? thickness : nil,
            height: vertical ? nil : thickness
        )
    }

    private var thickness: CGFloat {
        max(space?.thickness ?? 0, app?.thickness ?? 0)
    }

    /// Core's placement over the preview's own units: each bar's
    /// need is its drawn run plus the plate's pad at both ends,
    /// and the gutter is the preview's strip spacing.
    private func arrangement(length: CGFloat) -> ShelfArrangement {
        var scaled = shelf
        scaled.itemGap = 3 * scale
        return ShelfArrangement.arrange(
            length: length,
            spaceNeed: space.map(need),
            appNeed: app.map(need),
            // The mock run is a few items, so the floor never binds
            // at a thumbnail's scale; the #1517 preview redraw hands
            // it the scaled floor once the preview draws overflow.
            spaceFloor: 0,
            shelf: scaled
        )
    }

    private func need(_ spec: HomeCardBarsTile.BarSpec) -> CGFloat {
        let items = spec.items.map(\.length).reduce(0, +)
        let gaps = spec.gap * CGFloat(max(spec.items.count - 1, 0))
        return items + gaps + 2 * (spec.gap + 3 * scale)
    }

    private func seated(
        _ spec: HomeCardBarsTile.BarSpec,
        at alignment: KiwiShelf.Alignment
    ) -> HomeCardBarsTile.BarSpec {
        var seated = spec
        seated.alignment = alignment
        return seated
    }

    @ViewBuilder
    private func segment(
        _ spec: HomeCardBarsTile.BarSpec?,
        _ slot: ShelfArrangement.Slot?
    ) -> some View {
        if let spec, let slot {
            BarStripView(
                spec: seated(spec, at: slot.alignment),
                edge: edge,
                vertical: vertical,
                scale: scale
            )
            .frame(
                width: vertical ? nil : slot.length,
                height: vertical ? slot.length : nil
            )
            .offset(
                x: vertical ? 0 : slot.offset,
                y: vertical ? slot.offset : 0
            )
        }
    }
}

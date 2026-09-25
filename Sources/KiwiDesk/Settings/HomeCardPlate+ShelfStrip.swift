import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// The shelf's strip in the Bars preview (#1517): each shown bar
/// drawn in the segment `ShelfArrangement` gives it, measured on
/// the strip's drawn length, over ONE plate — the live shelf's
/// joined plate — with the section divider between two bars. A
/// run longer than its segment is cut there and fades at its
/// hidden end, as the live section does; its fade and the Space
/// section's floor are Core's own (`ShelfOverflow.fadeLength`,
/// `ShelfArrangement.hardFloor`).
struct ShelfStripPreview: View {
    let shelf: KiwiShelf
    let space: HomeCardBarsTile.BarSpec?
    let app: HomeCardBarsTile.BarSpec?
    let edge: AppBarEdge
    let vertical: Bool
    let scale: CGFloat
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        GeometryReader { geometry in
            let length =
                vertical ? geometry.size.height : geometry.size.width
            let placed = arrangement(length: length)
            ZStack(alignment: .topLeading) {
                plate(placed, length: length)
                segment(space, placed.space)
                segment(app, placed.app)
                divider(placed)
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

    private var gutter: CGFloat { 3 * scale }

    /// Core's placement over the preview's own units: each bar's
    /// need is its drawn run plus the plate's pad at both ends,
    /// the gutter is the preview's strip spacing, and the Space
    /// section's floor is the engine's, for the active Space.
    func arrangement(length: CGFloat) -> ShelfArrangement {
        let u = unit
        var live = shelf
        live.itemGap = gutter / u
        let placed = ShelfArrangement.arrange(
            length: length / u,
            spaceNeed: space.map { need($0) / u },
            appNeed: app.map { need($0) / u },
            spaceFloor: space.map {
                ShelfArrangement.hardFloor(
                    activeExtent: ($0.items.first?.length ?? 0) / u,
                    thickness: shelf.thickness,
                    gap: $0.gap / u
                )
            } ?? 0,
            shelf: live
        )
        return ShelfArrangement(
            space: placed.space.map { scaled($0, by: u) },
            app: placed.app.map { scaled($0, by: u) },
            divider: placed.divider
        )
    }

    /// Preview units per real point: the drawn thickness against
    /// the shelf's own, so Core's point-valued rules — the fade's
    /// bounds, the hard floor — apply at the scale they are for.
    var unit: CGFloat {
        shelf.thickness > 0 && thickness > 0
            ? thickness / shelf.thickness : 1
    }

    private func scaled(
        _ slot: ShelfArrangement.Slot,
        by u: CGFloat
    ) -> ShelfArrangement.Slot {
        var slot = slot
        slot.offset *= u
        slot.length *= u
        return slot
    }

    private func need(_ spec: HomeCardBarsTile.BarSpec) -> CGFloat {
        let items = spec.items.map(\.length).reduce(0, +)
        let gaps = spec.gap * CGFloat(max(spec.items.count - 1, 0))
        return items + gaps + 2 * (spec.gap + 3 * scale)
    }

    /// Where a bar's run sits in its slot, along the edge: an
    /// overflowing run starts at the slot's start — the live
    /// section follows the active item, the first here.
    func run(
        _ spec: HomeCardBarsTile.BarSpec,
        in slot: ShelfArrangement.Slot
    ) -> ClosedRange<CGFloat> {
        let length = min(need(spec), slot.length)
        let lead: CGFloat
        switch overflows(spec, slot) ? .start : slot.alignment {
        case .start: lead = 0
        case .center: lead = (slot.length - length) / 2
        case .end: lead = slot.length - length
        }
        return (slot.offset + lead)...(slot.offset + lead + length)
    }

    func overflows(
        _ spec: HomeCardBarsTile.BarSpec,
        _ slot: ShelfArrangement.Slot
    ) -> Bool {
        need(spec) > slot.length + 0.5
    }

    /// The one plate's span along the edge: Core's
    /// `ShelfArrangement.plateSpan` over the runs.
    func plateSpan(
        _ placed: ShelfArrangement,
        length: CGFloat
    ) -> ClosedRange<CGFloat>? {
        ShelfArrangement.plateSpan(
            asks: [
                space.flatMap { spec in placed.space.map { run(spec, in: $0) }
                },
                app.flatMap { spec in placed.app.map { run(spec, in: $0) } },
            ].compactMap { $0 },
            length: length,
            shelf: shelf
        )
    }

    @ViewBuilder
    private func plate(
        _ placed: ShelfArrangement,
        length: CGFloat
    ) -> some View {
        if let span = plateSpan(placed, length: length),
            let spec = space ?? app
        {
            RoundedRectangle(cornerRadius: spec.corner)
                .fill(Color(kiwiHex: spec.fill))
                .overlay(
                    RoundedRectangle(cornerRadius: spec.corner)
                        .strokeBorder(
                            palette?.frame
                                ?? SettingsTheme.plateInk.opacity(0.3)
                        )
                )
                .frame(
                    width: vertical
                        ? thickness : span.upperBound - span.lowerBound,
                    height: vertical
                        ? span.upperBound - span.lowerBound : thickness
                )
                .offset(
                    x: vertical ? 0 : span.lowerBound,
                    y: vertical ? span.lowerBound : 0
                )
        }
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
            let cut = overflows(spec, slot)
            BarStripView(
                spec: seated(spec, at: cut ? .start : slot.alignment),
                edge: edge,
                vertical: vertical,
                scale: scale,
                drawsPlate: false
            )
            .fixedSize(horizontal: !vertical && cut, vertical: vertical && cut)
            .frame(
                width: vertical ? thickness : slot.length,
                height: vertical ? slot.length : thickness,
                alignment: .topLeading
            )
            .clipped()
            .mask(fade(cut ? slot.length : 0, along: slot.length))
            .offset(
                x: vertical ? 0 : slot.offset,
                y: vertical ? slot.offset : 0
            )
        }
    }

    /// Opaque, fading to clear over the engine's fade length at
    /// the far end while `hidden` — the run's cut side.
    private func fade(_ hidden: CGFloat, along length: CGFloat) -> some View {
        let fade =
            hidden > 0
            ? ShelfOverflow.fadeLength(
                thickness: shelf.thickness,
                visible: length / unit
            ) * unit
            : 0
        let stop = length > 0 ? max(1 - fade / length, 0) : 1
        return LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: stop),
                .init(color: fade > 0 ? .clear : .black, location: 1),
            ],
            startPoint: vertical ? .top : .leading,
            endPoint: vertical ? .bottom : .trailing
        )
    }

    /// The section divider: Core's geometry and colour, centred
    /// in the gutter between two bars.
    @ViewBuilder
    private func divider(_ placed: ShelfArrangement) -> some View {
        if let middle = placed.dividerMiddle {
            let frame = BarDivider.sectionFrame(
                at: middle,
                depth: thickness,
                horizontal: !vertical
            )
            Capsule()
                .fill(
                    Color(
                        nsColor: BarDivider.sectionColor(
                            textColor: shelf.itemColor
                        )
                    )
                )
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
        }
    }
}

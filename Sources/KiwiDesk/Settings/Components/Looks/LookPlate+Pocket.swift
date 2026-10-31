import KiwiDeskCore
import SwiftUI

/// The gallery picture's pocket (#1740): how it rests is Core's
/// `pocketRest` — a section on the shelf's strip, or the whole mark
/// on an edge no bar shows, at its Position kept whole on the edge
/// (`ShelfMarkPlacement.bandStart`); a handle draws nothing here.
extension LookPlate {
    /// How the pocket rests on the picture; nil on a tile.
    var pocketRest: PocketRest? {
        size.drawsPocket ? settings.pocketRest(in: mode, on: nil) : nil
    }

    /// The layout the picture's App Bar is drawn from.
    var mode: LayoutMode {
        HomeCardBarsTile.appBarMode(settings) ?? .bsp
    }

    /// The edge the whole mark reserves its strip on, where Core's
    /// reservation keeps one.
    var pocketReserve: AppBarEdge? {
        guard pocketRest == .mark,
            let reserved = settings.pocketReservation(in: mode, on: nil)
        else { return nil }
        return reserved.edge
    }

    /// The whole mark's strip on the picture: the bars' own depth.
    var lonePocketDepth: CGFloat {
        HomeCardBarsTile(
            settings: settings,
            pocketStands: false,
            scale: Self.barScale
        ).crossSize(settings.kiwishelf.thickness)
    }

    /// The whole mark's centre on a plate of `size`.
    func lonePocketCentre(in plate: CGSize) -> CGPoint {
        let shelf = settings.kiwishelf
        let depth = lonePocketDepth
        // The live band, in the picture's units: the bars' depth
        // over the shelf's own thickness.
        let band =
            ShelfMarkPlacement.bandLength * depth
            / max(shelf.thickness, 1)
        let along = shelf.pocketEdge.isHorizontal ? plate.width : plate.height
        let start = ShelfMarkPlacement.bandStart(
            position: shelf.pocketPosition,
            low: 0,
            high: along,
            length: band
        )
        let middle = start + band / 2
        switch shelf.pocketEdge {
        case .top: return CGPoint(x: middle, y: depth / 2)
        case .bottom: return CGPoint(x: middle, y: plate.height - depth / 2)
        case .left: return CGPoint(x: depth / 2, y: middle)
        case .right: return CGPoint(x: plate.width - depth / 2, y: middle)
        }
    }

    var lonePocket: some View {
        GeometryReader { plate in
            Image(
                nsImage: PocketMark.mark.image(
                    size: PocketMarkGeometry.markSide(depth: lonePocketDepth),
                    hex: settings.pocketStyle.color
                )
            )
            .position(lonePocketCentre(in: plate.size))
        }
    }
}

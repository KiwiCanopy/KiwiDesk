import KiwiDeskCore
import SwiftUI

/// The strip's sizes, overflow fades and focus follow (#2901).
extension LayoutStrip {
    /// The thumbnail's width: six tiles fit the pane at
    /// `SettingsTheme.contentMaxWidth` (`LayoutStripTests`).
    nonisolated static let schematicWidth: CGFloat = 112
    /// Around the thumbnail inside its plate, and around the tile's
    /// content inside its chrome.
    nonisolated static let platePadding: CGFloat = 4
    nonisolated static let chromePadding: CGFloat = 6
    nonisolated static let gap: CGFloat = 10
    /// Room around the row for a tile's focus ring, inside the clip.
    nonisolated static let ringRoom: CGFloat = 4
    nonisolated static let space = "layoutStrip"

    /// Factor from `SchematicScale.tile` down to the strip's size.
    nonisolated static var schematicFactor: CGFloat {
        schematicWidth / (SchematicScale.tile.width ?? schematicWidth)
    }

    nonisolated static var tileWidth: CGFloat {
        schematicWidth + 2 * platePadding + 2 * chromePadding
    }

    /// Each tile's run along the row, the ring room riding on the
    /// end tiles.
    nonisolated static var lengths: [CGFloat] {
        let count = LayoutMode.placementTabs.count
        return (0..<count).map { index in
            tileWidth + (index == 0 ? ringRoom : 0)
                + (index == count - 1 ? ringRoom : 0)
        }
    }

    nonisolated static var rowWidth: CGFloat {
        lengths.reduce(0, +) + gap * CGFloat(max(lengths.count - 1, 0))
    }

    /// The fade's depth: the drawn thumbnail's height.
    nonisolated static var depth: CGFloat {
        SchematicScale.tile.height * schematicFactor
    }

    /// The thumbnail at the tile scale, scaled down as KiwiHub's
    /// layout tiles are (`JumpLayoutTile`).
    func schematic(_ mode: LayoutMode) -> some View {
        let tile = SchematicScale.tile
        let factor = Self.schematicFactor
        return LayoutSchematicView(
            mode: mode,
            settings: model.config.settings,
            windows: LayoutSchematic.defaultWindowCount,
            scale: .tile
        )
        .frame(width: tile.width, height: tile.height)
        .scaleEffect(factor)
        .frame(width: Self.schematicWidth, height: Self.depth)
    }

    /// Core's overflow fades (`ShelfOverflow.fades`), as the gesture
    /// strip's.
    nonisolated static func fades(offset: CGFloat, viewport: CGFloat)
        -> ShelfOverflow.Fades
    {
        ShelfOverflow.fades(
            lengths: lengths,
            gap: gap,
            total: rowWidth,
            offset: offset,
            viewport: viewport,
            depth: depth
        )
    }

    /// Where Core's follow (`ShelfOverflow.offset`) puts the strip
    /// for the tile at `index`, clear of the fade.
    nonisolated static func followOffset(
        index: Int,
        offset: CGFloat,
        viewport: CGFloat
    ) -> CGFloat {
        ShelfOverflow.offset(
            current: offset,
            lengths: lengths,
            gap: gap,
            total: rowWidth,
            activeIndex: index,
            viewport: viewport,
            margin: ShelfOverflow.followMargin(
                gap: gap,
                depth: depth,
                viewport: viewport
            )
        )
    }

    /// `followOffset` as a `scrollTo` anchor on the tile, or nil
    /// where the strip need not move: an anchor's x places the
    /// tile's leading edge at x · (viewport − tile) in view.
    nonisolated static func followAnchor(
        index: Int,
        offset: CGFloat,
        viewport: CGFloat
    ) -> UnitPoint? {
        let target = followOffset(
            index: index,
            offset: offset,
            viewport: viewport
        )
        guard abs(target - offset) > 0.5, viewport > tileWidth else {
            return nil
        }
        let start = ringRoom + CGFloat(index) * (tileWidth + gap)
        let share = (start - target) / (viewport - tileWidth)
        return UnitPoint(x: min(max(share, 0), 1), y: 0.5)
    }
}

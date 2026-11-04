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

    nonisolated static var rowWidth: CGFloat { run.total }

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

    /// The tiles' run, the ring room carried on the end tiles.
    nonisolated static var run: StripRun {
        StripRun(lengths: lengths, gap: gap, depth: depth, inset: ringRoom)
    }

    nonisolated static func fades(offset: CGFloat, viewport: CGFloat)
        -> ShelfOverflow.Fades
    {
        run.fades(StripScroll(offset: offset, viewport: viewport))
    }

    /// Where a Tab onto the tile at `index` scrolls the strip.
    nonisolated static func followAnchor(
        index: Int,
        offset: CGFloat,
        viewport: CGFloat
    ) -> UnitPoint? {
        run.followAnchor(
            index: index,
            width: tileWidth,
            scroll: StripScroll(offset: offset, viewport: viewport)
        )
    }
}

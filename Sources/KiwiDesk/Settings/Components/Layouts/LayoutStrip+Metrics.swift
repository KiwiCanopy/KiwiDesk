import KiwiDeskCore
import SwiftUI

/// The strip's sizes and overflow fades (#2901).
extension LayoutStrip {
    /// The thumbnail's width: six tiles fit the pane at
    /// `SettingsTheme.contentMaxWidth` (`LayoutStripTests`).
    nonisolated static let schematicWidth: CGFloat = 112
    nonisolated static let gap: CGFloat = 10
    /// Room around the row for a tile's focus ring, inside the clip.
    nonisolated static let ringRoom: CGFloat = 4
    nonisolated static let space = "layoutStrip"

    /// Factor from `SchematicScale.tile` down to the strip's size.
    nonisolated static var schematicFactor: CGFloat {
        schematicWidth / (SchematicScale.tile.width ?? schematicWidth)
    }

    /// A tile's outer width: the thumbnail, its plate padding (4)
    /// and the chrome padding (6), each on both sides.
    nonisolated static var tileWidth: CGFloat {
        schematicWidth + 2 * 4 + 2 * 6
    }

    /// The whole row, ring room included.
    nonisolated static var rowWidth: CGFloat {
        let count = CGFloat(LayoutMode.placementTabs.count)
        return count * tileWidth + (count - 1) * gap + 2 * ringRoom
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
        .frame(
            width: Self.schematicWidth,
            height: tile.height * factor
        )
    }

    var fades: ShelfOverflow.Fades {
        Self.fades(offset: offset, viewport: viewport)
    }

    /// Core's overflow fades (`ShelfOverflow.fades`), as the gesture
    /// strip's; the ring room rides on the end tiles.
    nonisolated static func fades(offset: CGFloat, viewport: CGFloat)
        -> ShelfOverflow.Fades
    {
        let count = LayoutMode.placementTabs.count
        let lengths = (0..<count).map { index -> CGFloat in
            let ends =
                (index == 0 ? ringRoom : 0)
                + (index == count - 1 ? ringRoom : 0)
            return tileWidth + ends
        }
        return ShelfOverflow.fades(
            lengths: lengths,
            gap: gap,
            total: rowWidth,
            offset: offset,
            viewport: viewport,
            depth: SchematicScale.tile.height * schematicFactor
        )
    }
}

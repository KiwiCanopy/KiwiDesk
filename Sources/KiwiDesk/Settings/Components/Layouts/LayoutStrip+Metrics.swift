import KiwiDeskCore
import SwiftUI

/// The strip's sizes and run (#2901).
extension LayoutStrip {
    /// The thumbnail's width: six tiles fit the pane at
    /// `SettingsTheme.contentMaxWidth` (`LayoutStripTests`).
    nonisolated static let schematicWidth: CGFloat = 112
    /// Around the thumbnail inside its plate, and around the tile's
    /// content inside its chrome.
    nonisolated static let platePadding: CGFloat = 4
    nonisolated static let chromePadding: CGFloat = 6
    nonisolated static let gap: CGFloat = 10
    /// Room around the row for a tile's focus ring and a risen tile's
    /// shadow, inside the clip.
    nonisolated static let ringRoom: CGFloat =
        SettingsTheme.hoverRiseShadowRadius

    /// Factor from `SchematicScale.tile` down to the strip's size.
    nonisolated static var schematicFactor: CGFloat {
        schematicWidth / (SchematicScale.tile.width ?? schematicWidth)
    }

    nonisolated static var tileWidth: CGFloat {
        schematicWidth + 2 * platePadding + 2 * chromePadding
    }

    /// The tiles' run, the ring room carried past the end tiles.
    nonisolated static var run: StripRun {
        StripRun(
            lengths: LayoutMode.placementTabs.map { _ in tileWidth },
            gap: gap,
            depth: depth,
            endRoom: ringRoom
        )
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
}

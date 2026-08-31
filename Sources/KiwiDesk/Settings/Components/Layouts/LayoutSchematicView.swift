import KiwiDeskCore
import SwiftUI

/// Renders schematic visualization for any LayoutMode and configuration.
struct LayoutSchematicView: View {
    let mode: LayoutMode
    let settings: TilingSettings
    /// No default: a caller that could omit the count would draw
    /// a different number of windows from its sibling and never
    /// say so — the drift this type exists to prevent.
    let windows: Int
    let scale: SchematicScale
    @Environment(\.schematicPalette) private var palette

    /// Resolved focus stroke: the draft's REAL
    /// `border.focused_color` (owner ruled 2026-08-10), set at
    /// this one mount so strip, panel and Home band cannot
    /// disagree. Stated residue: off-plate a user-invisible
    /// focused colour is shown invisible, which is the truth
    /// about it.
    private var focusStroke: Color? {
        let style = settings.borderStyle
        guard style.enabled else { return nil }
        if palette != nil,
            !HomeCardPlate.plateLegible(style.focusedColor)
        {
            return nil
        }
        return Color(kiwiHex: style.focusedColor)
    }

    var body: some View {
        schematic.environment(
            \.schematicFocusStroke,
            focusStroke
        )
    }

    @ViewBuilder private var schematic: some View {
        switch mode {
        case .bsp:
            BspSchematic(
                splitRatioH: settings.bsp.splitRatioH,
                splitRatioV: settings.bsp.splitRatioV,
                strategy: settings.bsp.strategy,
                placement: settings.bsp.newWindowPlacement,
                windows: windows,
                scale: scale
            )
        case .stack:
            StackSchematic(
                masterCount: settings.stack.masterCount,
                masterRatio: settings.stack.masterRatio,
                overflowStyle: settings.stack.overflowStyle,
                masterOrientation: settings.stack.masterOrientation,
                stackPosition: settings.stack.stackPosition,
                placement: settings.stack.newWindowPlacement,
                windows: windows,
                scale: scale
            )
        case .scrolling:
            ScrollingSchematic(
                orientation: settings.scrolling.orientation,
                anchor: settings.scrolling.anchor,
                slotSize: settings.scrolling.slotSize,
                placement: settings.scrolling.newWindowPlacement,
                windows: windows,
                scale: scale
            )
        case .grid:
            GridSchematic(
                columns: settings.grid.columns,
                rows: settings.grid.rows,
                type: settings.grid.type,
                fillEmptyCells: settings.grid.fillEmptyCells,
                autoSize: settings.grid.autoSize,
                splitDirection: settings.grid.splitDirection,
                placement: settings.grid.newWindowPlacement,
                windows: windows,
                scale: scale
            )
        case .monocle:
            MonocleSchematic(
                orientation: settings.monocle.orientation,
                hideStyle: settings.monocle.hideStyle,
                windows: windows,
                scale: scale
            )
        case .track:
            TrackSchematic(
                axis: settings.track.axis,
                overflowStyle: settings.track.overflowStyle,
                newWindow: settings.track.newWindow,
                placement: settings.track.newWindowPosition,
                limit: settings.track.limit,
                autoTracks: settings.track.autoTracks,
                windows: windows,
                scale: scale
            )
        case .floating:
            FloatingSchematic(windows: windows, scale: scale)
        }
    }
}

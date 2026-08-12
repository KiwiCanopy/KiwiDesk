import KiwiDeskCore
import SwiftUI

/// A layout's schematic, chosen by mode — the one place the
/// seven-way mapping from a `LayoutMode` to its drawing lives.
///
/// Both surfaces that draw a layout go through it: the "Choose a
/// layout" strip at `.tile` and the live preview at `.panel`.
/// Without it the mapping would exist twice, and a schematic
/// gaining an input would be wired into one caller and not the
/// other — the strip then quietly drawing a stale picture of the
/// same settings the panel below it draws correctly.
///
/// Floating draws nothing: it has no geometry to show and no
/// parameters to tune, which is why it is not in
/// `LayoutMode.placementTabs` at all.
struct LayoutSchematicView: View {
    let mode: LayoutMode
    let settings: TilingSettings
    /// No default: a caller that could omit the count would draw
    /// a different number of windows from its sibling and never
    /// say so — which is the drift this type exists to prevent,
    /// one parameter down. Every caller states its count.
    let windows: Int
    let scale: SchematicScale
    @Environment(\.schematicPalette) private var palette

    /// The active tile's focus stroke: the draft's REAL
    /// `border.focused_color` (owner ruled 2026-08-10 — the
    /// Gaps ring's honesty rule extended here). Set at this one
    /// mount so the strip, the panel and the Home band cannot
    /// disagree. `nil` — borders disabled, or a plate mount
    /// whose colour fails the plate floor — keeps the family
    /// stroke, which claims nothing. Stated residue: off-plate
    /// the colour is shown raw, like the Gaps ring — a
    /// user-invisible focused colour is shown invisible, which
    /// is the truth about it.
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

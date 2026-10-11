import KiwiDeskCore
import SwiftUI

/// Advanced Colours gating logic (#520, #527, #678).
@MainActor
struct AdvancedColorsGates {
    let settings: TilingSettings

    /// The bar halves, delegated whole.
    var bars: BarsGates { BarsGates(settings: settings) }

    // MARK: - Borders

    var borderOn: Bool { settings.borderStyle.enabled }
    var unfocusedOn: Bool { settings.borderStyle.unfocusedEnabled }

    // MARK: - Drag visuals

    func dragVisual(_ ghost: Bool) -> DragVisual {
        ghost ? settings.dragGhost : settings.dragDropZone
    }

    /// Whether a drag tint draws nothing: its visual is off, or
    /// the part it tints is (#527).
    func dragInert(ghost: Bool, fill: Bool) -> Bool {
        let visual = dragVisual(ghost)
        return !visual.enabled || (fill ? !visual.fill : !visual.border)
    }

    /// The hover reason for one drag tint.
    func dragHelp(ghost: Bool, fill: Bool) -> String {
        if !dragVisual(ghost).enabled { return AdvancedColorsHelp.dragOff }
        return fill
            ? AdvancedColorsHelp.dragFillOff
            : AdvancedColorsHelp.dragBorderOff
    }

    /// Whether any bar shows, so the shelf's colours draw.
    var shelfDraws: Bool {
        bars.containerReason(for: .kiwishelf) == nil
    }

    // MARK: - KiwiShelf

    /// The shelf draws no border, so its colour is inert (#1679).
    var shelfBorderOff: Bool { !settings.kiwishelf.border }

    // MARK: - Space Bar

    /// In-chip glyphs are native images and no front-app name renders
    /// (`SpaceBarOverlay+FrontApp`).
    var focusedItemInert: Bool {
        // Inert only where no screen draws the name (#1948).
        settings.screenVariants.allSatisfy { screen in
            let style = screen.spaceBarLook
            return !style.enabled
                || style.iconSource == .appImage
                    && !(style.showFrontApp && style.edge.isHorizontal)
        }
    }

    /// The front chip's indicator draws only while the segment
    /// does (#1856).
    var focusedHighlightInert: Bool {
        let style = settings.spaceBarLook
        return !style.enabled || !style.showFrontApp
    }
}

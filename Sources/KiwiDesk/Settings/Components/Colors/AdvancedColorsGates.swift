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

    /// Whether the unfocused row draws its remote reason as a
    /// link beneath the grid (#1310): only while the ring is on —
    /// off, the role links name the page instead.
    var unfocusedNeedsReference: Bool {
        borderOn && !unfocusedOn
    }

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

    // MARK: - Role groups (#1857)

    /// Whether any bar shows, so the shelf's colours draw.
    var shelfDraws: Bool {
        bars.containerReason(for: .kiwishelf) == nil
    }

    /// The destinations whose switches dim a row of a group, in
    /// the order the group lists them — each one link beneath
    /// the group (#1310), a row with its own sentence excepted.
    func dimmedDestinations(
        of keys: [SettingKey]
    ) -> [SettingsDestination] {
        var out: [SettingsDestination] = []
        for key in keys {
            guard let destination = genericReason(for: key),
                !out.contains(destination)
            else { continue }
            out.append(destination)
        }
        return out
    }

    /// Where the switch that dims `key` lives, for a row that
    /// takes the group's generic link; nil while the row draws,
    /// or where it names its own reason beneath the group.
    func genericReason(for key: SettingKey) -> SettingsDestination? {
        switch key {
        case .kiwishelf:
            return shelfDraws ? nil : .bars
        case .spaceBar(.spaceBarFocusedItemColor):
            // Bar on, the row's own sentence explains it.
            return shelfDraws ? nil : .bars
        case .spaceBar(.spaceBarFocusedHighlightColor):
            return !shelfDraws || focusedHighlightInert ? .bars : nil
        case .borders(.borderFocusedColor):
            return borderOn ? nil : .gapsAndBorders
        case .borders(.borderUnfocusedColor):
            return borderOn ? nil : .gapsAndBorders
        case .borders(.dragGhostBorderColor):
            return dragInert(ghost: true, fill: false)
                ? .gapsAndBorders : nil
        case .borders(.dragGhostFillColor):
            return dragInert(ghost: true, fill: true)
                ? .gapsAndBorders : nil
        case .borders(.dragDropZoneBorderColor):
            return dragInert(ghost: false, fill: false)
                ? .gapsAndBorders : nil
        case .borders(.dragDropZoneFillColor):
            return dragInert(ghost: false, fill: true)
                ? .gapsAndBorders : nil
        default:
            return nil
        }
    }

    // MARK: - KiwiShelf

    /// The shelf draws no border, so its colour is inert (#1679).
    var shelfBorderOff: Bool { !settings.kiwishelf.border }

    /// Whether the border row draws its remote reason as a link
    /// beneath the grid (#1310): only while a bar shows — with
    /// none, the header carries the outer reason.
    var shelfBorderNeedsReference: Bool {
        bars.containerReason(for: .kiwishelf) == nil && shelfBorderOff
    }

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

    /// Whether the focused-item row draws its remote reason as a
    /// link beneath the grid (#1310): only while the bar is on —
    /// off, the header carries the outer reason and the row is
    /// greyed for that.
    var focusedItemNeedsReference: Bool {
        bars.containerReason(for: .spaceBar) == nil
            && bars.containerReason(for: .kiwishelf) == nil
            && focusedItemInert
    }
}

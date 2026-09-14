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

    /// The Borders group's header reason, outermost first.
    var bordersHeaderHelp: String? {
        if !borderOn { return AdvancedColorsHelp.borderOff }
        if !unfocusedOn { return AdvancedColorsHelp.unfocusedOff }
        return nil
    }

    // MARK: - Drag visuals

    func dragVisual(_ ghost: Bool) -> DragVisual {
        ghost ? settings.dragGhost : settings.dragDropZone
    }

    /// Header explanation for a drag column (#527).
    func dragHeaderHelp(ghost: Bool) -> String? {
        let visual = dragVisual(ghost)
        if !visual.enabled { return AdvancedColorsHelp.dragOff }
        let reasons = [
            visual.border ? nil : AdvancedColorsHelp.dragBorderOff,
            visual.fill ? nil : AdvancedColorsHelp.dragFillOff,
        ]
        .compactMap { $0 }
        return reasons.isEmpty
            ? nil : reasons.joined(separator: "\n")
    }

    // MARK: - Space Bar

    /// In-chip glyphs are native images and no front-app name renders
    /// (`SpaceBarOverlay+FrontApp`).
    var focusedItemInert: Bool {
        let style = settings.spaceBarStyle
        return style.iconSource == .appImage
            && !(style.showFrontApp && style.edge.isHorizontal)
    }

    /// Whether the focused-item row draws its remote reason as a
    /// link beneath the grid (#1310): only while the bar is on —
    /// off, the header carries the outer reason and the row is
    /// greyed for that.
    var focusedItemNeedsReference: Bool {
        bars.containerReason(for: .spaceBar) == nil && focusedItemInert
    }
}

/// Explanatory strings for disabled swatches across destinations
/// (`SourceScan.interpolatingFrames`, `InterpolatedLabelTests.converted`).
/// Only the TITLE is derived — which destination owns each gate
/// is chosen by hand below, and no map can derive it (an area is
/// not a destination; one area spans two). So the obligation:
/// moving a gating control to another destination updates the
/// sentence that points at it, in the same change set — nothing
/// here reds when it does not.
@MainActor
enum AdvancedColorsHelp {
    static var borderOff: String {
        L(
            "colors.border_off.help",
            "The focus border is off, so its two colors aren't "
                + "drawn. Turn it on in %1$@.",
            SettingsDestination.gapsAndBorders.title
        )
    }

    static var unfocusedOff: String {
        L(
            "colors.unfocused_off.help",
            "Unfocused windows get no border, so this color "
                + "isn't drawn. Turn it on in %1$@.",
            SettingsDestination.gapsAndBorders.title
        )
    }

    static var dragOff: String {
        L(
            "colors.drag_off.help",
            "This drag visual is off, so its colors aren't "
                + "drawn. Turn it on in %1$@.",
            SettingsDestination.gapsAndBorders.title
        )
    }

    static var dragBorderOff: String {
        L(
            "colors.drag_border_off.help",
            "This visual draws no border. Turn Border on in "
                + "%1$@.",
            SettingsDestination.gapsAndBorders.title
        )
    }

    static var dragFillOff: String {
        L(
            "colors.drag_fill_off.help",
            "This visual draws no fill. Turn Fill on in %1$@.",
            SettingsDestination.gapsAndBorders.title
        )
    }

    static var spaceBarOff: String {
        L(
            "colors.space_bar_off.help",
            "The Space Bar is off, so its colors aren't drawn. "
                + "Turn it on in %1$@.",
            SettingsDestination.bars.title
        )
    }

    /// The focused-item row's remote gate, as the sentence a
    /// `CrossReferenceRow` links to Bars (#1310): the row, the
    /// control, its value and the value to set, every label by
    /// its own key (#818); `%5$@` is the link slot.
    static var focusedItemReference: String {
        L(
            "colors.focused_item_inert.xref",
            "\u{201C}%1$@\u{201D} tints nothing while "
                + "\u{201C}%2$@\u{201D} is \u{201C}%3$@\u{201D} — set "
                + "it to \u{201C}%4$@\u{201D} in %5$@.",
            L("space_bar.color.focused_item", "Focused window"),
            L("space_bar.icon_source.label", "App symbol style"),
            L("app_bar.icon_source.app_image", "System default"),
            L("app_bar.icon_source.app_font", "Glyphs"),
            CrossReferenceRow.linkSlot
        )
    }

    /// App Bar off explanatory string (#705, #818).
    static var appBarOff: String {
        L(
            "colors.app_bar_off.help",
            "No layout shows an App Bar, so its colors aren't "
                + "drawn. In %1$@, turn a layout's App Bar on "
                + "under “%2$@”.",
            SettingsDestination.bars.title,
            L("bars.show_in.title", "Show it in")
        )
    }
}

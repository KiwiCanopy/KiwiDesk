import KiwiDeskCore
import SwiftUI

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
            "This visual draws no border. Turn %1$@ on in %2$@.",
            L("drag.border", "Border"),
            SettingsDestination.gapsAndBorders.title
        )
    }

    static var dragFillOff: String {
        L(
            "colors.drag_fill_off.help",
            "This visual draws no fill. Turn %1$@ on in %2$@.",
            L("drag.fill", "Fill"),
            SettingsDestination.gapsAndBorders.title
        )
    }

    /// The unfocused row's remote gate, as the sentence a
    /// `CrossReferenceRow` links to Gaps & Borders (#1310): the
    /// row and the switch by their own keys (#818); `%3$@` is the
    /// link slot.
    static var unfocusedReference: String {
        L(
            "colors.unfocused_off.xref",
            "\u{201C}%1$@\u{201D} isn't drawn while "
                + "\u{201C}%2$@\u{201D} is off — turn it on in %3$@.",
            L("border.color.unfocused", "Unfocused windows"),
            L(
                "border.unfocused_enabled",
                "Show border on unfocused windows"
            ),
            CrossReferenceRow.linkSlot
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
            L("kiwishelf.icon_source.label", "App glyph style"),
            L("app_bar.icon_source.app_image", "App icons"),
            L("app_bar.icon_source.app_font", "Symbols"),
            CrossReferenceRow.linkSlot
        )
    }

    /// The front-app indicator row's hover reason (#1856): the
    /// switch by its own key, on the page that holds it (#818).
    static var frontAppOff: String {
        L(
            "colors.front_app_off.help",
            "No front-app segment draws, so its indicator isn't "
                + "drawn. Turn on \u{201C}%1$@\u{201D} in %2$@.",
            L("space_bar.show_front_app", "Show front app"),
            SettingsDestination.bars.title
        )
    }

    /// The border row's hover reason (#1679): the switch by its
    /// own key, on the page that holds it (#818).
    static var shelfBorderOff: String {
        L(
            "colors.kiwishelf_border_off.help",
            "The border is off, so its color isn't drawn. Turn on "
                + "\u{201C}%1$@\u{201D} in %2$@.",
            L("kiwishelf.border", "Border"),
            SettingsDestination.bars.title
        )
    }

    /// The border row's remote gate, as the sentence a
    /// `CrossReferenceRow` links to Bars (#1310): the switch by
    /// its own key (#818); `%2$@` is the link slot.
    static var shelfBorderReference: String {
        L(
            "colors.kiwishelf_border_off.xref",
            "The border color isn't drawn while "
                + "\u{201C}%1$@\u{201D} is off — turn it on in "
                + "%2$@.",
            L("kiwishelf.border", "Border"),
            CrossReferenceRow.linkSlot
        )
    }

    /// A role group's link for its dimmed rows (#1857, #1310):
    /// each row's own reason is its hover text, so the link names
    /// only the page; `%1$@` is the link slot.
    static var dimmedReference: String {
        L(
            "colors.dimmed.xref",
            "Dimmed colors here aren't drawn right now — turn on "
                + "what they color in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    /// The icon mode is INTERPOLATED from the picker entry's own
    /// key rather than named as text (#818) — this help lives on
    /// another page than the picker it names, which is exactly
    /// where a hand-typed label drifts unnoticed.
    static var focusedItemHelp: String {
        L(
            "space_bar.color.focused_item.help",
            "Tints the focused window — its glyph in the active "
                + "Space and the front-app segment. Glyph tint "
                + "needs \u{201C}%2$@\u{201D} set to "
                + "\u{201C}%1$@\u{201D}.",
            L("app_bar.icon_source.app_font", "Symbols"),
            L("kiwishelf.icon_source.label", "App glyph style")
        )
    }
}

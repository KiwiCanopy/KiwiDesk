import KiwiDeskCore
import SwiftUI

/// The Space Bar card's multi-line row builders, split from
/// `SpaceBarCard+Rows.swift` for the file ceiling. Internal
/// (not private) only because the `row(for:)` switch lives in
/// the sibling extension file.
extension SpaceBarCard {
    /// Front-app segment title length (#171, #818, #901, #937,
    /// renamed by #1517). Greys on the toggle alone: vertical
    /// bars announce the name via AX even when not drawn.
    @ViewBuilder var titleCapRow: some View {
        StepperRow(
            label: L(
                "space_bar.front_app_title_cap",
                "Front app title length"
            ),
            value: style.frontAppTitleCap,
            in: AppBarStyle.titleCapRange,
            help: L(
                "space_bar.front_app_title_cap.help",
                "How many characters of the focused window's "
                    + "title the front-app segment shows before it "
                    + "is shortened."
            )
        )
        .modifier(
            GreyOut(
                active: !style.wrappedValue.showFrontApp,
                help: L(
                    "space_bar.title_cap.front_app_only",
                    "Only \u{201C}%1$@\u{201D} draws a title.",
                    L(
                        "space_bar.show_front_app",
                        "Show front app"
                    )
                )
            )
        )
    }

    /// The Other Spaces `?` (#1683): each segment's own label
    /// interpolated, so the prose cannot drift from it (#818).
    var inactiveContentHelp: String {
        L(
            "space_bar.inactive_content.help",
            "What the Spaces not on screen show. %1$@ — their app "
                + "glyphs. %2$@ — just each Space's number, name or "
                + "icon, with how many windows it holds on its "
                + "corner. Either way an empty Space draws dimmer, "
                + "except a color emoji icon, which cannot dim.",
            L("space_bar.inactive_content.apps", "Apps"),
            L("space_bar.inactive_content.count", "Window count")
        )
    }

    /// The Space label `?` (#1535), its segments interpolated
    /// like the Other Spaces one above.
    var itemLabelHelp: String {
        L(
            "space_bar.item_label.help",
            "What names each Space on the bar. %1$@ — its icon, "
                + "else its number or name. %2$@ — the symbol of "
                + "the layout it uses now, as the menu bar shows "
                + "it. VoiceOver still reads the Space's name.",
            L("space_bar.item_label.identifier", "Name or icon"),
            L("space_bar.item_label.layout", "Layout")
        )
    }

    /// Glyphs per Space stepper (#94).
    @ViewBuilder var glyphCapRow: some View {
        StepperRow(
            label: L("space_bar.glyph_cap", "Glyphs per Space"),
            value: style.glyphCap,
            in: SpaceBarStyle.glyphCapRange,
            help: L(
                "space_bar.glyph_cap.help",
                "How many app glyphs a Space shows before the "
                    + "rest collapse into a +n badge. Adjacent "
                    + "windows of the same app count as one glyph."
            )
        )
    }
}

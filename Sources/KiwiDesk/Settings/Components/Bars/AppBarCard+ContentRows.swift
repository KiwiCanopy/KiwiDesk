import KiwiDeskCore
import SwiftUI

/// The App Bar card's three content rows: what an item draws
/// (`contentRow`), how much of a title it may draw
/// (`titleCapRow`), and how its icon is drawn
/// (`iconSourceRow`). Split from AppBarCard+Rows.swift at the
/// §2.1 ceiling — the shape `SpaceBarCard+RowHelpers.swift`
/// already uses on the other card.
///
/// The three travel together rather than by line count: each one
/// greys on a gate the other two decide. Icon-only content
/// silences the title cap; title-only content silences the icon
/// style; and a vertical bar, which renders icon-only whatever
/// is stored, silences both.
extension AppBarCard {
    var contentRow: some View {
        SegmentedPicker(
            L("app_bar.content.label", "Content"),
            selection: style.content,
            options: AppBarOptions.content.map { ($0.1, $0.0) }
        )
        .modifier(
            GreyOut(
                // Vertical bars render icon-only (names would
                // need stacked or rotated text) — the stored
                // preference survives an edge round-trip.
                active: gates.everyShownBarVertical,
                help: L(
                    "app_bar.content.vertical_only",
                    "Left and right bars always show icons "
                        + "only."
                )
            )
        )
    }

    /// How much of a window title an item shows, directly
    /// below the Content control it depends on. Deliberately
    /// NOT greyed under icon-only content (#937): an icon-only
    /// or vertical bar draws no title but its items still
    /// ANNOUNCE the capped title (`AppBarItemView`'s
    /// accessibility label), so the knob is live on every
    /// content — the same reasoning the Space Bar twin's
    /// asymmetry note reserved for the day #901 gave items an
    /// accessible name, which it since has.
    var titleCapRow: some View {
        StepperRow(
            label: L("app_bar.title_cap", "Title length"),
            value: style.titleCap,
            in: AppBarStyle.titleCapRange,
            help: L(
                "app_bar.title_cap.help",
                "How many characters of a window's title an "
                    + "item shows before it is shortened. "
                    + "Grouped windows show their app's name "
                    + "instead, which is never shortened."
            )
        )
    }

    /// #294 icon rendering, directly below the Content control
    /// it depends on; greyed (never hidden, #171) when
    /// title-only content shows no icons at all. Census-exempt from the
    /// container gate: the ⌃⌥K panel's Apps band reads this
    /// whether or not any bar renders.
    var iconSourceRow: some View {
        DropdownRow(
            label: L("app_bar.icon_source.label", "App symbol style"),
            // Five labels INTERPOLATED from their own keys, not
            // re-typed (#818): the mode, the three colour rows
            // this sentence sends the reader to, and the page
            // they are on. The rows are NOT below — they render
            // at `.row(.advancedColours, .appBar, .showMore)`,
            // all three Power-User-only — so the sentence
            // names the destination instead of saying "below",
            // which sent the reader looking down this card.
            help: L(
                "app_bar.icon_source.help",
                "How app icons are drawn. "
                    + "\u{201C}%1$@\u{201D} shows a "
                    + "monochrome symbol from KiwiDesk's "
                    + "built-in icon set, colored by the bar's "
                    + "item colors — %2$@, %3$@ and %4$@, in "
                    + "%5$@ — so those colors also "
                    + "decide how the glyphs look. Apps "
                    + "without a symbol keep their app icon.",
                L("app_bar.icon_source.app_font", "Glyphs"),
                L("app_bar.color.item", "Item"),
                L("app_bar.color.active_item", "Active item"),
                L("app_bar.color.hover_item", "Hover item"),
                SettingsDestination.advancedColors.title
            )
        ) {
            Picker(
                L("app_bar.icon_source.label", "App symbol style"),
                selection: style.iconSource
            ) {
                ForEach(
                    AppBarOptions.iconSource,
                    id: \.0
                ) { option in
                    Text(option.1).tag(option.0)
                }
            }
        }
        .modifier(
            GreyOut(
                // Gate on the RENDERED content: a vertical bar
                // collapses Title to icon-only, so icons are on
                // screen and this control must stay live.
                active: gates.everyShownBarTitleOnly,
                // Both labels INTERPOLATED from their own keys,
                // not re-typed (#818).
                help: L(
                    "app_bar.icon_source.title_only",
                    "Icons are hidden while \u{201C}%1$@\u{201D} "
                        + "is \u{201C}%2$@\u{201D}.",
                    L("app_bar.content.label", "Content"),
                    L("app_bar.content.title", "Title")
                )
            )
        )
    }
}

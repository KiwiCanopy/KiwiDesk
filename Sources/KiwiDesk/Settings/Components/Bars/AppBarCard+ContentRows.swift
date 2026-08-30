import KiwiDeskCore
import SwiftUI

/// Content configuration rows for AppBarCard: content, title cap, icon style.
extension AppBarCard {
    var contentRow: some View {
        SegmentedPicker(
            L("app_bar.content.label", "Content"),
            selection: style.content,
            options: AppBarOptions.content.map { ($0.1, $0.0) }
        )
        .modifier(
            GreyOut(
                active: gates.everyShownBarVertical,
                help: L(
                    "app_bar.content.vertical_only",
                    "Left and right bars always show icons "
                        + "only."
                )
            )
        )
    }

    /// Window title character length cap (#901, #937).
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

    /// App icon rendering dropdown (#171, #294, #818).
    var iconSourceRow: some View {
        DropdownRow(
            label: L("app_bar.icon_source.label", "App symbol style"),
            spokenValue: AppBarOptions.iconSourceTitle(
                style.iconSource.wrappedValue
            ),
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
                active: gates.everyShownBarTitleOnly,
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

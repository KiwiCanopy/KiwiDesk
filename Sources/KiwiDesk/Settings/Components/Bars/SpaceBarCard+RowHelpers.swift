import KiwiDeskCore
import SwiftUI

/// The Space Bar card's multi-line row builders, split from
/// `SpaceBarCard+Rows.swift` for the file ceiling. Internal
/// (not private) only because the `row(for:)` switch lives in
/// the sibling extension file.
extension SpaceBarCard {
    /// Space Bar enable toggle (#678, `StickyMarkEditor`).
    var showToggle: some View {
        ToggleRow(
            label: L("space_bar.enabled", "Show Space Bar"),
            isOn: style.enabled,
            help: L(
                "space_bar.enabled.help",
                "One bar per display listing that "
                    + "display's Spaces — click a Space to "
                    + "switch to it. The bar reserves its "
                    + "edge in every layout."
            )
        )
    }

    /// Position plus the shared-edge info row directly under it (#374).
    @ViewBuilder var edgeRow: some View {
        SegmentedPicker(
            L("space_bar.edge.label", "Position"),
            selection: style.edge,
            options: AppBarOptions.edge.map { ($0.1, $0.0) },
            help: L(
                "space_bar.edge.label.help",
                "Which screen edge the Space Bar occupies. "
                    + "Sharing an edge with the App Bar is "
                    + "fine — the two stack."
            )
        )
        if model.config.settings.spaceBarSharesEdgeWithAppBar {
            BarSameEdgeRow(edge: style.wrappedValue.edge)
        }
    }

    var backgroundFitRow: some View {
        SegmentedPicker(
            L(
                "space_bar.background_fit.label",
                "Background size"
            ),
            selection: style.backgroundFit,
            options: AppBarOptions.backgroundFit
                .map { ($0.1, $0.0) }
        )
        .modifier(
            GreyOut(
                // Inert when Boxed (#660, #818).
                active: style.wrappedValue.backgroundStyle
                    == .boxed,
                help: L(
                    "space_bar.background_fit.boxed_only",
                    "\u{201C}%1$@\u{201D} draws a box per item, "
                        + "not a shared plate, so there is "
                        + "nothing to size.",
                    L("app_bar.background_style.boxed", "Boxed")
                )
            )
        )
    }

    var iconSourceRow: some View {
        DropdownRow(
            label: L(
                "space_bar.icon_source.label",
                "App symbol style"
            ),
            spokenValue: AppBarOptions.iconSourceTitle(
                style.iconSource.wrappedValue
            ),
            // Interpolated labels (#818).
            help: L(
                "space_bar.icon_source.help",
                "How app glyphs are drawn. "
                    + "\u{201C}%1$@\u{201D} shows a "
                    + "monochrome symbol colored by the bar's "
                    + "item colors, set in %2$@; apps without a "
                    + "symbol keep their app icon.",
                L("app_bar.icon_source.app_font", "Glyphs"),
                SettingsDestination.advancedColors.title
            )
        ) {
            Picker(
                L(
                    "space_bar.icon_source.label",
                    "App symbol style"
                ),
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
    }

    /// Front segment title length cap (#171, #818, #901, #937,
    /// `SettingKey+SpaceBar`, `SpaceBarOverlay+FrontApp`).
    @ViewBuilder var titleCapRow: some View {
        StepperRow(
            label: L("space_bar.title_cap", "Title length"),
            value: style.titleCap,
            in: AppBarStyle.titleCapRange,
            help: L(
                "space_bar.title_cap.help",
                "How many characters of the focused window's "
                    + "title the front segment shows before it "
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

    /// Glyphs per Space stepper and live summary (#94).
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
        Text(
            L(
                "space_bar.glyph_cap.summary",
                "Up to %1$d app groups per Space; more collapse "
                    + "into a +n badge.",
                style.wrappedValue.resolvedGlyphCap
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

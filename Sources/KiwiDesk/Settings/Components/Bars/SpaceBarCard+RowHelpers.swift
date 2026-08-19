import KiwiDeskCore
import SwiftUI

/// The Space Bar card's multi-line row builders, split from
/// `SpaceBarCard+Rows.swift` for the file ceiling. Internal
/// (not private) only because the `row(for:)` switch lives in
/// the sibling extension file.
extension SpaceBarCard {
    /// A plain binding. It wrote `stickyStyle.mark = true`
    /// through on the way off until #678 Phase 3, to back the
    /// sticky-mark toggle's forced-ON greying; that gate is gone
    /// (`StickyMarkEditor`), and with it the only reason this
    /// switch had to reach into another setting.
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

    /// Position plus the shared-edge info row directly under it
    /// (#374) — the App Bar card shows the same row.
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
                // Boxed never draws a shared plate to size —
                // glass hugs each box, solid draws each box — so
                // fit is inert for Boxed regardless of the glass
                // finish. Plain (the shipped default, #660)
                // un-greys it.
                active: style.wrappedValue.backgroundStyle
                    == .boxed,
                // Style name INTERPOLATED from the picker entry's
                // own key, not re-typed (#818).
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
            // Two labels INTERPOLATED from their own keys, not
            // re-typed (#818): the picker entry, and the page
            // the item colours this sentence names are edited
            // on. The App Bar twin already named that page; this
            // one said "the bar's item colors" and pointed
            // nowhere, so the reader had no way to reach them.
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

    /// The front segment's title length — the only text the
    /// Space Bar draws, so the knob is inert while that segment
    /// is off. Greyed rather than hidden (#171), pairing the
    /// census gate `SettingKey+SpaceBar` declares with a live
    /// `GreyOut`, as `backgroundFitRow` above does.
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
                // Toggle name INTERPOLATED from its own key,
                // not re-typed (#818).
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

    /// The stepper plus a neutral live summary of the current
    /// cap — a caption that states what shows, not why (#94
    /// defers the why to `help`). The preview strip is a fixed
    /// stand-in and cannot honestly render N synthetic glyphs,
    /// so the fact lives here.
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

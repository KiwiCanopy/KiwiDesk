import KiwiDeskCore
import SwiftUI

/// The Space Bar editor (#293), behind the Bars switch. Row
/// order follows the canonical bar-editor shape (#374, App
/// Bar is the reference): preview, Show, Position (+ same-
/// edge row), item-look (background, indicator, symbol
/// style), content toggles, sizes, colors. All settings are
/// global — the bar is layout-independent, so there is no
/// per-layout override tier here.
struct SpaceBarEditorGroup: View {
    @ObservedObject var model: SettingsModel

    var style: Binding<SpaceBarStyle> {
        $model.config.settings.spaceBarStyle
    }

    var body: some View {
        SettingsSection(
            L("space_bar.global_style.title", "Space Bar style")
        ) {
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            SpaceBarPreviewStrip(
                style: style.wrappedValue,
                appBar: model.config.settings.appBarStyle,
                sameEdge: model.config.settings
                    .spaceBarSharesEdgeWithAppBar
            )
            // Coverage-guard write-through (#414): hiding
            // the bar makes the on-window mark the ONLY
            // sticky indicator, so its greyed "forced ON"
            // toggle in Appearance must be the real stored
            // state, not a display fiction. A write-through
            // BINDING, not .onChange: the set fires only on
            // the user's gesture, so a profile load that
            // replaces the model's config while this section
            // is open cannot overwrite a Lua-authored
            // indicator=false (Lua stays unclamped).
            ToggleRow(
                label: L("space_bar.enabled", "Show Space Bar"),
                isOn: Binding(
                    get: { style.wrappedValue.enabled },
                    set: { on in
                        style.wrappedValue.enabled = on
                        if !on {
                            model.config.settings
                                .stickyStyle.mark = true
                        }
                    }
                ),
                help: L(
                    "space_bar.enabled.help",
                    "One bar per display listing that "
                        + "display's Spaces — click a Space to "
                        + "switch to it. The bar reserves its "
                        + "edge in every layout."
                )
            )
            // Everything below configures a bar that isn't
            // drawn while the switch above is off — greyed,
            // never hidden (#171/#520). The precedent is three
            // files away: FocusBorderEditor greys its whole
            // block off its own enable toggle.
            behavior
                .modifier(GreyOut(active: !enabled, help: offHelp))
            appearance
                .modifier(GreyOut(active: !enabled, help: offHelp))
        }
        SettingsSection(
            L("space_bar.colors.title", "Space Bar colors")
        ) {
            SpaceBarColorsGroup(model: model)
                .modifier(GreyOut(active: !enabled, help: offHelp))
        }
    }

    var enabled: Bool { style.wrappedValue.enabled }

    /// Nested `GreyOut`s multiply their 0.5 opacity to 0.25, so
    /// every inner gate in this editor is written `enabled && …`
    /// — the block gate already covers the bar-is-off case.
    /// Keep that conjunction when adding one.
    var offHelp: String {
        L(
            "space_bar.disabled.help",
            "Turn on Show Space Bar to edit these settings."
        )
    }

    // MARK: - Behavior

    @ViewBuilder private var behavior: some View {
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
        sameEdgeRow
        SegmentedPicker(
            L("space_bar.alignment.label", "Alignment"),
            selection: style.alignment,
            options: AppBarOptions.alignment
                .map { ($0.1, $0.0) },
            help: L(
                "space_bar.alignment.label.help",
                "Where the Space items — and the front-app "
                    + "segment, when shown — sit along the "
                    + "bar. Start and End follow the edge — a "
                    + "left bar's Start is its top."
            )
        )
        SegmentedPicker(
            L(
                "space_bar.background_style.label",
                "Background style"
            ),
            selection: style.backgroundStyle,
            options: AppBarOptions.backgroundStyle
                .map { ($0.1, $0.0) }
        )
        // Liquid Glass finish — offered only on macOS 26+ (#390).
        if AppBarStyle.glassAvailable {
            ToggleRow(
                label: L("app_bar.liquid_glass", "Liquid Glass"),
                isOn: style.liquidGlass,
                help: L(
                    "app_bar.liquid_glass.help",
                    "Lays a translucent glass material over the "
                        + "boxes or the plate. The Fill color tints "
                        + "it, though the tint reads subtle on "
                        + "current macOS."
                )
            )
        }
        // Directly below the background it sizes (topic
        // grouping); greyed for Boxed, which draws no shared
        // plate (#171).
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
                // Boxed never draws a shared plate to size — glass
                // hugs each box, solid draws each box — so fit is
                // inert for Boxed regardless of the glass finish.
                active: style.wrappedValue.backgroundStyle
                    == .boxed,
                help: L(
                    "space_bar.background_fit.boxed_only",
                    "Boxed draws a box per item, not a shared "
                        + "plate, so there is nothing to size."
                )
            )
        )
        SegmentedPicker(
            L(
                "space_bar.active_indicator.label",
                "Active indicator"
            ),
            selection: style.activeIndicator,
            // No `.gap` here: an empty slot marking the active
            // Space reads as a missing Space, not a highlight
            // (QA 2026-07-19). The App Bar keeps it (an empty
            // window slot is legible there).
            options: AppBarOptions.activeIndicator
                .filter { $0.0 != .gap }
                .map { ($0.1, $0.0) }
        )
        DropdownRow(
            label: L(
                "space_bar.icon_source.label",
                "App symbol style"
            ),
            help: L(
                "space_bar.icon_source.help",
                "How app glyphs are drawn. Glyphs shows a "
                    + "monochrome symbol colored by the bar's "
                    + "item colors; apps without a symbol keep "
                    + "their app icon."
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
        ToggleRow(
            label: L(
                "space_bar.hide_empty",
                "Hide empty Spaces"
            ),
            isOn: style.hideEmpty,
            help: L(
                "space_bar.hide_empty.help",
                "Spaces with no windows are hidden from the "
                    + "bar, except the Space you're currently "
                    + "on. Use a shortcut to jump to a hidden "
                    + "Space."
            )
        )
        ToggleRow(
            label: L(
                "space_bar.show_front_app",
                "Show front app"
            ),
            isOn: style.showFrontApp,
            help: L(
                "space_bar.show_front_app.help",
                "Adds a trailing segment with the focused "
                    + "window of the Space each display "
                    + "currently shows. Icon-only on vertical "
                    + "bars."
            )
        )
        SecondsRow(
            label: L("space_bar.spring_delay", "Spring delay"),
            ms: style.springDelay,
            range: 1.0...4.0,
            help: L(
                "space_bar.spring_delay.help",
                "Drag a window onto a Space and hold this long "
                    + "for the view to spring to that Space, so "
                    + "you can drop the window into its layout. A "
                    + "quicker drop moves the window there "
                    + "without switching."
            )
        )
    }

    /// Gate stays here (needs the model); chrome and text are
    /// the shared `BarSameEdgeRow` (#374) — App Bar's editor
    /// shows the same row.
    @ViewBuilder private var sameEdgeRow: some View {
        if model.config.settings.spaceBarSharesEdgeWithAppBar {
            BarSameEdgeRow(edge: style.wrappedValue.edge)
        }
    }

    /// Neutral live summary of the current cap — a caption that
    /// states what shows, not why (#94 defers the why to `help`).
    /// The preview strip is a fixed stand-in and cannot honestly
    /// render N synthetic glyphs, so the fact lives here.
    var glyphCapSummary: some View {
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

    private var caption: String {
        L(
            "space_bar.global_style.caption",
            "One bar per display, every layout. All settings "
                + "are global."
        )
    }
}

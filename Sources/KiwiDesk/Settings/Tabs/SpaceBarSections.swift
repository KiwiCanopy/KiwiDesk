import KiwiDeskCore
import SwiftUI

/// The Space Bar editor (#293), behind the Bars switch. Order
/// per the issue: preview, Show, Position, sizes + icon source,
/// tab treatment + indicator, colors. All settings are global —
/// the bar is layout-independent, so there is no per-layout
/// override tier here.
struct SpaceBarEditorSection: View {
    @ObservedObject var model: SettingsModel

    var style: Binding<SpaceBarStyle> {
        $model.config.settings.spaceBarStyle
    }

    var body: some View {
        SettingsSection(
            L("space_bar.global_style.title", "Global style")
        ) {
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            SpaceBarPreviewStrip(
                style: style.wrappedValue,
                appBar: model.config.settings.appBarStyle
            )
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
            behavior
            appearance
            copyAppearance
        }
        SettingsSection(
            L("space_bar.colors.title", "Space Bar colors")
        ) {
            accentLadder
            AppBarColorGrid { otherColors }
        }
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
    }

    /// The neutral same-edge explainer (#293): shown only when
    /// both *enabled* bars resolve to the same edge — never a
    /// warning, never a popup.
    @ViewBuilder private var sameEdgeRow: some View {
        if style.wrappedValue.enabled,
            style.wrappedValue.edge
                == model.config.settings.appBarStyle.edge
        {
            Label {
                Text(sameEdgeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sameEdgeText: String {
        let edge =
            AppBarOptions.edge.first {
                $0.0 == style.wrappedValue.edge
            }?.1 ?? ""
        return L(
            "space_bar.same_edge",
            "Both bars share the %1$@ edge — Space Bar sits "
                + "at the screen edge, App Bar sits next to "
                + "the windows.",
            edge
        )
    }

    // MARK: - Appearance

    @ViewBuilder private var appearance: some View {
        PtSlider(
            label: L("space_bar.thickness", "Thickness"),
            value: style.thickness,
            range: 8...80
        )
        AutoGatedGroup(
            title: L(
                "space_bar.item_size.auto",
                "Auto item size"
            ),
            isOn: AppBarAuto.binding(
                style.itemSize,
                restore: 120
            )
        ) {
            PtSlider(
                label: L("space_bar.item_size", "Item size"),
                value: style.itemSize,
                range: 0...200
            )
        }
        PtSlider(
            label: L("space_bar.item_gap", "Item gap"),
            value: style.itemGap,
            range: 0...40
        )
        AutoGatedGroup(
            title: L(
                "space_bar.font_size.auto",
                "Auto font size"
            ),
            isOn: AppBarAuto.binding(style.fontSize, restore: 14)
        ) {
            PtSlider(
                label: L("space_bar.font_size", "Font size"),
                value: style.fontSize,
                range: 0...32
            )
        }
        DropdownRow(
            label: L(
                "space_bar.icon_source.label",
                "App symbol style"
            ),
            help: L(
                "space_bar.icon_source.help",
                "How app glyphs are drawn. Glyphs shows a "
                    + "monochrome symbol colored by the bar's "
                    + "text colors; apps without a symbol keep "
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
        Divider()
        SegmentedPicker(
            L("space_bar.tab_background.label", "Item background"),
            selection: style.tabBackground,
            options: AppBarOptions.tabBackground
                .map { ($0.1, $0.0) }
        )
        SegmentedPicker(
            L(
                "space_bar.active_indicator.label",
                "Active indicator"
            ),
            selection: style.activeIndicator,
            options: AppBarOptions.activeIndicator
                .map { ($0.1, $0.0) }
        )
        PtSlider(
            label: L(
                "space_bar.corner_roundness",
                "Corner roundness"
            ),
            value: style.cornerRoundness,
            range: 0...100,
            unit: "%"
        )
        .modifier(
            GreyOut(
                active: style.wrappedValue.tabBackground
                    != .boxed,
                help: L(
                    "space_bar.corner_roundness.boxed_only",
                    "Corner roundness only applies to Boxed "
                        + "items."
                )
            )
        )
    }

    /// One-shot copy, then fully independent — never a live
    /// inherit. Excludes enabled and edge (visibility and
    /// placement are not appearance).
    private var copyAppearance: some View {
        Button {
            model.config.settings.spaceBarStyle
                .copyAppearance(
                    from: model.config.settings.appBarStyle
                )
        } label: {
            Text(
                L(
                    "space_bar.copy_appearance",
                    "Copy App Bar appearance…"
                )
            )
        }
        .help(
            L(
                "space_bar.copy_appearance.help",
                "Takes the App Bar's current sizes, style, "
                    + "and colors once; edits afterwards stay "
                    + "independent."
            )
        )
    }

    private var caption: String {
        L(
            "space_bar.global_style.caption",
            "One bar per display, every layout. All settings "
                + "are global."
        )
    }
}

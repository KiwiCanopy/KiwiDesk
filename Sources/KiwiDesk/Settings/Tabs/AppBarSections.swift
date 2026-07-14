import KiwiDeskCore
import SwiftUI

// The App Bar sections are hosted by AppearanceSection (#68
// §3.2): the global look shared by every layout's bar, then a
// per-layout section for each layout that can show one
// (monocle, scrolling). A layout's checkbox toggles its bar
// on; while on, an accordion exposes per-field overrides
// (unchecked rows inherit the global value shown grayed out).

/// The global `app_bar.*` look every layout inherits.
struct GlobalAppBarSection: View {
    @Binding var style: AppBarStyle

    var body: some View {
        SettingsSection(
            L("app_bar.global_style.title", "Global style")
        ) {
            Text(globalStyleCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            // #125 Phase 2: the live mock strip sits above the
            // controls, GapsDiagram-style, so a color/size edit
            // is judged in place before Save.
            AppBarPreviewStrip(style: style)
            behavior
            appearance
        }
        SettingsSection(
            L("app_bar.global_colors.title", "Global colors")
        ) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading),
                ],
                alignment: .leading,
                spacing: 8
            ) {
                colors
            }
        }
    }

    @ViewBuilder private var behavior: some View {
        DropdownRow(label: positionLabel) {
            Picker(positionLabel, selection: $style.position) {
                ForEach(AppBarOptions.position, id: \.0) {
                    Text($0.1).tag($0.0)
                }
            }
        }
        DropdownRow(label: styleLabel) {
            Picker(styleLabel, selection: $style.style) {
                ForEach(AppBarOptions.style, id: \.0) {
                    Text($0.1).tag($0.0)
                }
            }
        }
        DropdownRow(label: activeItemLabel) {
            Picker(
                activeItemLabel,
                selection: $style.activeStyle
            ) {
                ForEach(AppBarOptions.activeStyle, id: \.0) {
                    Text($0.1).tag($0.0)
                }
            }
        }
        DropdownRow(label: contentLabel) {
            Picker(contentLabel, selection: $style.content) {
                ForEach(AppBarOptions.content, id: \.0) {
                    Text($0.1).tag($0.0)
                }
            }
        }
        Toggle(
            L(
                "app_bar.group_adjacent",
                "Group adjacent same-app windows"
            ),
            isOn: $style.groupAdjacentWindows
        )
    }

    @ViewBuilder private var appearance: some View {
        PtSlider(
            label: L("app_bar.thickness", "Thickness"),
            value: $style.thickness,
            range: 8...80
        )
        PtSlider(
            label: L("app_bar.item_size", "Item size"),
            value: $style.itemSize,
            range: 0...200
        )
        PtSlider(
            label: L("app_bar.item_gap", "Item gap"),
            value: $style.itemGap,
            range: 0...40
        )
        PtSlider(
            label: L("app_bar.font_size", "Font size"),
            value: $style.fontSize,
            range: 0...32
        )
        // Corner radius only rounds Pills (segments are always
        // square; underline rounds only its transient hover box).
        // Grey it out otherwise — the "grey, don't hide"
        // convention (#171) — so it never reads as a no-op knob.
        PtSlider(
            label: L("app_bar.corner_radius", "Corner radius"),
            value: $style.cornerRadius,
            range: 0...40
        )
        .disabled(style.style != .pills)
        .opacity(style.style == .pills ? 1 : 0.5)
        .help(
            style.style == .pills
                ? ""
                : L(
                    "app_bar.corner_radius.pills_only",
                    "Corner radius only applies to the Pills "
                        + "style."
                )
        )
    }

    @ViewBuilder private var colors: some View {
        Group {
            HexColorField(
                label: L("app_bar.color.text", "Text"),
                hex: $style.textColor
            )
            HexColorField(
                label: L("app_bar.color.box", "Box"),
                hex: $style.boxColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.active_text",
                    "Active text"
                ),
                hex: $style.activeTextColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.active_box",
                    "Active box"
                ),
                hex: $style.activeBoxColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.highlight",
                    "Highlight"
                ),
                hex: $style.highlightColor
            )
            HexColorField(
                label: L("app_bar.color.hover", "Hover"),
                hex: $style.hoverColor
            )
        }
        Group {
            HexColorField(
                label: L(
                    "app_bar.color.hover_text",
                    "Hover text"
                ),
                hex: $style.hoverTextColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.background",
                    "Background"
                ),
                hex: $style.backgroundColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.group_badge",
                    "Group badge"
                ),
                hex: $style.groupBadgeColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.badge_text",
                    "Badge text"
                ),
                hex: $style.groupBadgeTextColor
            )
        }
    }

    private var globalStyleCaption: String {
        L(
            "app_bar.global_style.caption",
            "Shared by every layout's bar. A layout can "
                + "override any of these below."
        )
    }
    private var positionLabel: String {
        L("app_bar.position.label", "Position")
    }
    private var styleLabel: String {
        L("app_bar.style.label", "Style")
    }
    private var activeItemLabel: String {
        L("app_bar.active_item.label", "Active item")
    }
    private var contentLabel: String {
        L("app_bar.content.label", "Content")
    }
}

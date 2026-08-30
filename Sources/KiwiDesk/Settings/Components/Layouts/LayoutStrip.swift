import KiwiDeskCore
import SwiftUI

/// Layout selection strip with live schematic thumbnails
/// (`SchematicScale.tile`).
struct LayoutStrip: View {
    @ObservedObject var model: SettingsModel
    @Binding var selection: LayoutMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsGroupHeader(chooseTitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(
                        LayoutMode.placementTabs,
                        id: \.self
                    ) { mode in
                        tile(mode)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chooseTitle)
    }

    private var chooseTitle: String {
        L("layout_defaults.choose", "Choose a layout")
    }

    private func tile(_ mode: LayoutMode) -> some View {
        let selected = mode == selection
        return Button {
            selection = mode
        } label: {
            VStack(spacing: 4) {
                LayoutSchematicView(
                    mode: mode,
                    settings: model.config.settings,
                    windows: LayoutSchematic.defaultWindowCount,
                    scale: .tile
                )
                Label(mode.displayName, systemImage: mode.glyph)
                    .font(.subheadline)
                    .labelStyle(.titleAndIcon)
                Text(usageText(mode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
            .background(selectionChrome(selected))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            selected ? [.isButton, .isSelected] : .isButton
        )
    }

    /// Background plate indicating selection state.
    private func selectionChrome(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                selected
                    ? SettingsTheme.accent.opacity(0.12)
                    : SettingsTheme.card
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        selected
                            ? SettingsTheme.accent
                            : SettingsTheme.ink2.opacity(0.25),
                        lineWidth: selected ? 2 : 1
                    )
            )
    }

    /// Usage summary for layout across active spaces (`LayoutUsage.spaces`).
    private func usageText(_ mode: LayoutMode) -> String {
        let count = LayoutUsage.spaces(
            on: mode,
            in: model.config
        ).count
        if count == 0 {
            return L("layout_defaults.uses.none", "No Spaces")
        }
        if count == 1 {
            return L("layout_defaults.uses.one", "1 Space")
        }
        return L(
            "layout_defaults.uses.many",
            "%1$d Spaces",
            count
        )
    }
}

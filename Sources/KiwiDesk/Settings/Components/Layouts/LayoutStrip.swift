import KiwiDeskCore
import SwiftUI

/// Layout selection strip with live schematic thumbnails, drawn
/// below `SchematicScale.tile` so the six fit a full-width pane
/// (#2901). Narrower, it scrolls sideways with the gesture strip's
/// overflow fade, and a Tab onto a tile scrolls it into view.
struct LayoutStrip: View {
    @ObservedObject var model: SettingsModel
    @Binding var selection: LayoutMode
    @State private var hovered: LayoutMode?
    @FocusState private var focused: LayoutMode?
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsGroupHeader(chooseTitle)
            SidewaysStrip(run: Self.run, followed: followed) {
                row
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chooseTitle)
    }

    /// The Tab-focused tile, which the strip scrolls clear of the fade.
    private var followed: StripFollow<LayoutMode>? {
        guard let focused,
            let index = LayoutMode.placementTabs.firstIndex(of: focused)
        else { return nil }
        return StripFollow(id: focused, index: index)
    }

    private var row: some View {
        HStack(alignment: .top, spacing: Self.gap) {
            ForEach(
                LayoutMode.placementTabs,
                id: \.self
            ) { mode in
                tile(mode)
                    .focused($focused, equals: mode)
                    .id(mode)
                    // Over the next tile, which would cover the shadow.
                    .zIndex(hovered == mode ? 1 : 0)
            }
        }
    }

    private var chooseTitle: String {
        L("layout_defaults.choose", "Choose a layout")
    }

    private func tile(_ mode: LayoutMode) -> some View {
        let selected = mode == selection
        let risen = hovered == mode && isEnabled && !selected
        return Button {
            selection = mode
        } label: {
            VStack(spacing: 4) {
                schematic(mode)
                    .padding(Self.platePadding)
                    .deskPlate(
                        model.config.settings,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                HStack(spacing: 3) {
                    // A slot on each side, so the name holds its place
                    // whichever tile is selected.
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.semibold))
                        .frame(width: Self.checkSlot)
                        .opacity(selected ? 1 : 0)
                        .selectionFade(selected)
                        .accessibilityHidden(true)
                    Label(mode.displayName, systemImage: mode.symbol)
                        .font(.subheadline)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Color.clear.frame(width: Self.checkSlot, height: 0)
                }
                Text(usageText(mode))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
            }
            .padding(Self.chromePadding)
            .frame(width: Self.tileWidth)
            .background(chrome(selected: selected, risen: risen))
            .hoverRise(risen, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                hovered = mode
            } else if hovered == mode {
                hovered = nil
            }
        }
        .accessibilityAddTraits(
            selected ? [.isButton, .isSelected] : .isButton
        )
    }

    /// The tile's plate. Selection and the pointer share the stroke,
    /// told apart by its weight, the rise and the name's check
    /// (#3042); the selected tile, whose click changes nothing, stays
    /// flat.
    private func chrome(selected: Bool, risen: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(SettingsTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        risen
                            ? SettingsTheme.hoverEdge
                            : SettingsTheme.ink2.opacity(0.25),
                        lineWidth: risen ? SettingsTheme.hoverEdgeStroke : 1
                    )
            )
            .overlay(
                SelectionStroke(
                    selected: selected,
                    shape: RoundedRectangle(cornerRadius: 8),
                    style: SettingsTheme.accent,
                    lineWidth: SettingsTheme.paletteCardStrokeApplied
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

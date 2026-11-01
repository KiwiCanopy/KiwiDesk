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
    @State var offset: CGFloat = 0
    @State var viewport: CGFloat = 0
    @FocusState private var focused: LayoutMode?
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsGroupHeader(chooseTitle)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    row
                }
                .coordinateSpace(.named(Self.space))
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.width
                } action: {
                    viewport = $0
                }
                .mask(StripFade(fades: fades))
                // The ring inset stays inside the clip; the row
                // still lines up with the header.
                .padding(.horizontal, -Self.ringRoom)
                .onChange(of: focused) { _, mode in
                    guard let mode else { return }
                    withAnimation(
                        reduceMotion ? nil : .easeOut(duration: 0.2)
                    ) {
                        proxy.scrollTo(mode)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chooseTitle)
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
            }
        }
        .padding(Self.ringRoom)
        .onGeometryChange(for: CGFloat.self) {
            -$0.frame(in: .named(Self.space)).minX
        } action: {
            offset = $0
        }
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
                schematic(mode)
                    .padding(4)
                    .deskPlate(
                        model.config.settings,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                Label(mode.displayName, systemImage: mode.symbol)
                    .font(.subheadline)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(usageText(mode))
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
            }
            .padding(6)
            .frame(width: Self.tileWidth)
            .background(selectionChrome(mode, selected: selected))
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

    /// The tile's plate: selection is the stroke alone, and the
    /// pointer's grey lift a fill apart from it (#1173); the
    /// selected tile, whose click changes nothing, stays flat.
    private func selectionChrome(
        _ mode: LayoutMode,
        selected: Bool
    ) -> some View {
        let lifted = hovered == mode && isEnabled && !selected
        return RoundedRectangle(cornerRadius: 8)
            .fill(SettingsTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(lifted ? SettingsTheme.chipRest : .clear)
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

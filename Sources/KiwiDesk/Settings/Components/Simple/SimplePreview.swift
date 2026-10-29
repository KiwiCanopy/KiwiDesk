import KiwiDeskCore
import SwiftUI

/// Simple's live preview (#2737 ruling 9): the shown Space's screen
/// drawn from the draft on the neutral plate, never a wallpaper, and
/// below it a map of the connected screens with that screen lit,
/// absent on one screen. Static frames: nothing in it moves.
struct SimplePreview: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let space = model.simplePreviewSpace {
                Text(header(space))
                    .font(.system(size: 10, weight: .semibold).monospaced())
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(SettingsTheme.ink3)
                    .accessibilityAddTraits(.isHeader)
                desk(space)
                if let caption = caption(space) {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.offersScreenMenu {
                    HomeCardScreensTile(
                        model: model,
                        lit: model.simpleLanding(of: space)?.id
                    )
                    .frame(height: Self.mapHeight)
                    .environment(\.schematicPalette, palette)
                    .accessibilityHidden(true)
                }
            } else {
                Text(
                    L("spaces.preview.none", "No Spaces in this draft yet.")
                )
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private static let mapHeight: CGFloat = 96
    private static let deskHeight: CGFloat = 300

    private var settings: TilingSettings { model.simplePreviewSettings }

    private var palette: SchematicPalette? {
        HomeCardPlate.palette(settings)
    }

    private func header(_ space: SpaceID) -> String {
        L("panel.live_preview", "Live preview · %1$@", space.raw)
    }

    /// The hovered Space or look by name; for an offline pin, both
    /// screens as well, since the frame draws where it opens now.
    func caption(_ space: SpaceID) -> String? {
        var lines: [String] = []
        switch model.simplePreviewHover {
        case .space(let hovered):
            lines.append(previewing(hovered.raw))
        case .look(let name):
            lines.append(previewing(name))
        case nil:
            break
        }
        if model.spacePinBadge(space) == .offline {
            lines.append(model.offlinePinSentence(space))
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func previewing(_ name: String) -> String {
        L("simple.preview.previewing", "Previewing %1$@", name)
    }

    private func desk(_ space: SpaceID) -> some View {
        let mode = model.config.modes(for: [space])[space] ?? .bsp
        let shape = RoundedRectangle(cornerRadius: 12)
        return HomeCardBarsTile(
            settings: settings,
            spaceCount: model.config.spaces.count,
            scale: 1.8,
            spaceLabels: BarsPanelPreview.spaceLabels(of: model.config),
            showsAppBar: settings.appBarVisibility(in: mode)
                .map(\.showsUnprompted) == true,
            wellContent: AnyView(schematic(space, mode: mode))
        )
        .padding(12)
        .frame(height: Self.deskHeight)
        .frame(maxWidth: .infinity)
        .background(shape.fill(SettingsTheme.previewPlate))
        .overlay(shape.strokeBorder(SettingsTheme.planeRing, lineWidth: 1))
        // The accent ring says the frame shows what a click kept;
        // a hover shows neutral and says so in the caption.
        .overlay(
            shape.strokeBorder(
                model.simplePreviewIsKept ? SettingsTheme.accent : .clear,
                lineWidth: 1
            )
        )
        .environment(\.schematicPalette, palette)
        // One description: the header above names the Space, the
        // picture its layout — never the bar strip's own labels.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode.displayName)
    }

    @ViewBuilder
    private func schematic(_ space: SpaceID, mode: LayoutMode) -> some View {
        if LayoutMode.placementTabs.contains(mode) {
            LayoutSchematicView(
                mode: mode,
                settings: settings.resolved(for: space, activeMode: mode),
                windows: LayoutSchematic.windowCount(
                    LayoutSchematic.defaultWindowCount,
                    for: mode
                ),
                scale: .panel
            )
        }
    }
}

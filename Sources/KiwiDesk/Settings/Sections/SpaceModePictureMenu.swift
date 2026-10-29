import AppKit
import KiwiDeskCore
import SwiftUI

/// A Space's layout menu whose face is a picture (Simple's Space
/// cards, #2777): the same layouts and the one write
/// `SpaceModeMenu` takes, each item drawn with its layout's picture
/// beside its name, so the drawing stays the label (#291).
struct SpaceModePictureMenu<Face: View>: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    @ViewBuilder let face: () -> Face

    var body: some View {
        let mode = SpaceModeMenu.binding(model, space)
        Menu {
            Picker("", selection: mode) {
                ForEach(LayoutMode.allCases, id: \.self) { mode in
                    Label {
                        Text(mode.displayName)
                    } icon: {
                        Image(nsImage: LayoutMenuPictures.image(mode))
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            face()
        }
        // The button style draws the face whole, as the profile
        // chip's menu does; the face carries its own hover.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .neutralMenuLabel()
        .menuIndicator(.hidden)
        .help(L("spaces.mode.help", "Layout mode for this Space"))
        .accessibilityLabel(
            L("spaces.mode.help", "Layout mode for this Space")
        )
        .accessibilityValue(mode.wrappedValue.displayName)
    }
}

/// Each layout's picture for a menu item: its schematic at rest on
/// a small screen of the cards' plate, in the plate's palette, so
/// its ghost windows read in a light or dark menu (#2777). The
/// schematic is inset in the plate, so every layout shows the same
/// rim whether its windows fill the screen or not.
/// Rendered once per layout and kept.
@MainActor
enum LayoutMenuPictures {
    private static var memo: [LayoutMode: NSImage] = [:]

    /// How many windows a picture draws: the schematic's default,
    /// and Floating's whole scatter.
    static func windows(for mode: LayoutMode) -> Int {
        let count = LayoutSchematic.windowCount(
            LayoutSchematic.defaultWindowCount,
            for: mode
        )
        return mode == .floating ? max(count, 3) : count
    }

    /// The picture's size in points, and the plate's rim around
    /// the schematic.
    static let size = CGSize(width: 40, height: 25)
    static let rim: CGFloat = 2

    static func image(_ mode: LayoutMode) -> NSImage {
        if let hit = memo[mode] { return hit }
        let settings = TilingSettings()
        let renderer = ImageRenderer(
            content: LayoutSchematicView(
                mode: mode,
                settings: settings,
                windows: windows(for: mode),
                scale: .tile
            )
            .scaleEffect(
                (size.width - 2 * rim) / (SchematicScale.tile.width ?? 132)
            )
            .frame(
                width: size.width - 2 * rim,
                height: size.height - 2 * rim
            )
            .padding(rim)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(SettingsTheme.previewPlate)
            )
            .environment(
                \.schematicPalette,
                HomeCardPlate.palette(settings)
            )
        )
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: size)
        image.size = size
        memo[mode] = image
        return image
    }
}

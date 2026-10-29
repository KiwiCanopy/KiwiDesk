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

/// Each layout's picture for a menu item: its schematic at rest,
/// rendered once per layout and kept.
@MainActor
enum LayoutMenuPictures {
    private static var memo: [LayoutMode: NSImage] = [:]

    /// The picture's size in points.
    static let size = CGSize(width: 40, height: 25)

    static func image(_ mode: LayoutMode) -> NSImage {
        if let hit = memo[mode] { return hit }
        let renderer = ImageRenderer(
            content: LayoutSchematicView(
                mode: mode,
                settings: TilingSettings(),
                windows: LayoutSchematic.windowCount(
                    LayoutSchematic.defaultWindowCount,
                    for: mode
                ),
                scale: .tile
            )
            .scaleEffect(size.width / (SchematicScale.tile.width ?? 132))
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: size)
        image.size = size
        memo[mode] = image
        return image
    }
}

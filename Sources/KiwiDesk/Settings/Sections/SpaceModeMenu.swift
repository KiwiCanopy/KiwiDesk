import KiwiDeskCore
import SwiftUI

/// A Space's layout menu, every layout (#123), each item drawn with
/// its layout's picture: the Spaces page's rows; Simple's cards
/// take `SpaceModePictureMenu`, whose face is a picture (#2777).
struct SpaceModeMenu: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID

    var body: some View {
        let modeHint = L(
            "spaces.mode.help",
            "Layout mode for this Space"
        )
        Picker("", selection: binding) {
            ForEach(LayoutMode.allCases, id: \.self) { mode in
                // The layout's picture, as Simple's cards' menu
                // draws it: one drawing per layout (#2777).
                Label {
                    Text(mode.displayName)
                } icon: {
                    Image(nsImage: LayoutMenuPictures.image(mode))
                }
                .tag(mode)
            }
        }
        .labelsHidden()
        // Explicit: the automatic style IS the pop-up on macOS and
        // takes the tint the same way, uncounted (#1502).
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.large)
        .frame(width: 150)
        .help(modeHint)
        .accessibilityLabel(modeHint)
        .accessibilityValue(binding.wrappedValue.displayName)
    }

    private var binding: Binding<LayoutMode> {
        Self.binding(model, space)
    }

    /// The draft's mode, the default bsp stored as absent: the one
    /// write both menus take (#2777).
    static func binding(
        _ model: SettingsModel,
        _ space: SpaceID
    ) -> Binding<LayoutMode> {
        Binding(
            get: { model.config.spaceModes[space] ?? .bsp },
            set: { mode in
                model.config.spaceModes[space] =
                    mode == .bsp ? nil : mode
            }
        )
    }
}

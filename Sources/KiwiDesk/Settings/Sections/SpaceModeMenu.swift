import KiwiDeskCore
import SwiftUI

/// A Space's layout menu, every layout (#123), each item drawn with
/// its layout's picture (#2777): the Spaces page's pop-up, or —
/// handed a `face` — a menu whose face is that face, as Simple's
/// Space cards draw it. One item list, one write, one name.
struct SpaceModeMenu<Face: View>: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    private let face: (() -> Face)?

    init(
        model: SettingsModel,
        space: SpaceID,
        @ViewBuilder face: @escaping () -> Face
    ) {
        self.model = model
        self.space = space
        self.face = face
    }

    var body: some View {
        let hint = L("spaces.mode.help", "Layout mode for this Space")
        Group {
            if let face {
                Menu {
                    Picker("", selection: binding) { items }
                        .pickerStyle(.inline)
                        .labelsHidden()
                } label: {
                    face()
                }
                // The button style draws the face whole, as the
                // profile chip's menu does; the face lifts itself.
                .menuStyle(.button)
                .buttonStyle(.plain)
                .neutralMenuLabel()
                .menuIndicator(.hidden)
            } else {
                Picker("", selection: binding) { items }
                    .labelsHidden()
                    // Explicit: the automatic style IS the pop-up on
                    // macOS and takes the tint the same way,
                    // uncounted (#1502).
                    .pickerStyle(.menu)
                    .neutralMenuLabel()
                    .controlSize(.large)
                    .frame(width: 150)
            }
        }
        .help(hint)
        .accessibilityLabel(hint)
        .accessibilityValue(binding.wrappedValue.displayName)
    }

    /// Every layout, each with its picture beside its name.
    private var items: some View {
        ForEach(LayoutMode.allCases, id: \.self) { mode in
            Label {
                Text(mode.displayName)
            } icon: {
                Image(nsImage: LayoutMenuPictures.image(mode))
            }
            .tag(mode)
        }
    }

    /// The draft's mode, the default bsp stored as absent.
    private var binding: Binding<LayoutMode> {
        Binding(
            get: { model.config.spaceModes[space] ?? .bsp },
            set: { mode in
                model.config.spaceModes[space] =
                    mode == .bsp ? nil : mode
            }
        )
    }
}

extension SpaceModeMenu where Face == EmptyView {
    /// The Spaces page's pop-up.
    init(model: SettingsModel, space: SpaceID) {
        self.model = model
        self.space = space
        self.face = nil
    }
}

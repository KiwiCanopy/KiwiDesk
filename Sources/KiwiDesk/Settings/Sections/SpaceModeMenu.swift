import KiwiDeskCore
import SwiftUI

/// A Space's layout menu, every layout (#123): drawn by the Spaces
/// page's rows and by Simple's (#2737).
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
                Label(
                    mode.displayName,
                    systemImage: mode.symbol
                )
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

import KiwiDeskCore
import SwiftUI

/// A Space row's Customize button (#2674). Its badge counts the
/// Space's overrides; a Floating Space whose overrides all wait
/// for a tiling layout dims it (`OverrideCellState`, #678 8a).
struct SpaceCustomizeButton: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    let open: () -> Void

    var body: some View {
        let state = Self.state(of: space, in: model)
        Button(action: open) {
            Image(systemName: "slider.horizontal.3")
                .overlay(alignment: .topTrailing) {
                    OverrideCountBadge(state: state)
                        .offset(x: 5, y: -5)
                }
                .padding(.horizontal, 6)
        }
        .buttonStyle(.borderless)
        .iconHoverChip()
        .help(L("spaces.overrides.customize", "Customize…"))
        .accessibilityLabel(
            L("spaces.customize.a11y", "Customize Space %1$@", space.raw)
        )
        .accessibilityValue(OverrideCountBadge.spokenValue(state))
    }

    /// The badge's state for `space` in the draft.
    static func state(
        of space: SpaceID,
        in model: SettingsModel
    ) -> OverrideCellState {
        let settings = model.config.settings
        return OverrideCellState.resolve(
            count: settings.spaceOverrideCount(for: space),
            live: settings.floatingLiveOverrideCount(for: space),
            isFloating: (model.config.spaceModes[space] ?? .bsp) == .floating
        )
    }
}

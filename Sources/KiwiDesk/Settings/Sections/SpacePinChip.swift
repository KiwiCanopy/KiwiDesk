import KiwiDeskCore
import SwiftUI

/// A Space row's Screen pin chip (`SpacePinBadge`, #678 Phase 3):
/// the pinned screen's name, or "Pin offline" for a pin to a
/// screen that is not attached. `offlineOnly` draws the second
/// alone, for a row whose Screen menu already names the screen.
struct SpacePinChip: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    var offlineOnly = false

    var body: some View {
        switch SpacePinBadge.resolve(
            pin: model.config.spacePins[space],
            connectedFingerprints: Set(
                model.displays.map(\.fingerprint)
            ),
            name: model.screenName
        ) {
        case .none:
            EmptyView()
        case .pinned(let displayName):
            if !offlineOnly {
                BadgeChip(label: displayName)
                    .help(
                        L(
                            "spaces.pin_badge.help",
                            "Pinned to %1$@ for this profile.",
                            displayName
                        )
                    )
            }
        case .offline:
            BadgeChip(
                label: L("spaces.pin_offline_badge", "Pin offline")
            )
            .help(
                L(
                    "spaces.pin_offline_badge.help",
                    "Pinned to a screen that isn't attached, so "
                        + "this Space opens on the main screen "
                        + "for now."
                )
            )
        }
    }
}

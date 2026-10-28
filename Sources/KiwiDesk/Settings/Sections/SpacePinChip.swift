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
            .help(offlineHelp)
            .accessibilityHint(offlineHelp)
        }
    }

    /// Names both screens where it can: the one the pin waits for,
    /// by the name its fingerprint keeps, and the main screen the
    /// Space opens on meanwhile (#2737).
    private var offlineHelp: String {
        guard let pin = model.config.spacePins[space],
            let main = model.mainDisplay
        else {
            return L(
                "spaces.pin_offline_badge.help",
                "Pinned to a screen that isn't attached, so "
                    + "this Space opens on the main screen "
                    + "for now."
            )
        }
        return L(
            "spaces.pin_offline_badge.help_named",
            "Pinned to %1$@, which isn't connected.\nOpens on %2$@, "
                + "the main screen, until it's back.",
            Display.fingerprintParts(pin).name,
            main.name
        )
    }
}

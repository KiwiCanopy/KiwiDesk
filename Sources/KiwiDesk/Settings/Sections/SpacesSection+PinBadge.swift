import KiwiDeskCore
import SwiftUI

/// Space row display-pin badge view for SpacesSection (#678 Phase 3).
extension SpacesSection {
    @ViewBuilder
    func pinBadge(_ space: SpaceID) -> some View {
        switch SpacePinBadge.resolve(
            pin: model.config.spacePins[space],
            connectedFingerprints: Set(
                model.displays.map(\.fingerprint)
            ),
            name: model.monitorName
        ) {
        case .none:
            EmptyView()
        case .pinned(let displayName):
            BadgeChip(label: displayName)
                .help(
                    L(
                        "spaces.pin_badge.help",
                        "Pinned to %1$@ for this profile.",
                        displayName
                    )
                )
        case .offline:
            BadgeChip(
                label: L("spaces.pin_offline_badge", "Pin offline")
            )
            .help(
                L(
                    "spaces.pin_offline_badge.help",
                    "Pinned to a display that isn't attached, so "
                        + "this Space opens on the main display "
                        + "for now."
                )
            )
        }
    }
}

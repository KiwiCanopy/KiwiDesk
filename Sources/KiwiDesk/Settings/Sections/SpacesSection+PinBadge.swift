import KiwiDeskCore
import SwiftUI

/// The space row's display-pin badge (#678 Phase 3, turn 8a),
/// split from `SpacesSection.swift` to stay under the line ceiling
/// (same seam as `+Drag`/`+Customize`/`+ModePicker`).
///
/// Names the display a space is pinned to, or flags a pin whose
/// display is offline — so the pin is visible on the row without
/// opening Monitors. The connected/offline split is resolved by
/// `SpacePinBadge` from the same attached-fingerprint set the
/// placement resolver reads, so the row and the placement cannot
/// disagree about whether a pin is live.
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

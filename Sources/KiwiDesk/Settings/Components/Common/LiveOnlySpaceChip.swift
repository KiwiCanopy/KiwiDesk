import KiwiDeskCore
import SwiftUI

/// The badge a live Space the profile does not hold wears (#1790):
/// Temporary, or where it was held from (#1507). Settings ▸ Spaces
/// and the per-Space shortcut rows draw the same chip (#1827).
struct LiveOnlySpaceChip: View {
    let kind: LiveOnlySpace.Kind

    var body: some View {
        switch kind {
        case .temporary:
            BadgeChip(label: L("spaces.temporary_badge", "Temporary"))
                .help(
                    L(
                        "spaces.temporary_badge.help",
                        "Made on the fly. It goes away once its last "
                            + "window leaves; switching profiles keeps "
                            + "it while it has windows."
                    )
                )
        case .held(let screen, let profile):
            BadgeChip(label: Self.heldLabel(screen, profile), maxWidth: 180)
                .help(Self.heldHelp(screen, profile))
        }
    }

    /// Where it was held from: its profile where one was live, else
    /// its screen (#1507, #1790).
    static func heldLabel(
        _ screen: String,
        _ profile: String?
    ) -> String {
        guard let profile else {
            return L("spaces.held_badge", "Held from %1$@", screen)
        }
        return L(
            "spaces.held_badge.profile",
            "Held from %1$@ · %2$@",
            profile,
            screen
        )
    }

    static func heldHelp(
        _ screen: String,
        _ profile: String?
    ) -> String {
        guard let profile else {
            return L(
                "spaces.held_badge.help",
                "Goes back to its own profile when %1$@ is connected "
                    + "again",
                screen
            )
        }
        return L(
            "spaces.held_badge.profile.help",
            "Goes back when %1$@ is live again with %2$@ connected",
            profile,
            screen
        )
    }
}

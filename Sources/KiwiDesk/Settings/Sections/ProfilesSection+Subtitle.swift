import KiwiDeskCore
import SwiftUI

/// Subtitle and summary phrases for profile rows (#678 turn
/// 13a). Counts only what the profile OWNS: the third segment
/// counts overrides — the resolved set would say the profile
/// carries a keybinding set of its own, exactly what a sparse
/// override is not — and disappears at zero. Two frames rather
/// than one optional slot, because a frame with an empty argument
/// leaves its own separator behind in every locale
/// (`ProfileSummary`).
extension ProfilesSection {
    func subtitle(_ summary: ProfileSummary) -> String {
        let screens = screensPhrase(summary.count)
        let spaces = spacesPhrase(summary.spaceCount)
        guard summary.shortcutOverrideCount > 0 else {
            return L(
                "profiles.summary.pair",
                "%1$@ · %2$@",
                screens,
                spaces
            )
        }
        return L(
            "profiles.summary.triple",
            "%1$@ · %2$@ · %3$@",
            screens,
            spaces,
            overridesPhrase(summary.shortcutOverrideCount)
        )
    }

    /// Tooltip text listing associated monitor names.
    func monitorTooltip(_ summary: ProfileSummary) -> String {
        summary.sets
            .map { set in
                set.map(model.monitorName)
                    .joined(separator: ", ")
            }
            .joined(separator: "\n")
    }

    /// Localized screen count phrase.
    func screensPhrase(_ count: Int) -> String {
        count == 1
            ? L("profiles.screens.one", "1 screen")
            : L("profiles.screens.many", "%1$d screens", count)
    }

    /// Localized Space count phrase (`PresetScreenCard.spaceCountPhrase`).
    private func spacesPhrase(_ count: Int) -> String {
        count == 1
            ? L("profiles.spaces.one", "1 Space")
            : L("profiles.spaces.many", "%1$d Spaces", count)
    }

    private func overridesPhrase(_ count: Int) -> String {
        count == 1
            ? L(
                "profiles.overrides.one",
                "1 shortcut override"
            )
            : L(
                "profiles.overrides.many",
                "%1$d shortcut overrides",
                count
            )
    }
}

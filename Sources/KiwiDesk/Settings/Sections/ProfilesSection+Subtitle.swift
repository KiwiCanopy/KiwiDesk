import KiwiDeskCore
import SwiftUI

/// A saved profile's one-line subtitle (#678 turn 13a), split
/// from `ProfilesSection` for the file ceiling.
///
/// It counts only what the profile OWNS. "18 shortcuts" would be
/// the resolved set — the global bindings the profile inherits
/// plus its own — and reading it on a profile row says the
/// profile carries a keybinding set of its own, which is exactly
/// what a sparse override is not. So the third segment counts
/// *overrides*, and disappears at zero rather than reading
/// "0 shortcut overrides" on every profile that never touched
/// one.
///
/// The segments are assembled through a positional frame, not
/// joined in Swift: the separator and the order are the
/// translator's (`profiles.summary.*`). Two frames rather than one
/// optional slot, because a frame with an empty argument leaves
/// its own separator behind in every locale.
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

    /// The monitor names behind "N screens" — the detail the old
    /// row spent a chip row on. A tooltip keeps it reachable
    /// without letting the hardware outrank the profile's own
    /// name; each covered combination is its own line.
    func monitorTooltip(_ summary: ProfileSummary) -> String {
        summary.sets
            .map { set in
                set.map(model.monitorName)
                    .joined(separator: ", ")
            }
            .joined(separator: "\n")
    }

    private func screensPhrase(_ count: Int) -> String {
        count == 1
            ? L("profiles.screens.one", "1 screen")
            : L("profiles.screens.many", "%1$d screens", count)
    }

    private func spacesPhrase(_ count: Int) -> String {
        count == 1
            ? L("profiles.spaces.one", "1 space")
            : L("profiles.spaces.many", "%1$d spaces", count)
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

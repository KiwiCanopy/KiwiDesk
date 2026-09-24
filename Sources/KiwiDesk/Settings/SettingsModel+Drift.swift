import Foundation
import KiwiDeskCore

/// Why the live target reports unsaved state that no draft leaf
/// carries (#1197). ONE verdict, read by the header's status
/// line, the save pill's presence and the pill's drift rows —
/// three surfaces that used to derive it apart and disagreed.
enum ProfileDrift: Equatable {
    /// A built-in layout is composing; nothing saved holds it.
    case builtIn
    /// The active profile stores no set for the connected
    /// screens.
    case screensUnsaved(profile: String)
    /// Nothing matches: the matched profile was deleted, or a
    /// Lua-owned config adopts no Standard.
    case noMatch
}

extension SettingsModel {
    /// Whether the LIVE target has drift to report. False while
    /// a stored profile is on the table: its draft owns the pill
    /// then, and the header hides divergence the same way.
    var liveDrift: Bool {
        profileDirty && !editingStoredProfile
    }

    /// The drift's shape, nil without `liveDrift`. The Standard
    /// arm leads only by convention: `ProfileManager` clears the
    /// other whenever it sets one, so both-set is unreachable
    /// and the order decides nothing (guard-prover, 2026-09-03).
    var profileDrift: ProfileDrift? {
        guard liveDrift else { return nil }
        if activeStandard != nil { return .builtIn }
        if let name = activeProfile {
            // A set another profile owns is not this profile's to
            // save — a binding put it here, or a pick moved the set
            // away — so it is no unsaved change (#1530).
            let fitsCount =
                profileSummaries.first { $0.name == name }?
                .matchesConnectedCount ?? false
            let ownedElsewhere = profileSummaries.contains {
                $0.name != name && $0.matchesLive
            }
            if fitsCount, ownedElsewhere { return nil }
            return .screensUnsaved(profile: name)
        }
        return .noMatch
    }

    /// Why the live draft cannot be saved as it stands: another
    /// profile was loaded under it, and its page is the old one.
    var pageMovedReason: String? {
        guard target == .live, let page = reachPage,
            let current = core.profiles.currentName, current != page
        else { return nil }
        return L(
            "profiles.page_moved",
            "%1$@ was loaded while you were editing %2$@. Revert, "
                + "then make your edits again.",
            current,
            page
        )
    }
}

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

    /// Whether the live page no longer names the loaded profile —
    /// one was loaded under it, or over a page drawn with none.
    var pageMoved: Bool {
        target == .live && ruleReachStored != nil
            && reachPage != core.profiles.currentName
    }

    /// Whether the live page's shell disagrees with `init.lua`:
    /// the file gained or lost code the visual editor cannot
    /// co-own since the page was drawn (#2183).
    var ownerMoved: Bool {
        target == .live
            && forcedLuaEditor != core.configHasForeignCode
    }

    /// Whether the live draft no longer matches what the next
    /// load reads: a profile loaded under the page (#1393), or
    /// `init.lua` changing owner under it (#2183).
    var draftStale: Bool { pageMoved || ownerMoved }

    /// Why a dirty live draft cannot be saved — the ONE refusal
    /// every gui.json door reads first, owner ahead of page.
    var staleDraftReason: String? {
        ownerMovedReason ?? pageMovedReason ?? writeLatchReason
    }

    /// A newer build's file every structured Save would write,
    /// read FRESH at the door before its first write — not the
    /// refresh's copy, which a synced file can outrun (#2324).
    var writeLatchReason: String? {
        core.guiConfigWriteLatch().map(NewerFormatText.saveBlocked)
    }

    /// `init.lua` now owns what the draft would write, so the load
    /// would ignore its gui.json half. The whole Save refuses: a
    /// clean page re-draws as the Lua editor (#2183).
    private var ownerMovedReason: String? {
        guard ownerMoved, !forcedLuaEditor, isDirty else {
            return nil
        }
        return L(
            "profiles.owner_moved",
            "init.lua was changed outside Settings and now sets "
                + "these settings itself, so your edits can't be "
                + "saved. %1$@, then make them in init.lua.",
            L("footer.revert", "Revert")
        )
    }

    /// Why a dirty live draft cannot be saved as it stands: its
    /// page is not the loaded profile's any more.
    private var pageMovedReason: String? {
        guard pageMoved, isDirty else { return nil }
        guard let current = core.profiles.currentName else {
            // The loaded profile went away under the page.
            return L(
                "profiles.page_gone",
                "%1$@ is no longer loaded. %2$@, then make your edits "
                    + "again.",
                reachPage ?? "",
                L("footer.revert", "Revert")
            )
        }
        guard let page = reachPage else {
            return L(
                "profiles.page_moved.unnamed",
                "%1$@ was loaded while you were editing. %2$@, then "
                    + "make your edits again.",
                current,
                L("footer.revert", "Revert")
            )
        }
        return L(
            "profiles.page_moved",
            "%1$@ was loaded while you were editing %2$@. %3$@, "
                + "then make your edits again.",
            current,
            page,
            L("footer.revert", "Revert")
        )
    }
}

import Foundation
import KiwiDeskCore

/// Profile and shortcut refresh operations (#678 turn 13a).
/// `reload()` and `selectEditTarget` — the single edit-mode state
/// machine — live in `SettingsModel+EditTarget.swift` (#64).
extension SettingsModel {
    func refreshProfiles() {
        profiles = core.profiles.list()
        activeProfile = core.profiles.currentName
        activeStandard = core.profiles.currentStandard
        profileDirty = core.profiles.isDirty
        duplicateDefaultCounts =
            core.profiles.duplicateDefaultCounts()
        let live = displays.map(\.fingerprint)
        profileSummaries = core.profiles.allProfiles().map {
            profile in
            ProfileSummary(
                name: profile.name,
                count: profile.monitorCount,
                sets: profile.monitorSets.map(\.monitors),
                isDefault: profile.isDefault,
                matchesLive: profile.set(matching: live) != nil,
                // Derived from the SAME `live` read as
                // `matchesLive` one line up (#789): threaded as a
                // parameter instead, nothing stopped a second,
                // later `displays.count` read at the call site.
                matchesConnectedCount: profile.monitorCount
                    == live.count,
                openingModes: profile.openingModes(),
                spaceCount: profile.declaredSpaces.count,
                shortcutOverrideCount:
                    profile.layers?.overrideCount ?? 0
            )
        }
        brokenProfiles = core.profiles.brokenProfiles().map {
            BrokenProfile(name: $0.name, cause: $0.cause)
        }
        // ONE topology reading for all four consumers — the card's
        // offer, the wider shortcut list, the current badge, and
        // the verdict below (a Desktop binding outranks monitor
        // matching). Read apart, the sentence could pair a verdict
        // with a later reading of the arrangement (#888).
        let desktops = NativeSpaces.desktopSnapshot()
        mainDesktops = desktops.mainDisplayDesktops
        bindableDesktops = core.bindableDesktops(in: desktops)
        currentDesktop = desktops.authority
        let resolved = core.profileVerdict(
            activeDesktop: currentDesktop
        )
        profileResolution = ProfileResolution(
            verdict: resolved.verdict,
            screens: resolved.screens
        )
        refreshLayoutDrift()
    }

    /// Imports live Lua shortcuts into current config (`KeybindingMerge`, #4).
    func importCurrentShortcuts() {
        var updated = config
        KeybindingMerge.merge(
            recovered: core.recoverKeybindings(),
            into: &updated
        )
        KeybindingImportClassifier.classify(
            &updated,
            recoverResizeStep: true
        )
        config = updated
    }
}

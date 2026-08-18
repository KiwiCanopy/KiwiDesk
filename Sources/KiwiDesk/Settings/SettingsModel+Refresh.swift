import Foundation
import KiwiDeskCore

/// The dashboard model's backend sync (#678 turn 13a split): the
/// snapshots `refreshProfiles` takes of live state, and the
/// keybinding import that seeds the edited config from
/// `init.lua`.
///
/// Split from `SettingsModel.swift` on the file ceiling. The
/// stored `@Published` properties these write must stay on the
/// class (an extension cannot hold them), so the seam here is
/// state vs. the refresh that fills it.
extension SettingsModel {
    // MARK: - Sync with the backend

    // `reload()` and `selectEditTarget` — the single edit-mode
    // state machine — live in `SettingsModel+EditTarget.swift`
    // (#64).

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
                // `matchesLive`, one line up (#789). The two are
                // answers about one moment by construction here;
                // threaded into the sort as a parameter instead,
                // "one moment" was a comment at the call site
                // and nothing stopped a second, later
                // `displays.count` from being read there.
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
        // ONE topology reading for all three: the Desktops the
        // card offers, the one it badges as current, and the
        // verdict below — which needs the Desktop this pass just
        // read, since a Desktop binding outranks monitor
        // matching. Read apart, the card's sentence could pair a
        // verdict with a later reading of the arrangement (#888).
        let desktops = NativeSpaces.desktopSnapshot()
        mainDesktops = desktops.mainDisplayDesktops
        currentNativeSpace = desktops.authority
        let resolved = core.profileVerdict(
            activeDesktop: currentNativeSpace
        )
        profileResolution = ProfileResolution(
            verdict: resolved.verdict,
            screens: resolved.screens
        )
        refreshLayoutDrift()
    }

    // MARK: - Import live keybindings (#4)

    /// Merges the shortcuts currently active in `init.lua` into
    /// the edited config: each recovered mode is matched by name
    /// (created if new), every recovered row upserted by combo,
    /// and the result reclassified so known actions land in their
    /// sections. Marks the config dirty so the user reviews the
    /// import before Save writes it.
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

import Foundation
import KiwiDeskCore

/// Profile and shortcut refresh operations for SettingsModel (#678 turn 13a).
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
        let desktops = NativeSpaces.desktopSnapshot()
        mainDesktops = desktops.mainDisplayDesktops
        bindableDesktops = core.bindableDesktops(in: desktops)
        // The GUI never mints (#1147): it reads the stamps the
        // Core's own callers wrote, and a Desktop still unstamped
        // joins under its number like everything else.
        desktopKeys = Dictionary(
            desktops.spaces.filter(\.isUser).compactMap { space in
                desktops.number(of: space.id).flatMap { number in
                    desktops.key(of: space.id).map { (number, $0) }
                }
            },
            uniquingKeysWith: { first, _ in first }
        )
        currentDesktop = desktops.authority
        let resolved = core.profileVerdict(
            activeDesktop: desktops.mainCurrentKey
        )
        profileResolution = ProfileResolution(
            verdict: resolved.verdict,
            screens: resolved.screens
        )
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

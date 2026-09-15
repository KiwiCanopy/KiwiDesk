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
        // Core's own callers wrote, through the snapshot's own
        // join rather than a second copy of it.
        desktopKeys = desktops.keysByNumber
        presentDesktopKeys = desktops.presentKeys
        currentDesktop = desktops.authority
        currentDesktopKey = desktops.mainCurrentKey
        let resolved = core.profileVerdict(
            activeBinding: core.mainDesktopBinding(in: desktops)
        )
        profileResolution = ProfileResolution(
            verdict: resolved.verdict,
            screens: resolved.screens
        )
        adoptRekeyedBindings()
    }

    /// Take Core's re-keyed bindings into an UNEDITED draft
    /// (#1147).
    ///
    /// Core rewrites the sidecar's `profile_bindings` when a
    /// renumber moves a binding onto its Desktop's stamp. A
    /// Settings window open across that rewrite holds a draft
    /// seeded from the OLD sidecar, and its Save would put the
    /// number keys back — where the next snapshot re-keys them to
    /// whichever Desktop now holds that number, which is the
    /// silent wrong-Desktop this lane removes, arriving through
    /// the GUI instead.
    ///
    /// Only an UNTOUCHED draft is re-seeded: a user who has
    /// edited a binding owns that value, and their edit must
    /// survive a refresh. The clean baseline moves with it, so
    /// adopting Core's rewrite never reads as a pending change.
    private func adoptRekeyedBindings() {
        guard let saved = core.guiConfigStore.load(),
            saved.profileBindings != cleanConfig.profileBindings
        else { return }
        // PER ENTRY, not per map: ownership is per binding, so a
        // user who edited ONE row while Core re-keyed another
        // would otherwise Save every untouched entry back under
        // its old number key — the wrong-Desktop this closes,
        // re-entering through the GUI (architect review,
        // 2026-09-04).
        var adopted = saved.profileBindings
        bindingEdits.apply(to: &adopted)
        let wasSuppressed = suppressDirty
        suppressDirty = true
        config.profileBindings = adopted
        suppressDirty = wasSuppressed
        cleanConfig.profileBindings = saved.profileBindings
        savedSidecar?.profileBindings = saved.profileBindings
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

/// The binding rows the user touched in the draft — per ENTRY,
/// since ownership is per binding (#1147).
struct BindingEdits {
    var edited: [DesktopKey: DesktopBinding]
    var dropped: [DesktopKey]

    var isEmpty: Bool { edited.isEmpty && dropped.isEmpty }

    func apply(to bindings: inout [DesktopKey: DesktopBinding]) {
        for (key, value) in edited { bindings[key] = value }
        for key in dropped { bindings[key] = nil }
    }
}

extension SettingsModel {
    /// The draft's binding edits against the clean baseline —
    /// the one derivation the re-key adopt and the
    /// stored-profile Save both read.
    var bindingEdits: BindingEdits {
        BindingEdits(
            edited: config.profileBindings.filter {
                cleanConfig.profileBindings[$0.key] != $0.value
            },
            dropped: cleanConfig.profileBindings.keys.filter {
                config.profileBindings[$0] == nil
            }
        )
    }
}

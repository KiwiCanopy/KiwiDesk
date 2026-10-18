import Foundation
import KiwiDeskCore

/// Profile and shortcut refresh operations for SettingsModel (#678 turn 13a).
extension SettingsModel {
    func refreshProfiles() {
        profiles = core.profiles.list()
        guiManaged = core.isGuiManaged
        // The switches too (#1752): a Keep, a crossing or a switch
        // outside Settings moves them; the draft's ticks stay.
        lookReachStored = core.lookReach()
        sidecarExists = core.guiConfigStore.exists
        activeProfile = core.profiles.currentName
        activeProfileID = core.profiles.currentID
        activeStandard = core.profiles.currentStandard
        activeStandardTitle = core.profiles.currentStandardTitle
        profileDirty = core.profiles.isDirty
        duplicateDefaultCounts =
            core.profiles.duplicateDefaultCounts()
        profileSummaries = core.profiles.allProfiles().map {
            profile in
            ProfileSummary(
                name: profile.name,
                profileID: profile.id,
                count: profile.monitorCount,
                sets: profile.monitorSets.map(\.monitors),
                isDormant: profile.isDormant,
                isUsableDefault: profile.isUsableDefault,
                isDefault: profile.isDefault,
                matchesLive: profile.monitorSets.contains {
                    core.isConnectedMonitorSet($0.monitors)
                },
                matchesConnectedCount: profile.monitorCount
                    == displays.count,
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
        desktopScreens = core.desktopScreens(in: desktops)
        currentDesktop = desktops.authority
        currentDesktopKey = desktops.mainCurrentKey
        let resolved = core.profileVerdict(
            activeBinding: core.mainDesktopBinding(in: desktops)
        )
        profileResolution = ProfileResolution(
            verdict: resolved.verdict,
            screens: resolved.screens
        )
        bindableSetups = Dictionary(
            uniqueKeysWithValues: Set(profileSummaries.map(\.count))
                .map { ($0, core.monitorSets(count: $0)) }
        )
        adoptRekeyedBindings()
        refreshBindingReadings()
        // A profile loaded under a CLEAN live page (a Desktop
        // binding, `load_profile`) takes the page with it (#1393);
        // a dirty draft keeps its page and its Save refuses. So
        // does an `init.lua` that changed owner under it (#2183).
        if draftStale, !isDirty { reload() }
    }

    /// Re-draws a clean live page whose `init.lua` changed owner
    /// (#2183) or, in the Lua editor, changed at all (#2206) —
    /// file reads cheap enough for every window-key.
    func refreshOwner() {
        if ownerMoved || luaChangedOnDisk, !isDirty {
            reload()
        } else {
            // A live setting a verb moved while the window was away
            // calls nothing back (#2262).
            refreshUnsavedLive()
        }
    }

    /// Re-reads what each draft binding loads (#1609). Owed by
    /// every writer of `config.profileBindings` and every change
    /// of what the gate reads (the screens, the live profile) —
    /// today the profile refresh and the Desktops card's write.
    func refreshBindingReadings() {
        var readings: [DesktopBinding: BoundReading] = [:]
        var resolutions: BindingResolutions = [:]
        for record in config.profileBindings.values {
            readings[record] = core.boundReading(of: record)
            for entry in record.entries {
                resolutions[entry.key] = core.bindingResolution(of: entry)
            }
        }
        bindingReadings = readings
        bindingResolutions = resolutions
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
            Set(saved.profileBindings.keys)
                .union(cleanConfig.profileBindings.keys)
                .contains(where: {
                    !DesktopBinding.sameStored(
                        saved.profileBindings[$0],
                        cleanConfig.profileBindings[$0]
                    )
                })
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
        importShortcuts(core.recoverKeybindings())
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
    /// Runs a Save's `gui.json` write with the draft's binding edits
    /// ordered around it (#2324): before it where the config reads,
    /// so the reload it triggers applies the new bindings, and after
    /// it where this Save mints or repairs the config the binding
    /// door requires.
    func savingBindingEdits(_ save: () throws -> Void) throws {
        let store = core.guiConfigStore
        guard store.exists, store.load() != nil else {
            try save()
            try persistBindingEdits()
            return
        }
        try persistBindingEdits()
        try save()
    }

    /// Writes the draft's binding edits, per entry, into the stored
    /// map (#2324): a Save carries only what the user changed, so a
    /// re-key or a promotion made since the draft was read stands.
    func persistBindingEdits() throws {
        let edits = bindingEdits
        guard !edits.isEmpty else { return }
        // The write loads a rebound Desktop's profile: a control's
        // motion, never an ambient pass (#804).
        try core.withUserMotion {
            try core.rewriteSidecarBindings { edits.apply(to: &$0) }
        }
    }

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

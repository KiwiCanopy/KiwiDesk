import Foundation

/// Applying profiles and the total space→display resolution
/// (#36), including the monitor-change matching that decides
/// what to apply (#53 fallback composition).
extension KiwiCore {
    // MARK: - Applying

    /// Applies a profile to live state and retiles.
    func apply(profile: Profile) {
        tiler.settings = profile.settings
        for (raw, mode) in profile.spaceModes {
            let id = SpaceID(raw)
            state.workspaces.ensureSpace(id)
            state.workspaces.setMode(id, mode)
        }
        // Adopt the pins of the set covering the live monitors
        // (none when the profile loads dirty on other hardware)
        // and the profile-wide Main role.
        let live = state.workspaces.allDisplays
            .map(\.fingerprint)
        spacePins =
            profile.set(matching: live)?.spaceMonitorMap ?? [:]
        mainSpaces = Set(profile.mainSpaces)
        resolveSpaceDisplays()
        retile()
        emitSpaceChange()
    }

    /// Applies a composed Standard fallback (#53): transient,
    /// nothing is written until the user saves.
    func apply(composed: ProfileComposition.Composed) {
        tiler.settings = composed.settings
        for space in composed.spaces {
            state.workspaces.ensureSpace(space)
            state.workspaces.setMode(
                space,
                composed.spaceModes[space] ?? .bsp
            )
        }
        spacePins = [:]
        mainSpaces = []
        resolveSpaceDisplays()
        retile()
        emitSpaceChange()
    }

    /// Total space→display resolution (#36): explicit pin →
    /// Main role → the positional default (#53). Writes the
    /// result into workspace state so every space has a screen
    /// and the GUI renders the resolved mapping.
    func resolveSpaceDisplays(
        mainID: DisplayID = PositionalDisplays.liveMainID
    ) {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return }
        let composed = ProfileComposition.compose(
            displays: displays,
            mainID: mainID
        )
        let main =
            displays.first { $0.id == mainID }
            ?? PositionalDisplays.ordered(
                displays,
                mainID: mainID
            )[0]
        for space in state.workspaces.allSpaces {
            let id = space.id
            let resolved: DisplayID
            if let pin = spacePins[id],
                let pinned = displays.first(where: {
                    $0.fingerprint == pin
                })
            {
                resolved = pinned.id
            } else if mainSpaces.contains(id) {
                resolved = main.id
            } else {
                resolved =
                    composed?.assignment[id] ?? main.id
            }
            state.workspaces.assign(id, to: resolved)
        }
    }

    // MARK: - Monitor changes

    /// Profile selection on monitor reconfiguration (#36):
    /// exact stored set → adopt clean; the count's default
    /// user profile → load dirty; else compose the built-in
    /// Standard (#53) → transient dirty state.
    func handleMonitorChange() {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return }
        let fingerprints = displays.map(\.fingerprint)

        // A native-Space binding wins over matching (#7).
        if let number = NativeSpaces.activeSpaceNumber(),
            let boundName = nativeSpaceBindings[number],
            let bound = try? profiles.load(name: boundName)
        {
            apply(profile: bound)
            if bound.set(matching: fingerprints) == nil {
                profiles.markDirty()
            }
            onLog(
                "monitor change: loaded bound profile "
                    + "'\(boundName)'"
            )
            return
        }

        switch profiles.match(fingerprints: fingerprints) {
        case .exact(let profile):
            if profile.name != profiles.currentName {
                apply(profile: profile)
                profiles.adopt(profile)
                onLog(
                    "monitor change: loaded profile "
                        + "'\(profile.name)'"
                )
            } else {
                // Same profile, possibly a different set of
                // its — re-resolve placement, stay clean.
                spacePins =
                    profile.set(matching: fingerprints)?
                    .spaceMonitorMap ?? [:]
                resolveSpaceDisplays()
            }
        case .countDefault(let profile):
            if profile.name != profiles.currentName {
                apply(profile: profile)
                profiles.adopt(profile)
                onLog(
                    "monitor change: loaded default profile "
                        + "'\(profile.name)' (dirty)"
                )
            }
            profiles.markDirty()
        case .none:
            guard
                let composed = ProfileComposition.compose(
                    displays: displays,
                    mainID: PositionalDisplays.liveMainID
                )
            else { return }
            apply(composed: composed)
            profiles.adoptStandard(named: composed.sourceName)
            onLog(
                "monitor change: no matching profile, "
                    + "composed standard '\(composed.sourceName)'"
            )
        }
    }
}

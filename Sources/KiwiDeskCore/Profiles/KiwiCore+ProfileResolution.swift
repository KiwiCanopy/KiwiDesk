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

    /// Applies a built-in Preset and materializes it as a real,
    /// editable profile named after the preset (`_N`-suffixed
    /// when taken; repeated Applies accumulate copies — #53).
    /// Spaces planned for the main display take the Main role;
    /// secondary-screen spaces pin to the live fingerprints.
    /// Returns the saved profile's name.
    @discardableResult
    public func applyStandard(
        _ layout: StandardLayout
    ) throws -> String {
        let displays = state.workspaces.allDisplays
        guard displays.count == layout.screenCount else {
            throw ProfileSaveError.screenCountMismatch(
                expected: layout.screenCount,
                live: displays.count
            )
        }
        let mainID = PositionalDisplays.liveMainID
        guard
            let composed = ProfileComposition.compose(
                layout: layout,
                displays: displays,
                mainID: mainID
            )
        else {
            throw ProfileSaveError.screenCountMismatch(
                expected: layout.screenCount,
                live: 0
            )
        }
        apply(composed: composed)
        let ordered = PositionalDisplays.ordered(
            displays,
            mainID: mainID
        )
        var pins: [SpaceID: String] = [:]
        var mains: Set<SpaceID> = []
        for space in composed.spaces {
            let assigned = composed.assignment[space]
            if assigned == ordered.first?.id || assigned == nil {
                mains.insert(space)
            } else if let display = ordered.first(where: {
                $0.id == assigned
            }) {
                pins[space] = display.fingerprint
            }
        }
        spacePins = pins
        mainSpaces = mains
        let name = profiles.freeName(base: layout.name)
        try profiles.save(buildProfile(name: name))
        return name
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

    /// Re-applies the active profile (or recomposes the active
    /// Standard) after a config reload, so the Lua base state
    /// never clobbers profile-owned tiling. No-op in the plain
    /// transient state.
    func reapplyActiveProfileState() {
        if let name = profiles.currentName,
            let profile = try? profiles.read(name: name)
        {
            apply(profile: profile)
        } else if profiles.currentStandard != nil,
            let composed = ProfileComposition.compose(
                displays: state.workspaces.allDisplays,
                mainID: PositionalDisplays.liveMainID
            )
        {
            apply(composed: composed)
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

        // A native-Space binding wins over matching (#7); a
        // binding that fails to load falls through to matching.
        if let number = NativeSpaces.activeSpaceNumber(),
            let boundName = nativeSpaceBindings[number]
        {
            do {
                let bound = try profiles.load(name: boundName)
                apply(profile: bound)
                if bound.set(matching: fingerprints) == nil {
                    profiles.markDirty()
                }
                onLog(
                    "monitor change: loaded bound profile "
                        + "'\(boundName)'"
                )
                return
            } catch {
                onLog(
                    "cannot load bound profile "
                        + "'\(boundName)': \(error)"
                )
            }
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
                // Same profile back on one of its exact sets
                // (e.g. re-docked after an interim mismatch):
                // re-adopt so a lingering dirty flag clears,
                // and re-resolve with that set's pins.
                profiles.adopt(profile)
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
            // A hand-written Lua config (no gui.json) owns its
            // tiling: the Standard only steers placement, and
            // no transient-standard state is adopted — the Lua
            // base survives reloads untouched (#36 promise).
            guard guiConfigStore.exists else {
                resolveSpaceDisplays()
                retile()
                emitSpaceChange()
                onLog(
                    "monitor change: no matching profile, "
                        + "placement follows standard "
                        + "'\(composed.sourceName)' "
                        + "(Lua-owned tiling untouched)"
                )
                return
            }
            apply(composed: composed)
            profiles.adoptStandard(named: composed.sourceName)
            onLog(
                "monitor change: no matching profile, "
                    + "composed standard '\(composed.sourceName)'"
            )
        }
    }
}

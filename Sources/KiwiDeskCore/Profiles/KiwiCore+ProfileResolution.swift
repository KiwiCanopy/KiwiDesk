import Foundation

/// Applying profiles and the total space→display resolution
/// (#36), including the monitor-change matching that decides
/// what to apply (#53 fallback composition).
extension KiwiCore {
    // MARK: - Applying

    /// Applies a profile to live state and retiles. An explicit
    /// user load passes `pruneStaleSpaces: true` so the profile's
    /// space set becomes authoritative (see `pruneSpaces`);
    /// hardware-driven applies (monitor change, native-space
    /// binding) leave it false to avoid shuffling windows on a
    /// reconnect.
    func apply(
        profile: Profile,
        pruneStaleSpaces: Bool = false
    ) {
        tiler.settings = profile.settings
        let declared = profile.declaredSpaces
        for id in declared {
            state.workspaces.ensureSpace(id)
        }
        if pruneStaleSpaces {
            pruneSpaces(keeping: declared)
        }
        // Dense over all live spaces: a space a (hand-edited,
        // sparse) profile doesn't declare reverts to bsp
        // instead of keeping the previous state's mode.
        for space in state.workspaces.allSpaces {
            state.workspaces.setMode(
                space.id,
                profile.spaceModes[space.id] ?? .bsp
            )
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

    /// Explicit-load reconcile: drop live spaces whose name isn't
    /// in the new profile, forwarding any windows they hold to the
    /// profile's first space so none are orphaned. A space whose
    /// name also exists in the new profile is kept untouched — its
    /// windows stay put regardless of the layout difference. The
    /// fallback follows the same order the Spaces list shows; a
    /// user-chosen order is a follow-up (roadmap #27).
    private func pruneSpaces(keeping survivors: Set<SpaceID>) {
        guard
            let fallback =
                GuiConfig.orderedSpaces(Array(survivors)).first
        else { return }
        for space in state.workspaces.allSpaces
        where !survivors.contains(space.id) {
            for window in space.windows {
                state.workspaces.add(window, to: fallback)
            }
            state.workspaces.removeSpace(space.id)
        }
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
                live: displays.count
            )
        }
        apply(composed: composed)
        // If the save below fails, state honestly reflects a
        // transient Standard instead of a stale profile.
        profiles.adoptStandard(named: composed.sourceName)
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

    /// Total space→display resolution (#36): every space gets
    /// a screen via the shared `SpacePlacement` precedence,
    /// written into workspace state so the GUI renders the
    /// resolved mapping.
    func resolveSpaceDisplays(
        mainID: DisplayID = PositionalDisplays.liveMainID
    ) {
        let displays = state.workspaces.allDisplays
        // The one unresolvable state; resolve() below can then
        // never return nil.
        guard !displays.isEmpty else { return }
        let assignment =
            ProfileComposition.compose(
                displays: displays,
                mainID: mainID
            )?.assignment ?? [:]
        for space in state.workspaces.allSpaces {
            guard
                let resolved = SpacePlacement.resolve(
                    space: space.id,
                    pins: spacePins,
                    mainSpaces: mainSpaces,
                    displays: displays,
                    mainID: mainID,
                    assignment: assignment
                )
            else { continue }
            state.workspaces.assign(
                space.id,
                to: resolved.display.id
            )
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
            // A hand-written or hybrid Lua config keeps
            // owning tiling: the Standard only steers
            // placement and no transient-standard state is
            // adopted, so with no active profile the Lua base
            // survives reloads untouched (#36 promise). A
            // still-active profile keeps its tiling and its
            // still-valid pins, but goes dirty — the same
            // rule as load_profile onto other hardware.
            guard isGuiManaged else {
                if profiles.currentName != nil {
                    profiles.markDirty()
                }
                resolveSpaceDisplays()
                retile()
                emitSpaceChange()
                onLog(
                    "monitor change: no matching profile, "
                        + "placement follows standard "
                        + "'\(composed.sourceName)' (tiling "
                        + "stays Lua/profile-owned)"
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

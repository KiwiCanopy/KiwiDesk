import Foundation

/// Applying profiles and the total space→display resolution
/// (#36). The monitor-change matching that decides what to apply
/// lives in `KiwiCore+MonitorChange`.
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
        // The engine's cached durations sync via
        // `TilingEngine.settings.didSet` (#51).
        tiler.settings = profile.settings
        let declared = profile.declaredSpaces
        // Seed live order from the profile's stored list so
        // creation order matches display order. Using
        // orderedSpaces (never the declaredSpaces Set) means
        // WorkspaceManager.order follows the profile's list,
        // not Set-hash order — making the subsequent
        // buildProfile capture deterministic and faithful.
        // `ensureSpace` early-returns for spaces that already
        // exist (profile switch with shared names), so
        // reconcile the order explicitly (#75/#55).
        for id in profile.orderedSpaces {
            state.workspaces.ensureSpace(id)
        }
        state.workspaces.reorder(
            matching: profile.orderedSpaces
        )
        if pruneStaleSpaces {
            pruneSpaces(
                keeping: declared,
                orderedBy: profile.orderedSpaces
            )
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
        // Per-profile keybinding tier (#55 phase 6): register
        // THIS profile's override (base survives unmentioned,
        // O4 soft). Passed explicitly — callers adopt after
        // apply, so `currentName` may still be the old profile.
        reapplyStructuredKeybindings(
            profileModes: profile.modes
        )
        resolveSpaceDisplays()
        retile()
        emitSpaceChange()
    }

    /// Explicit-load reconcile: drop live spaces whose name isn't
    /// in the new profile, forwarding any windows they hold to
    /// the rehome target so none are orphaned. A space whose
    /// name also exists in the new profile is kept untouched —
    /// its windows stay put regardless of the layout difference.
    ///
    /// `orderedBy` is the profile's `orderedSpaces` list (#75):
    /// the rehome target is the first element that is also a
    /// survivor, so windows land in the first space of the new
    /// profile's displayed list. When both lists are empty
    /// (degenerate call) the guard skips pruning entirely.
    private func pruneSpaces(
        keeping survivors: Set<SpaceID>,
        orderedBy storedOrder: [SpaceID]
    ) {
        // `orderedSpaces ⊆ declaredSpaces == survivors` so a
        // non-empty storedOrder always has a match — nil only
        // when storedOrder itself is empty (empty profile).
        let fallback = storedOrder.first {
            survivors.contains($0)
        }
        guard let fallback else { return }
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
        // A transient Standard has no keybinding override —
        // revert to the base gui.json modes (#55 phase 6).
        reapplyStructuredKeybindings(profileModes: nil)
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
}

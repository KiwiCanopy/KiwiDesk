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
    ///
    /// `forceRetile` has no default so every caller classifies
    /// itself (AGENTS.md §5): explicit applies — load_profile,
    /// an in-effect edit re-apply, the post-reload re-apply —
    /// force past the engine's ±2 pt tolerance so a small
    /// settings change can't be swallowed; event-driven applies
    /// (monitor change, native-space binding) stay un-forced so
    /// AX-echo lag can't wobble windows.
    ///
    /// Growth threshold (review 2026-07): two classification
    /// Bools is the ceiling. A THIRD would be the point to
    /// fold them into one apply-intent value (.userExplicit /
    /// .hardwareEvent) — do not add Bool #3. The session
    /// ratio-layer clear (#458) rides this same classification;
    /// an eventual fold carries it along.
    func apply(
        profile: Profile,
        pruneStaleSpaces: Bool = false,
        forceRetile: Bool
    ) {
        // The engine's cached durations sync via
        // `TilingEngine.settings.didSet` (#51).
        tiler.settings = profile.settings
        // An EXPLICIT apply reseeds the session resize layer
        // (#458): the incoming settings are the new truth, and
        // a session shadow would make the profile's ratios
        // visibly do nothing (§5 forced-retile rationale).
        // Event-driven applies (monitor change, native-space
        // binding) keep it — a display reconnect must not eat
        // the user's interactive resizes.
        if forceRetile {
            clearSessionRatios { $0 = SessionRatios() }
        }
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
                orderedBy: profile.orderedSpaces,
                preferring: profile.fallbackSpace
            )
            // An authoritative reconcile just fixed the live space
            // set — mirror it into the sidecar so the cold-boot
            // seed can't re-inject a space this prune dropped
            // (#77). No-op when not GUI-managed.
            syncGuiSpacesToLive()
        }
        // Dense over all live spaces: a space a (hand-edited,
        // sparse) profile doesn't declare reverts to bsp
        // instead of keeping the previous state's mode.
        for space in state.workspaces.allSpaces {
            setSpaceMode(
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
        // Adopt the profile's explicit rehome target (#68);
        // a dangling reference reads as unset.
        fallbackSpace = profile.fallbackSpace.flatMap {
            declared.contains($0) ? $0 : nil
        }
        // Per-profile override tiers — keybindings (#55 phase
        // 6) and app rules (#109): register THIS profile's
        // overrides (base survives unmentioned). Passed
        // explicitly — callers adopt after apply, so
        // `currentName` may still be the old profile.
        reapplyStructuredOverrides(
            profileModes: profile.modes,
            profileAppRules: profile.appRules,
            profileFloatRules: profile.floatRules,
            profileIgnoreRules: profile.ignoreRules
        )
        resolveSpaceDisplays()
        retile(force: forceRetile)
        emitSpaceChange()
    }

    /// Explicit-load reconcile: drop live spaces whose name isn't
    /// in the new profile, forwarding any windows they hold to
    /// the rehome target so none are orphaned. A space whose
    /// name also exists in the new profile is kept untouched —
    /// its windows stay put regardless of the layout difference.
    ///
    /// `preferring` is the profile's explicit fallback space
    /// (#68): when it names a survivor, windows rehome there.
    /// Otherwise `orderedBy` — the profile's `orderedSpaces`
    /// list (#75) — decides: the rehome target is the first
    /// element that is also a survivor, so windows land in the
    /// first space of the new profile's displayed list. When
    /// both lists are empty (degenerate call) the guard skips
    /// pruning entirely.
    ///
    /// `internal` (not `private`): the GUI save path
    /// (`applyProfileScopedState`) reuses this same reconcile so a
    /// Spaces-tab deletion drops the space from live too (#77),
    /// not just profile loads.
    func pruneSpaces(
        keeping survivors: Set<SpaceID>,
        orderedBy storedOrder: [SpaceID],
        preferring explicit: SpaceID? = nil
    ) {
        // `orderedSpaces ⊆ declaredSpaces == survivors` so a
        // non-empty storedOrder always has a match — nil only
        // when storedOrder itself is empty (empty profile).
        let fallback =
            explicit.flatMap {
                survivors.contains($0) ? $0 : nil
            }
            ?? storedOrder.first {
                survivors.contains($0)
            }
        guard let fallback else { return }
        for space in state.workspaces.allSpaces
        where !survivors.contains(space.id) {
            for window in space.windows {
                state.workspaces.add(window, to: fallback)
                // A rehome is a cross-space move: a float whose
                // fallback lives on another display re-anchors
                // (#444). A later `resolveSpaceDisplays` moving
                // the fallback re-translates from the seeded
                // capture, so the order composes.
                reanchorFloat(window, to: fallback)
            }
            state.workspaces.removeSpace(space.id)
        }
    }

    /// Applies a composed Standard fallback (#53): transient,
    /// nothing is written until the user saves. `forceRetile`
    /// classifies the caller like `apply(profile:)`.
    func apply(
        composed: ProfileComposition.Composed,
        forceRetile: Bool
    ) {
        tiler.settings = composed.settings
        // Same explicit-apply reseed as `apply(profile:)`.
        if forceRetile {
            clearSessionRatios { $0 = SessionRatios() }
        }
        for space in composed.spaces {
            state.workspaces.ensureSpace(space)
            setSpaceMode(
                space,
                composed.spaceModes[space] ?? .bsp
            )
        }
        spacePins = [:]
        mainSpaces = []
        fallbackSpace = nil
        // A transient Standard has no keybinding or app-rule
        // override — revert to the base gui.json config
        // (#55 phase 6, #109).
        reapplyStructuredOverrides(
            profileModes: nil,
            profileAppRules: nil,
            profileFloatRules: nil,
            profileIgnoreRules: nil
        )
        resolveSpaceDisplays()
        retile(force: forceRetile)
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
        apply(composed: composed, forceRetile: true)
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
        var relocated: [SpaceID] = []
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
            let previous = state.workspaces.display(of: space.id)
            state.workspaces.assign(
                space.id,
                to: resolved.display.id
            )
            if let previous, previous != resolved.display.id {
                relocated.append(space.id)
            }
        }
        // Every space-relocation path funnels through this
        // resolve — monitor re-dock, profile apply, config
        // reload, pin displacement — so the cross-display float
        // re-anchor lives HERE (#444 review), not per verb. A
        // first-ever assignment (`previous == nil`, boot) is not
        // a relocation.
        for space in relocated {
            reanchorFloats(of: space)
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
            // Explicit: reloads follow a config/profile edit
            // whose deltas may sit inside the tolerance.
            apply(profile: profile, forceRetile: true)
        } else if profiles.currentStandard != nil,
            let composed = ProfileComposition.compose(
                displays: state.workspaces.allDisplays,
                mainID: PositionalDisplays.liveMainID
            )
        {
            apply(composed: composed, forceRetile: true)
        }
    }
}

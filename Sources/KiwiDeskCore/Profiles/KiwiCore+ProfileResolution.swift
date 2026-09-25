import Foundation

/// Applying profiles and the total space→display resolution
/// (#36). The monitor-change matching that decides what to apply
/// lives in `KiwiCore+MonitorChange`.
extension KiwiCore {
    // MARK: - Applying

    /// Applies a profile to live state and retiles. `cause` has
    /// no default so every caller classifies itself (AGENTS.md
    /// §5) — `ProfileApplyCause` states what each one implies.
    /// The prune has two independent causes (`cause.prunesStale
    /// || switching`), and the session ratio-layer clear rides
    /// both an explicit apply and a profile change (#458, #764).
    func apply(
        profile: Profile,
        cause: ProfileApplyCause
    ) {
        let pruneStaleSpaces = cause.prunesStale
        let forceRetile = cause.forcesRetile
        supersedeMonitorSettle()
        // #1230: file the OUTGOING profile's partitioning before
        // anything rebuilds the space set, and learn in one
        // answer whether this apply is a profile CHANGE — which
        // gates the session clear, the prune below and the
        // restore after it.
        let switching = recordOutgoingPartitioning(before: profile)
        // A held Space keeps the icon it had where it lived (#1507),
        // read before the incoming settings replace them.
        let outgoingIcons = tiler.settings.spaceIcons
        // The engine's cached durations sync via
        // `TilingEngine.settings.didSet` (#51).
        tiler.settings = profile.settings
        // The session layer reseeds on an explicit apply, and on
        // any apply that CHANGES the profile — it outranks the
        // incoming authored overrides (#458, #764). A same-
        // profile event apply keeps it.
        if forceRetile || switching {
            clearSessionRatios { $0 = SessionRatios() }
        }
        let declared = profile.declaredSpaces
        // A seed this profile declares is its own now (#1175).
        retireHealedSpaces(declared: declared)
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
        // A profile CHANGE always replaces the space set (#1230):
        // name-matching into the outgoing profile's Spaces is what
        // made two profiles' `1` the same Space, and merged an
        // arrangement away for good. Derived, not a third
        // classification Bool — the growth threshold above stands.
        // #1507: an unplug holds the gone screen's Spaces; an
        // explicit load ends every hold and prunes them like any
        // undeclared Space.
        if cause == .monitorChange, switching {
            holdDepartingSpaces(declared: declared, icons: outgoingIcons)
        }
        if pruneStaleSpaces { forgetHeldSpaces() }
        if pruneStaleSpaces || switching {
            pruneSpaces(
                keeping: declared.union(state.heldSpaces.keys),
                orderedBy: profile.orderedSpaces,
                preferring: profile.fallbackSpace
            )
        }
        if pruneStaleSpaces {
            // An authoritative reconcile just fixed the live space
            // set — mirror it into the sidecar so the cold-boot
            // seed can't re-inject a space this prune dropped
            // (#77). No-op when not GUI-managed. A switch-driven
            // prune deliberately does NOT sync: the sidecar is the
            // user's managed config, and a Desktop binding
            // swapping profiles under them must not rewrite it.
            syncGuiSpacesToLive()
        }
        // #1230: and now put this profile's own windows back into
        // its own Spaces. After the prune, so what the profile has
        // never seen is already in its `fallback_space`.
        if switching { restorePartitioning(of: profile) }
        // Dense over all live spaces: a space a (hand-edited,
        // sparse) profile doesn't declare reverts to bsp
        // instead of keeping the previous state's mode.
        for space in state.workspaces.allSpaces
        where state.heldSpaces[space.id] == nil {
            setSpaceMode(
                space.id,
                profile.spaceModes[space.id] ?? .bsp
            )
        }
        // Adopt the pins of the set covering the live monitors
        // (none when the profile loads dirty on other hardware)
        // and the profile-wide Main role.
        let live = liveFingerprints
        let fitting = profile.set(matching: live)
        let fits = fitting != nil
        spacePins = fitting?.spaceMonitorMap ?? [:]
        mainSpaces = Set(profile.mainSpaces)
        // Adopt the profile's explicit rehome target (#68);
        // a dangling reference reads as unset.
        fallbackSpace = profile.fallbackSpace.flatMap {
            declared.contains($0) ? $0 : nil
        }
        // After the pins, which a held Space's home pin joins.
        refileHeldSpaces(declared: declared)
        // Per-profile override tiers — keybindings (#55 phase
        // 6) and app rules (#109): register THIS profile's
        // overrides (base survives unmentioned). Passed
        // explicitly — callers adopt after apply, so
        // `currentName` may still be the old profile.
        reapplyStructuredOverrides(
            profileModes: profile.layers,
            profileAppRules: profile.appRules,
            profileFloatRules: profile.floatRules,
            profileIgnoreRules: profile.ignoreRules
        )
        // A renumbered held Space owes its ⌃⌥N (#485's top-up).
        if !state.heldSpaces.isEmpty { topUpDigitShortcuts() }
        resolveSpaceDisplays()
        retile(pass: forceRetile ? .apply : .event)
        emitSpaceChange()
        // #1145: a profile may override `desktop_reach` — after
        // the pins and the space→display resolve the carry's
        // home-screen read rests on. Its own topology read on
        // purpose: this door is also a no-snapshot verb path
        // (`load_profile`), and the carry is idempotent.
        refreshStickyReach()
        // LAST, and this door's alone (#1249): everything above
        // still reads the OUTGOING name, which is why
        // `reapplyStructuredOverrides` is handed the incoming
        // profile's tiers explicitly. `fits` is the #36 verdict,
        // read off the set already matched for the pins.
        profiles.becameLive(profile, fits: fits)
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
            forwardWindows(of: space.id, to: fallback)
        }
    }

    /// Applies a composed Standard fallback (#53): transient,
    /// nothing is written until the user saves. `forceRetile`
    /// classifies the caller like `apply(profile:)`.
    func apply(
        composed: ProfileComposition.Composed,
        forceRetile: Bool
    ) {
        supersedeMonitorSettle()
        // #1230: a Standard is not a profile — file whatever
        // profile was live before the compose rearranges it, or
        // its arrangement is what gets recorded under that
        // profile's name at the next switch. Standing the name
        // down is this door's too, not its caller's (#1249).
        recordLivePartitioning()
        // A seed the Standard plans is its own now (#1175).
        retireHealedSpaces(declared: Set(composed.spaces))
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
        // Honor the composed layout's own positional plan (#485):
        // for a workflow Standard this equals what
        // `resolveSpaceDisplays` re-derives below, but the setup's
        // five-per-display plan is NOT the count's Standard, so its
        // blocks would otherwise scatter into the Standard's slots.
        adoptComposedPlacement(composed)
        refileHeldSpaces(declared: Set(composed.spaces))
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
        retile(pass: forceRetile ? .apply : .event)
        emitSpaceChange()
        // #1145: same tail as `apply(profile:)`, same reasons.
        refreshStickyReach()
        // Last, like `apply(profile:)`'s `becameLive` — and after
        // `recordLivePartitioning` by constraint: it files under
        // the outgoing name, which this call stands down
        // (`ProfileSaveAdoptionTests`).
        profiles.standardIsLive(
            ActiveStandard(
                name: composed.sourceName,
                spaces: Set(composed.spaces)
            )
        )
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
        // `apply(composed:)` adopts the composed placement, so the
        // pins/mains `buildProfile` captures below are already set
        // — and files the Standard, so if the save below fails,
        // state honestly reflects a transient Standard instead of
        // a stale profile, and `buildProfile` tags the starter
        // setup from `currentStandard` (#485).
        apply(composed: composed, forceRetile: true)
        let name = profiles.freeName(base: layout.name)
        // Capture-live: the standard was just adopted onto
        // live above, so live IS what this profile records.
        try saveProfile(
            buildProfile(name: name, modes: nil)
        )
        // A preset can define more spaces than the first-run seed
        // authored digit shortcuts for; bind the newcomers
        // additively so ⌃⌥N covers them too (#485).
        topUpDigitShortcuts()
        return name
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
            apply(profile: profile, cause: .reapply)
        } else if profiles.currentStandard != nil,
            let composed = composeMonitorChangeFallback(
                displays: state.workspaces.allDisplays
            )
        {
            // Recompose through the same baseline-aware fallback as
            // a monitor change, so a reload while on the transient
            // Starter Standard re-applies the LADDER, not the count's
            // workflow Standard (#485). `apply` adopts its placement
            // and files what it recomposed (#1509).
            apply(composed: composed, forceRetile: true)
        }
    }
}

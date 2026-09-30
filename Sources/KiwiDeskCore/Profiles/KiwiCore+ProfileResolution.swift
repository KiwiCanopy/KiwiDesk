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
        // Owed #1741 and #1752 crossings end at the first apply.
        profiles.arrangementInFlight += 1  // #1790: no retire mid-apply
        defer { profiles.arrangementInFlight -= 1 }
        adoptAppWide(from: profile)
        adoptSharedLook(from: profile)
        let pruneStaleSpaces = cause.prunesStale
        let forceRetile = cause.forcesRetile
        supersedeMonitorSettle()
        // #1230: file the OUTGOING profile's partitioning before
        // anything rebuilds the space set, and learn in one
        // answer whether this apply is a profile CHANGE — which
        // gates the session clear, the prune below and the
        // restore after it.
        // A held number this profile claims moves off it first.
        reclaimHeldNames(
            declared: profile.declaredSpaces,
            into: .profile(profile.name)
        )
        // Read before anything moves what is live or declared (#1790).
        let temporaries = Set(liveTemporarySpaces)
        let switching = recordOutgoingPartitioning(before: profile)
        // A held Space keeps the icon it had where it lived (#1507),
        // read before the incoming settings replace them.
        let outgoingIcons = tiler.settings.spaceIcons
        // The engine's cached durations sync via
        // `TilingEngine.settings.didSet` (#51).
        tiler.settings = resolvedSettings(of: profile)
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
        // #1507/#1790: a switch holds every Space the incoming
        // profile does not name that still holds windows; the
        // prune below drops the empty ones.
        if switching {
            holdDepartingSpaces(
                declared: declared,
                icons: outgoingIcons,
                temporaries: temporaries,
                alsoHolding: {
                    !declared.contains($0) && self.liveArrangement != nil
                }
            )
        }
        // One the incoming profile declares is that profile's now;
        // a same-profile Load or a reload keeps them (#1790).
        if pruneStaleSpaces || switching {
            pruneSpaces(
                keeping: declared.union(state.heldSpaces.keys)
                    .union(switching ? [] : temporaries),
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
        if switching { restoreProfilePartitioning(of: profile) }
        // Dense over all live spaces: a space a (hand-edited,
        // sparse) profile doesn't declare reverts to bsp
        // instead of keeping the previous state's mode.
        // A held or temporary Space's mode is its own (#1507, #1790).
        for space in state.workspaces.allSpaces
        where state.heldSpaces[space.id] == nil
            && !(temporaries.contains(space.id)
                && !declared.contains(space.id))
        {
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
        spacePins = keepingPins(
            of: temporaries.subtracting(declared),
            over: fitting?.spaceMonitorMap ?? [:]
        )
        mainSpaces = Set(profile.mainSpaces)
        // Adopt the profile's explicit rehome target (#68);
        // a dangling reference reads as unset.
        fallbackSpace = profile.fallbackSpace.flatMap {
            declared.contains($0) ? $0 : nil
        }
        // After the pins, which a held Space's home pin joins; one
        // back under its own name takes this profile's mode.
        for id in refileHeldSpaces(
            declared: declared,
            into: .profile(profile.name)
        ) {
            setSpaceMode(id, profile.spaceModes[id] ?? .bsp)
        }
        // Per-profile override tiers — keybindings (#55 phase
        // 6) and app rules (#109): register THIS profile's
        // overrides (base survives unmentioned). Passed
        // explicitly — callers adopt after apply, so
        // `currentName` may still be the old profile.
        reapplyStructuredOverrides(
            profileModes: profile.layers,
            profileAppRules: profile.appRules,
            profileFloatRules: profile.floatRules,
            profileIgnoreRules: profile.ignoreRules,
            profileScrollGesture: profile.scrollGesture
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
        updateBars()  // #1790: the adoption moved `isTemporary`
    }

    /// Applies a composed Standard fallback (#53): transient,
    /// nothing is written until the user saves. `forceRetile`
    /// classifies the caller like `apply(profile:)`.
    func apply(
        composed: ProfileComposition.Composed,
        forceRetile: Bool
    ) {
        supersedeMonitorSettle()
        profiles.arrangementInFlight += 1  // #1790: no retire mid-apply
        defer { profiles.arrangementInFlight -= 1 }
        let temporaries = Set(liveTemporarySpaces)
        let outgoingIcons = tiler.settings.spaceIcons
        reclaimHeldNames(
            declared: Set(composed.spaces),
            into: .standard(composed.sourceName)
        )
        // #1230/#1829: a Standard is an arrangement like a
        // profile — file the outgoing one, restore its own.
        let standard = HeldOrigin.Arrangement.standard(composed.sourceName)
        let switching = recordOutgoingPartitioning(before: standard)
        // A seed the Standard plans is its own now (#1175).
        retireHealedSpaces(declared: Set(composed.spaces))
        tiler.settings = wearingSharedLook(composed.settings)
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
        adoptComposedPlacement(
            composed,
            keepingPinsOf: temporaries.subtracting(composed.spaces)
        )
        if switching {
            holdForStandard(
                planned: composed.spaces,
                icons: outgoingIcons,
                temporaries: temporaries
            )
            restorePartitioning(of: standard, declaring: Set(composed.spaces))
        }
        refileHeldSpaces(
            declared: Set(composed.spaces),
            into: .standard(composed.sourceName)
        )
        fallbackSpace = nil
        // A transient Standard has no keybinding or app-rule
        // override — revert to the base gui.json config
        // (#55 phase 6, #109).
        reapplyStructuredOverrides(
            profileModes: nil,
            profileAppRules: nil,
            profileFloatRules: nil,
            profileIgnoreRules: nil,
            profileScrollGesture: nil
        )
        resolveSpaceDisplays()
        retile(pass: forceRetile ? .apply : .event)
        emitSpaceChange()
        // #1145: same tail as `apply(profile:)`, same reasons.
        refreshStickyReach()
        // Last, like `apply(profile:)`'s `becameLive`: the filing
        // above read the outgoing arrangement, which this stands
        // down (`ProfileSaveAdoptionTests`).
        profiles.standardIsLive(
            ActiveStandard(
                name: composed.sourceName,
                spaces: Set(composed.spaces),
                title: composed.sourceTitle
            )
        )
        updateBars()  // #1790: the adoption moved `isTemporary`
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
        let name = profiles.freeName(
            base: layout.starterTitle?.profileName ?? layout.name
        )
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

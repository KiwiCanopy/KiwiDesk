import Foundation

/// Thrown when a profile save cannot honor the live monitors.
enum ProfileSaveError: Error, CustomStringConvertible {
    case screenCountMismatch(expected: Int, live: Int)

    var description: String {
        switch self {
        case .screenCountMismatch(let expected, let live):
            return
                "profile is for \(expected) screen(s), "
                + "\(live) connected"
        }
    }
}

/// Profile commands and monitor-change handling (#36/#53).
extension KiwiCore {
    // MARK: - Commands

    func profileCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "save_profile":
            return namedProfileCommand(args) { name in
                // Capture-live, like the quick menu's Keep.
                try self.persistProfile(named: name, modes: nil)
            }
        case "load_profile":
            return namedProfileCommand(args) { name in
                let profile = try self.profiles.load(
                    name: name
                )
                // Explicit user load: the profile's spaces become
                // authoritative — stale spaces are pruned and
                // their windows forwarded (see `pruneSpaces`).
                self.apply(
                    profile: profile,
                    pruneStaleSpaces: true,
                    forceRetile: true
                )
                // A profile saved for other monitors stays
                // loadable but loads dirty (#36).
                let live = self.state.workspaces.allDisplays
                    .map(\.fingerprint)
                if profile.set(matching: live) == nil {
                    self.profiles.markDirty()
                }
            }
        case "delete_profile":
            return namedProfileCommand(args) { name in
                try self.profiles.delete(name: name)
                self.handleMonitorChange()
                // A broken profile's issue clears with it.
                self.refreshConfigIssues()
            }
        case "set_default_profile":
            return namedProfileCommand(args) { name in
                try self.profiles.setDefault(name: name)
            }
        case "list_profiles":
            return .ok(
                .array(
                    profiles.list().map { .string($0) }
                )
            )
        case "get_profile_status":
            return .ok(
                .object([
                    "name": profiles.currentName.map {
                        .string($0)
                    } ?? .null,
                    "standard": profiles.currentStandard.map {
                        .string($0)
                    } ?? .null,
                    "isDirty": .bool(profiles.isDirty),
                ])
            )
        default:
            return .fail("unknown command: \(command)")
        }
    }

    private func namedProfileCommand(
        _ args: [JSONValue],
        _ body: (String) throws -> Void
    ) -> CommandResponse {
        guard let name = args.first?.stringValue,
            !name.isEmpty
        else {
            return .fail("expected profile name")
        }
        do {
            try body(name)
            return .ok()
        } catch {
            return .fail("\(error)")
        }
    }

    // MARK: - Building / persisting

    /// Writes a composed layout's positional `assignment` into the
    /// live `spacePins` + `mainSpaces` — the composed-placement
    /// primitive behind `apply(composed:)`. A space assigned to the
    /// main display (or unassigned) takes the Main role; the rest
    /// pin to their display's fingerprint. For a workflow Standard
    /// this equals what `resolveSpaceDisplays` re-derives from the
    /// count's Standard, so it's a no-op in effect; for the beginner
    /// setup, whose five-per-display plan is NOT the count's
    /// Standard, it's load-bearing — without it the blocks scatter
    /// into the Standard's slots (#485).
    func adoptComposedPlacement(
        _ composed: ProfileComposition.Composed
    ) {
        let ordered = PositionalDisplays.ordered(
            state.workspaces.allDisplays,
            mainID: PositionalDisplays.liveMainID
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
    }

    /// The connected monitors as a stored set, carrying the
    /// live space pins (pins to disconnected monitors drop).
    func liveMonitorSet() -> MonitorSet {
        MonitorSet(
            monitors: state.workspaces.allDisplays
                .map(\.fingerprint),
            spaceMonitorMap: spacePins
        )
    }

    /// Snapshot of the current configuration as a new profile
    /// carrying only the live monitor set. The live space order
    /// from `allSpaces` is captured as the profile's stored
    /// order (#75) so the Spaces list round-trips unchanged.
    /// `modes` is REQUIRED — see `persistProfile`. Dense over
    /// the LIVE spaces either way, which is only correct because
    /// the caller has already reconciled them (a GUI save runs
    /// `applyProfileScopedState` first).
    func buildProfile(
        name: String,
        modes overrides: [SpaceID: LayoutMode]?
    ) -> Profile {
        let liveSpaces = state.workspaces.allSpaces.map(\.id)
        let modes =
            overrides
            ?? Dictionary(
                uniqueKeysWithValues:
                    state.workspaces.allSpaces.map {
                        ($0.id, $0.mode)
                    }
            )
        return Profile(
            name: name,
            monitorSets: [liveMonitorSet()],
            mainSpaces: mainSpaces.sorted { $0.raw < $1.raw },
            // Carry the starter-setup identity when the live
            // layout IS that setup (#485): the transient Starter
            // Standard sets `currentStandard`, so a first save of
            // it stays a baseline that re-scales on later display
            // changes. `applyStandard` adopts the standard before
            // this, so the preset path is covered here too; a
            // save-as-new copy (which reads, not builds) is not.
            isStarterSetup: profiles.currentStandard
                == StarterSetup.name,
            spaces: liveSpaces,
            fallbackSpace: fallbackSpace.flatMap {
                liveSpaces.contains($0) ? $0 : nil
            },
            spaceModes: modes,
            settings: tiler.settings
        )
    }

    /// Persists the live configuration under `name`: an
    /// existing profile is updated (settings overwritten, the
    /// live monitor set added or refreshed), a new name creates
    /// a profile with only the live set. Updating a profile of
    /// a different screen count is refused — that state needs
    /// "save as new" (#36).
    ///
    /// `modes` is REQUIRED so every call site chooses (the
    /// `forceRetile` pattern, §5). Nil means capture live — the
    /// Keep verb's "write down what is on screen". A Settings
    /// Save passes its draft's modes, dense over the live
    /// spaces, because that write commits what was edited and a
    /// standing temporary layout is not in it (#1179).
    public func persistProfile(
        named name: String,
        modes: [SpaceID: LayoutMode]?
    ) throws {
        guard var existing = try? profiles.read(name: name)
        else {
            try profiles.save(
                buildProfile(name: name, modes: modes)
            )
            refreshConfigIssues()
            if modes == nil { onProfileCapturedLive(name) }
            return
        }
        let live = liveMonitorSet()
        guard existing.upsert(live) else {
            throw ProfileSaveError.screenCountMismatch(
                expected: existing.monitorCount,
                live: live.monitors.count
            )
        }
        let fresh = buildProfile(name: name, modes: modes)
        existing.spaces = fresh.spaces
        existing.fallbackSpace = fresh.fallbackSpace
        existing.spaceModes = fresh.spaceModes
        existing.mainSpaces = fresh.mainSpaces
        existing.settings = fresh.settings
        existing.savedAt = .now
        try profiles.save(existing)
        // Re-saving repairs an unreadable profile — clear its
        // issue without waiting for a config reload (#68).
        refreshConfigIssues()
        if modes == nil { onProfileCapturedLive(name) }
    }

    // The non-adopting edit writes (`overwriteProfile`,
    // `copyProfile`) and their shared transform live in
    // `KiwiCore+ProfileEdit.swift` (#18/#82).

    /// Whether `name` is the layout currently on screen — it is
    /// the active profile, or a native Space bound to it is the
    /// active one — so a non-adopting edit should hot-reload it
    /// (#18).
    public func isProfileInEffect(_ name: String) -> Bool {
        if profiles.currentName == name { return true }
        guard let active = NativeSpaces.activeDesktopNumber()
        else { return false }
        return desktopBindings[active] == name
    }

    /// Re-applies `name` to the live layout after an in-effect
    /// edit. The active profile re-applies in place (no adopt);
    /// a profile merely bound to the active native Space
    /// re-resolves through the shared monitor-change path so the
    /// binding picks up the freshly-written JSON (#18). That
    /// bound path runs the normal resolver, which *adopts* the
    /// bound profile (it is now the on-screen layout) — an
    /// intended live-state change, unlike the in-place branch.
    public func reapplyIfInEffect(_ name: String) {
        guard isProfileInEffect(name) else { return }
        if profiles.currentName == name,
            let fresh = try? profiles.read(name: name)
        {
            // Explicit re-apply of an in-effect edit; prunes so a
            // deleted space leaves live now, not at the next
            // load_profile (#77). Bound branch below keeps
            // monitor-change's no-prune-on-reconnect rule.
            apply(
                profile: fresh,
                pruneStaleSpaces: true,
                forceRetile: true
            )
        } else {
            handleMonitorChange()
        }
    }

    /// Names of profiles (other than `name`) already claiming
    /// the live monitor set — the GUI warns before Update
    /// makes the set ambiguous (#36 overlap policy).
    public func profilesClaimingLiveSet(
        excluding name: String
    ) -> [String] {
        let live = state.workspaces.allDisplays
            .map(\.fingerprint)
        return profiles.allProfiles()
            .filter {
                $0.name != name
                    && $0.set(matching: live) != nil
            }
            .map(\.name)
    }
}

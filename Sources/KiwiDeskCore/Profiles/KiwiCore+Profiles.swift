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
                try self.persistProfile(named: name)
            }
        case "load_profile":
            return namedProfileCommand(args) { name in
                let profile = try self.profiles.load(
                    name: name
                )
                self.apply(profile: profile)
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
    /// carrying only the live monitor set.
    func buildProfile(name: String) -> Profile {
        var modes: [String: LayoutMode] = [:]
        for space in state.workspaces.allSpaces {
            modes[space.id.raw] = space.mode
        }
        return Profile(
            name: name,
            monitorSets: [liveMonitorSet()],
            mainSpaces: mainSpaces.sorted { $0.raw < $1.raw },
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
    public func persistProfile(named name: String) throws {
        guard var existing = try? profiles.read(name: name)
        else {
            try profiles.save(buildProfile(name: name))
            return
        }
        let live = liveMonitorSet()
        guard existing.upsert(live) else {
            throw ProfileSaveError.screenCountMismatch(
                expected: existing.monitorCount,
                live: live.monitors.count
            )
        }
        let fresh = buildProfile(name: name)
        existing.spaceModes = fresh.spaceModes
        existing.mainSpaces = fresh.mainSpaces
        existing.settings = fresh.settings
        existing.savedAt = .now
        try profiles.save(existing)
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

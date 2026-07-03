import Foundation

/// Profile commands and monitor-change handling.
extension KiwiCore {
    // MARK: - Commands

    func profileCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "save_profile":
            guard let name = args.first?.stringValue else {
                return .fail("expected profile name")
            }
            do {
                try profiles.save(buildProfile(name: name))
                return .ok()
            } catch {
                return .fail("save failed: \(error)")
            }
        case "load_profile":
            guard let name = args.first?.stringValue else {
                return .fail("expected profile name")
            }
            do {
                let profile = try profiles.load(name: name)
                apply(profile: profile)
                return .ok()
            } catch {
                return .fail("load failed: \(error)")
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
                    "isDirty": .bool(profiles.isDirty),
                ])
            )
        default:
            return .fail("unknown command: \(command)")
        }
    }

    // MARK: - Building / applying

    /// Snapshot of the current configuration as a profile.
    func buildProfile(name: String) -> Profile {
        var modes: [String: LayoutMode] = [:]
        for space in state.workspaces.allSpaces {
            modes[space.id.raw] = space.mode
        }
        let displays = state.workspaces.allDisplays
        return Profile(
            name: name,
            fingerprints: displays.map(\.fingerprint),
            monitorCount: displays.count,
            spaceModes: modes,
            settings: tiler.settings
        )
    }

    /// Applies a profile to live state and retiles.
    func apply(profile: Profile) {
        tiler.settings = profile.settings
        for (raw, mode) in profile.spaceModes {
            let id = SpaceID(raw)
            state.workspaces.ensureSpace(id)
            state.workspaces.setMode(id, mode)
        }
        retile()
        emitSpaceChange()
    }

    // MARK: - Monitor changes

    /// Profile selection on monitor reconfiguration:
    /// direct fingerprint match -> monitor count match ->
    /// transient state (dirty flag for the GUI).
    func handleMonitorChange() {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return }
        let fingerprints = displays.map(\.fingerprint)
        if let matched = profiles.match(
            fingerprints: fingerprints,
            count: displays.count
        ) {
            if matched.name != profiles.currentName {
                apply(profile: matched)
                profiles.adopt(matched)
                onLog(
                    "monitor change: loaded profile "
                        + "'\(matched.name)'"
                )
            }
        } else {
            profiles.markDirty()
            onLog(
                "monitor change: no matching profile, "
                    + "using transient state"
            )
        }
    }
}

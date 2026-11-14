import Foundation

/// A stored screen setup as the Known screen setups card and
/// `list_monitor_sets` read it (#3324): one exact combination of
/// screens and the profile holding it.
public struct KnownMonitorSet: Hashable, Sendable {
    /// Sorted `Name:WxH` fingerprints — the setup's identity.
    public let monitors: [String]
    public let profile: String
    public let isConnected: Bool
    /// The profile holds no other setup, so forgetting this one
    /// leaves it dormant (#1530).
    public let isProfilesLast: Bool

    public init(
        monitors: [String],
        profile: String,
        isConnected: Bool,
        isProfilesLast: Bool
    ) {
        self.monitors = monitors
        self.profile = profile
        self.isConnected = isConnected
        self.isProfilesLast = isProfilesLast
    }
}

/// Why a forget wrote nothing — a case, never a GUI sentence
/// (core-boundaries.md). `description` is the CLI's English.
public enum MonitorSetForgetError: Error, Equatable,
    CustomStringConvertible
{
    /// The connected setup: the next Save would write it back.
    case connected
    /// No profile holds the setup.
    case unknown

    /// The `reason` code a command answers with.
    public var code: String {
        switch self {
        case .connected: return "connected_setup"
        case .unknown: return "unknown_setup"
        }
    }

    public var description: String {
        switch self {
        case .connected:
            return
                "The connected screen setup can't be forgotten; "
                + "disconnect those screens first."
        case .unknown:
            return
                "No profile holds that screen setup "
                + "(see list_monitor_sets)."
        }
    }
}

/// Forgetting a remembered screen setup (#3324): a page-level act
/// beside the claim-only chips, whose ruling amends #1530 in
/// `docs/design-decisions.md`.
extension KiwiCore {
    /// Every stored setup with its holder — the connected one
    /// first, then by profile, then by screens.
    public func knownMonitorSets() -> [KnownMonitorSet] {
        profiles.allProfiles()
            .flatMap { profile in
                profile.monitorSets.map { set in
                    KnownMonitorSet(
                        monitors: set.monitors,
                        profile: profile.name,
                        isConnected: isConnectedMonitorSet(set.monitors),
                        isProfilesLast: profile.monitorSets.count == 1
                    )
                }
            }
            .sorted {
                if $0.isConnected != $1.isConnected {
                    return $0.isConnected
                }
                return ($0.profile, $0.monitors.joined(separator: "\n"))
                    < ($1.profile, $1.monitors.joined(separator: "\n"))
            }
    }

    /// Forgets the stored setup `monitors` through the one strip a
    /// claim takes (`ProfileManager.strip`): it leaves its holder
    /// with its pins, nobody takes it, and a default left dormant
    /// keeps no flag. The holder's per-screen bar edges outside
    /// its remaining setups and the connected screens go, and so
    /// does every stored Desktop binding entry scoped to the
    /// setup. Returns the holders, sorted — one, save a
    /// hand-edited duplicate `settleSharedSets` has not settled.
    @discardableResult
    public func forgetMonitorSet(_ monitors: [String]) throws -> [String] {
        let wanted = MonitorSet(monitors: monitors).monitors
        guard !isConnectedMonitorSet(wanted) else {
            throw MonitorSetForgetError.connected
        }
        var holders: [String] = []
        // A holder written before a failed write keeps the forget,
        // so what follows it runs for the holders that landed.
        defer { followForget(wanted, from: holders) }
        for var holder in profiles.allProfiles() {
            guard ProfileManager.strip(wanted, from: &holder) != nil
            else { continue }
            holder.settings.keepScreenEdges(
                in: screenEdgeScope(monitorSets: holder.monitorSets)
            )
            try profiles.write(holder)
            holders.append(holder.name)
        }
        guard !holders.isEmpty else {
            throw MonitorSetForgetError.unknown
        }
        return holders.sorted()
    }

    /// The live copy of the holders' edges, the stored bindings
    /// and an open draft follow the files the forget wrote.
    private func followForget(_ setup: [String], from holders: [String]) {
        guard !holders.isEmpty else { return }
        if let current = profiles.currentName, holders.contains(current) {
            // Or the next Save writes the live copy's edges back.
            tiler.settings.keepScreenEdges(in: liveScreenEdgeScope)
        }
        forgetSetupBindings(setup)
        for name in holders {
            profiles.onCapturedLive(name, .forgottenSetup(monitors: setup))
        }
    }

    /// The stored bindings' entries scoped to `setup` go, through
    /// the one sidecar rewrite; `init.lua`'s own lines stay its
    /// own, as a rename leaves them (`renameProfile`).
    private func forgetSetupBindings(_ setup: [String]) {
        do {
            try rewriteSidecarBindings { $0.forgetSetup(setup) }
        } catch SidecarError.missing {
            // A hand-written config: nothing stored to follow.
        } catch {
            onLog("forget setup: binding follow failed: \(error)")
        }
    }

    /// `list_monitor_sets` and `forget_monitor_set`. English — a
    /// machine contract (core-boundaries.md).
    func monitorSetCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command == "forget_monitor_set" else {
            return .ok(.array(knownMonitorSets().map(Self.row)))
        }
        let screens = args.compactMap(\.stringValue)
        guard !screens.isEmpty, screens.count == args.count,
            !screens.contains("")
        else {
            return .fail(
                "expected screen fingerprints (see list_monitor_sets)"
            )
        }
        do {
            let holders = try forgetMonitorSet(screens)
            return .ok(
                .object([
                    "forgotten_from": .array(holders.map { .string($0) })
                ])
            )
        } catch let refusal as MonitorSetForgetError {
            return CommandResponse(
                status: "error",
                data: .object(["reason": .string(refusal.code)]),
                error: refusal.description
            )
        } catch {
            return .fail("\(error)")
        }
    }

    private static func row(_ set: KnownMonitorSet) -> JSONValue {
        .object([
            "screens": .array(set.monitors.map { .string($0) }),
            "profile": .string(set.profile),
            "connected": .bool(set.isConnected),
            "last_of_profile": .bool(set.isProfilesLast),
        ])
    }
}

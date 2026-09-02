import Foundation

/// One reading of every user Desktop's layer-0 windows (#1146),
/// shown Desktops included: which native Space hosts each window,
/// who owns it, and whether it is up or parked there. Pure once
/// built, so every consumer decides from one snapshot.
public struct DesktopCensus: Sendable, Equatable {
    public struct Host: Sendable, Equatable {
        public let space: SkyLight.SpaceID
        public let pid: pid_t
        /// Listed among the Desktop's UP windows — neither
        /// minimized nor hidden with its app.
        public let isUp: Bool

        public init(space: SkyLight.SpaceID, pid: pid_t, isUp: Bool) {
            self.space = space
            self.pid = pid
            self.isUp = isUp
        }
    }

    /// The Desktop hosting each layer-0 window of another process.
    public let hosts: [WindowID: Host]
    /// The user Desktops some display currently shows.
    public let shown: Set<SkyLight.SpaceID>

    public init(hosts: [WindowID: Host], shown: Set<SkyLight.SpaceID>) {
        self.hosts = hosts
        self.shown = shown
    }

    /// Hosted on a user Desktop nobody shows.
    public func isAway(_ id: WindowID) -> Bool {
        guard let host = hosts[id] else { return false }
        return !shown.contains(host.space)
    }

    /// The away windows a process owns, up ones first, by id.
    public func awayWindows(pid: pid_t) -> [WindowID] {
        hosts
            .filter { $0.value.pid == pid && isAway($0.key) }
            .sorted {
                ($0.value.isUp ? 0 : 1, $0.key.raw)
                    < ($1.value.isUp ? 0 : 1, $1.key.raw)
            }
            .map(\.key)
    }

    /// Builds the census from the topology and two readers —
    /// pure, so `DesktopCensusTests` needs no WindowServer. A
    /// window listed on more than one Desktop (an own
    /// all-spaces overlay) keeps a SHOWN host over an unshown
    /// one, so it is never read as away.
    static func build(
        spaces: [NativeSpace],
        owners: [WindowID: pid_t],
        ownPID: pid_t,
        list: (SkyLight.SpaceID, _ includingParked: Bool) -> [WindowID]?
    ) -> DesktopCensus? {
        var hosts: [WindowID: Host] = [:]
        let shown = Set(
            spaces.filter { $0.isCurrent && $0.isUser }.map(\.id)
        )
        for space in spaces where space.isUser {
            guard let all = list(space.id, true),
                let up = list(space.id, false)
            else { return nil }
            let upSet = Set(up)
            for id in all {
                guard let pid = owners[id], pid != ownPID else {
                    continue
                }
                if let existing = hosts[id],
                    shown.contains(existing.space)
                {
                    continue
                }
                hosts[id] = Host(
                    space: space.id,
                    pid: pid,
                    isUp: upSet.contains(id)
                )
            }
        }
        return DesktopCensus(hosts: hosts, shown: shown)
    }
}

extension NativeSpaces {
    #if DEBUG
        /// Pins the census a test's core reads (#1146).
        public static nonisolated(unsafe) var desktopCensusOverride:
            (([NativeSpace]) -> DesktopCensus?)?
    #endif

    /// The census against `spaces` — the caller's ONE topology
    /// reading, never re-read here. Nil where the per-Desktop
    /// list cannot be read: absent, not faked.
    public static func desktopCensus(
        spaces: [NativeSpace]
    ) -> DesktopCensus? {
        #if DEBUG
            if let override = desktopCensusOverride {
                return override(spaces)
            }
        #endif
        guard SkyLight.canListSpaceWindows else { return nil }
        return DesktopCensus.build(
            spaces: spaces,
            owners: AXHelper.allNormalWindowOwners(),
            ownPID: getpid()
        ) { space, parked in
            SkyLight.windows(on: space, includingParked: parked)?
                .map(WindowID.init)
        }
    }

    /// Whether the per-window Space read can answer at all, so a
    /// nil `nativeSpace(of:)` means "hosted nowhere" rather than
    /// "cannot tell" (#1146).
    public static var canReadWindowSpaces: Bool {
        #if DEBUG
            if windowSpaceOverride != nil { return true }
        #endif
        return SkyLight.connection != nil
            && SkyLight.copySpacesForWindows != nil
    }
}

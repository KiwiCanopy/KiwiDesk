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

    /// Builds the census from the topology and two readers —
    /// pure, so `DesktopCensusTests` needs no WindowServer. A
    /// window listed on more than one Desktop (an all-spaces
    /// overlay) keeps a SHOWN host over an unshown one, so it is
    /// never read as away. Our own windows are hosted like any
    /// other: the tiling Settings window is a tracked window
    /// (`OwnWindowTiling`), and a builder that skipped its
    /// process would prune it as closed the moment it was away.
    static func build(
        spaces: [NativeSpace],
        owners: [WindowID: pid_t],
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
                guard let pid = owners[id] else { continue }
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

/// The compositor's word on where ONE window is (#1146) — the
/// per-window sibling of `DesktopCensus`, read at a destroy.
public enum WindowSpaceReading: Sendable, Equatable {
    /// No SkyLight: nothing can be said.
    case unavailable
    /// Hosted on no Space at all.
    case gone
    case hosted(SkyLight.SpaceID)
}

extension NativeSpaces {
    /// The census against `spaces` — the caller's ONE topology
    /// reading, never re-read here. Nil where the per-Desktop
    /// list cannot be read: absent, not faked. Production reads
    /// it through `DesktopMemory.readCensus`, the one door a
    /// test pins (`DesktopCensusSeamTests`).
    public static func desktopCensus(
        spaces: [NativeSpace]
    ) -> DesktopCensus? {
        guard SkyLight.canListSpaceWindows else { return nil }
        return DesktopCensus.build(
            spaces: spaces,
            owners: AXHelper.allNormalWindowOwners()
        ) { space, parked in
            SkyLight.windows(on: space, includingParked: parked)?
                .map(WindowID.init)
        }
    }

    /// The per-window reading behind `DesktopMemory.readWindowSpace`
    /// (#1146): `nativeSpace(of:)` told apart from "cannot tell".
    public static func windowSpaceReading(
        of window: WindowID
    ) -> WindowSpaceReading {
        guard canReadWindowSpaces else { return .unavailable }
        return nativeSpace(of: window).map { .hosted($0) } ?? .gone
    }

    /// Whether the per-window Space read can answer at all, so a
    /// nil `nativeSpace(of:)` means "hosted nowhere" rather than
    /// "cannot tell" (#1146). Residue: `SkyLight.windowSpace` also
    /// answers nil for a call that failed outright, which then
    /// reads as `closed` — accepted, since a closed window is the
    /// common case and the ledger cannot file what it cannot host.
    public static var canReadWindowSpaces: Bool {
        SkyLight.connection != nil
            && SkyLight.copySpacesForWindows != nil
    }
}

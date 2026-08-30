import KiwiDeskCore

/// Instance representing expanded row in Monitors census (#678).
enum MonitorsRowInstance: Hashable {
    case space(String)
    case orphan(String)
    case display(String)
    case banner
}

/// Space pinned to a monitor currently disconnected.
struct OrphanPin: Identifiable, Hashable {
    let space: SpaceID
    let fingerprint: String

    var id: String { space.raw }
}

/// Expands Monitors census keys into rendered instances (#678,
/// `MonitorsGateWiringTests`).
struct MonitorsFamilyRows {
    let spaces: [SpaceID]
    let mainSpaces: Set<SpaceID>
    let resolutions: [SpaceID: SpaceResolution]
    let pins: [SpaceID: String]
    let displays: [Display]

    /// Connected displays in left-to-right desk reading order.
    var orderedDisplays: [Display] {
        DeskOrder.reading(displays)
    }

    /// Whether connected displays share identical model and resolution
    /// fingerprint.
    var hasAmbiguousDisplays: Bool {
        Set(displays.map(\.fingerprint)).count < displays.count
    }

    /// Space chips assigned to display card via pin or positional default
    /// (#53).
    func chips(on fingerprint: String) -> [SpaceAssignment] {
        spaces.compactMap { space in
            guard !mainSpaces.contains(space) else { return nil }
            switch resolutions[space] {
            case .pinned(let pinned) where pinned == fingerprint:
                return SpaceAssignment(space: space, kind: .pinned)
            case .auto(let auto) where auto == fingerprint:
                return SpaceAssignment(space: space, kind: .auto)
            default:
                return nil
            }
        }
    }

    /// Spaces assigned to follows-main tray.
    var trayChips: [SpaceID] {
        spaces.filter { mainSpaces.contains($0) }
    }

    /// Total spaces active on display including follows-main spaces on main
    /// display.
    func held(on display: Display, isMain: Bool) -> Int {
        chips(on: display.fingerprint).count
            + (isMain ? trayChips.count : 0)
    }

    /// Stored pins for currently disconnected displays.
    var orphans: [OrphanPin] {
        let connected = Set(displays.map(\.fingerprint))
        return
            pins
            .filter { !connected.contains($0.value) }
            .filter { !mainSpaces.contains($0.key) }
            .map { OrphanPin(space: $0.key, fingerprint: $0.value) }
            .sorted { $0.space.raw < $1.space.raw }
    }

    /// Deduplicated spaces assigned to display cards.
    var cardedSpaces: [SpaceAssignment] {
        var seen: Set<SpaceID> = []
        return
            orderedDisplays
            .flatMap { chips(on: $0.fingerprint) }
            .filter { seen.insert($0.space).inserted }
    }

    func rows(for key: SettingKey) -> [MonitorsRowInstance]? {
        guard case .monitors(let family) = key else { return nil }
        return rows(for: family)
    }

    private func rows(
        for family: MonitorsKey
    ) -> [MonitorsRowInstance]? {
        switch family {
        case .spacePins:
            return cardedSpaces.map {
                MonitorsRowInstance.space($0.space.raw)
            }
        case .mainSpaces:
            return trayChips.map {
                MonitorsRowInstance.space($0.raw)
            }
        case .orphanPinClear:
            return orphans.map {
                MonitorsRowInstance.orphan($0.space.raw)
            }
        case .fingerprints:
            return orderedDisplays.map {
                MonitorsRowInstance.display($0.fingerprint)
            }
        case .placementUnavailable:
            return [.banner]
        }
    }
}

import KiwiDeskCore

/// Instance representing expanded row in Screens census (#678).
enum ScreensRowInstance: Hashable {
    case space(String)
    case orphan(String)
    case display(String)
    case banner
}

/// Space pinned to a screen currently disconnected.
struct OrphanPin: Identifiable, Hashable {
    let space: SpaceID
    let fingerprint: String

    var id: String { space.raw }
}

/// Expands Screens census keys into rendered instances (#678).
/// The views build one and READ it, never re-derive beside it —
/// `ScreensGateWiringTests` pins each call site — and the switch
/// is exhaustive so a new census key fails to compile until given
/// an expansion.
struct ScreensFamilyRows {
    let spaces: [SpaceID]
    let mainSpaces: Set<SpaceID>
    /// From the model's one `resolutions()` pass — the runtime's
    /// own precedence, never re-implemented here.
    let resolutions: [SpaceID: SpaceResolution]
    let pins: [SpaceID: String]
    let displays: [Display]

    /// Connected screens in left-to-right desk reading order.
    var orderedDisplays: [Display] {
        DeskOrder.reading(displays)
    }

    /// Whether connected screens share identical model and resolution
    /// fingerprint.
    var hasAmbiguousDisplays: Bool {
        Set(displays.map(\.fingerprint)).count < displays.count
    }

    /// Space chips assigned to screen card via pin or positional default
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

    /// Total spaces active on screen including follows-main spaces on main
    /// screen.
    func held(on display: Display, isMain: Bool) -> Int {
        chips(on: display.fingerprint).count
            + (isMain ? trayChips.count : 0)
    }

    /// Stored pins for currently disconnected screens — read from
    /// the SAVED pins (a resolution can only name a connected
    /// screen), keeping the user's intent visible and clearable;
    /// follows-main spaces are excluded, the tray already draws
    /// them.
    var orphans: [OrphanPin] {
        let connected = Set(displays.map(\.fingerprint))
        return
            pins
            .filter { !connected.contains($0.value) }
            .filter { !mainSpaces.contains($0.key) }
            .map { OrphanPin(space: $0.key, fingerprint: $0.value) }
            .sorted { $0.space.raw < $1.space.raw }
    }

    /// Deduplicated spaces assigned to screen cards: fingerprint
    /// twins would each claim the same chips, double-counting the
    /// census expansion — the picture may draw both, the COUNT
    /// must not (code review, 2026-08-04).
    var cardedSpaces: [SpaceAssignment] {
        var seen: Set<SpaceID> = []
        return
            orderedDisplays
            .flatMap { chips(on: $0.fingerprint) }
            .filter { seen.insert($0.space).inserted }
    }

    func rows(for key: SettingKey) -> [ScreensRowInstance]? {
        guard case .screens(let family) = key else { return nil }
        return rows(for: family)
    }

    private func rows(
        for family: ScreensKey
    ) -> [ScreensRowInstance]? {
        switch family {
        case .spacePins:
            return cardedSpaces.map {
                ScreensRowInstance.space($0.space.raw)
            }
        case .mainSpaces:
            return trayChips.map {
                ScreensRowInstance.space($0.raw)
            }
        case .orphanPinClear:
            return orphans.map {
                ScreensRowInstance.orphan($0.space.raw)
            }
        case .fingerprints:
            return orderedDisplays.map {
                ScreensRowInstance.display($0.fingerprint)
            }
        case .placementUnavailable:
            // Exactly one row, always — on-screen is the GATE's
            // answer, not this seam's.
            return [.banner]
        }
    }
}

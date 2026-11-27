import CoreGraphics
import Foundation
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
    /// The screen number it waits for, where the pin is one (#3647).
    var number: Int?
    /// The connected screen left unnumbered at `number`'s place,
    /// named for copy; nil where no connected screen holds it.
    var unnumberedScreen: String?

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
    /// The draft's splits by fingerprint (#3517); a screen with
    /// none, or a whole one, is one area 0.
    var splits: [String: ScreenSplit] = [:]
    /// Stored pins to a number no connected screen holds (#3647):
    /// they wait, as a pin to a gone screen does.
    var waiting: [SpaceID: Int] = [:]
    /// Each waiting number whose screen is connected but left
    /// unnumbered, with that screen's name (#3688).
    var unnumbered: [Int: String] = [:]

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
            // A waiting pin has its own row, never a chip (#3647).
            guard !mainSpaces.contains(space), waiting[space] == nil
            else { return nil }
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

    /// Spaces an area holds — `key` names it as a pin stores it —
    /// with the follows-main Spaces where it is the first area of
    /// the main screen (#3517 ruling 29).
    func held(on key: String, isMain: Bool) -> Int {
        let first = ScreenAreaKey(parsing: key).areaID == 0
        return chips(on: key).count
            + (isMain && first ? trayChips.count : 0)
    }

    /// `display`'s areas in reading order, each with the key a pin
    /// stores; a whole screen is one area under its fingerprint.
    func areas(of display: Display) -> [(area: ScreenArea, key: String)] {
        Self.areas(of: display, in: splits)
    }

    /// `areas(of:)` over a draft's splits, without a rows pass.
    static func areas(
        of display: Display,
        in splits: [String: ScreenSplit]
    ) -> [(area: ScreenArea, key: String)] {
        guard
            let split = ScreenSplit.effective(
                splits[display.fingerprint],
                for: display
            )
        else {
            let whole = ScreenSplit.whole(of: display).areas[0]
            return [(whole, display.fingerprint)]
        }
        return ScreenArea.readingOrder(split.areas).map { area in
            (
                area,
                ScreenAreaKey(
                    fingerprint: display.fingerprint,
                    areaID: area.id
                ).description
            )
        }
    }

    /// Stored pins for currently disconnected screens — read from
    /// the SAVED pins (a resolution can only name a connected
    /// screen), keeping the user's intent visible and clearable;
    /// follows-main spaces are excluded, the tray already draws
    /// them.
    var orphans: [OrphanPin] {
        let connected = Set(displays.map(\.fingerprint))
        let gone =
            pins
            .filter {
                !connected.contains(
                    ScreenAreaKey(parsing: $0.value).fingerprint
                )
            }
            .filter { !mainSpaces.contains($0.key) }
            .map { OrphanPin(space: $0.key, fingerprint: $0.value) }
        let numbered = waiting.filter { !mainSpaces.contains($0.key) }
            .map {
                OrphanPin(
                    space: $0.key,
                    fingerprint: "",
                    number: $0.value,
                    unnumberedScreen: unnumbered[$0.value]
                )
            }
        return (gone + numbered).sorted { $0.space.raw < $1.space.raw }
    }

    /// Deduplicated spaces assigned to screen cards: fingerprint
    /// twins would each claim the same chips, double-counting the
    /// census expansion — the picture may draw both, the COUNT
    /// must not (code review, 2026-08-04).
    var cardedSpaces: [SpaceAssignment] {
        var seen: Set<SpaceID> = []
        return
            orderedDisplays
            .flatMap { areas(of: $0).flatMap { chips(on: $0.key) } }
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
        case .fingerprints, .displayAreas, .screenNumbers:
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

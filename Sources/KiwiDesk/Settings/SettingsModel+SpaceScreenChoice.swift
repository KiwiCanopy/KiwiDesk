import Foundation
import KiwiDeskCore

/// Where a Space is placed, as the Screen menus offer it. Every
/// per-Space placement write in Settings — Screens' chips, drops and
/// orphan clear, the Screen menu — goes through `place` (#758,
/// #2737; `SimpleSectionsTests` ▸ `placementHasOneDoor`). Writers
/// of the whole map (a kept layout, a screen setup's adopt, the
/// revert register) are outside that guard.
enum SpaceScreenChoice: Hashable, Sendable {
    case auto
    case followsMain
    /// Pinned to a screen by its fingerprint, connected or not.
    case screen(String)
    /// Pinned to a screen number no connected screen holds: the
    /// stored pin waits, and re-picking it keeps it (#3689).
    case waiting(ScreenSlotKey)
}

extension SettingsModel {
    /// The draft's placement of `space`.
    func screenChoice(of space: SpaceID) -> SpaceScreenChoice {
        if let pin = pin(of: space), !pin.isEmpty {
            return .screen(resolvedPin(pin))
        }
        if config.mainSpaces.contains(space) { return .followsMain }
        // A number no connected screen holds waits (#3689), read by
        // the predicate the chip reads (`waitingPins`).
        if let slot = config.spacePins[space], !screenOrder.holds(slot) {
            return .waiting(slot)
        }
        return .auto
    }

    /// Places `space`, clearing the other placement it held.
    func place(_ space: SpaceID, _ choice: SpaceScreenChoice) {
        switch choice {
        case .auto:
            config.spacePins[space] = nil
            config.mainSpaces.remove(space)
        case .followsMain:
            config.mainSpaces.insert(space)
            config.spacePins[space] = nil
        case .screen(let fingerprint):
            // Stored by the number its screen holds (#3647); a
            // screen not connected holds none, so pins nothing.
            config.spacePins[space] = screenOrder.slot(
                of: ScreenAreaKey(parsing: fingerprint)
            )
            config.mainSpaces.remove(space)
        case .waiting:
            // Offered only as the Space's own pin: re-picking it
            // keeps the stored number (#3689).
            return
        }
    }
}

/// The Screen menus' one vocabulary (#2737 ruling 4): what each
/// choice is called, and which a Space is offered.
extension SpaceScreenChoice {
    @MainActor func title(in model: SettingsModel) -> String {
        switch self {
        case .auto:
            L("monitor_chip.automatic", "Automatic")
        case .followsMain:
            L("monitor_card.follows_main", "Follows main screen")
        case .screen(let key):
            // A connected twin reads by position (#3496); an area as
            // "Screen – Left" (#3517 ruling 11).
            model.pinWords(key)
                ?? model.screenName(ScreenAreaKey(parsing: key).fingerprint)
        case .waiting(let slot):
            model.offlinePinLabel(number: slot.number)
        }
    }

    /// Automatic, Follows main screen, each connected screen — each
    /// area of a split one (#3517 ruling 11) — and the Space's own
    /// pin where its screen, area or number is not there (#3689).
    @MainActor static func offered(
        for space: SpaceID,
        in model: SettingsModel
    ) -> [SpaceScreenChoice] {
        var choices: [SpaceScreenChoice] =
            [.auto, .followsMain]
            + model.areaKeys.map { SpaceScreenChoice.screen($0) }
        let current = model.screenChoice(of: space)
        if !choices.contains(current) { choices.append(current) }
        return choices
    }
}

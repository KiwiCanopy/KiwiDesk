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
}

extension SettingsModel {
    /// The draft's placement of `space`.
    func screenChoice(of space: SpaceID) -> SpaceScreenChoice {
        if let pin = config.spacePins[space], !pin.isEmpty {
            return .screen(pin)
        }
        return config.mainSpaces.contains(space)
            ? .followsMain : .auto
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
            config.spacePins[space] = fingerprint
            config.mainSpaces.remove(space)
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
        case .screen(let fingerprint):
            model.screenName(fingerprint)
        }
    }

    /// Automatic, Follows main screen, each connected screen, and
    /// the Space's own pin where its screen is not connected.
    @MainActor static func offered(
        for space: SpaceID,
        in model: SettingsModel
    ) -> [SpaceScreenChoice] {
        var choices: [SpaceScreenChoice] =
            [.auto, .followsMain]
            + model.displays.map { .screen($0.fingerprint) }
        let current = model.screenChoice(of: space)
        if !choices.contains(current) { choices.append(current) }
        return choices
    }
}

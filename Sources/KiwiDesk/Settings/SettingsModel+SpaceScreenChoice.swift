import KiwiDeskCore

/// Where a Space is placed, as the Screen menus offer it: Screens'
/// chip and Simple's Space row write through the one door
/// (#758, #2737).
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

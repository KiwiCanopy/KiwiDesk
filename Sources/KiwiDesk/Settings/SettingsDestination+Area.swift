/// Destination to census area bijection (`DestinationAreaParityTests`, #678).
extension SettingsDestination {
    /// The census area this destination renders.
    var area: SettingsArea {
        switch self {
        case .spaces: return .spacesAndLayouts
        case .layoutDefaults: return .layoutDefaults
        case .monitors: return .monitors
        case .colors: return .coloursAndMotion
        case .advancedColors: return .advancedColours
        case .gapsAndBorders: return .gapsAndBorders
        case .bars: return .bars
        case .behavior: return .behaviour
        case .profiles: return .profiles
        case .shortcuts: return .shortcuts
        case .appRules: return .appRules
        case .general: return .general
        }
    }

    /// The destination that renders `area` — total because the
    /// bijection test holds every area to exactly one owner.
    init(area: SettingsArea) {
        switch area {
        case .spacesAndLayouts: self = .spaces
        case .layoutDefaults: self = .layoutDefaults
        case .monitors: self = .monitors
        case .coloursAndMotion: self = .colors
        case .advancedColours: self = .advancedColors
        case .gapsAndBorders: self = .gapsAndBorders
        case .bars: self = .bars
        case .behaviour: self = .behavior
        case .profiles: self = .profiles
        case .shortcuts: self = .shortcuts
        case .appRules: self = .appRules
        case .general: self = .general
        }
    }
}

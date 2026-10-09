/// Destination ↔ census-area bridge (#678): the destination is
/// the navigation identity, the area the census's placement
/// vocabulary. One exhaustive map each way;
/// `DestinationAreaParityTests` pins the bijection so a new
/// case on either side reds instead of missing a card.
extension SettingsDestination {
    /// The census area this destination renders.
    var area: SettingsArea {
        switch self {
        case .spaces: return .spacesAndLayouts
        case .layoutDefaults: return .layoutDefaults
        case .screens: return .screens
        case .looks: return .coloursAndMotion
        case .advancedColors: return .advancedColours
        case .gapsAndBorders: return .gapsAndBorders
        case .bars: return .bars
        case .profiles: return .profiles
        case .shortcuts: return .shortcuts
        case .appRules: return .appRules
        case .general: return .general
        case .macChecklist: return .macChecklist
        }
    }

    /// The destination that renders `area` — total because the
    /// bijection test holds every area to exactly one owner.
    init(area: SettingsArea) {
        switch area {
        case .spacesAndLayouts: self = .spaces
        case .layoutDefaults: self = .layoutDefaults
        case .screens: self = .screens
        case .coloursAndMotion: self = .looks
        case .advancedColours: self = .advancedColors
        case .gapsAndBorders: self = .gapsAndBorders
        case .bars: self = .bars
        case .profiles: self = .profiles
        case .shortcuts: self = .shortcuts
        case .appRules: self = .appRules
        case .general: self = .general
        case .macChecklist: self = .macChecklist
        }
    }
}

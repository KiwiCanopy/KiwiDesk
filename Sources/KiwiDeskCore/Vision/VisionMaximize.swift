import Foundation

/// What KiwiVision's focused window fills (#3064): nothing, the
/// whole screen, or one axis at the Layout Defaults share. The raw
/// values are `gui.json`'s stored spelling, so renaming one owes a
/// `ConfigMigration` crossing (AGENTS.md §5).
public enum VisionMaximize: String, APIChoiceType, Codable, Sendable {
    case off
    case full
    case height
    case width

    /// The axis a directional fill takes, nil for Off and Full.
    public var axis: MaximizeAxis? {
        switch self {
        case .off, .full: nil
        case .height: .height
        case .width: .width
        }
    }
}

import QuartzCore

/// The curve the window focus leaves takes into KiwiVision's dim
/// (#2417). The raw values are `gui.json`'s stored spelling, so
/// renaming one owes a `ConfigMigration` crossing (AGENTS.md §5).
public enum VisionFadeCurve: String, APIChoiceType, Codable, Sendable {
    case easeOut = "ease_out"
    case easeInOut = "ease_in_out"
    case easeIn = "ease_in"
    case linear

    /// The Core Animation curve.
    var timing: CAMediaTimingFunction {
        switch self {
        case .easeOut: CAMediaTimingFunction(name: .easeOut)
        case .easeInOut: CAMediaTimingFunction(name: .easeInEaseOut)
        case .easeIn: CAMediaTimingFunction(name: .easeIn)
        case .linear: CAMediaTimingFunction(name: .linear)
        }
    }
}

import Foundation

/// Registers reduced hover help delay
/// (`ToolTipDelayTests`, `docs/design-decisions.md`).
enum ToolTipDelay {
    /// AppKit reads this in milliseconds.
    static let key = "NSInitialToolTipDelay"
    static let milliseconds = 700

    static func install(into defaults: UserDefaults = .standard) {
        defaults.register(defaults: [key: milliseconds])
    }
}

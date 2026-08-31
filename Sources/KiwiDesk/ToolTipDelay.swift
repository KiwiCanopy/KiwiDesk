import Foundation

/// Registers reduced hover help delay (argued in
/// `docs/design-decisions.md`; band held by `ToolTipDelayTests`).
/// `register`, never `set`: a user's own `NSInitialToolTipDelay`
/// must win — overwriting it would be silent.
enum ToolTipDelay {
    /// AppKit reads this in milliseconds.
    static let key = "NSInitialToolTipDelay"
    static let milliseconds = 700

    static func install(into defaults: UserDefaults = .standard) {
        defaults.register(defaults: [key: milliseconds])
    }
}

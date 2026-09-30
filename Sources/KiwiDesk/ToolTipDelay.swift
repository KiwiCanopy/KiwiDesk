import Foundation

/// Stores the shortened hover-help delay in the app's own domain
/// (argued in `docs/design-decisions.md`; band held by
/// `ToolTipDelayTests`). Stored, never registered: AppKit reads the
/// stored value, not the registration domain (measured 2026-10-01,
/// macOS 27). A user's own `NSInitialToolTipDelay` wins — `install`
/// rewrites only a value `markerKey` says it wrote itself.
enum ToolTipDelay {
    /// AppKit reads this in milliseconds.
    static let key = "NSInitialToolTipDelay"
    /// The value `install` last wrote; a stored value that differs,
    /// or one present without this marker, is the user's.
    static let markerKey = "KiwiDeskToolTipDelayWritten"
    static let milliseconds = 250

    static func install(into defaults: UserDefaults = .standard) {
        let stored = defaults.object(forKey: key) as? Int
        let marker = defaults.object(forKey: markerKey) as? Int
        if let stored, stored != marker { return }
        defaults.set(milliseconds, forKey: key)
        defaults.set(milliseconds, forKey: markerKey)
    }
}

import Foundation

/// How long the pointer must rest before hover help appears.
///
/// AppKit's own default is around two seconds (measured on
/// device, macOS 15, 2026-08-03) — long enough that a greyed
/// control's `GreyOut(help:)` sentence reads as *absent* rather
/// than as slow. That is the whole reason hover is a fallback
/// and not the #94 affordance: a channel nobody waits for
/// explains nothing. Shortening it does not promote hover to
/// the primary explanation, it just stops the fallback from
/// being a dead letter.
///
/// Not shorter than this: below roughly half a second, tooltips
/// fire while the pointer merely *crosses* a row on its way
/// somewhere else, which is worse than late help.
///
/// `register`, never `set` — a user who has already chosen an
/// `NSInitialToolTipDelay` (globally or for this app) keeps
/// their value, since `register` only supplies a fallback.
enum ToolTipDelay {
    /// AppKit reads this in milliseconds.
    static let key = "NSInitialToolTipDelay"
    static let milliseconds = 700

    static func install(into defaults: UserDefaults = .standard) {
        defaults.register(defaults: [key: milliseconds])
    }
}

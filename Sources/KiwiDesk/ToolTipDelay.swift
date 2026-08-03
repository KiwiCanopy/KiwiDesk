import Foundation

/// How long the pointer must rest before hover help appears —
/// shorter than AppKit's own default, which is long enough that
/// a greyed control's `GreyOut(help:)` sentence reads as absent
/// rather than as slow.
///
/// Why that trade, why this value, and why not shorter, are
/// argued once in `docs/design-decisions.md` ▸ "Hover help
/// appears sooner than AppKit's default". The band this value
/// must stay inside is asserted by `ToolTipDelayTests`.
///
/// `register`, never `set` — a user who has already chosen an
/// `NSInitialToolTipDelay` (globally or for this app) keeps
/// their value, since `register` only supplies a fallback.
/// `ToolTipDelayTests` holds that too: it is the one line here
/// whose failure mode is silent, overwriting a preference the
/// user set deliberately.
enum ToolTipDelay {
    /// AppKit reads this in milliseconds.
    static let key = "NSInitialToolTipDelay"
    static let milliseconds = 700

    static func install(into defaults: UserDefaults = .standard) {
        defaults.register(defaults: [key: milliseconds])
    }
}

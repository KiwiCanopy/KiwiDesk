import CoreGraphics
import Foundation

/// Snapshot of macOS login session state (#835,
/// `CGSessionCopyCurrentDictionary`).
///
/// Records `kCGSessionOnConsoleKey` and `CGSSessionScreenIsLocked`
/// for wake/unlock diagnostic replay. `onConsole` cannot stand in
/// for `screenLocked`: fast user switching flips it and locking
/// does not (observed 2026-08-13, macOS 26.6.1). The lock key is
/// present ONLY while locked, so absence decodes to `nil`, never
/// `false` — a diagnostic that guesses is worse than one that
/// says it does not know.
public struct SessionPresence: Sendable, Equatable {
    /// Whether this session owns the console, or `nil` if unreadable.
    public let onConsole: Bool?

    /// Whether the screen is locked, or `nil` when key is absent from session
    /// dict.
    public let screenLocked: Bool?

    public init(onConsole: Bool?, screenLocked: Bool?) {
        self.onConsole = onConsole
        self.screenLocked = screenLocked
    }

    private static let lockedKey = "CGSSessionScreenIsLocked"

    /// Live system session presence snapshot.
    public static func live() -> SessionPresence {
        SessionPresence(
            session: CGSessionCopyCurrentDictionary()
                as? [String: Any]
        )
    }

    /// Decodes presence from session dictionary.
    init(session: [String: Any]?) {
        self.init(
            onConsole: Self.flag(session, kCGSessionOnConsoleKey),
            screenLocked: Self.flag(session, Self.lockedKey)
        )
    }

    private static func flag(
        _ session: [String: Any]?,
        _ key: String
    ) -> Bool? {
        guard let raw = session?[key] else { return nil }
        return (raw as? NSNumber)?.boolValue
    }

    /// Diagnostic description for logging (core-boundaries.md ▸
    /// #96, `onLog`). Says "lock not reported" rather than
    /// "unlocked" on nil: writing "unlocked" would hand the next
    /// reader a conclusion the read did not make.
    var summary: String {
        let lock: String
        switch screenLocked {
        case .some(true): lock = "screen locked"
        case .some(false): lock = "screen unlocked"
        case nil: lock = "screen lock not reported"
        }
        let console: String
        switch onConsole {
        case .some(true): console = "on console"
        case .some(false): console = "off console"
        case nil: console = "console unknown"
        }
        return "\(lock), \(console)"
    }
}

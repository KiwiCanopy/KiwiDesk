import CoreGraphics
import Foundation

/// Snapshot of macOS login session state (#835,
/// `CGSessionCopyCurrentDictionary`).
///
/// Records `kCGSessionOnConsoleKey` and `CGSSessionScreenIsLocked` for
/// wake/unlock diagnostic replay. Screen lock status decodes to `nil` when key
/// is absent.
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

    /// Diagnostic description for logging
    /// (core-boundaries.md ▸ #96, `onLog`).
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

import CoreGraphics
import Foundation

/// What macOS says about the login session at one instant.
///
/// Read where the wake/unlock replay decides (#835): a
/// lock → lid → unlock cycle produces two rest events and two
/// return events, and the open question is whether the replay
/// fires while the screen is still locked. Nothing branches on
/// this — it is carried into the log so the next failing cycle
/// answers that instead of a predicate chosen in advance.
///
/// Both facts come from the public
/// `CGSessionCopyCurrentDictionary()`, so there is no private
/// symbol here and nothing to fall back from. What differs is
/// the two keys:
///
/// - `kCGSessionOnConsoleKey` is public and always present. It
///   reports whether this session owns the console, which **fast
///   user switching** flips and locking the screen does not
///   (observed 2026-08-13, macOS 26.6.1: `1` on an unlocked
///   session). It therefore cannot stand in for `screenLocked`,
///   which is the whole reason both are recorded.
/// - `CGSSessionScreenIsLocked` has no public constant, and macOS
///   adds it to the dictionary **only while the screen is
///   locked** — the same observation shows the key absent
///   entirely when unlocked. An absent key is thus not
///   distinguishable from an unlocked screen by reading alone, so
///   it decodes to `nil` rather than to `false`. A diagnostic
///   that guesses is worse than one that says it does not know.
public struct SessionPresence: Sendable, Equatable {
    /// Whether this session owns the console, or `nil` when the
    /// session dictionary could not be read at all.
    public let onConsole: Bool?

    /// Whether the screen is locked, or `nil` when macOS did not
    /// report the key — see the type's note on why that is not
    /// the same as `false`.
    public let screenLocked: Bool?

    public init(onConsole: Bool?, screenLocked: Bool?) {
        self.onConsole = onConsole
        self.screenLocked = screenLocked
    }

    /// The key with no public constant; see the type's note.
    private static let lockedKey = "CGSSessionScreenIsLocked"

    /// The live read — the one host touch, kept to a single
    /// statement so everything a test would want to exercise is
    /// in the dictionary initializer below.
    public static func live() -> SessionPresence {
        SessionPresence(
            session: CGSessionCopyCurrentDictionary()
                as? [String: Any]
        )
    }

    /// Decodes one session dictionary. Every field is optional so
    /// a dictionary macOS stops publishing — or never returns at
    /// all — degrades to "unknown" rather than to a confident
    /// wrong answer.
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

    /// One log-ready clause, e.g. `screen locked, on console`.
    ///
    /// Says "lock not reported" rather than "unlocked" on the
    /// `nil` case on purpose: on this machine the two are the
    /// same observation, and writing "unlocked" would hand the
    /// next reader a conclusion the read did not make.
    public var summary: String {
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

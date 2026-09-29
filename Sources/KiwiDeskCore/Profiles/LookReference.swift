import Foundation

/// Which look a profile wears (#1752). Stored as `look` in the
/// profile file; ABSENT means the shared look in `gui.json`, which
/// is why a profile from before #1752 is stamped `own` by
/// `ConfigMigration` rather than read as absent. Strict: an
/// unknown value refuses the file, so a later `"<saved look>"`
/// reference is a format bump, never a silent fallback.
public enum LookReference: String, Codable, Sendable, Equatable {
    /// A private copy, kept in the profile's own settings.
    case own
}

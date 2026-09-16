import Foundation

/// What one Desktop→profile binding holds (#1147).
///
/// The binding is KEYED by `DesktopKey`; everything here is what
/// that key cannot carry. `desktop` and `screen` are
/// **projections** of the DESKTOP — the Mission Control number
/// the binding was declared at and the name of the screen it was
/// last seen on (#1438), refreshed from every snapshot that
/// resolves the Desktop, and what a row is labelled with while
/// the Desktop is away. Nothing resolves a binding through
/// either; they sit once on this per-Desktop record, beside the
/// per-count profile list (#1436).
public struct DesktopBinding: Hashable, Sendable, Codable {
    /// The profiles this Desktop selects, one per screen count
    /// (#1436). The count is each profile's own `monitorCount`,
    /// read at the gate and never stored here; which one loads
    /// is `KiwiCore.boundProfile(of:)`'s to decide against the
    /// connected screens. Never empty: a record with nothing
    /// bound is removed rather than kept.
    public var profiles: [String]
    /// The Mission Control number last seen for this Desktop.
    public var desktop: Int
    /// The display name this Desktop was last seen on (#1438),
    /// nil until a reading has named it. Additive: a record
    /// written before it decodes to nil, which IS "not yet
    /// named", so no format bump — #1230's `desktop_spaces`
    /// precedent. Encoded only where set.
    public var screen: String?

    public init(
        profiles: [String],
        desktop: Int,
        screen: String? = nil
    ) {
        self.profiles = profiles
        self.desktop = desktop
        self.screen = screen
    }

    /// One bound profile — the shape every binding had before
    /// #1436, and the one a single-count user still writes.
    public init(profile: String, desktop: Int, screen: String? = nil) {
        self.init(profiles: [profile], desktop: desktop, screen: screen)
    }

    /// Files `name` on this Desktop: replacing the entry saved
    /// for the same screen count, sitting beside the others
    /// (#1436). `countOf` reads a profile's count — nil for one
    /// not saved yet, which is a class of its own: two unsaved
    /// names cannot be told apart, so the newer replaces the
    /// older, and each is judged once its file exists.
    public mutating func bind(
        _ name: String,
        countOf: (String) -> Int?
    ) {
        guard !profiles.contains(name) else { return }
        let count = countOf(name)
        profiles.removeAll { countOf($0) == count }
        profiles.append(name)
    }

    /// Drops `name`; true when the list is now empty and the
    /// record with it.
    @discardableResult
    public mutating func unbind(_ name: String) -> Bool {
        profiles.removeAll { $0 == name }
        return profiles.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case profiles
        case desktop
        case screen
    }
}

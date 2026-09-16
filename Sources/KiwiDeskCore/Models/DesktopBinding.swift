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
/// either, and a record that grows a per-count profile list
/// (#1436) keeps both on the one per-Desktop record.
public struct DesktopBinding: Hashable, Sendable, Codable {
    /// The profile this Desktop selects.
    public var profile: String
    /// The Mission Control number last seen for this Desktop.
    public var desktop: Int
    /// The display name this Desktop was last seen on (#1438),
    /// nil until a reading has named it. Additive: a record
    /// written before it decodes to nil, which IS "not yet
    /// named", so no format bump — #1230's `desktop_spaces`
    /// precedent. Encoded only where set.
    public var screen: String?

    public init(profile: String, desktop: Int, screen: String? = nil) {
        self.profile = profile
        self.desktop = desktop
        self.screen = screen
    }

    private enum CodingKeys: String, CodingKey {
        case profile
        case desktop
        case screen
    }
}

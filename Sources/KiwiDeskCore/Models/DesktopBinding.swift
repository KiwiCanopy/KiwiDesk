import Foundation

/// What one Desktop→profile binding holds (#1147).
///
/// The binding is KEYED by `DesktopKey`; everything here is what
/// that key cannot carry. `desktop` and `screen` are
/// **projections** — the Mission Control number the binding was
/// declared at and the name of the screen its Desktop was last
/// seen on, refreshed from every snapshot that resolves the
/// Desktop, and what a row is labelled with while its Desktop
/// is away. Nothing resolves a binding through either.
///
/// It carried a `display` until the reconnect arm it was written
/// for was dropped: an unplugged screen's Desktops come back
/// carrying their stamps, so nothing adopts a dormant record by
/// order (measured 2026-09-04). `screen` is not that field back:
/// it is a LABEL, read by the Desktops card alone (#1438).
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

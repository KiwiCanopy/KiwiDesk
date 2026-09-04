import Foundation

/// What one Desktop→profile binding holds (#1147).
///
/// The binding is KEYED by `DesktopKey`; everything here is what
/// that key cannot carry. `desktop` is the Mission Control
/// number as a **projection** — the number the binding was
/// declared at, refreshed from every snapshot that resolves the
/// Desktop, and the number a row is labelled with while its
/// Desktop is away. Nothing resolves a binding through it.
///
/// It carried a `display` until the reconnect arm it was written
/// for was dropped: an unplugged screen's Desktops come back
/// carrying their stamps, so nothing adopts a dormant record by
/// order (measured 2026-09-04). Removed while this release's
/// format bump was already open, rather than shipping a
/// persisted field whose meaning no code defines.
public struct DesktopBinding: Hashable, Sendable, Codable {
    /// The profile this Desktop selects.
    public var profile: String
    /// The Mission Control number last seen for this Desktop.
    public var desktop: Int

    public init(profile: String, desktop: Int) {
        self.profile = profile
        self.desktop = desktop
    }

    private enum CodingKeys: String, CodingKey {
        case profile
        case desktop
    }
}

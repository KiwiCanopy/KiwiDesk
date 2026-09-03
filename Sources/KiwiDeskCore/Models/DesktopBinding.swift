import Foundation

/// What one Desktop→profile binding holds (#1147).
///
/// The binding is KEYED by `DesktopKey`; everything here is what
/// that key cannot carry. `desktop` is the Mission Control number
/// as a **projection** — the number the user declared the binding
/// at, refreshed from every snapshot that resolves the Desktop,
/// and the number a row is labelled with while its Desktop is
/// away. Nothing resolves a binding through it.
public struct DesktopBinding: Hashable, Sendable, Codable {
    /// The profile this Desktop selects.
    public var profile: String
    /// The Mission Control number last seen for this Desktop.
    public var desktop: Int
    /// The display it was last seen on, where the topology could
    /// name one. Written for the reconnect arm (#1147 R4b), which
    /// is where a fresh Desktop on a returning display adopts a
    /// dormant record; nothing reads it yet, and a record written
    /// before it existed answers nil.
    public var display: String?

    public init(
        profile: String,
        desktop: Int,
        display: String? = nil
    ) {
        self.profile = profile
        self.desktop = desktop
        self.display = display
    }

    private enum CodingKeys: String, CodingKey {
        case profile
        case desktop
        case display
    }
}

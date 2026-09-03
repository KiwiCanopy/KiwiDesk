import Foundation

/// A KiwiDesk identity stamped onto one macOS Desktop (#1147).
///
/// Opaque on purpose: never parsed, never derived from anything,
/// compared only for equality. It is a STORED value the
/// WindowServer persists (os-private-apis.md), so a change to
/// what it holds owes a one-shot re-stamp of every Desktop
/// carrying the old shape — never a reader lenient to both.
public struct DesktopIdentity: Hashable, Sendable, Codable {
    public let raw: String

    public init(raw: String) { self.raw = raw }

    /// A fresh identity for a Desktop that carries none.
    public static func mint() -> DesktopIdentity {
        DesktopIdentity(raw: UUID().uuidString)
    }

    /// The bare key the wrapper namespaces when writing.
    public static let storeKey = "identity"

    /// The FULL key as the WindowServer plist spells it — the
    /// read door, which never goes through the bridge. Joined
    /// here once so the two doors cannot drift.
    public static let plistKey =
        WMBridge.valueKeyPrefix + storeKey
}

/// What durable per-Desktop state is keyed by (#1147).
///
/// `.identity` survives renumbering, display migration, logout
/// and restart; `.number` is the pre-#1147 key — the global
/// Mission Control number — and is what a Desktop falls back to
/// while it has no stamp: this macOS exposes no bridge, or a
/// stamp write was declined this session.
///
/// **#1230 keys a Desktop's whole Space set by this**, so the
/// stored spelling below is a stored value in that lane too; the
/// contract is `plan/1147-desktop-identity.md` ▸ #1230 contract
/// while that file lives, and this doc after it.
public enum DesktopKey: Hashable, Sendable {
    case identity(DesktopIdentity)
    case number(Int)

    /// The stored spelling: the UUID for an identity, the decimal
    /// for a number. Parsed back by SHAPE, so the two can never
    /// collide — a Mission Control number is never a UUID.
    public var stored: String {
        switch self {
        case .identity(let id): return id.raw
        case .number(let n): return String(n)
        }
    }

    public init(stored: String) {
        if let n = Int(stored) {
            self = .number(n)
        } else {
            self = .identity(DesktopIdentity(raw: stored))
        }
    }

    /// The Mission Control number this key names, if it is one.
    /// An identity deliberately answers nil: its number is a fact
    /// about the current topology, read from a snapshot, never
    /// carried by the key.
    public var number: Int? {
        if case .number(let n) = self { return n }
        return nil
    }
}

/// A dictionary keyed by `DesktopKey` encodes as a JSON OBJECT
/// under the stored spelling. Without this Swift emits an ARRAY
/// of alternating keys and values, which no config file of ours
/// is shaped like and no hand edit could survive.
extension DesktopKey: CodingKeyRepresentable {
    public var codingKey: any CodingKey {
        StoredCodingKey(stringValue: stored)
    }

    public init?<T: CodingKey>(codingKey: T) {
        self.init(stored: codingKey.stringValue)
    }
}

/// The `CodingKey` a `DesktopKey` presents itself as.
private struct StoredCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension DesktopKey: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(stored: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stored)
    }
}

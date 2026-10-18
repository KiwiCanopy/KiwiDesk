import CryptoKit
import Foundation

/// A profile's stable identity, stored in its file (#2324 ruling
/// 11): what a Desktop binding names, so a rename — on this Mac or
/// another one sharing the folder — keeps the binding. Opaque and
/// never a name, so a path that resolves by name instead cannot
/// pass for one.
public struct ProfileID: Hashable, Sendable, Codable,
    CustomStringConvertible
{
    public let raw: String

    public init(raw: String) { self.raw = raw }

    /// A new profile's id.
    public static func fresh() -> ProfileID {
        ProfileID(raw: UUID().uuidString)
    }

    /// The id a profile written before ids existed takes: a UUIDv5
    /// of its name, so every Mac stamps the same one on upgrade and
    /// a binding written by name reaches it after a rename.
    public static func legacy(name: String) -> ProfileID {
        var bytes = Array(legacyNamespace)
        bytes.append(contentsOf: Array(name.utf8))
        var hash = Array(Insecure.SHA1.hash(data: bytes).prefix(16))
        hash[6] = (hash[6] & 0x0F) | 0x50
        hash[8] = (hash[8] & 0x3F) | 0x80
        let uuid = UUID(
            uuid: (
                hash[0], hash[1], hash[2], hash[3], hash[4], hash[5],
                hash[6], hash[7], hash[8], hash[9], hash[10],
                hash[11], hash[12], hash[13], hash[14], hash[15]
            )
        )
        return ProfileID(raw: uuid.uuidString)
    }

    /// The UUIDv5 namespace of `legacy(name:)`. Never change it:
    /// every stamped file and every carried binding derives from it.
    private static let legacyNamespace: Data = {
        let uuid = UUID(
            uuidString: "8C0B3E1A-7F4D-4B6E-9A2C-5D1E0F3A6B7C"
        )!.uuid
        return withUnsafeBytes(of: uuid) { Data($0) }
    }()

    public var description: String { raw }

    public init(from decoder: Decoder) throws {
        raw = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

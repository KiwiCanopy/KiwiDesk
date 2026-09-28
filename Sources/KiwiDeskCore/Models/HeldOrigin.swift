import Foundation

/// Where a held Space came from (#1507): its name in the
/// arrangement it left and the screen it lived on. A stored
/// cross-version shape — every session snapshot carries it
/// (#1646, `StateSnapshot+Held`).
public struct HeldOrigin: Codable, Equatable, Sendable {
    /// The Space's name there — its live id too, unless that name
    /// was taken on the remaining screen and it was renumbered.
    public let name: SpaceID
    /// The fingerprint of the screen it lived on (`name:WxH`).
    public let screen: String
    /// The identifier icon it carried there.
    public let icon: String?
    /// The arrangement it left — it goes home only into that one
    /// (#1230: arrangements never merge by name). Nil where no
    /// profile or Standard was live.
    public let arrangement: Arrangement?

    /// A saved profile or a composed Standard, by name.
    public enum Arrangement: Codable, Equatable, Sendable {
        case profile(String)
        case standard(String)

        private enum CodingKeys: String, CodingKey { case kind, name }
        private enum Kind: String, Codable { case profile, standard }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let name = try c.decode(String.self, forKey: .name)
            switch try c.decode(Kind.self, forKey: .kind) {
            case .profile: self = .profile(name)
            case .standard: self = .standard(name)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .profile(let name):
                try c.encode(Kind.profile, forKey: .kind)
                try c.encode(name, forKey: .name)
            case .standard(let name):
                try c.encode(Kind.standard, forKey: .kind)
                try c.encode(name, forKey: .name)
            }
        }
    }

    /// The screen's own name, for the sentence the bar announces.
    public var screenName: String {
        Display.fingerprintParts(screen).name
    }
}

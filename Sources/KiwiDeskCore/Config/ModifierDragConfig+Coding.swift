import Foundation

/// The wire shape (#2447): `move` and `resize`, each
/// `{ keys, start }`, where `keys` is a chord's spelling ("" off)
/// and `start` is `drag` or `hover`. A key a file leaves out keeps
/// its default, so the group is additive key by key; the encoder
/// states every key.
enum ModifierDragKeys: String, CodingKey {
    case move, resize
}

enum ModifierDragBindingKeys: String, CodingKey {
    case keys, start
}

extension ModifierDragStart: Codable {}

extension ModifierDragBinding: Codable {
    public init(from decoder: Decoder) throws {
        self = try Self.decode(from: decoder, over: .init(chord: []))
    }

    /// Decodes over `base`, which supplies what the file omits.
    static func decode(
        from decoder: Decoder,
        over base: ModifierDragBinding
    ) throws -> ModifierDragBinding {
        let c = try decoder.container(keyedBy: ModifierDragBindingKeys.self)
        return ModifierDragBinding(
            chord: try c.decodeIfPresent(ScrollChord.self, forKey: .keys)
                ?? base.chord,
            start: try c.decodeIfPresent(
                ModifierDragStart.self,
                forKey: .start
            ) ?? base.start
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ModifierDragBindingKeys.self)
        try c.encode(chord, forKey: .keys)
        try c.encode(start, forKey: .start)
    }
}

extension ModifierDragSettings: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ModifierDragKeys.self)
        var result = Self.defaults
        for action in ModifierDragAction.allCases {
            let key: ModifierDragKeys = action == .move ? .move : .resize
            guard c.contains(key) else { continue }
            result[action] = try ModifierDragBinding.decode(
                from: try c.superDecoder(forKey: key),
                over: result[action]
            )
        }
        self = result
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ModifierDragKeys.self)
        try c.encode(move, forKey: .move)
        try c.encode(resize, forKey: .resize)
    }
}

import Foundation

/// The wire shape (#3199): `{ "tap4": { "lua": …, "kind": … },
/// "swipe2:control+option": { "family": "focus" },
/// "drag:control+command": { "grab": "move" },
/// "wheel:control+option": { "split": { "up": { "lua": … } } },
/// "swipe3:control+option": { "split": { "left_right":
/// { "family": "space" }, "up": { "lua": … } } },
/// "tap3": null }`. Lua sits under `lua`, the key a migration that
/// rewrites stored Lua already matches in shortcut rows (#1511). A
/// key the object leaves out inherits and `null` is the tombstone;
/// an unknown key or a body naming no action fails the decode, as
/// every stored value's does.
extension GestureMap: Codable {
    struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        var entries: [GestureKey: GestureEntry] = [:]
        for key in c.allKeys {
            guard let gesture = GestureKey(spelling: key.stringValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: c,
                    debugDescription: "unknown gesture"
                )
            }
            if try c.decodeNil(forKey: key) {
                entries[gesture] = .unbound
            } else {
                entries[gesture] = .bound(
                    try c.decode(GestureAction.self, forKey: key)
                )
            }
        }
        self.init(entries)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        for gesture in entries.keys.sorted() {
            let key = Key(stringValue: gesture.spelling)
            switch entries[gesture] {
            case nil: continue
            case .unbound: try c.encodeNil(forKey: key)
            case .bound(let action): try c.encode(action, forKey: key)
            }
        }
    }
}

extension GestureAction: Codable {
    private enum Keys: String, CodingKey, CaseIterable {
        case family, grab, split
    }

    /// The keys a body of each kind may carry, so a body naming two
    /// actions or a stray key fails rather than picking one.
    private static func check(_ decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: GestureMap.Key.self)
        let names = Set(all.allKeys.map(\.stringValue))
        let action = names.intersection(Keys.allCases.map(\.rawValue))
        let lua = Set(LuaAction.Keys.allCases.map(\.rawValue))
        let allowed = action.count == 1 ? action : lua
        guard action.count <= 1, names.isSubset(of: allowed) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "expected one action"
                )
            )
        }
    }

    public init(from decoder: Decoder) throws {
        try Self.check(decoder)
        let c = try decoder.container(keyedBy: Keys.self)
        if let family = try c.decodeIfPresent(
            GestureFamily.self,
            forKey: .family
        ) {
            self = .family(family)
        } else if let grab = try c.decodeIfPresent(
            String.self,
            forKey: .grab
        ) {
            guard let action = ModifierDragAction(rawValue: grab) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .grab,
                    in: c,
                    debugDescription: "expected move or resize"
                )
            }
            self = .grab(action)
        } else if c.contains(.split) {
            self = try Self.decodeSplit(c.superDecoder(forKey: .split))
        } else {
            self = .run(try LuaAction(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .run(let action):
            try action.encode(to: encoder)
        case .family(let family):
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(family, forKey: .family)
        case .grab(let grab):
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(grab.rawValue, forKey: .grab)
        case .split(let split):
            var c = encoder.container(keyedBy: Keys.self)
            var body = c.nestedContainer(
                keyedBy: GestureMap.Key.self,
                forKey: .split
            )
            for (axis, family) in split.axes {
                try body.encode(
                    AxisBody(family: family),
                    forKey: GestureMap.Key(stringValue: axis.rawValue)
                )
            }
            for (direction, action) in split.arms {
                try body.encode(
                    action,
                    forKey: GestureMap.Key(stringValue: direction.rawValue)
                )
            }
        }
    }

    /// An axis's body: its family alone, `{ "family": "space" }`.
    private struct AxisBody: Codable {
        let family: GestureFamily
    }

    /// A split's body (#1873): an axis key takes a family body, a
    /// direction key a Lua body. A body the one fold would change —
    /// an arm under an axis family, two axes on one family — is
    /// refused, so each behaviour has one stored spelling.
    private static func decodeSplit(_ decoder: Decoder) throws -> Self {
        let c = try decoder.container(keyedBy: GestureMap.Key.self)
        var split = GestureSplit(axes: [:], arms: [:])
        for key in c.allKeys {
            if let axis = GestureAxis(rawValue: key.stringValue) {
                let body = try c.superDecoder(forKey: key)
                let names = try body.container(keyedBy: GestureMap.Key.self)
                    .allKeys.map(\.stringValue)
                guard names == ["family"] else {
                    throw corrupt(c, key, "an axis takes a family")
                }
                split.axes[axis] =
                    try c.decode(AxisBody.self, forKey: key).family
            } else if let direction = GestureDirection(
                rawValue: key.stringValue
            ) {
                split.arms[direction] =
                    try c.decode(LuaAction.self, forKey: key)
            } else {
                throw corrupt(c, key, "unknown direction \(key.stringValue)")
            }
        }
        guard let action = GestureAction.split(normalizing: split) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "an empty table binds nothing"
                )
            )
        }
        guard action == .split(split) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "not the one spelling of this split"
                )
            )
        }
        return action
    }

    private static func corrupt(
        _ c: KeyedDecodingContainer<GestureMap.Key>,
        _ key: GestureMap.Key,
        _ text: String
    ) -> DecodingError {
        .dataCorruptedError(forKey: key, in: c, debugDescription: text)
    }
}

extension LuaAction: Codable {
    enum Keys: String, CodingKey, CaseIterable {
        case lua, kind, desc, group, symbol
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        lua = try c.decode(String.self, forKey: .lua)
        kind =
            try c.decodeIfPresent(KeyBinding.Kind.self, forKey: .kind)
            ?? .custom
        meta = KeyBindingMeta(
            desc: try c.decodeIfPresent(String.self, forKey: .desc) ?? "",
            group: try c.decodeIfPresent(String.self, forKey: .group) ?? "",
            symbol: try c.decodeIfPresent(String.self, forKey: .symbol) ?? ""
        )
    }

    /// Sparse, as an end key's: what it says of itself only where
    /// it says something.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(lua, forKey: .lua)
        try c.encode(kind, forKey: .kind)
        if !meta.desc.isEmpty { try c.encode(meta.desc, forKey: .desc) }
        if !meta.group.isEmpty { try c.encode(meta.group, forKey: .group) }
        if !meta.symbol.isEmpty { try c.encode(meta.symbol, forKey: .symbol) }
    }
}

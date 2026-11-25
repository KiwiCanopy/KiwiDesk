import Foundation

/// The gesture bindings per keybinding layer (#3535): one sparse
/// `GestureMap` per layer name. The `default` layer's map lies over
/// the seeds; every other layer's binds only what it names, since a
/// layer binds gestures as it binds keys, with no fall-through
/// (`GestureSeeds.seeds(on:layer:)`). The same shape stores the
/// global base in `gui.json` and a profile's sparse override, laid
/// over the base layer by layer. An empty map is never stored.
public struct LayerGestures: Hashable, Sendable {
    public private(set) var maps: [String: GestureMap]

    public init(_ maps: [String: GestureMap] = [:]) {
        self.maps = maps.filter { !$0.value.isEmpty }
    }

    /// `map` as the default layer's, every other layer empty.
    public init(defaultLayer map: GestureMap) {
        self.init([KeyLayer.defaultName: map])
    }

    public var isEmpty: Bool { maps.isEmpty }

    /// The layers that store a map, sorted.
    public var layers: [String] { maps.keys.sorted() }

    /// `layer`'s map; empty where it stores none.
    public subscript(layer: String) -> GestureMap {
        get { maps[layer] ?? GestureMap() }
        set { maps[layer] = newValue.isEmpty ? nil : newValue }
    }

    /// This base with `profile`'s maps laid over it, layer by layer.
    public func overlaid(by profile: LayerGestures?) -> LayerGestures {
        var out = self
        for (layer, map) in profile?.maps ?? [:] {
            out[layer] = self[layer].overlaid(by: map)
        }
        return out
    }

    /// The sparse override that turns `base` into `edited`, layer by
    /// layer (`GestureMap.diff`); nil where every layer resolves
    /// alike.
    public static func diff(
        base: LayerGestures,
        edited: LayerGestures,
        shortcutBase: ShortcutBase
    ) -> LayerGestures? {
        var out = LayerGestures()
        for layer in Set(base.maps.keys).union(edited.maps.keys) {
            out[layer] =
                GestureMap.diff(
                    base: base[layer],
                    edited: edited[layer],
                    shortcutBase: shortcutBase,
                    layer: layer
                ) ?? GestureMap()
        }
        return out.isEmpty ? nil : out
    }

    /// The maps with `old`'s renamed to `new`, as a layer rename
    /// carries its keys.
    public func renaming(_ old: String, to new: String) -> LayerGestures {
        guard old != new, let map = maps[old] else { return self }
        var out = self
        out.maps[old] = nil
        out[new] = map
        return out
    }

    /// The maps without `layer`'s, as a layer delete drops its keys.
    public func removing(_ layer: String) -> LayerGestures {
        var out = self
        out.maps[layer] = nil
        return out
    }

    /// Each layer's map passed through `transform`.
    public func mapLayers(
        _ transform: (String, GestureMap) -> GestureMap
    ) -> LayerGestures {
        var out = LayerGestures()
        for (layer, map) in maps { out[layer] = transform(layer, map) }
        return out
    }
}

/// The wire shape: an object keyed by layer name, each value a
/// `GestureMap` (`{ "default": { "tap4": … }, "Coding": { … } }`).
extension LayerGestures: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self.init(try c.decode([String: GestureMap].self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(maps)
    }
}

/// One binding's key across the layers (#3535): a layer and a
/// `GestureKey`. Its spelling keys the gesture reach table, where
/// the default layer's keys keep their bare `GestureKey` spelling
/// and every other layer's prefix the layer's name and a unit
/// separator, which no layer name a user types and no gesture
/// spelling carries.
public struct LayerGestureKey: Hashable, Sendable {
    public let layer: String
    public let key: GestureKey

    static let separator: Character = "\u{1F}"

    public init(_ layer: String, _ key: GestureKey) {
        self.layer = layer
        self.key = key
    }

    public var spelling: String {
        layer == KeyLayer.defaultName
            ? key.spelling
            : layer + String(Self.separator) + key.spelling
    }

    /// The key `spelling` names; nil for a spelling no key has.
    public init?(spelling: String) {
        guard let cut = spelling.lastIndex(of: Self.separator) else {
            guard let key = GestureKey(spelling: spelling) else {
                return nil
            }
            self.init(KeyLayer.defaultName, key)
            return
        }
        let layer = String(spelling[..<cut])
        let rest = String(spelling[spelling.index(after: cut)...])
        guard !layer.isEmpty, layer != KeyLayer.defaultName,
            let key = GestureKey(spelling: rest)
        else { return nil }
        self.init(layer, key)
    }
}

import Foundation

/// One stored layer entry: the layer, plus the base combos it
/// leaves out under `removed` (#1393) or, under `left_out`, the
/// whole base layer (#2022). An entry carrying only marks is no
/// diverging layer of its own.
private struct KeyLayerOverrideEntry: Codable {
    var layer: KeyLayer
    var removed: [String]
    var leftOut: Bool

    private enum CodingKeys: String, CodingKey {
        case removed
        case leftOut = "left_out"
    }

    init(layer: KeyLayer, removed: [String], leftOut: Bool = false) {
        self.layer = layer
        self.removed = removed
        self.leftOut = leftOut
    }

    init(from decoder: Decoder) throws {
        layer = try KeyLayer(from: decoder)
        let marks = try decoder.container(keyedBy: CodingKeys.self)
        removed =
            try marks.decodeIfPresent([String].self, forKey: .removed) ?? []
        leftOut =
            try marks.decodeIfPresent(Bool.self, forKey: .leftOut) ?? false
    }

    func encode(to encoder: Encoder) throws {
        try layer.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !removed.isEmpty {
            try container.encode(removed, forKey: .removed)
        }
        if leftOut { try container.encode(true, forKey: .leftOut) }
    }

    var marksOnly: Bool {
        (leftOut || !removed.isEmpty) && layer.bindings.isEmpty
            && layer.icon == nil
    }
}

extension KeyLayerOverride: Codable {
    /// Decodes normalized sparse layer list (#31).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let entries = try container.decode([KeyLayerOverrideEntry].self)
        var removed: [String: [String]] = [:]
        for entry in entries where !entry.removed.isEmpty {
            removed[entry.layer.name, default: []] += entry.removed
        }
        self.init(
            layers: KeyLayer.normalized(
                sparse: entries.filter { !$0.marksOnly }.map(\.layer)
            ),
            removed: removed,
            leftOut: entries.filter(\.leftOut).map(\.layer.name)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var entries = layers.map {
            KeyLayerOverrideEntry(layer: $0, removed: removed[$0.name] ?? [])
        }
        let named = Set(layers.map(\.name))
        for name in removed.keys.sorted() where !named.contains(name) {
            entries.append(
                KeyLayerOverrideEntry(
                    layer: KeyLayer(name: name),
                    removed: removed[name] ?? []
                )
            )
        }
        for name in leftOut {
            entries.append(
                KeyLayerOverrideEntry(
                    layer: KeyLayer(name: name),
                    removed: [],
                    leftOut: true
                )
            )
        }
        var container = encoder.singleValueContainer()
        try container.encode(entries)
    }
}

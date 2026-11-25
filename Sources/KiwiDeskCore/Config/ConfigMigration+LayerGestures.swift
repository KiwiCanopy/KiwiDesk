import Foundation

/// The gesture map becomes the default layer's (#3535 ▸ Ruling 2,
/// `LayerGestureMigrationTests`): a `gesture` object written below
/// the floor is one map, keyed by gesture, and crosses whole into
/// `{ "default": map }`. Reaches `gui.json`, a profile root, a
/// bundle's `config` and its `profiles[]`; gated on each shape's
/// format, since the two shapes are told apart by nothing else.
extension ConfigMigration {
    /// The formats this step introduced, per shape, spelled as
    /// history.
    static let layerGesturesGuiFormat = 29
    static let layerGesturesProfileFormat = 42
    static let layerGesturesBundleFormat = 53
    /// Spelled rather than derived, as a historical step names what
    /// it was written to name.
    static let layerGesturesKey = "gesture"
    static let layerGesturesDefault = "default"

    @Sendable
    static func migratingGesturesOntoLayers(_ data: Data) -> Data? {
        let needle = Data("\"\(layerGesturesKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { data in
                data.range(of: needle) != nil
                    && belowLayerGesturesFloor(data)
            },
            rewriting: withLayerGestures,
            editing: { _ in nil }
        )
    }

    private static func belowLayerGesturesFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < layerGesturesBundleFormat
        case .gui: return format < layerGesturesGuiFormat
        case .profile: return format < layerGesturesProfileFormat
        case .palettes, .looks: return false
        }
    }

    /// The root itself, a bundle's `config` and each inline profile.
    static func withLayerGestures(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = layered(&root)
        if var config = root["config"] as? [String: Any],
            layered(&config)
        {
            root["config"] = config
            changed = true
        }
        if var profiles = root[barEdgeProfilesKey] as? [[String: Any]] {
            var did = false
            for index in profiles.indices where layered(&profiles[index]) {
                did = true
            }
            if did {
                root[barEdgeProfilesKey] = profiles
                changed = true
            }
        }
        return (root, changed)
    }

    /// One owner's map, moved under the default layer; true where it
    /// changed. An empty map has no bindings to carry and leaves.
    private static func layered(_ object: inout [String: Any]) -> Bool {
        guard let map = object[layerGesturesKey] as? [String: Any] else {
            return false
        }
        object[layerGesturesKey] =
            map.isEmpty ? [String: Any]() : [layerGesturesDefault: map]
        return true
    }
}

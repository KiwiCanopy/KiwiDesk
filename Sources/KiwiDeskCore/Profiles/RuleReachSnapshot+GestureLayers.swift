import Foundation

/// A keybinding layer's rename or delete over the stored gesture
/// maps (#3535): the layer's map in the shared base and in each
/// profile's override moves with its name, or leaves with it, as
/// the layer pass moves the shortcut files. Laid over the files
/// AHEAD of the row encode.
extension RuleReachSnapshot {
    /// Every layer `map` names renamed at once, so a swap or a chain
    /// cannot merge two layers' maps.
    public mutating func renameGestureLayers(
        _ map: [String: String]
    ) throws {
        try rewriteGestureLayers { maps in
            var out = LayerGestures()
            for layer in maps.layers {
                out[map[layer] ?? layer] = maps[layer]
            }
            return out
        }
    }

    /// `layer`'s maps dropped from `profiles`' overrides, nil naming
    /// every profile, and from the shared base where `base` says so.
    public mutating func dropGestureLayer(
        _ layer: String,
        profiles: [String]?,
        base: Bool
    ) throws {
        try rewriteGestureLayers(
            profiles: profiles.map(Set.init),
            base: base
        ) { $0.removing(layer) }
    }

    /// The gesture maps through `transform`: the shared base where
    /// `base` holds, and each override `profiles` names, nil naming
    /// every profile.
    private mutating func rewriteGestureLayers(
        profiles: Set<String>? = nil,
        base: Bool = true,
        _ transform: (LayerGestures) -> LayerGestures
    ) throws {
        guard gestures.baseTouched.isEmpty,
            gestures.touched.values.allSatisfy(\.isEmpty)
        else { throw LayerPassError.afterRowEncode }
        let newBase = base ? transform(storedGestureBase) : storedGestureBase
        var overrides: [(profile: String, override: LayerGestures?)] = []
        for profile in gestures.profiles {
            let old = gestures.gestureOverride(for: profile)
            let reached = profiles?.contains(profile) ?? true
            let new = reached ? old.map(transform) : old
            if new != old { movedGestureProfiles.insert(profile) }
            overrides.append(
                (profile, new.flatMap { $0.isEmpty ? nil : $0 })
            )
        }
        storedGestureBase = newBase
        gestures = .gestures(
            base: newBase,
            overrides: overrides,
            shortcutBase: gestureShortcutBase
        )
    }
}

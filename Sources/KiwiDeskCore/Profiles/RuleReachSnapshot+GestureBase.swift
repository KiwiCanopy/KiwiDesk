import Foundation

/// The "Shortcuts use" switch over the stored gesture maps (#3444):
/// each layer's shared map moves onto the new base and every
/// profile's override follows it, layer by layer (#3535), as
/// `moveShortcutBase` moves the shortcut files. Laid over the files
/// AHEAD of the row encode.
extension RuleReachSnapshot {
    /// Moves the shared maps onto `base` — save the keys `staying`
    /// names — and each profile's override after them, then rebuilds
    /// the gesture table over the seeds on `base`. Moving onto the
    /// base the maps already sit on moves nothing.
    public mutating func moveGestureBase(
        onto base: ShortcutBase,
        staying: (LayerGestureKey) -> Bool
    ) throws {
        guard gestures.baseTouched.isEmpty,
            gestures.touched.values.allSatisfy(\.isEmpty)
        else { throw LayerPassError.afterRowEncode }
        guard base != gestureShortcutBase else { return }
        let layers = Set(storedGestureBase.layers).union(
            gestures.profiles.flatMap {
                gestures.gestureOverride(for: $0)?.layers ?? []
            }
        )
        var movedBase = LayerGestures()
        var moves: [String: [GestureKey: GestureBaseSwitch.Move]] = [:]
        for layer in layers.union([KeyLayer.defaultName]) {
            let moved = GestureBaseSwitch.move(
                storedGestureBase[layer],
                from: gestureShortcutBase,
                onto: base,
                layer: layer,
                staying: { staying(LayerGestureKey(layer, $0)) }
            )
            movedBase[layer] = moved.map
            moves[layer] = moved.moves
        }
        var overrides: [(profile: String, override: LayerGestures?)] = []
        for profile in gestures.profiles {
            let old = gestures.gestureOverride(for: profile)
            let new = old?.mapLayers { layer, map in
                map.following(moves[layer] ?? [:])
            }
            if new != old { movedGestureProfiles.insert(profile) }
            overrides.append((profile, new.flatMap { $0.isEmpty ? nil : $0 }))
        }
        storedGestureBase = movedBase
        gestureShortcutBase = base
        gestures = .gestures(
            base: movedBase,
            overrides: overrides,
            shortcutBase: base
        )
    }
}

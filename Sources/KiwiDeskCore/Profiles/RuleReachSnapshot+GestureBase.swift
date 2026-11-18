import Foundation

/// The "Shortcuts use" switch over the stored gesture maps (#3444):
/// the shared map moves onto the new base and every profile's
/// override follows it, as `moveShortcutBase` moves the shortcut
/// files. Laid over the files AHEAD of the row encode.
extension RuleReachSnapshot {
    /// Moves the shared map onto `base` — save the keys `staying`
    /// names — and each profile's override after it, then rebuilds
    /// the gesture table over the seeds on `base`. Moving onto the
    /// base the map already sits on moves nothing.
    public mutating func moveGestureBase(
        onto base: ShortcutBase,
        staying: (GestureKey) -> Bool
    ) throws {
        guard gestures.baseTouched.isEmpty,
            gestures.touched.values.allSatisfy(\.isEmpty)
        else { throw LayerPassError.afterRowEncode }
        guard base != gestureShortcutBase else { return }
        let moved = GestureBaseSwitch.move(
            storedGestureBase,
            from: gestureShortcutBase,
            onto: base,
            staying: staying
        )
        let profiles = gestures.profiles
        var overrides: [(profile: String, override: GestureMap?)] = []
        for profile in profiles {
            let old = gestures.gestureOverride(for: profile)
            let new = old?.following(moved.moves)
            if new != old { movedGestureProfiles.insert(profile) }
            overrides.append((profile, new.flatMap { $0.isEmpty ? nil : $0 }))
        }
        storedGestureBase = moved.map
        gestureShortcutBase = base
        gestures = .gestures(
            base: moved.map,
            overrides: overrides,
            shortcutBase: base
        )
    }
}

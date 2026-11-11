import Foundation

/// Where the gesture bindings reach their fronts (#3199).
extension KiwiCore {
    /// The ONE resolve: the seeds, the base over them and the live
    /// profile's override on top, handed to the pointer tap's grab.
    /// The scroll tap and the touch reader read it through
    /// `applyScrollGestures`, which every caller runs right after,
    /// since a swipe's direction reads the scroll's Natural
    /// scrolling. A config load passes the base it read; a profile
    /// apply passes nil and keeps the base in hand, which under a
    /// Lua-owned config is what `init.lua`'s verbs declared.
    func applyGestures(base: GestureMap? = nil, profile: GestureMap?) {
        let gestures = mouse.gestures
        gestures.adopt(
            base: base ?? gestures.base,
            profileOverride: profile
        )
        mouse.pointer.configure(grab: Self.grabSettings(gestures.resolved))
    }

    /// A config load's reset: the load applies at its tail.
    func resetGestureInputs() {
        mouse.gestures.resetInputs()
    }

    /// The pointer tap's grab: every `drag` and `hover_move` row,
    /// in the list's order, a `drag` row starting on a press and a
    /// `hover_move` row on the keys alone.
    static func grabSettings(
        _ resolved: [GestureKey: GestureAction]
    ) -> ModifierDragSettings {
        var bindings: [ModifierDragBinding] = []
        for key in resolved.keys.sorted() {
            guard case .grab(let grab) = resolved[key],
                let start = key.input.grabStart
            else { continue }
            bindings.append(
                ModifierDragBinding(grab, chord: key.keys, start: start)
            )
        }
        return ModifierDragSettings(bindings).sanitized
    }

    /// The scroll tap's routes: each chord's swipe, wheel and
    /// sideways-wheel bindings.
    static func scrollRoutes(
        _ resolved: [GestureKey: GestureAction]
    ) -> [ScrollChord: ScrollRoute] {
        var routes: [ScrollChord: ScrollRoute] = [:]
        for (key, action) in resolved {
            switch key.input {
            case .swipe2: routes[key.keys, default: .init()].swipe = action
            case .wheel: routes[key.keys, default: .init()].wheel = action
            case .wheelX: routes[key.keys, default: .init()].wheelX = action
            default: continue
            }
        }
        return routes
    }
}

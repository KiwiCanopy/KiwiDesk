import Foundation

/// Where the gesture bindings reach their fronts (#3199).
extension KiwiCore {
    /// The ONE resolve: the seeds, the base over them and the live
    /// profile's override on top, handed to the three fronts — the
    /// pointer tap's grab here, the scroll tap and the touch reader
    /// through `applyScrollGestures`, the one caller of their doors.
    /// A config load passes the base it read; a profile apply passes
    /// nil and keeps the base in hand, which under a Lua-owned config
    /// is what `init.lua`'s verbs declared.
    func applyGestures(base: GestureMap? = nil, profile: GestureMap?) {
        let gestures = mouse.gestures
        gestures.adopt(
            base: base ?? gestures.base,
            profileOverride: profile
        )
        mouse.pointer.configure(grab: Self.grabSettings(gestures.resolved))
        // The scroll resolve hands the touch reader its bindings,
        // since a swipe's direction reads the scroll's Natural
        // scrolling.
        applyScrollGestures(profile: mouse.scroll.profileOverride)
    }

    /// A config load's reset: the load applies at its tail.
    func resetGestureInputs() {
        mouse.gestures.resetInputs()
    }

    /// The pointer tap's grab: the first drag binding of each grab
    /// action, in the list's order. A second drag binding of the
    /// same action is stored and never fires: one chord per grab.
    static func grabSettings(
        _ resolved: [GestureKey: GestureAction]
    ) -> ModifierDragSettings {
        var settings = ModifierDragSettings(
            move: ModifierDragBinding(chord: []),
            resize: ModifierDragBinding(chord: [])
        )
        for key in resolved.keys.sorted() where key.input.isDrag {
            guard case .grab(let grab) = resolved[key],
                let start = key.input.grabStart,
                settings[grab.action].isOff
            else { continue }
            settings[grab.action] = ModifierDragBinding(
                chord: key.keys,
                start: start
            )
        }
        return settings.sanitized
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

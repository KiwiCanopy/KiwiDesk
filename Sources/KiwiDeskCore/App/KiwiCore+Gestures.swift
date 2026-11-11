import Foundation

/// Where the gesture bindings reach their fronts (#3199).
extension KiwiCore {
    /// The ONE resolve: the seeds, the base over them and the live
    /// profile's override on top, handed to the pointer tap's grab,
    /// then the scroll settings resolved and the scroll tap and the
    /// touch reader handed the bindings, since a swipe's direction
    /// reads the scroll's Natural scrolling. A config load passes
    /// the bases it read; a profile apply passes nil and keeps the
    /// bases in hand, which under a Lua-owned config is what
    /// `init.lua`'s verbs declared. A scroll setting alone, which
    /// moves no binding, takes `applyScrollGestures`.
    func applyGestures(
        base: GestureMap? = nil,
        profile: GestureMap?,
        scrollBase: ScrollGestureBase? = nil,
        scrollProfile: ScrollGestureOverride?
    ) {
        let gestures = mouse.gestures
        gestures.adopt(
            base: base ?? gestures.base,
            profileOverride: profile
        )
        mouse.pointer.configure(grab: Self.grabSettings(gestures.resolved))
        applyScrollGestures(base: scrollBase, profile: scrollProfile)
    }

    /// A config load's reset: the load applies at its tail.
    func resetGestureInputs() {
        mouse.gestures.resetInputs()
    }

    /// The pointer tap's grab, from the resolved list
    /// (`ModifierDragSettings.init(resolved:)`).
    static func grabSettings(
        _ resolved: [GestureKey: GestureAction]
    ) -> ModifierDragSettings {
        ModifierDragSettings(resolved: resolved)
    }

    /// The scroll tap's routes: each chord's swipe, wheel and
    /// sideways-wheel bindings.
    static func scrollRoutes(
        _ resolved: [GestureKey: GestureAction]
    ) -> [ScrollChord: ScrollRoute] {
        var routes: [ScrollChord: ScrollRoute] = [:]
        for (key, action) in resolved {
            switch key.input {
            case .swipe2: routes[key.chord, default: .init()].swipe = action
            case .wheel: routes[key.chord, default: .init()].wheel = action
            case .wheelX: routes[key.chord, default: .init()].wheelX = action
            default: continue
            }
        }
        return routes
    }
}

import Foundation

/// Where the gesture bindings reach their fronts (#3199).
extension KiwiCore {
    /// The ONE resolve: the active keybinding layer's seeds, its
    /// base over them and the live profile's override on top
    /// (#3535), handed to the pointer tap's grab
    /// and its buttons,
    /// then the scroll settings resolved and the scroll tap and the
    /// touch reader handed the bindings, since a swipe's direction
    /// reads the scroll's Natural scrolling. A config load passes
    /// the bases it read; a profile apply passes nil and keeps the
    /// bases in hand, which under a Lua-owned config is what
    /// `init.lua`'s verbs declared; `shortcutBase` likewise, nil
    /// keeping the one in hand. A scroll setting alone, which
    /// moves no binding, takes `applyScrollGestures`.
    func applyGestures(
        base: LayerGestures? = nil,
        shortcutBase: ShortcutBase? = nil,
        profile: LayerGestures?,
        scrollBase: ScrollGestureBase? = nil,
        scrollProfile: ScrollGestureOverride?
    ) {
        let gestures = mouse.gestures
        gestures.adopt(
            base: base ?? gestures.base,
            profileOverride: profile,
            shortcutBase: shortcutBase ?? gestures.shortcutBase,
            layer: keys.currentLayer
        )
        mouse.pointer.configure(grab: Self.grabSettings(gestures.resolved))
        mouse.pointer.configure(
            buttons: PointerButtonSettings(resolved: gestures.resolved)
        )
        applyScrollGestures(base: scrollBase, profile: scrollProfile)
        keys.setHyperGestureBound(
            gestures.resolved.keys.contains { $0.chord.contains(.hyper) }
        )
    }

    /// A keybinding layer switch: the gestures re-resolve onto the
    /// layer now active, then the event goes out.
    func layerChanged(_ from: String, _ to: String) {
        layerChangedGestures()
        emitLayerChange(from: from, to: to)
    }

    /// The bindings re-resolved onto the layer now active, every
    /// input kept (#3535).
    func layerChangedGestures() {
        let gestures = mouse.gestures
        guard gestures.layer != keys.currentLayer else { return }
        applyGestures(
            profile: gestures.profileOverride,
            scrollProfile: mouse.scroll.profileOverride
        )
    }

    /// Hands the three gesture readers the Hyper layer's one hold
    /// (#3407): Hyper is no event flag, so each reads it there.
    func wireHyperHold() {
        let hold = keys.hyperHold
        mouse.scroll.hyperHold = hold
        mouse.pointer.hyperHold = hold
        mouse.trackpad.hyperHold = hold
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

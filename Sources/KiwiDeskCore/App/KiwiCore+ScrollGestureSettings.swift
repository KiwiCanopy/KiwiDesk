import Foundation

/// Where the scroll gestures' settings reach the tap (#1656).
extension KiwiCore {
    /// The ONE resolve: the base with the live profile's override
    /// on top, sanitised, handed to the tap through the front's one
    /// door. A config load passes the base it read; a profile
    /// apply passes nil and keeps the base in hand, which under a
    /// Lua-owned config is what `init.lua`'s verbs declared.
    func applyScrollGestures(
        base: ScrollGestureBase? = nil,
        profile: ScrollGestureOverride?
    ) {
        let gestures = mouse.scroll
        let base = base ?? gestures.base
        let raw = profile?.resolved(onto: base) ?? base
        let resolved = raw.sanitized
        // Said once per change, not on every re-resolve.
        if resolved != raw, resolved != gestures.resolved {
            onLog("scroll_gesture: refused values turned off or clamped")
        }
        let bindings = mouse.gestures.resolved
        gestures.adoptResolution(
            base: base,
            profileOverride: profile,
            resolved: resolved,
            routes: Self.scrollRoutes(bindings)
        )
        mouse.trackpad.resolve(
            bindings,
            natural: gestures.settings.naturalTrackpad
        )
    }

    /// A config load's reset: the load configures at its tail.
    func resetScrollGestureInputs() {
        mouse.scroll.resetInputs()
    }

    /// `scroll_gesture.*`: writes the BASE, so a profile's own
    /// override still wins, and lasts until the next config load.
    /// No window moves, so no retile.
    func scrollGestureCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        var base = mouse.scroll.base
        switch command {
        case "scroll_gesture.set_natural_scrolling":
            guard let value = Self.naturalScrolling(args.first) else {
                return .fail("expected boolean or \"system\"")
            }
            guard let raw = args.dropFirst().first?.stringValue else {
                base.naturalTrackpad = value
                base.naturalMouse = value
                break
            }
            switch ScrollInput(rawValue: raw) {
            case .trackpad: base.naturalTrackpad = value
            case .mouse: base.naturalMouse = value
            case nil: return .expected(ScrollInput.self)
            }
        case "scroll_gesture.set_long_swipes":
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            base.longSwipes = enabled
        case "scroll_gesture.set_step_distance":
            let range = ScrollGestureBase.stepDistanceRange
            guard let points = args.first?.numberValue,
                range.contains(points)
            else {
                return .fail(
                    "expected points from \(Int(range.lowerBound)) "
                        + "to \(Int(range.upperBound))"
                )
            }
            base.stepDistance = points
        default:
            return .fail("unknown command: \(command)")
        }
        applyScrollGestures(
            base: base,
            profile: mouse.scroll.profileOverride
        )
        return .ok()
    }

    /// A Natural scrolling argument: a boolean pins it, `"system"`
    /// follows macOS (#3200).
    static func naturalScrolling(_ arg: JSONValue?) -> NaturalScrolling? {
        if let flag = arg?.boolValue { return .pinned(flag) }
        return arg?.stringValue == NaturalScrolling.systemSpelling
            ? .system : nil
    }
}

import Foundation

/// Where the scroll gestures' settings reach the tap (#1656).
extension KiwiCore {
    /// The ONE `configure` caller: the base with the live
    /// profile's override on top. A config load passes the base it
    /// read; a profile apply passes nil and keeps the base in hand,
    /// which under a Lua-owned config is what `init.lua`'s verbs
    /// declared. So no path hands the tap a value that skipped the
    /// override.
    func applyScrollGestures(
        base: ScrollGestureBase? = nil,
        profile: ScrollGestureOverride?
    ) {
        let gestures = mouse.scroll
        if let base { gestures.base = base }
        gestures.profileOverride = profile
        let resolved =
            profile?.resolved(onto: gestures.base) ?? gestures.base
        gestures.resolved = resolved
        gestures.configure(resolved.tapSettings)
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
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            guard let raw = args.dropFirst().first?.stringValue else {
                base.naturalTrackpad = enabled
                base.naturalMouse = enabled
                break
            }
            switch ScrollInput(rawValue: raw) {
            case .trackpad: base.naturalTrackpad = enabled
            case .mouse: base.naturalMouse = enabled
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
        case "scroll_gesture.set_pan", "scroll_gesture.set_space_step":
            guard
                let text = args.first?.stringValue,
                let chord = ScrollChord(spelling: text)
            else {
                return .fail(
                    "expected modifiers like \"control+option\", "
                        + "or \"\" for off"
                )
            }
            let pan = command.hasSuffix("pan")
            let resolved =
                mouse.scroll.profileOverride?.resolved(onto: base)
                ?? base
            if let refusal = Self.scrollChordRefusal(
                chord,
                other: pan ? resolved.spaceStep : resolved.pan
            ) {
                return .fail(refusal)
            }
            if pan { base.pan = chord } else { base.spaceStep = chord }
        default:
            return .fail("unknown command: \(command)")
        }
        applyScrollGestures(
            base: base,
            profile: mouse.scroll.profileOverride
        )
        return .ok()
    }

    /// The #1656 ruling's refusals, in CLI English: one modifier
    /// alone belongs to macOS and apps, and the two gestures never
    /// share a chord. Empty (off) is always accepted.
    static func scrollChordRefusal(
        _ chord: ScrollChord,
        other: ScrollChord
    ) -> String? {
        guard !chord.isEmpty else { return nil }
        if chord.rawValue.nonzeroBitCount < 2 {
            return "needs two or more modifiers"
        }
        if chord == other {
            return "the other scroll gesture already uses "
                + chord.spelling
        }
        return nil
    }
}

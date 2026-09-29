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
        let resolved = sanitizedScrollGestures(
            profile?.resolved(onto: gestures.base) ?? gestures.base
        )
        gestures.resolved = resolved
        gestures.configure(resolved.tapSettings)
    }

    /// A config load's reset: the inputs go back to the defaults
    /// without configuring, since the load configures at its tail.
    func resetScrollGestureInputs() {
        mouse.scroll.base = .defaults
        mouse.scroll.profileOverride = nil
    }

    /// The refusals the recorder and the verbs make at entry,
    /// applied once more to the RESOLVED value, which a hand-edited
    /// file or two cascade levels can still reach: a lone modifier
    /// turns that gesture off, a shared chord stays the pan's (the
    /// `Consumer` order), and the step distance is clamped.
    private func sanitizedScrollGestures(
        _ value: ScrollGestureBase
    ) -> ScrollGestureBase {
        var result = value
        if ScrollChordRefusal.of(value.pan, other: [], heldBy: .step)
            != nil
        {
            onLog("scroll_gesture: pan needs two modifiers; off")
            result.pan = []
        }
        if ScrollChordRefusal.of(
            value.spaceStep,
            other: result.pan,
            heldBy: .pan
        ) != nil {
            onLog("scroll_gesture: space_step refused; off")
            result.spaceStep = []
        }
        let range = ScrollGestureBase.stepDistanceRange
        result.stepDistance = min(
            max(result.stepDistance, range.lowerBound),
            range.upperBound
        )
        return result
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
            // The base is written, and the live profile resolves
            // over it: the chord must clear the other in both.
            let others =
                pan
                ? [base.spaceStep, resolved.spaceStep]
                : [base.pan, resolved.pan]
            for other in others {
                if let refusal = Self.scrollChordRefusal(
                    chord,
                    other: other,
                    heldBy: pan ? .step : .pan
                ) {
                    return .fail(refusal)
                }
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

    /// The #1656 ruling's refusals, in CLI English.
    static func scrollChordRefusal(
        _ chord: ScrollChord,
        other: ScrollChord,
        heldBy: ScrollGestures.Consumer
    ) -> String? {
        switch ScrollChordRefusal.of(chord, other: other, heldBy: heldBy) {
        case nil: return nil
        case .singleModifier: return "needs two or more modifiers"
        case .otherGesture:
            return "the other scroll gesture already uses "
                + chord.spelling
        }
    }
}

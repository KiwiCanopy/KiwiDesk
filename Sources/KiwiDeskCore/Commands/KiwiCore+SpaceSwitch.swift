import Foundation

/// `focus_space` and the switch it shares with the ⌃⌥⌘ + scroll
/// Space step (#1519).
extension KiwiCore {
    func focusSpace(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        switchSpace(to: SpaceID(raw), warp: true)
        return .ok()
    }

    /// `focus_space`'s switch. `warp: false` is a pointer gesture's
    /// (#1519): the pointer stays where the hand holds it.
    func switchSpace(to space: SpaceID, warp: Bool) {
        // Who is frontmost BEFORE the switch: the settle uses it
        // to tell "the handoff's activate never landed" (#463)
        // apart from "the user moved on since".
        let priorFrontmost = frontmostPIDProvider?()
        tiler.meter.noteSpaceSwitch()  // #1508
        // A first visit to an undeclared id gets its screen ahead
        // of the slide's read, so it slides too (#1994).
        state.workspaces.ensureSpace(space)
        placeUnplacedSpaces()
        let slide = spaceSlideIntent(to: space)
        state.workspaces.activate(space)
        logSpaceContents(space)
        spaceSwitchRetile(asSwitch: true, slide: slide)
        // Floats and sticky windows come back above the
        // tiled plane, then real (AX) focus lands on the
        // space's last focused window — otherwise keystrokes
        // keep going to a window that is now stashed
        // offscreen (#412 QA: without the raise, a restored
        // float sat buried behind full-frame tiled windows).
        // Warp at INTENT time: the deferred re-assert runs
        // under the z-order counter, where warps are swallowed
        // — and the forced retile above already assigned the
        // slot the warp targets.
        let next = resolveSpaceSwitchFocusTarget()
        if warp, let next {
            warpMouseToFocused(next)
        }
        raiseFloatsAndSticky(thenFocus: next)
        if next == nil {
            yieldFocusAfterEmptySwitch()
        }
        emitSpaceChange()
        scheduleSpaceSettle(
            space,
            priorFrontmost: priorFrontmost
        )
    }
}

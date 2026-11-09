import CoreGraphics

/// The verbs that move the focused float and change no size or
/// membership (#3007). They act on the focus anchor, judged and
/// bounded where it renders, so a sticky traveler and an out pocket
/// window stay in the Space they are filed in.
extension KiwiCore {
    /// The anchor a float-move verb may move, and where it renders.
    struct FloatMoveTarget {
        let id: WindowID
        let window: ManagedWindow
        let space: SpaceID
        let region: CGRect
    }

    /// What a float-move verb acts on, or the answer it gives instead.
    enum FloatMoveFocus {
        case target(FloatMoveTarget)
        case answered(CommandResponse)
    }

    /// The anchor as a float-move verb may move it: full screen
    /// refuses first, then a tiled focus, each with its pill. A drag
    /// or an aspect probe stands the verb down: a write now would
    /// fight the hand or read as the user moving it (#2973).
    func floatMoveFocus() -> FloatMoveFocus {
        guard let id = focusedWindowID,
            let window = state.windows[id]
        else { return .answered(.fail("no focused window")) }
        if window.isFullscreen {
            refuseMoveWhileFullscreen(id)
            return .answered(.fail("the focused window is fullscreen"))
        }
        guard isEffectiveFloatForPlacement(id) else {
            refuseMoveNotFloating(id)
            return .answered(.fail("the focused window is not floating"))
        }
        guard let space = floatPlacementSpace(of: id),
            let region = floatBounds(on: space)
        else {
            return .answered(.fail("no screen to lay the space out on"))
        }
        if tiler.dragExemptWindow == id || floatAspectProbeOwed(id) {
            return .answered(.ok())
        }
        return .target(
            FloatMoveTarget(
                id: id,
                window: window,
                space: space,
                region: region
            )
        )
    }

    /// `frame` clear of the bars of the Space `target` renders on,
    /// with no bar's push taking its top or left edge out of reach.
    func floatMoveFrame(
        _ frame: CGRect,
        for target: FloatMoveTarget
    ) -> CGRect {
        FloatMove.keepingNearEdges(
            floatFrameClampedClearOfBars(
                target.id,
                frame: frame,
                space: target.space
            ),
            of: frame,
            in: target.region
        )
    }

    /// `center_floating`: the middle of the screen of the Space the
    /// window renders on, clear of the bars, at its own size. Follows
    /// `animations.on_state_change`; reads and writes no remembered
    /// frame, so `float_placement` has no say. A window already there
    /// answers success in silence.
    func centerFloating() -> CommandResponse {
        let target: FloatMoveTarget
        switch floatMoveFocus() {
        case .answered(let response): return response
        case .target(let focus): target = focus
        }
        let id = target.id
        endMaximizeBeforeFloatVerb(id)  // #3036
        let base = tiler.commandedFrame(of: id) ?? target.window.frame
        let centred = floatMoveFrame(
            FloatPlacement.centered(base.size, in: target.region),
            for: target
        )
        guard centred != base else { return .ok() }
        tiler.applyFrame(
            id,
            from: base,
            to: centred,
            animated: tiler.settings.animations.onStateChange,
            sizing: .allSpringSized
        )
        holdRingForStateChange([id])
        return .ok()
    }

    /// `move_floating`: `delta` points along `axis`, positive y moving
    /// down, stopping at the float region, so it never reaches another
    /// screen. A tap and a glide both write instantly. It ends the
    /// float's own Maximize first (#3036), never one standing on a tile
    /// beneath, which is that tile's (#2972). Base and retire as
    /// `resizeFloating`, whose comments argue them.
    func moveFloating(_ args: [JSONValue]) -> CommandResponse {
        guard let axis = args.first?.stringValue,
            axis == "x" || axis == "y",
            let delta = args.dropFirst().first?.numberValue,
            delta.isFinite
        else {
            return .fail("expected axis (x|y) and delta")
        }
        let target: FloatMoveTarget
        switch floatMoveFocus() {
        case .answered(let response): return response
        case .target(let focus): target = focus
        }
        let id = target.id
        endMaximizeBeforeFloatVerb(id)  // #3036
        let isGlideWrite = keys.isApplyingGlideStep
        let base =
            tiler.animation.commandedFrame(
                window: id,
                includingHeldGlide: isGlideWrite
            ) ?? target.window.frame
        let horizontal = axis == "x"
        let moved = FloatMove.holdingTheAsk(
            floatMoveFrame(
                FloatMove.moved(
                    base,
                    horizontal: horizontal,
                    delta: delta,
                    bounds: target.region
                ),
                for: target
            ),
            from: base,
            horizontal: horizontal,
            delta: delta
        )
        // A truncated step cues, its landing on the wall included (#933).
        if FloatMove.stoppedShort(
            of: base,
            at: moved,
            horizontal: horizontal,
            delta: delta
        ) {
            refuseMoveAtBoundary(
                id,
                horizontal
                    ? (delta > 0 ? .right : .left)
                    : (delta > 0 ? .down : .up)
            )
        }
        if moved != base {
            tiler.applyFrame(
                id,
                from: target.window.frame,
                to: moved,
                animated: false
            )
        }
        tiler.animation.recordGlideCommanded(id, frame: moved)
        return .ok()
    }
}

import AppKit
import CoreGraphics
import Foundation

/// Mouse-resize resolution: classifying resize events and
/// applying a finished resize gesture to the layout. The
/// gesture itself travels through the drag pipeline (see
/// KiwiCore+Drag), which calls handleResizeEnd on drop.
extension KiwiCore {
    /// Whether a resized event belongs to a mouse gesture:
    /// the button is still down, or it is the trailing AX
    /// event of a fast resize — released moments ago, with
    /// the press having started near the window's slot edge
    /// (where resize drags begin; app-initiated resizes like
    /// a zoom button don't match).
    func isResizeGesture(_ id: WindowID) -> Bool {
        if NSEvent.pressedMouseButtons & 1 == 1 {
            return true
        }
        guard let press = mouse.press,
            let up = press.upAt,
            Date().timeIntervalSince(up) < 1,
            let slot = tiler.calculatedFrames(
                state: state
            )[id]
        else { return false }
        return MouseResize.nearEdge(
            press.location,
            of: slot
        )
    }

    /// Mouse resize of a tiled window, applied on release:
    /// translate the size delta into the same layout change
    /// the `resize` command makes (neighbors give or take
    /// space). Layouts without a parameter for the resized
    /// axis — and snap_back mode — animate the window back.
    func handleResizeEnd(
        _ id: WindowID,
        slot: CGRect,
        frame: CGRect,
        in space: Space
    ) {
        // The bounds resolve on the space's OWN display (#449):
        // every ratio cap and translate below reads them, and
        // main-screen math was wrong on a secondary monitor.
        guard tiler.settings.mouseResize == .layout,
            let screen = TilingEngine.screen(
                for: space.id,
                in: state
            )
        else {
            // No sizing promise, for the reason spelled out at the
            // settle below: the pointer, not the spring, decided
            // this window's size.
            retile(
                animated: tiler.settings.animations.onWindowResize
            )
            focusWindow(id, warp: false)
            return
        }
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        // Everything below resolves against the active space's
        // params (#17): base value, master classification, and
        // the write target all follow the space's own override,
        // never the global — so a resize can't shift other spaces.
        let stack = tiler.settings.resolvedStack(for: space.id)
        let track = tiler.settings.resolvedTrack(for: space.id)
        // Zone membership via the partition authority — never
        // a re-derived boundary comparison (#67 review).
        let isMaster = StackLayout.partition(
            tiled,
            masterCount: stack.masterCount
        ).master.contains(id)
        // The layout region, not the raw frame (#537): `translate`
        // divides the drag delta by this span and classifies the
        // slot against its midpoint, and both belong to the region
        // the layout filled — the keyboard path's own span now
        // resolves the same way.
        let bounds = tiler.layoutBounds(on: screen)
        let adjustment = MouseResize.translate(
            mode: space.mode,
            isMaster: isMaster,
            stackSplitHorizontal: stack.stackPosition
                .splitsHorizontally,
            trackAxisVertical: track.axis == .vertical,
            slot: slot,
            frame: frame,
            bounds: bounds
        )
        applyResizeAdjustment(
            adjustment,
            for: id,
            in: space,
            bounds: bounds
        )
        // **No sizing promise here**, unlike the keyboard verb —
        // and the difference is not taste, it is the definition
        // (#593). `.allSpringSized` asserts that every window in
        // the pass got its size from the spring. The dragged
        // window got its size from the *pointer*: it is already at
        // its final frame when this runs, so the un-forced retile
        // below usually finds it inside the ±2 pt tolerance and
        // skips it entirely — an instantly-sized window in the
        // batch, which is exactly what the promise denies.
        //
        // "Usually" is the point, not a hedge. `cappedRatioWrite`
        // and the 0.1…0.9 clamp mean a drag past the min-size
        // cliff recomputes a slot far from where the pointer left
        // the window (0.95 → 0.9 is ~96 pt on a 1920 display), and
        // *that* run does re-frame and spring-size it. A promise
        // has to hold on every run, so one run that breaks it is
        // enough to withhold it.
        //
        // The keyboard verb has no such member — both panes spring
        // from the old ratio to the new, on one clock — which is
        // the whole reason that path may promise and this one may
        // not.
        //
        // It would also buy nothing. Smoothing here only affects
        // the NEIGHBOUR, and a neighbour that shrinks is vacating
        // room the dragged window already covers, so the motion is
        // either invisible (dragged window on top) or an obvious
        // artifact (neighbour on top, overhanging mid-flight). The
        // grow direction is smooth regardless — that is #47, and
        // it is untouched here.
        retile(
            animated: tiler.settings.animations.onWindowResize
        )
        // A track resize can flip a track into/out of an overflow
        // cascade — restack the pile once it settles (#193).
        scheduleTrackZOrderRestoreIfOverflowing()
        focusWindow(id, warp: false)
    }

    /// Writes one translated adjustment into the space's
    /// settings — split from `handleResizeEnd` so the
    /// case→setter mapping is testable without a screen.
    /// (Named apart from the profile `apply(...)` family,
    /// whose members classify their own forced retile — this
    /// one never retiles; the caller does.)
    // `window` carries no default on purpose: the track cases
    // no-op without the identity, so a caller that forgot it
    // would compile and silently drop track drags — nil is an
    // explicit answer ("no window identity at this site"),
    // never an omission.
    func applyResizeAdjustment(
        _ adjustment: ResizeAdjustment?,
        for window: WindowID?,
        in space: Space,
        bounds: CGRect
    ) {
        switch adjustment {
        // The ratio and slot writes go through the same capped
        // writers the keyboard `resize` verb calls (#933) —
        // per-side effective minimums, and the refusal cues
        // when the drag ran into one.
        case .bspRatioH(let delta):
            let base =
                tiler.settings.resolvedBsp(for: space)
                .splitRatioH
            writeCappedBspRatio(
                proposed: base + Double(delta),
                axis: "x",
                span: Double(bounds.width),
                space: space,
                focused: window,
                deltaSign: bspDragSign(
                    ratioDelta: Double(delta),
                    axis: "x",
                    space: space,
                    window: window
                )
            )
        case .bspRatioV(let delta):
            let base =
                tiler.settings.resolvedBsp(for: space)
                .splitRatioV
            writeCappedBspRatio(
                proposed: base + Double(delta),
                axis: "y",
                span: Double(bounds.height),
                space: space,
                focused: window,
                deltaSign: bspDragSign(
                    ratioDelta: Double(delta),
                    axis: "y",
                    space: space,
                    window: window
                )
            )
        case .masterRatio(let delta):
            let stack =
                tiler.settings.resolvedStack(for: space)
            let splitH = stack.stackPosition.splitsHorizontally
            let available =
                splitH ? bounds.width : bounds.height
            let axis = splitH ? "x" : "y"
            // The translate's sign already follows the dragged
            // window (isMaster), so the gesture grows it when
            // the signed ratio delta moves the ratio toward its
            // zone: master grows with +, stack with −.
            let inMaster =
                window.map {
                    StackLayout.partition(
                        state.effectiveTiledMembers(
                            of: space,
                            activeSpace: activeSpace?.id
                        ),
                        masterCount: stack.masterCount
                    ).master.contains($0)
                } ?? true
            writeCappedMasterRatio(
                proposed: stack.masterRatio + delta,
                span: Double(available),
                axis: axis,
                space: space,
                focused: window,
                deltaSign: inMaster ? delta : -delta
            )
        case .scrollWidth(let delta):
            // Resize grows the slot by a pt delta; the shared
            // writer clamps at the effective minimum, which the
            // mouse path previously skipped.
            writeCappedScrollSlot(
                delta: Double(delta),
                space: space,
                bounds: bounds
            )
        case .trackAcross(let delta):
            guard let window else { break }
            let track = tiler.settings.resolvedTrack(for: space.id)
            let vertical = track.axis == .vertical
            let acrossAxis = vertical ? "x" : "y"
            let span =
                Double(vertical ? bounds.width : bounds.height)
            resizeTrackMember(
                window,
                axis: acrossAxis,
                delta: Double(delta),
                span: span,
                space: space
            )
        case .trackAlong(let delta):
            guard let window else { break }
            let track = tiler.settings.resolvedTrack(for: space.id)
            let vertical = track.axis == .vertical
            let alongAxis = vertical ? "y" : "x"
            let span =
                Double(vertical ? bounds.height : bounds.width)
            resizeTrackMember(
                window,
                axis: alongAxis,
                delta: Double(delta),
                span: span,
                space: space
            )
        case nil:
            break
        }
    }

    /// Whether a BSP ratio delta GROWS (+) or SHRINKS (−) the
    /// dragged window: a positive ratio move grows the FIRST
    /// region, so the window's own growth is its side times the
    /// delta — via the shared `MouseResize.bspSide` authority,
    /// never a re-derived comparison. Unknown window/slot keeps
    /// the raw delta (first-region perspective).
    private func bspDragSign(
        ratioDelta: Double,
        axis: String,
        space: Space,
        window: WindowID?
    ) -> Double {
        guard let window,
            let slot = tiler.calculatedFrames(
                state: state
            )[window],
            let screen = TilingEngine.screen(
                for: space.id,
                in: state
            )
        else { return ratioDelta }
        let side = Double(
            MouseResize.bspSide(
                slot: slot,
                bounds: tiler.layoutBounds(on: screen),
                horizontal: axis == "x"
            )
        )
        return side * ratioDelta
    }
}

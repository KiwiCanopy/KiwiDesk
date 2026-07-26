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
            slot: slot,
            frame: frame,
            bounds: bounds
        )
        applyResizeAdjustment(
            adjustment,
            in: space,
            bounds: bounds
        )
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
    func applyResizeAdjustment(
        _ adjustment: ResizeAdjustment?,
        in space: Space,
        bounds: CGRect
    ) {
        switch adjustment {
        case .bspRatioH(let delta):
            let base =
                tiler.settings.resolvedBsp(for: space)
                .splitRatioH
            // Cap at the display's effective range (#383): no
            // invisible ratchet past the min-size cliff, matching
            // the keyboard path and the stack drag (#44).
            let value = SplitDomain.cappedRatioWrite(
                base + Double(delta),
                base: base,
                available: Double(bounds.width),
                minSize: Double(tiler.settings.minWindowSize)
            )
            writeSplitRatioH(
                min(max(value, 0.1), 0.9),
                for: space.id
            )
        case .bspRatioV(let delta):
            let base =
                tiler.settings.resolvedBsp(for: space)
                .splitRatioV
            let value = SplitDomain.cappedRatioWrite(
                base + Double(delta),
                base: base,
                available: Double(bounds.height),
                minSize: Double(tiler.settings.minWindowSize)
            )
            writeSplitRatioV(
                min(max(value, 0.1), 0.9),
                for: space.id
            )
        case .masterRatio(let delta):
            let stack =
                tiler.settings.resolvedStack(for: space)
            let base = stack.masterRatio
            // The ratio lives on the split axis (#222), so the
            // cap's available span follows it too.
            let available =
                stack.stackPosition.splitsHorizontally
                ? bounds.width : bounds.height
            // Cap at the display's effective range (#44), like
            // the keyboard path — no invisible ratchet.
            let value = SplitDomain.cappedRatioWrite(
                base + delta,
                base: base,
                available: Double(available),
                minSize: Double(tiler.settings.minWindowSize)
            )
            writeMasterRatio(
                min(max(value, 0.1), 0.9),
                for: space.id
            )
        case .scrollWidth(let delta):
            // Resize grows the slot by a pt delta: take the current
            // magnitude (a stored pt as-is; auto/% seeded against
            // the scroll axis), add the delta, store as points.
            let scrolling =
                tiler.settings.resolvedScrolling(for: space)
            let horizontal = scrolling.axisIsHorizontal
            let along = horizontal ? bounds.width : bounds.height
            let current = scrolling.slotSize
                .editablePoints(along: along, horizontal: horizontal)
            writeSlotSize(
                .points(clamping: current + delta),
                for: space.id
            )
        case nil:
            break
        }
    }
}

import CoreGraphics

/// The entry-into-floating gather (#1177), the retile's arm. An
/// entry is a change in the mode a space was last DRAWN in
/// (`drawnSpaceModes`), never in the previous write, and a
/// re-file into a floating space is one too (`refiledWindows`);
/// the seed lands AHEAD of
/// `recoverStrandedFloats`, which defers to a pending capture.
/// The argument is state-and-layout.md's.
extension KiwiCore {
    /// Seeds a gather target for every out-of-region member of
    /// each space entering floating mode, then records every
    /// space's mode as drawn. Runs at the top of `retile()`.
    func gatherIntoFloating() {
        let refiled = refiledWindows
        refiledWindows = []
        var drawn: [SpaceID: LayoutMode] = [:]
        for space in state.workspaces.allSpaces {
            drawn[space.id] = space.mode
            guard space.mode == .floating else { continue }
            // A space no pass has drawn is the boot's: its
            // windows' frames are the user's, not a layout's.
            let entered =
                drawnSpaceModes[space.id].map { $0 != .floating }
                ?? false
            guard
                entered
                    || space.windows.contains(where: refiled.contains)
            else { continue }
            seedFloatGather(of: space)
        }
        drawnSpaceModes = drawn
    }

    /// Records the live modes as drawn without gathering: a
    /// replay's frames are the user's, not a layout's.
    func settleDrawnSpaceModes() {
        drawnSpaceModes = Dictionary(
            uniqueKeysWithValues: state.workspaces.allSpaces.map {
                ($0.id, $0.mode)
            }
        )
    }

    private func seedFloatGather(of space: Space) {
        // Judged on the correctness bound, laid in the GROW bound
        // — ring reserved on every edge, so a grid cell flush with
        // a strip takes no second write from the clamp.
        guard let region = floatBounds(on: space.id),
            let grid = floatGrowBounds(on: space.id)
        else { return }
        var frames: [WindowID: CGRect] = [:]
        for id in space.windows {
            guard let window = state.windows[id],
                // A fullscreen member lives on its own macOS
                // Space (#670); the pointer owns a dragged one.
                !window.isFullscreen,
                id != tiler.dragExemptWindow
            else { continue }
            frames[id] = wouldBeFrame(of: window)
        }
        let targets = FloatGather.targets(
            members: space.windows,
            frames: frames,
            region: region,
            grid: grid,
            minSize: tiler.settings.minWindowSize,
            targetDepth: tiler.settings.quitGridTargetDepth
        )
        for (id, target) in targets {
            tiler.seedStash(id, frame: target)
        }
        if !targets.isEmpty {
            let outside = frames.filter {
                FloatGather.isOutside($0.value, of: region)
            }.count
            onLog(
                "space \(space.id) entered floating: \(outside) of "
                    + "\(targets.count) window(s) outside its bounds "
                    + "— gathered all into the grid"
            )
        }
    }

    /// The frame a member would show: its pending capture, then
    /// the commanded frame, then the recent instant target, then
    /// state — every rung, since this site meets every float kind.
    private func wouldBeFrame(of window: ManagedWindow) -> CGRect {
        tiler.stashOriginal(window.id)
            ?? tiler.animation.commandedFrame(
                window: window.id,
                includingHeldGlide: false
            )
            ?? tiler.recentInstantTarget(window.id)
            ?? window.frame
    }
}

import AppKit
import CoreGraphics

/// The traveler re-home net (#1217): a floating-mode space draws
/// no frames, so a tiled sticky traveler rendering on one from
/// another display is moved onto that display from the retile,
/// clear of the strips painted there. A NET, so it asks
/// `EffectiveFloat.applies` with the RENDER space as the mode arm
/// (#1178).
extension KiwiCore {
    func rehomeFloatingTravelers(animated: Bool) {
        let screens = tiler.allScreenBounds()
        guard !screens.isEmpty else { return }
        for display in state.workspaces.displays.keys {
            guard
                let spaceID = state.workspaces.activeSpace(
                    on: display
                ),
                let space = state.workspaces[spaceID],
                let screen = TilingEngine.screen(for: display)
            else { continue }
            let destination = tiler.visibleBounds(screen)
            let members = Set(space.windows)
            let travelers =
                state
                .effectiveTiledMembers(of: space)
                .filter { !members.contains($0) }
            for id in travelers {
                rehomeTraveler(
                    id,
                    onto: destination,
                    mode: space.mode,
                    screens: screens,
                    space: spaceID,
                    animated: animated
                )
            }
        }
    }

    private func rehomeTraveler(
        _ id: WindowID,
        onto destination: CGRect,
        mode: LayoutMode,
        screens: [CGRect],
        space: SpaceID,
        animated: Bool
    ) {
        guard let window = state.windows[id],
            EffectiveFloat.applies(
                isFloating: window.isFloating,
                mode: mode
            ),
            tiler.dragExemptWindow != id
        else { return }
        // The commanded frame outranks the echo-fed state one, so
        // a retile mid-flight compares the move already made.
        let base =
            tiler.animation.commandedFrame(
                window: id,
                includingHeldGlide: false
            )
            ?? tiler.recentInstantTarget(id)
            ?? window.frame
        guard
            let moved = TravelerRehome.target(
                frame: base,
                screens: screens,
                destination: destination,
                scaleSize: tiler.settings.floatScaleOnDisplayChange
            )
        else { return }
        // Fitted and clamped for the RENDER space (#1091/#242):
        // the home-keyed nets never see a traveler. A refused fit
        // falls back to the position clamp alone.
        let fitted = floatFrameFittedClearOfBars(
            id,
            frame: moved,
            space: space
        )
        let target =
            shouldIssueFloatFit(id, current: window.frame, fitted: fitted)
            ? fitted
            : floatFrameClampedClearOfBars(id, frame: moved, space: space)
        tiler.forgetStash(id)
        tiler.applyFrame(
            id,
            from: window.frame,
            to: target,
            animated: animated
        )
        // A size change outside the layout's asks (#677): the
        // echo must not read as a refusal of the previous space's
        // ask, or the next tiled space places a residue.
        tiler.forgetSizeBound(id)
        // A size change outside the layout's asks (#677): the
        // echo must not read as a refusal of the previous space's
        // ask, or the next tiled space places a residue.
        // A size change outside the layout's asks (#677): the
        // echo must not read as a refusal of the previous space's
        // ask, or the next tiled space places a residue.
        // A size change outside the layout's asks (#677): the
        // echo must not read as a refusal of the previous space's
        // ask, or the next tiled space places a residue.
        onLog(
            "traveler re-home: w\(id.raw) moved onto the screen of "
                + "floating space \(space.raw)"
        )
    }
}

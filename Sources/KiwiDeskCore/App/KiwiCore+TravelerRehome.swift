import AppKit
import CoreGraphics

/// The traveler re-home net (#1217): a floating-mode space draws
/// no frames, so a tiled sticky traveler rendering on one from
/// another display kept the frame its previous space gave it. A
/// NET, so it asks `EffectiveFloat.applies` with the RENDER space
/// as the mode arm (#1178); the math is `FloatReanchor`'s and the
/// delivery `reanchorFloat`'s sticky arm.
extension KiwiCore {
    func rehomeFloatingTravelers() {
        let screens = tiler.allScreenBounds()
        guard !screens.isEmpty else { return }
        let active = state.workspaces.activeSpace
        for display in state.workspaces.displays.keys {
            guard
                let spaceID = state.workspaces.activeSpace(
                    on: display
                ),
                let space = state.workspaces[spaceID],
                space.mode == .floating,
                let screen = TilingEngine.screen(
                    for: spaceID,
                    in: state
                )
            else { continue }
            let destination = tiler.visibleBounds(screen)
            let members = Set(space.windows)
            let travelers = state.effectiveTiledMembers(
                of: space,
                activeSpace: active
            ).filter { !members.contains($0) }
            for id in travelers {
                rehomeTraveler(
                    id,
                    onto: destination,
                    mode: space.mode,
                    screens: screens,
                    space: spaceID
                )
            }
        }
    }

    private func rehomeTraveler(
        _ id: WindowID,
        onto destination: CGRect,
        mode: LayoutMode,
        screens: [CGRect],
        space: SpaceID
    ) {
        guard let window = state.windows[id],
            EffectiveFloat.applies(
                isFloating: window.isFloating,
                mode: mode
            ),
            tiler.dragExemptWindow != id
        else { return }
        // A just-commanded frame outranks the echo-fed state one,
        // so a retile before the echo lands compares the move
        // already made and moves nothing twice.
        let base = tiler.recentInstantTarget(id) ?? window.frame
        guard
            let target = TravelerRehome.target(
                frame: base,
                screens: screens,
                destination: destination,
                scaleSize: tiler.settings.floatScaleOnDisplayChange
            )
        else { return }
        tiler.forgetStash(id)
        tiler.applyFrame(
            id,
            from: window.frame,
            to: target,
            animated: tiler.settings.animations.onRelayout
        )
        onLog(
            "traveler re-home: w\(id.raw) moved onto the screen of "
                + "floating space \(space.raw)"
        )
    }
}

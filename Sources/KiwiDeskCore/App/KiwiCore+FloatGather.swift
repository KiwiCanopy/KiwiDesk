import CoreGraphics

/// The entry-into-floating gather (#1177), the retile's arm.
///
/// An ENTRY is judged against the mode a space was last DRAWN
/// in (`drawnSpaceModes`), never against the previous write:
/// the frames on screen are the last drawn layout's, so a
/// config reload that resets every mode and re-declares it
/// without a pass between owes nothing, and a space no pass
/// has drawn yet — the boot's — is recorded rather than
/// gathered, its windows' frames being the user's. A snapshot
/// replay re-states a mode whose entry was gathered when it
/// happened, so `restore` settles the ledger instead
/// (`settleDrawnSpaceModes`).
///
/// Delivery rides the stash seed, the #1352 shape and for the
/// same reason: one delivery path. On a shown space the pass's
/// own restore delivers the seed; on a parked one the park
/// keeps it (its capture guard is nil-only) and the activation
/// delivers. Seeded AHEAD of `recoverStrandedFloats`, which
/// defers to a pending capture, so a monocle pile at the corner
/// takes the grid rather than one centre — no second centring.
extension KiwiCore {
    /// Seeds a gather target for every out-of-region member of
    /// each space entering floating mode, then records every
    /// space's mode as drawn. Runs at the top of `retile()`.
    func gatherIntoFloating() {
        var drawn: [SpaceID: LayoutMode] = [:]
        for space in state.workspaces.allSpaces {
            drawn[space.id] = space.mode
            guard space.mode == .floating,
                let previous = drawnSpaceModes[space.id],
                previous != .floating
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
        guard let region = floatBounds(on: space.id) else { return }
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
            minSize: tiler.settings.minWindowSize,
            targetDepth: tiler.settings.quitGridTargetDepth
        )
        for (id, target) in targets {
            tiler.seedStash(id, frame: target)
        }
        if !targets.isEmpty {
            onLog(
                "space \(space.id) entered floating: gathered "
                    + "\(targets.count) of \(space.windows.count) "
                    + "window(s) from outside its bounds"
            )
        }
    }

    /// The frame a member would show: a pending capture is
    /// where a parked or re-anchored float is going, and the
    /// commanded frame outranks the echo-fed state one mid-flight.
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

import Foundation

/// Persists where the active Space's scrolled Stack zones and
/// Track tracks rest (#2235), the `ScrollRest` loop's twin: the
/// layout reads `Space.runHeads` and this writes back the heads
/// the pass just drew.
extension KiwiCore {
    /// The cover the active Space draws now, nil off Stack and
    /// Track — read off the same `layoutInput` the retile drew.
    var activeRunCover: RunCover? {
        guard let input = tiler.layoutInput(state: state) else {
            return nil
        }
        return RunCover.of(
            space: input.space.id,
            mode: input.space.mode,
            tiled: input.tiled,
            in: input.context
        )
    }

    /// Writes the drawn heads back, and arms the z-order restore
    /// when what the runs hide changed: a hidden window must sit
    /// under the window whose slot it shares, and a new member or
    /// a scroll leaves the stacking stale. Narrow by construction
    /// (#674): an unchanged cover arms nothing, so the restore's
    /// own re-assert cannot re-arm it.
    func persistRunHeads() {
        guard let cover = activeRunCover else {
            drawnRunCover = nil
            return
        }
        if state.workspaces[cover.space]?.runHeads != cover.heads {
            state.workspaces.withSpace(cover.space) {
                $0.runHeads = cover.heads
            }
        }
        guard cover != drawnRunCover else { return }
        drawnRunCover = cover
        if !cover.behind.isEmpty { scheduleZOrderRestore() }
    }

    /// The restore for a Space whose runs hide windows: each
    /// hidden window raised under the window it waits behind,
    /// and only the windows that overlap (#192). False where no
    /// run hides, leaving a whole-zone pile to the cascade order.
    func restoreRunZOrder(_ space: Space) -> Bool {
        guard let cover = activeRunCover, cover.space == space.id,
            !cover.behind.isEmpty
        else { return false }
        let tiled = state.effectiveTiledMembers(of: space)
        raiseSequentially(
            cover.raiseOrder(in: tiled),
            thenFocus: state.focusAnchor(of: space, tiled: tiled),
            above: []
        )
        return true
    }
}

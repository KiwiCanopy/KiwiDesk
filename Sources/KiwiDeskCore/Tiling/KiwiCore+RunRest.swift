import Foundation

/// The scrolled runs' z-order arm (#2235): the cover each Space's
/// arm last answered for, and the hold a removal's retile places
/// on it until the close-return tail decides (#936).
@MainActor
final class RunArm {
    /// Per Space, the `RunCover.stacking` its last arm answered
    /// for — so a switch away and back arms nothing (#674), nor
    /// does a gap or learned-floor change that moves no window
    /// between layers. Pruned to live Spaces at each pass, so a
    /// dropped or renumbered Space's entry goes with it and a
    /// renumbered one arms once; a rekeyed window re-arms once.
    var answered: [SpaceID: [[[WindowID]]]] = [:]
    /// Raised around a removal's event retile: its arm is owed to
    /// the close-return tail rather than issued.
    var holding = false
    /// A held arm the tail still has to pay or stand down.
    var owed = false

    /// The arm a removal owed, taken once.
    func takeOwed() -> Bool {
        defer { owed = false }
        return owed
    }
}

/// Persists where the shown Spaces' scrolled Stack zones and Track
/// tracks rest (#2235), the `ScrollRest` loop's twin: the layout
/// reads `Space.runHeads` and this writes back the heads the pass
/// drew, read off the engine's own record of it.
extension KiwiCore {
    /// The cover the active Space drew in the last retile, nil off
    /// Stack and Track.
    var activeRunCover: RunCover? {
        state.workspaces.activeSpace.flatMap { tiler.runCovers[$0] }
    }

    /// Writes the drawn heads back, and arms the z-order restore
    /// when what the active Space's runs hide changed: a hidden
    /// window must sit under the run it waits behind, and a scroll
    /// or a new member leaves the stacking stale. Narrow by
    /// construction (#674): a cover the Space's last arm answered
    /// for arms nothing, so neither the restore's own re-assert nor
    /// a switch away and back re-arms it.
    func persistRunHeads() {
        for (id, cover) in tiler.runCovers
        where state.workspaces[id]?.runHeads != cover.heads {
            state.workspaces.withSpace(id) { $0.runHeads = cover.heads }
        }
        runArm.answered = runArm.answered.filter {
            state.workspaces[$0.key] != nil
        }
        guard let cover = activeRunCover,
            runArm.answered[cover.space] != cover.stacking
        else { return }
        runArm.answered[cover.space] = cover.stacking
        guard !cover.runs.isEmpty else { return }
        if runArm.holding {
            runArm.owed = true
        } else {
            scheduleZOrderRestore()
        }
    }

    /// Every window a shown Space's run hides (#2235).
    var runHidden: Set<WindowID> {
        Set(tiler.runCovers.values.flatMap { $0.behind.keys })
    }

    /// The slots a classifier reads — a geometric step, a drop
    /// target, a pile test: `calculatedFrames` without the windows
    /// a run hides, which share their edge slot's frame and so
    /// would read as that slot's pile. The one door, so a new
    /// classifier cannot forget the filter. The slots are fresh,
    /// the hidden set the last pass's: between a membership change
    /// and its retile, a window can read on the wrong side of the
    /// run for one press.
    func shownSlots() -> [WindowID: CGRect] {
        let hidden = runHidden
        return tiler.calculatedFrames(state: state).filter {
            !hidden.contains($0.key)
        }
    }

    /// Whether a focus on `id` scrolls a run: the window waits
    /// hidden in the active Space, so the run must move to show
    /// it — the one focus a Stack or Track pass answers, since
    /// focus drives the scroll (#2235 ruling).
    func focusScrollsRun(to id: WindowID) -> Bool {
        activeRunCover?.behind[id] != nil
    }

    /// Whether a focus on `id` owes a pass: a focus-driven layout
    /// always, Stack or Track where the focus scrolls a run. The
    /// one predicate the commanded focus and the focus report share.
    func focusRetiles(to id: WindowID) -> Bool {
        activeSpace?.mode.isFocusDriven == true || focusScrollsRun(to: id)
    }

    /// Runs `retile` for a removal with the run arm held, so the
    /// close-return tail decides it (#936). A hold starts with no
    /// debt, so an earlier one no tail took never pays here.
    func holdingRunArm(_ removal: Bool, _ body: () -> Void) {
        if removal { runArm.owed = false }
        runArm.holding = removal
        defer { runArm.holding = false }
        body()
    }

    /// The restore for a Space whose runs hide windows: every
    /// hidden window raised under its zone's shown run, and only
    /// the windows of zones that hide (#192). False where no run
    /// hides, leaving a whole-zone pile to the cascade order.
    func restoreRunZOrder(_ space: Space) -> Bool {
        guard let cover = tiler.runCovers[space.id], !cover.runs.isEmpty
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

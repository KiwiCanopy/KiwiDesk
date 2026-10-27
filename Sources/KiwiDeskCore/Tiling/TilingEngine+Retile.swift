import AppKit
import CoreGraphics

/// The layout pass (`retile`), split from `TilingEngine.swift` at
/// the §2.1 ceiling.
extension TilingEngine {
    /// Recomputes and applies the active space's layout.
    /// `animated: false` snaps windows to their targets in
    /// one frame-set each (Space switches).
    ///
    /// `pass` (#1488): `.reissue` and `.apply` skip the "already
    /// there" tolerance check and (re)issue every layout frame —
    /// a Space switch needs that, since the check reads state
    /// frames whose AX echoes lag during rapid switching and
    /// strand windows mid-transition — and `.apply` alone probes
    /// past corroborated bounds once (#1055). The parks they
    /// force are only the ones `StashDepartures` owes (#1508).
    ///
    /// `sizing` is the caller's promise about how every window in
    /// this pass gets its size (#593); promising them all
    /// spring-sized lets a shrinking pane slide its shared edge
    /// instead of snapping. It rides the layout loop only: the
    /// stash park and the float restore below place windows that
    /// sit *outside* the layout, and a promise about the layout
    /// cannot extend to them.
    /// `stateChange` is the one window changing state (#2676): it
    /// follows `on_state_change`, springs its size where no
    /// newcomer shares the pass, and its park and stash return
    /// slide.
    public func retile(
        state: StateCoordinator,
        animated: Bool = true,
        pass: RetilePass = .event,
        newlyCreatedWindow: WindowID? = nil,
        sizing: BatchSizing = .mayInstantSize,
        stateChange: WindowID? = nil
    ) {
        guard
            let screen = ScreenList.mainOrFirst
        else { return }
        // An apply probes past bounds once; the one door (#1055).
        withForcedPass(pass.probes) {
            // The issued set, not the slots (#934), recording what
            // each scrolled run draws (#2235).
            runCovers = [:]
            let frames = placedFrames(state: state, recordingCovers: true)
            // The #45 invariant, enforced here because the routing
            // guard counts occurrences, not combinations: a newcomer
            // IS an instant size, so no promise survives one.
            let promised: BatchSizing =
                newlyCreatedWindow == nil ? sizing : .mayInstantSize
            stateChangeWindow =
                stateChange == newlyCreatedWindow ? nil : stateChange
            stateChangeSprings = newlyCreatedWindow == nil
            defer { stateChangeWindow = nil }

            for (id, target) in frames {
                // A window in an active drag keeps its user-driven
                // frame: the pointer owns it. Reframing it here would
                // yank it to its computed slot mid-drag — a Space Bar
                // spring retiles the target's OTHER windows but must
                // leave the dragged one under the cursor (#372). Its
                // real placement happens at drop, once the exemption
                // clears.
                if id == dragExemptWindow { continue }
                issueLayoutFrame(
                    id,
                    target: target,
                    state: state,
                    pass: pass,
                    animated: animated,
                    isNew: id == newlyCreatedWindow,
                    sizing: promised
                )
            }
            stashInactive(
                state: state,
                fallback: screen,
                forcesDepartures: pass.reissues
            )
            restoreStashed(state: state, frames: frames)
        }
    }
}

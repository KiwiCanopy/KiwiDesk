import Foundation

/// The retile behind a Space switch (#207, #2228).
///
/// State (active space, focus, bars, events) commits up front; the
/// frames then land in one instant pass, and an explicit switch
/// names the Space it landed on with the plate (`paySpaceCue`,
/// #2143) where nothing else names it.
///
/// Native macOS Space switches are untouched: AX cannot address
/// an inactive desktop's windows, so that path stays instant in
/// both directions (accepted limitation, #25/#26).
extension KiwiCore {
    /// Always a `.reissue` pass (#1488): a switch must push past
    /// the "already there" tolerance, whose state frames lag
    /// behind AX echoes during rapid switching, and probes
    /// nothing — it is not an apply.
    ///
    /// `cueOn` is the screen an EXPLICIT switch changes, read
    /// before it activated (`spaceSwitchDisplay`); only navigation
    /// passes one — boot, wake, a restore, a display follow and a
    /// Space moved between screens name nothing. The 300 ms
    /// settle re-assert and the Space Bar spring switch do not
    /// route here at all.
    /// `newcomer` is a window arriving with this switch (#1599's
    /// launch follow), given the arrival's #45 start-at-target.
    ///
    /// `asSwitch` says whether this is a switch the user is
    /// watching, which the motion gate never holds (#804), or a
    /// boot, wake or sweep activation, which waits for the hand.
    func spaceSwitchRetile(
        asSwitch: Bool,
        newcomer: WindowID? = nil,
        cueOn: DisplayID? = nil
    ) {
        // The focused ring appears with its window (#1959) — a
        // window this switch brings out of its park; one already
        // shown keeps its ring.
        if let space = activeSpace,
            let anchor = state.focusAnchor(of: space),
            let frame = state.windows[anchor]?.frame,
            tiler.looksStashed(frame)
        {
            borders.holdArrival(of: anchor)
        }
        let pass = { [self] in
            retile(
                animated: false,
                pass: .reissue,
                newlyCreatedWindow: newcomer
            )
        }
        if asSwitch {
            tiler.motionGate.exemptingSwitch(pass)
        } else {
            pass()
        }
        if let cueOn { paySpaceCue(on: cueOn) }
    }
}

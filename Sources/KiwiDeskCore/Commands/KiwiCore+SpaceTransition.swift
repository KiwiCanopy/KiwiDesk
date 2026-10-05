import Foundation

/// The retile behind a Space switch (#207, #1956).
///
/// State (active space, focus, bars, events) commits up front; the
/// frames then land in one instant pass. An explicit switch with
/// `animations.on_space_change` on plays the plate slide around
/// that pass (`playSpaceSlide`): the motion is drawn, and the
/// windows still move once each. The corner slide that animated
/// the windows themselves is retired (#1956).
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
    /// `slide` is the screen an EXPLICIT switch changes, read
    /// before it activated (`spaceSlideIntent`); only navigation
    /// passes one — boot, wake, a restore, a display follow and a
    /// Space moved between screens retile instantly. The 300 ms
    /// settle re-assert and the Space Bar spring switch do not
    /// route here at all.
    /// `newcomer` is a window arriving with this switch (#1599's
    /// launch follow), given the arrival's #45 start-at-target.
    func spaceSwitchRetile(
        newcomer: WindowID? = nil,
        slide: SpaceSlideIntent? = nil
    ) {
        // A Monocle flip owed on the Space being left is DROPPED
        // with its play (#1391): the switch's own raise picks the
        // focus, and the plate must not linger over the arrival.
        dropMonocleFlip()
        if let slide, playSpaceSlide(slide, arriving: newcomer) {
            return
        }
        retile(
            animated: false,
            pass: .reissue,
            newlyCreatedWindow: newcomer
        )
    }
}

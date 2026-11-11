import Foundation

/// The mouse front's handlers, installed once at bootstrap: the
/// scroll pan and Space step (#1656), the modifier grab (#2447)
/// and the trackpad gesture slots (#1873).
extension KiwiCore {
    func wireInputHandlers() {
        wireScrollPan()
        wireModifierGrab()
        wireScrollSpaceStep()
        wireTrackpadGestures()
        // A `.system` Natural scrolling follows macOS live (#3200).
        mouse.scroll.onHostChange = { [weak self] in
            self?.applyScrollGestures(
                profile: self?.mouse.scroll.profileOverride
            )
        }
    }
}

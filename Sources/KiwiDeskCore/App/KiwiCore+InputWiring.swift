import Foundation

/// The mouse front's handlers, installed once at bootstrap: the
/// scroll pan and Space step (#1656), the modifier grab (#2447)
/// and the trackpad gesture slots (#1873).
extension KiwiCore {
    func wireInputHandlers() {
        wireGestures()
        wireModifierGrab()
        // A `.system` Natural scrolling follows macOS live (#3200).
        mouse.scroll.onHostChange = { [weak self] in
            guard let self else { return }
            applyScrollGestures(profile: mouse.scroll.profileOverride)
            onLog(Self.naturalLine(mouse.scroll))
        }
    }

    /// The line a host Natural scrolling change leaves: macOS's
    /// value and what each input then scrolls with (#3200), so a
    /// device check reads the follow from the log.
    static func naturalLine(_ scroll: ScrollGestures) -> String {
        let on = { (flag: Bool) in flag ? "natural" : "standard" }
        return "natural scrolling: macOS "
            + (scroll.hostNatural ? "on" : "off")
            + "; trackpad " + on(scroll.settings.naturalTrackpad)
            + ", mouse " + on(scroll.settings.naturalMouse)
    }
}

import AppKit

/// One resolution of "does our own process hold the key?", read
/// by two stand-downs through different facets (#935) — the
/// `ownKeyWindow` seam's doc on `EventLoop` owns the split's
/// argument.
struct OwnKeyWindowReading: Equatable {
    /// The own key/modal window's `windowNumber` — the facet
    /// the #933 focused-ring suppression compares against the
    /// focus anchor.
    let number: Int
    /// Whether that window is in the dialog class the #929
    /// close-return raise stand-down governs — see
    /// `EventLoop.classifiesAsOwnDialog`.
    let isDialog: Bool
}

/// The close-return raise stand-down (#913/#929/#935) and the
/// dialog classification it narrows to.
extension EventLoop {
    /// Whether the close-return raise stands down for this
    /// removal — the ONE predicate the raise site and the
    /// trailing restore arm ask (#935/#936), so a new clause
    /// lands here, behavior-testable, rather than as a third
    /// inline condition pinned by its own source needle.
    ///
    /// Three arms. A HIDE stands the raise down (#913): macOS
    /// picks the next frontmost app itself when an app hides,
    /// and a raise racing that choice lands the user somewhere
    /// neither chose — with `warp: true` dragging the pointer
    /// after it on a keystroke that never moved the mouse. An
    /// active own DIALOG stands it down too (#929): when an own
    /// progress window closes to yield to a newly opened own
    /// alert (Sparkle's update dialog), raising the background
    /// window submerges the own alert. Dialog, not any own key
    /// window (#935) — the class is `classifiesAsOwnDialog`'s.
    /// And a Desktop follow's EAGER DEPARTURE stands it down
    /// (#1023): that synthetic removal runs at t=0 of the
    /// switch, while the origin is still composited, so the
    /// isListed guard passes on timing a real swipe-away
    /// destroy never has — and the raise would fight the very
    /// follow the user just asked for, warp included.
    func closeReturnRaiseStandsDown(after event: KiwiEvent)
        -> Bool
    {
        event.isHideDrop
            || eagerDepartureInFlight != nil
            || ownKeyWindow()?.isDialog == true
    }

    /// Whether an own key window is in the DIALOG class the
    /// close-return raise stand-down governs (#935): a window a
    /// third-party raise could submerge and whose surface made
    /// no promise that window commands keep working beside it.
    ///
    /// - A MODAL window always is: it blocks the app, so any
    ///   raise beneath it fights a surface the user must answer
    ///   first.
    /// - An `NSPanel` never is: an own utility summon (the ⌃⌥K
    ///   shortcuts panel, whose own doc promises the global
    ///   hotkeys keep firing while it is open) floats above the
    ///   raise's reach, so the successor raise it would
    ///   suppress cannot touch it.
    /// - The `OwnWindowTiling`-marked window never is: it TILES
    ///   (#678 item 18), so the close-return raise beside it is
    ///   the layout's own behavior, not a submersion.
    /// - Everything else own-and-key is chrome the user is
    ///   looking at, and stands the raise down —
    ///   `OwnWindowTiling`'s doc is the census of which own
    ///   window is which; cite it, do not re-list it.
    nonisolated static func classifiesAsOwnDialog(
        isModal: Bool,
        isPanel: Bool,
        isMarkedTilingWindow: Bool
    ) -> Bool {
        if isModal { return true }
        return !isPanel && !isMarkedTilingWindow
    }

    /// Production resolution of the `ownKeyWindow` seam: the
    /// active key window when visible, else the modal window.
    /// A sheet classifies as the window it is attached to —
    /// walked to the chain's ROOT, so a sheet (however nested)
    /// over the marked Settings window inherits its exemption —
    /// while `number` stays the key window's own, which is what
    /// the ring compares against the anchor.
    static func ownKeyWindowReading() -> OwnKeyWindowReading? {
        let app = NSApplication.shared
        let key =
            app.keyWindow?.isVisible == true
            ? app.keyWindow : app.modalWindow
        guard let key else { return nil }
        var classified = key
        while let parent = classified.sheetParent {
            classified = parent
        }
        return OwnKeyWindowReading(
            number: key.windowNumber,
            isDialog: classifiesAsOwnDialog(
                isModal: app.modalWindow === classified
                    || app.modalWindow === key,
                isPanel: classified is NSPanel,
                isMarkedTilingWindow: classified.identifier?
                    .rawValue == OwnWindowTiling.identifier
            )
        )
    }
}

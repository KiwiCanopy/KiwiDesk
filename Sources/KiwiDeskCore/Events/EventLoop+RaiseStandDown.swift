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
    /// Two arms. A HIDE stands the raise down (#913): macOS
    /// picks the next frontmost app itself when an app hides,
    /// and a raise racing that choice lands the user somewhere
    /// neither chose — with `warp: true` dragging the pointer
    /// after it on a keystroke that never moved the mouse. An
    /// active own DIALOG stands it down too (#929): when an own
    /// progress window closes to yield to a newly opened own
    /// alert (Sparkle's update dialog), raising the background
    /// window submerges the own alert. Dialog, not any own key
    /// window (#935) — the class is `classifiesAsOwnDialog`'s.
    func closeReturnRaiseStandsDown(after event: KiwiEvent)
        -> Bool
    {
        event.isHideDrop || ownKeyWindow()?.isDialog == true
    }

    /// Whether an own key window is in the DIALOG class the
    /// close-return raise stand-down governs (#935): a window a
    /// third-party raise could submerge and whose surface made
    /// no promise that window commands keep working beside it.
    ///
    /// - A MODAL window always is: it blocks the app, so any
    ///   raise beneath it fights a surface the user must answer
    ///   first.
    /// - An `NSPanel` never is: the own utility summons — the
    ///   ⌃⌥K shortcuts panel, whose own doc promises the global
    ///   hotkeys keep firing while it is open, and
    ///   `NSColorPanel` — float above the raise's reach, so the
    ///   successor raise they would suppress cannot touch them.
    /// - The `OwnWindowTiling`-marked window never is: it TILES
    ///   (#678 item 18), so the close-return raise beside it is
    ///   the layout's own behavior, not a submersion.
    /// - Everything else own-and-key — Sparkle's alerts, the
    ///   tour, the Config Issues window; `OwnWindowTiling`'s
    ///   doc is the census — is chrome the user is looking at,
    ///   and stands the raise down.
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
    /// A sheet classifies as the window it is attached to — the
    /// sheet belongs to its parent, so a sheet over the marked
    /// Settings window inherits its exemption — while `number`
    /// stays the key window's own, which is what the ring
    /// compares against the anchor.
    static func ownKeyWindowReading() -> OwnKeyWindowReading? {
        let app = NSApplication.shared
        if let key = app.keyWindow, key.isVisible {
            let classified = key.sheetParent ?? key
            return OwnKeyWindowReading(
                number: key.windowNumber,
                isDialog: classifiesAsOwnDialog(
                    isModal: app.modalWindow === classified,
                    isPanel: classified is NSPanel,
                    isMarkedTilingWindow: classified.identifier?
                        .rawValue == OwnWindowTiling.identifier
                )
            )
        }
        if let modal = app.modalWindow {
            return OwnKeyWindowReading(
                number: modal.windowNumber,
                isDialog: true
            )
        }
        return nil
    }
}

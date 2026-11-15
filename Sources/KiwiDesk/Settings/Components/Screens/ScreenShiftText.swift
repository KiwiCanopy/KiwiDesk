import Foundation
import KiwiDeskCore

/// The one author of the boxed-in offer's words (#2756), read by
/// the Screens row, the Mac Checklist row and the alert, so the
/// three say one sentence.
@MainActor
enum ScreenShiftText {
    /// A screen's name, with its position where another screen
    /// shares the name.
    static func named(
        _ name: String,
        at position: ScreenNamePosition?
    ) -> String {
        switch position {
        case nil: return name
        case .left: return L("screens.shift.name.left", "%1$@ (left)", name)
        case .right:
            return L("screens.shift.name.right", "%1$@ (right)", name)
        case .middle:
            return L("screens.shift.name.middle", "%1$@ (middle)", name)
        case .above:
            return L("screens.shift.name.above", "%1$@ (above)", name)
        case .below:
            return L("screens.shift.name.below", "%1$@ (below)", name)
        }
    }

    /// What happens to the boxed-in screen's hidden windows.
    static func title(
        _ boxed: BoxedInScreen,
        in state: ScreenShiftState
    ) -> String {
        L(
            "screens.shift.boxed.title",
            "On %1$@, windows from the Spaces you aren't on show on "
                + "%2$@",
            state.name(of: boxed.screen),
            state.name(of: boxed.landsOn)
        )
    }

    /// Which screens cover its two bottom corners.
    static func cause(
        _ boxed: BoxedInScreen,
        in state: ScreenShiftState
    ) -> String {
        switch boxed.cause {
        case .corners(let left, let right):
            return L(
                "screens.shift.boxed.corners",
                "KiwiDesk tucks them into a bottom corner, but %1$@ "
                    + "sits at the left one and %2$@ at the right one.",
                state.name(of: left),
                state.name(of: right)
            )
        case .belowBoth(let below):
            return L(
                "screens.shift.boxed.below_both",
                "KiwiDesk tucks them into a bottom corner, but %1$@ "
                    + "sits below both.",
                state.name(of: below)
            )
        }
    }

    /// The `?` beside the row: what a parked window is.
    static var help: String {
        L(
            "screens.shift.help",
            "Parked windows are the windows from the Spaces you "
                + "aren't looking at. KiwiDesk tucks them into a "
                + "bottom corner of their screen, out of sight. Where "
                + "other screens cover both bottom corners, they show "
                + "on one of those screens instead."
        )
    }

    /// What the `?` explains, so VoiceOver names the button.
    static var helpSubject: String {
        L("screens.shift.help_subject", "Parked windows")
    }

    static func button(_ offer: ScreenOffer) -> String {
        offer.shifts.count > 1
            ? L("screens.shift.button.many", "Shift Screens…")
            : L("screens.shift.button.one", "Shift Screen…")
    }

    /// Apple's own pane, the link of the shifted and the unfixable
    /// lines.
    static var displaysPath: String {
        L("screens.shift.displays_path", "System Settings ▸ Displays")
    }

    /// After a yes: what moved, and where to change it back.
    static func shifted(_ ids: [String], in state: ScreenShiftState) -> String
    {
        L(
            "screens.shift.shifted",
            "KiwiDesk shifted %1$@ in your macOS screen arrangement, "
                + "so parked windows stay on their own screen. To "
                + "change it back, use %2$@.",
            LocalizedList.join(ids.map(state.name(of:))),
            CrossReferenceRow.linkSlot
        )
    }

    /// No set of moves frees every corner.
    static var unfixable: String {
        L(
            "screens.shift.unfixable",
            "KiwiDesk can't free a corner here by shifting a screen. "
                + "To give each screen one, arrange them in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }
}

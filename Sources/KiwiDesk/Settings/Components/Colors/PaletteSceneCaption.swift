import KiwiDeskCore
import SwiftUI

/// The one sentence describing the panel-scale palette scene.
///
/// Two destinations mount `PaletteSceneThumbnail` at `.panel` —
/// Colours & Animations's "Current colors" and Advanced Colours'
/// "Every color at once" — and they draw the identical picture.
/// They shipped two different English captions of it, into ten
/// catalogs each, with nothing checking the two agreed
/// (localization audit, 2026-08-16). One picture gets one
/// description; the TITLES stay distinct because they name what
/// each page is for, which is a different question from what the
/// drawing shows.
///
/// It labels what IS drawn and does not disclaim what is not.
/// The four hover roles are absent because a still frame can
/// only draw a pointer state as the resting one
/// (`PaletteSceneRoles.withheld`); a caption saying so would
/// teach the reader that a rule exists without teaching the
/// rule, which is the trade `gui.md` settles in favour of
/// labelling the picture.
@MainActor
enum PaletteSceneCaption {
    static var panel: String {
        L(
            "colors.scene.caption",
            "Both bars with their active items, the focused and "
                + "unfocused rings with their state marks, and "
                + "the drag ghost beside its drop zone."
        )
    }
}

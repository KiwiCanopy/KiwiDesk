import KiwiDeskCore
import SwiftUI

/// The App Rules cards' prose (#1022, #1608): every sentence the
/// section draws, the section owning the views and this the
/// words they are handed. Computed per read, never stored: a
/// `static let` resolves `L()` once and keeps that locale for the
/// process (#1311).
extension AppRulesSection {
    /// What an app with no rule does, drawn while both lists are
    /// empty.
    static var emptyProse: String {
        L(
            "app_rules.empty",
            "Apps with no rule tile normally, in whichever "
                + "Space you open them."
        )
    }

    static var noSpacesProse: String {
        L(
            "app_rules.no_spaces",
            "This profile has no Spaces yet, so there is nothing "
                + "to open an app in. Add one in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    /// Says the Space is title-blind, which is the reading the
    /// one-row form got wrong (#1608).
    static var spaceCaption: String {
        L(
            "app_rules.space_list.caption",
            "Each new window of the app opens in its Space, "
                + "whatever its title."
        )
    }

    static var floatCaption: String {
        L(
            "app_rules.float_list.caption",
            "Floating windows keep their own size and position, "
                + "above the tiled ones."
        )
    }

    /// Stated once above both lists while a stored profile is
    /// edited. Must-know, so never only in a popover (#815).
    static var overrideProse: String {
        L(
            "app_rules.override.lists.caption",
            "Rules made here apply to this profile only. Dimmed "
                + "values are inherited from the app-wide rules "
                + "and stay in sync with them; changing one "
                + "overrides it for this profile, and the trash "
                + "removes an inherited rule here. To edit the "
                + "app-wide rules, switch back to the currently "
                + "loaded profile in the header's picker."
        )
    }

    /// The Space card's `?`. That the user travels with a window
    /// they OPEN is #1599's launch follow; the remembered-Space
    /// exception is a precedence detail, so it comes last.
    static var spaceHelp: String {
        L(
            "app_rules.space_list.help",
            "The app's new windows go to its Space, whatever Space "
                + "you are in, and opening the app takes you there "
                + "with them.\n\nAn app can float as well: a "
                + "floating window still belongs to its Space, it "
                + "simply is not tiled inside it. A window KiwiDesk "
                + "already remembers keeps the Space it was last "
                + "in."
        )
    }

    /// The Float card's `?`. `app_rules.float.help` is the one
    /// copy of the float explanation; the title-pattern paragraph
    /// joins only where the mode offers patterns at all.
    var floatHelp: String {
        var text = L(
            "app_rules.float.help",
            "Floating takes this app's matching windows out "
                + "of tiling: each keeps its last position "
                + "and size and stays above the tiled "
                + "windows, instead of snapping into one "
                + "Space's grid.\n\nThis is per-app floating "
                + "— not the **Floating** layout mode, which "
                + "floats every window in a Space."
        )
        if offersTitles {
            text +=
                "\n\n"
                + L(
                    "app_rules.section.help.titles",
                    "%1$@ matches a fragment of a window's "
                        + "title, so an app can float some of "
                        + "its windows and tile the rest.",
                    L(
                        "app_rules.float.scope.titled.resting",
                        "Windows titled"
                    )
                )
        }
        return text
    }
}
